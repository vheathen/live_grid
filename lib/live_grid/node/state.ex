defmodule LiveGrid.Node.State do
  alias LiveGrid.Node, as: LiveNode
  alias LiveGrid.Routes

  @type t :: %__MODULE__{
          me: LiveNode.peer(),
          routes: LiveGrid.Routes.t(),
          neighbors: LiveNode.neighbors(),
          neighbor_refs: LiveNode.neighbor_refs()
        }

  @enforce_keys [:me]
  defstruct me: nil,
            routes: nil,
            neighbors: [],
            neighbor_refs: %{}

  def new(attrs) do
    %{
      struct!(__MODULE__, attrs)
      | routes: Routes.new()
    }
  end
end
