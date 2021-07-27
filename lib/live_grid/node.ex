defmodule LiveGrid.Node do
  use GenServer

  @app :live_grid

  @default_initial_timeout 2_000

  @type x :: non_neg_integer()
  @type y :: non_neg_integer()

  @type t :: {x(), y()}

  @type peer :: t()

  @spec name(peer :: peer()) :: {:via, Registry, {LiveGrid, peer()}}
  def name(peer), do: {:via, Registry, {LiveGrid, peer}}

  def start_link({_x, _y} = me) do
    GenServer.start_link(__MODULE__, me, name: name(me))
  end

  @impl GenServer
  def init(me) do
    {:ok, me}
  end

  def initial_timeout, do: config(:initial_timeout)

  def config(key) do
    @app
    |> Application.get_env(Node, [])
    |> Keyword.get(key, @default_initial_timeout)
  end
end
