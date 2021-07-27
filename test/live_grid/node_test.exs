defmodule LiveGrid.NodeTest do
  use LiveGrid.Case

  alias LiveGrid.Node, as: LiveNode

  setup do
    me = {0, 0}

    [me: me]
  end

  describe "API" do
    test "name/1 should return a correct tuple", %{me: me} do
      assert {:via, Registry, {LiveGrid, ^me}} = LiveNode.name(me)
    end

    test "start_link/1 should start genserver with correct name", %{me: me} do
      assert [] = Registry.lookup(LiveGrid, me)

      start_supervised({LiveNode, me})

      assert [{pid, nil}] = Registry.lookup(LiveGrid, me)
      assert is_pid(pid)
    end

    test "initial_timeout/0 should return initial timeout from settings" do
      configure(Node, :initial_timeout, 3_000)
      assert 3_000 == LiveNode.initial_timeout()
    end

    test "initial_timeout/0 should return default initial timeout if no setting available" do
      configure(Node, :initial_timeout, nil)
      assert 2_000 == LiveNode.initial_timeout()
    end
  end

  describe "init/1" do
    test "should send :connect_to_peers message after :initial_timeout", %{me: me} do
      configure(Node, :initial_timeout, 50)
      assert {:ok, _} = LiveNode.init(me)

      refute_receive :link_to_peers, 45

      assert_receive :link_to_peers, 10
    end
  end
end
