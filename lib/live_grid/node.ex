defmodule LiveGrid.Node do
  use GenServer

  import LiveGrid.Helpers

  alias LiveGrid.Node.State

  alias LiveGrid.Routes
  alias LiveGrid.Routes.Route

  alias LiveGrid.Message.{
    ConnectionOffered,
    ConnectionOfferAccepted,
    RouteUpdated
  }

  # alias LiveGrid.Routes

  @default_initial_timeout 2_000

  @type x :: non_neg_integer()
  @type y :: non_neg_integer()

  @type t :: {x(), y()}

  @type peer :: t()
  @type neighbors :: [peer()]
  @type neighbor_refs :: %{peer() => reference()}
  @type routes :: LiveGrid.Routes.t()

  def offer_connection(attrs) do
    message = ConnectionOffered.new(attrs)
    GenServer.cast(name(message.offered_to), message)
  end

  def accept_connection_offer(attrs) do
    message = ConnectionOfferAccepted.new(attrs)
    GenServer.cast(name(message.offered_from), message)
  end

  def send_route_update(attrs) do
    message = RouteUpdated.new(attrs)
    GenServer.cast(name(message.to), message)
  end

  @spec name(node :: peer()) :: {:via, Registry, {LiveGrid, peer()}}
  def name(node), do: {:via, Registry, {LiveGrid, node}}

  def initial_timeout, do: get_config(Node, :initial_timeout, @default_initial_timeout)

  def possible_neighbors({x, y} = node) do
    for nx <- [x - 1, x, x + 1],
        nx >= 0,
        ny <- [y - 1, y, y + 1],
        ny >= 0,
        {nx, ny} != node,
        do: {nx, ny}
  end

  def start_link({_x, _y} = me) do
    GenServer.start_link(__MODULE__, me, name: name(me))
  end

  @impl GenServer
  def init(me) do
    Process.send_after(self(), :connect_to_peers, initial_timeout())

    {:ok, State.new(me: me)}
  end

  @impl GenServer
  def handle_cast(%ConnectionOffered{offered_from: offerer}, %State{} = state) do
    state =
      if offerer not in state.neighbors do
        state
        |> accept_offer(offerer)
        |> handle_new_peer(offerer)
      else
        state
      end

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(%ConnectionOfferAccepted{accepted_by: accepter}, %State{} = state) do
    state =
      if accepter not in state.neighbors do
        handle_new_peer(state, accepter)
      else
        state
      end

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(%RouteUpdated{destination: me} = _route_update, %State{me: me} = state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(%RouteUpdated{from: peer, weight: weight} = route_update, %State{} = state) do
    state =
      if peer in state.neighbors do
        route =
          Route.new(
            destination: route_update.destination,
            gateway: peer,
            weight: (weight && weight + 1) || weight,
            serial: route_update.serial
          )

        add_or_update_route(state, route)
      else
        state
      end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:connect_to_peers, %State{me: me, neighbors: neighbors} = state) do
    me
    |> possible_neighbors()
    |> Stream.reject(&(&1 in neighbors))
    |> Stream.each(&offer_connection(offered_to: &1, offered_from: me))
    |> Stream.run()

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:DOWN, node_ref, :process, _pid, _reason}, %State{} = state) do
    state =
      case Map.get(state.neighbor_refs, node_ref) do
        nil ->
          state

        node ->
          state
          |> stop_monitoring_and_remove_node_from_neighbors(node_ref)
          |> put_in([Access.key(:routes)], Routes.remove_neighbor_routes(state.routes, node))
          |> send_route_updates_to_neighbors()
      end

    {:noreply, state}
  end

  defp accept_offer(%State{me: me} = state, offerer) do
    accept_connection_offer(accepted_by: me, offered_from: offerer)

    state
  end

  defp handle_new_peer(%State{} = state, peer) do
    state
    |> add_node_as_neighbor_and_start_monitoring(peer)
    |> send_current_routes_to_peer(peer)
    |> add_or_update_route(Route.new(destination: peer, gateway: peer, weight: 1))
  end

  defp add_node_as_neighbor_and_start_monitoring(%State{} = state, node) do
    node_ref = Process.monitor(find_pid(node))

    %{
      state
      | neighbors: [node | state.neighbors],
        neighbor_refs: Map.put(state.neighbor_refs, node_ref, node)
    }
  end

  defp stop_monitoring_and_remove_node_from_neighbors(%State{} = state, node_ref) do
    Process.demonitor(node_ref)

    {node, neighbor_refs} = Map.pop(state.neighbor_refs, node_ref)

    %{
      state
      | neighbor_refs: neighbor_refs,
        neighbors: List.delete(state.neighbors, node)
    }
  end

  defp add_or_update_route(%State{} = state, route) do
    state
    |> put_in([Access.key(:routes)], Routes.update_route(state.routes, route))
    |> send_route_updates_to_neighbors()
    |> put_in([Access.key(:routes), Access.key(:updated_destinations)], [])
  end

  def send_route_updates_to_neighbors(%State{} = state) do
    Enum.each(
      state.neighbors,
      fn neighbor ->
        state.routes
        |> Routes.get_updates_for(neighbor)
        |> Enum.each(fn route_update ->
          send_route_update(
            to: neighbor,
            from: state.me,
            destination: route_update.destination,
            weight: route_update.weight,
            serial: route_update.serial
          )
        end)
      end
    )

    state
  end

  def send_current_routes_to_peer(%State{} = state, peer) do
    for {destination, [shortest_route | _rest]} <- state.routes.entries,
        %Route{weight: weight, serial: serial} = shortest_route do
      send_route_update(
        to: peer,
        from: state.me,
        destination: destination,
        weight: weight,
        serial: serial
      )
    end

    state
  end

  defp find_pid(node) do
    case Registry.lookup(LiveGrid, node) do
      [{pid, nil}] when is_pid(pid) -> pid
      _ -> nil
    end
  end
end
