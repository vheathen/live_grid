defmodule LiveGrid.Message.ConnectionOfferAccepted do
  @moduledoc false

  @type t :: %__MODULE__{
          offered_from: LiveGrid.Node.peer(),
          accepted_by: LiveGrid.Node.peer()
        }

  @enforce_keys [:offered_from, :accepted_by]
  defstruct offered_from: nil, accepted_by: nil

  def new(attrs), do: struct!(__MODULE__, attrs)
end
