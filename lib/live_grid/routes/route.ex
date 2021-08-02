defmodule LiveGrid.Routes.Route do
  @moduledoc false

  @type destination :: LiveGrid.Routes.peer()
  @type gateway :: LiveGrid.Routes.peer()

  @type weight :: non_neg_integer() | nil

  @type unix_timestamp_us :: non_neg_integer()
  @type serial :: unix_timestamp_us()

  @type t :: %__MODULE__{
          destination: destination(),
          gateway: gateway(),
          weight: weight(),
          serial: serial()
        }

  @enforce_keys [:destination, :gateway, :weight]
  defstruct [:destination, :gateway, :weight, :serial]

  @spec new(Enum.t()) :: t()
  def new(attrs) do
    __MODULE__
    |> struct!(attrs)
    |> Map.update(:serial, nil, &(&1 || System.system_time(:microsecond)))
  end
end
