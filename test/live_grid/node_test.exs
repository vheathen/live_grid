defmodule LiveGrid.NodeTest do
  use ExUnit.Case

  alias LiveGrid.Node, as: LiveNode

  @app :live_grid

  setup do
    current_settings = Application.get_all_env(@app)

    on_exit(fn -> Application.put_all_env([{@app, current_settings}]) end)

    :ok
  end

  describe "API" do
    setup do
      me = {0, 0}
      peer = {1, 1}

      # register(peer)

      [me: me, peer: peer]
    end

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
      live_node_config =
        @app
        |> Application.get_env(Node, [])
        |> Keyword.put(:initial_timeout, 3_000)

      Application.put_env(@app, Node, live_node_config)

      assert 3_000 == LiveNode.initial_timeout()
    end

    test "initial_timeout/0 should return default initial timeout if no setting available" do
      live_node_config =
        @app
        |> Application.get_env(Node, [])
        |> Keyword.delete(:initial_timeout)

      Application.put_env(@app, Node, live_node_config)

      assert 2_000 == LiveNode.initial_timeout()
    end
  end
end
