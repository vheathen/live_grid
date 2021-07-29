defmodule LiveGrid.Message.RouteUpdated do
  @moduledoc false

  @type t :: %__MODULE__{
          to: LiveGrid.Node.peer(),
          from: LiveGrid.Routes.gateway(),
          destination: LiveGrid.Routes.destination(),
          weight: LiveGrid.Routes.weight(),
          serial: LiveGrid.Routes.serial()
        }

  @enforce_keys [:to, :from, :destination, :weight, :serial]

  defstruct [:to, :from, :destination, :weight, :serial]

  def new(attrs), do: struct!(__MODULE__, attrs)
end
