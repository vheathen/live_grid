defmodule LiveGrid.Node.State do
  alias LiveGrid.Routes

  @type t :: %__MODULE__{
          me: LiveGrid.Node.peer(),
          routes: LiveGrid.Node.routes(),
          neighbors: LiveGrid.Node.neighbors(),
          neighbor_refs: LiveGrid.Node.neighbor_refs()
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
