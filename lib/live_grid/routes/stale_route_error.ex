defmodule LiveGrid.Routes.StaleRouteError do
  defexception [:message]

  @impl true
  def exception({destination, route}) do
    msg = "got a stale route #{inspect(route)} for destination #{inspect(destination)}"

    %__MODULE__{message: msg}
  end
end
