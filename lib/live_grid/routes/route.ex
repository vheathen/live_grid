defmodule LiveGrid.Routes.Route do
  @moduledoc false

  @type weight :: non_neg_integer() | nil

  @type unix_timestamp_us :: non_neg_integer()
  @type serial :: unix_timestamp_us()

  @type gateway :: LiveGrid.Routes.peer()

  @type t :: %__MODULE__{
          gateway: gateway(),
          weight: weight(),
          serial: serial()
        }

  @enforce_keys [:gateway, :weight, :serial]
  defstruct gateway: nil, weight: nil, serial: nil

  @spec new(Enum.t()) :: t()
  def new(attrs), do: struct!(__MODULE__, attrs)
end
