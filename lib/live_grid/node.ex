defmodule LiveGrid.Node do
  use GenServer

  import LiveGrid.Helpers

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
    Process.send_after(self(), :link_to_peers, initial_timeout())

    {:ok, me}
  end

  def initial_timeout, do: get_config(Node, :initial_timeout, @default_initial_timeout)
end
