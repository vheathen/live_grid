defmodule LiveGrid.Node.State do
  alias LiveGrid.Node, as: LiveNode

  @type t :: %__MODULE__{
          me: LiveNode.peer()
        }

  @enforce_keys [:me]
  defstruct me: nil
end
