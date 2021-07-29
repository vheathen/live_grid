defmodule LiveGrid.Message.ConnectionOffered do
  @moduledoc false

  @type t :: %__MODULE__{
          offered_from: LiveGrid.Node.peer(),
          offered_to: LiveGrid.Node.peer()
        }

  @enforce_keys [:offered_from, :offered_to]

  defstruct offered_from: nil,
            offered_to: nil

  def new(attrs), do: struct!(__MODULE__, attrs)
end
