defmodule LiveGrid.NodeTest do
  use LiveGrid.Case

  alias LiveGrid.Node, as: GridNode
  alias LiveGrid.Node.State

  alias LiveGrid.Routes
  # alias LiveGrid.Routes.Route

  alias LiveGrid.Message.{
    ConnectionOffered,
    ConnectionOfferAccepted,
    RouteUpdated
  }

  # Test grid
  # {1, 1}  {1, 2} {1, 3} {1, 4}
  # {2, 1}  {2, 2} {2, 3} {2, 4}
  # {3, 1}  {3, 2} {3, 3} {3, 4}
  # {4, 1}  {4, 2} {4, 3} {4, 4}

  setup do
    node = {2, 2}

    peer = {9, 9}
    register(peer)

    [node: node, peer: peer]
  end

  describe "API" do
    test "name/1 should return a correct tuple", %{node: node} do
      assert {:via, Registry, {LiveGrid, ^node}} = GridNode.name(node)
    end

    test "start_link/1 should start genserver with correct name", %{node: node} do
      assert [] = Registry.lookup(LiveGrid, node)

      start_supervised({GridNode, node})

      assert [{pid, nil}] = Registry.lookup(LiveGrid, node)
      assert is_pid(pid)
    end

    test "initial_timeout/0 should return initial timeout from settings" do
      configure(Node, :initial_timeout, 3_000)
      assert 3_000 == GridNode.initial_timeout()
    end

    test "initial_timeout/0 should return default initial timeout if no setting available" do
      configure(Node, :initial_timeout, nil)
      assert 2_000 == GridNode.initial_timeout()
    end

    test "possible_peers/1 should return a list of possible peers", %{node: node} do
      assert [
               {1, 1},
               {1, 2},
               {1, 3},
               {2, 1},
               {2, 3},
               {3, 1},
               {3, 2},
               {3, 3}
             ] == GridNode.possible_neighbors(node)
    end

    test "offer_connection/1", %{node: node, peer: peer} do
      GridNode.offer_connection(offered_to: peer, offered_from: node)

      assert_received {:"$gen_cast", %ConnectionOffered{offered_from: ^node, offered_to: ^peer}}
    end

    test "accept_connection_offer/1", %{node: node, peer: peer} do
      GridNode.accept_connection_offer(accepted_by: node, offered_from: peer)

      assert_received {:"$gen_cast",
                       %ConnectionOfferAccepted{accepted_by: ^node, offered_from: ^peer}}
    end

    test "send_route_update/1", %{node: node, peer: peer} do
      GridNode.send_route_update(to: peer, from: node, destination: node, weight: 1, serial: 123)

      assert_receive {:"$gen_cast",
                      %RouteUpdated{
                        to: ^peer,
                        from: ^node,
                        destination: ^node,
                        weight: 1,
                        serial: 123
                      }},
                     50
    end
  end

  describe "init/1" do
    test "should return a state with its coordinate", %{node: node} do
      assert {:ok, %State{me: ^node}} = GridNode.init(node)
    end

    test "should send :connect_to_peers message to itself after :initial_timeout", %{node: node} do
      configure(Node, :initial_timeout, 50)

      assert {:ok, _} = GridNode.init(node)

      refute_receive :connect_to_peers, 45
      assert_receive :connect_to_peers, 20
    end
  end

  describe "handle_info(:connect_to_peers, state)" do
    test "should send ConnectionOffer message to all peers which aren't already connected", %{
      node: node
    } do
      all_neighbors =
        node
        |> GridNode.possible_neighbors()
        |> Enum.shuffle()

      {pretend_as_connected_neigbors, rest_neighbors} =
        Enum.split(all_neighbors, all_neighbors |> length() |> div(2))

      Enum.each(rest_neighbors, &register/1)

      state = State.new(me: node, neighbors: pretend_as_connected_neigbors)

      assert {:noreply, state} == GridNode.handle_info(:connect_to_peers, state)

      Process.sleep(50)

      Enum.each(rest_neighbors, fn peer ->
        assert_received {:"$gen_cast", %ConnectionOffered{offered_from: ^node, offered_to: ^peer}}
      end)

      Enum.each(pretend_as_connected_neigbors, fn peer ->
        refute_received {:"$gen_cast", %ConnectionOffered{offered_from: ^node, offered_to: ^peer}}
      end)
    end
  end

  def connection_offered_setup(%{node: me, peer: peer}) do
    assert %{neighbors: []} = state = State.new(me: me)
    message = ConnectionOffered.new(offered_from: peer, offered_to: me)

    assert {:noreply, %State{me: ^me} = state} = GridNode.handle_cast(message, state)

    another_peer = {10, 10}
    register(another_peer)
    another_message = ConnectionOffered.new(offered_from: another_peer, offered_to: me)

    [
      state: state,
      message: message,
      another_peer: another_peer,
      another_message: another_message
    ]
  end

  def connection_offer_accepted_setup(%{node: me, peer: peer}) do
    assert %{neighbors: []} = state = State.new(me: me)
    message = ConnectionOfferAccepted.new(offered_from: me, accepted_by: peer)

    assert {:noreply, %State{me: ^me} = state} = GridNode.handle_cast(message, state)

    another_peer = {10, 10}
    register(another_peer)
    another_message = ConnectionOfferAccepted.new(offered_from: me, accepted_by: another_peer)

    [
      state: state,
      message: message,
      another_peer: another_peer,
      another_message: another_message
    ]
  end

  [
    {"handle_cast(%ConnectionOffered{}, state)", :connection_offered_setup},
    {"handle_cast(%ConnectionOfferAccepted{}, state)", :connection_offer_accepted_setup}
  ]
  |> Enum.map(fn {describe_title, setup_fun} ->
    describe describe_title do
      setup setup_fun

      if String.contains?(describe_title, "ConnectionOffered") do
        test "should reply to the new neighbor with ConnectionOfferAccepted message if it isn't in the neighbors already",
             %{
               node: me,
               peer: peer,
               state: state,
               message: message
             } do
          assert_received {:"$gen_cast",
                           %ConnectionOfferAccepted{
                             offered_from: ^peer,
                             accepted_by: ^me
                           }}

          assert {:noreply, %State{me: ^me} = _state} = GridNode.handle_cast(message, state)

          refute_received {:"$gen_cast",
                           %ConnectionOfferAccepted{
                             offered_from: ^peer,
                             accepted_by: ^me
                           }}
        end
      end

      test "should add a peer to the neighbors list if its not already there", %{
        node: me,
        peer: peer,
        state: state,
        message: message,
        another_peer: another_peer,
        another_message: another_message
      } do
        assert %State{neighbors: [^peer]} = state

        assert {:noreply, %State{me: ^me, neighbors: [^peer]} = state} =
                 GridNode.handle_cast(message, state)

        assert {:noreply, %State{me: ^me, neighbors: [^another_peer, ^peer]}} =
                 GridNode.handle_cast(another_message, state)
      end

      test "should start monitoring a peer if its not already started", %{
        node: me,
        peer: peer,
        state: state,
        message: message,
        another_peer: another_peer,
        another_message: another_message
      } do
        assert %State{neighbor_refs: neighbor_refs} = state

        assert [{ref, ^peer}] = Enum.into(neighbor_refs, [])
        assert is_reference(ref)

        assert {:noreply, %State{me: ^me, neighbor_refs: neighbor_refs} = state} =
                 GridNode.handle_cast(message, state)

        assert [{ref, ^peer}] = Enum.into(neighbor_refs, [])
        assert is_reference(ref)

        assert {:noreply, %State{me: ^me, neighbor_refs: neighbor_refs} = _state} =
                 GridNode.handle_cast(another_message, state)

        assert [{ref1, ^peer}, {ref2, ^another_peer}] = Enum.into(neighbor_refs, [])
        assert is_reference(ref1)
        assert is_reference(ref2)
      end

      test "should add a route to a peer to the routing list if its not already there", %{
        node: me,
        peer: peer,
        state: state,
        message: message,
        another_peer: another_peer,
        another_message: another_message
      } do
        assert %Routes{entries: %{^peer => [%{gateway: ^peer, weight: 1}]}} = state.routes

        assert {:noreply, %State{me: ^me} = state} = GridNode.handle_cast(message, state)
        assert %Routes{entries: %{^peer => [%{gateway: ^peer, weight: 1}]}} = state.routes

        assert {:noreply, %State{me: ^me} = state} = GridNode.handle_cast(another_message, state)

        assert %Routes{
                 entries: %{
                   ^peer => [%{gateway: ^peer, weight: 1}],
                   ^another_peer => [%{gateway: ^another_peer, weight: 1}]
                 }
               } = state.routes
      end

      test "should sent all current routes to a peer if new", %{
        node: me,
        peer: peer,
        state: state,
        message: message,
        another_peer: another_peer,
        another_message: another_message
      } do
        assert %Routes{entries: %{^peer => [%{gateway: ^peer, weight: 1, serial: peer_serial}]}} =
                 state.routes

        assert {:noreply, %State{me: ^me} = state} = GridNode.handle_cast(another_message, state)

        assert %Routes{
                 entries: %{
                   ^peer => [%{gateway: ^peer, weight: 1}],
                   ^another_peer => [%{gateway: ^another_peer, weight: 1}]
                 }
               } = state.routes

        assert_received {:"$gen_cast",
                         %RouteUpdated{
                           to: ^another_peer,
                           from: ^me,
                           destination: ^peer,
                           weight: 1,
                           serial: ^peer_serial
                         }}
      end

      test "should notify neighbors about the new route", %{
        node: me,
        peer: peer,
        state: state,
        message: _message,
        another_peer: another_peer,
        another_message: another_message
      } do
        refute_received {:"$gen_cast",
                         %RouteUpdated{
                           to: ^peer,
                           from: ^me,
                           destination: ^another_peer,
                           weight: 1,
                           serial: _serial
                         }}

        assert {:noreply, %State{me: ^me} = _state} = GridNode.handle_cast(another_message, state)

        assert_received {:"$gen_cast",
                         %RouteUpdated{
                           to: ^peer,
                           from: ^me,
                           destination: ^another_peer,
                           weight: 1,
                           serial: serial
                         }}

        assert is_integer(serial)
        assert serial < System.system_time(:microsecond)
      end
    end
  end)

  describe "on monitoring peer process exit" do
    setup :connection_offered_setup

    setup %{
      peer: peer,
      state: state,
      another_peer: another_peer
    } do
      assert [{ref, ^peer}] = Enum.into(state.neighbor_refs, [])
      assert peer == Routes.get_next_hop(state.routes, peer)
      assert peer in state.neighbors

      state = %{state | neighbors: [another_peer | state.neighbors]}

      assert {:noreply, state} =
               GridNode.handle_info({:DOWN, ref, :process, self(), :normal}, state)

      [state: state]
    end

    test "should remove a neighbor ref from neighbor_refs if its there", %{
      node: _me,
      peer: _peer,
      state: state
    } do
      assert state.neighbor_refs == %{}
    end

    test "should remove a neighbor from neighbors if its there", %{
      node: _me,
      peer: peer,
      state: state
    } do
      refute peer in state.neighbors
    end

    test "should remove a neighbor's route if its there", %{
      node: _me,
      peer: peer,
      state: state
    } do
      assert is_nil(Routes.get_next_hop(state.routes, peer))
    end

    test "should notify other neighbors than the route is gone", %{
      node: me,
      peer: peer,
      state: _state,
      another_peer: another_peer
    } do
      assert_received {:"$gen_cast",
                       %RouteUpdated{
                         to: ^another_peer,
                         from: ^me,
                         destination: ^peer,
                         weight: nil,
                         serial: serial
                       }}

      assert is_integer(serial)
      assert serial < System.system_time(:microsecond)
    end
  end

  describe "handle_cast(%RouteUpdated{}, state" do
    setup :connection_offered_setup

    setup %{node: me, peer: peer, state: state, another_peer: another_peer} do
      assert %Routes{entries: %{^peer => [%{gateway: ^peer, weight: 1}]}} = state.routes

      state = %{state | neighbors: [another_peer | state.neighbors]}

      destination = {100, 100}

      route_message =
        RouteUpdated.new(to: me, from: peer, destination: destination, weight: 50, serial: 100)

      assert {:noreply, %State{} = state} = GridNode.handle_cast(route_message, state)

      [state: state, destination: destination, message: route_message]
    end

    test "should update local route table", %{
      node: me,
      peer: peer,
      state: state,
      destination: destination
    } do
      assert %Routes{
               entries: %{
                 ^peer => [%{gateway: ^peer, weight: 1}],
                 ^destination => [%{gateway: ^peer, weight: 51, serial: 100}]
               }
             } = state.routes

      route_message =
        RouteUpdated.new(to: me, from: peer, destination: destination, weight: nil, serial: 200)

      assert {:noreply, %State{} = state} = GridNode.handle_cast(route_message, state)

      assert %Routes{
               entries: %{
                 ^peer => [%{gateway: ^peer, weight: 1}],
                 ^destination => [%{gateway: ^peer, weight: nil, serial: 200}]
               }
             } = state.routes
    end

    test "should NOT update local route table if destination == itself", %{
      node: me,
      peer: peer,
      state: state
    } do
      destination = me

      route_message =
        RouteUpdated.new(to: me, from: peer, destination: destination, weight: 1, serial: 200)

      assert {:noreply, %State{} = ^state} = GridNode.handle_cast(route_message, state)
    end

    test "should notify other neighbors about routes update", %{
      node: me,
      destination: destination,
      another_peer: another_peer,
      message: route_message
    } do
      expected_weight = route_message.weight + 1
      serial = route_message.serial

      assert_received {:"$gen_cast",
                       %RouteUpdated{
                         to: ^another_peer,
                         from: ^me,
                         destination: ^destination,
                         weight: ^expected_weight,
                         serial: ^serial
                       }}
    end
  end

  def register(node), do: {:ok, _} = Registry.register(LiveGrid, node, nil)
end
