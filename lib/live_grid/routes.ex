defmodule LiveGrid.Routes do
  alias LiveGrid.Routes.{Route, StaleRouteError}

  @type t :: %__MODULE__{
          entries: entries()
        }
  @type new_routes :: t()
  @type old_routes :: t()

  @type entries :: %{destination() => [entry()]}
  @type entry :: Route.t()

  @type peer :: LiveGrid.Node.peer()
  @type destination :: peer()

  @type route :: LiveGrid.Routes.Route.t()

  defstruct entries: %{}

  @spec new :: t()
  def new, do: %__MODULE__{}

  @spec update_route(t(), destination(), route()) :: {:ok, new_routes()} | {:stale, old_routes()}
  def update_route(%__MODULE__{} = routes, destination, offered_route) do
    routes
    |> get_and_update_in(
      [
        Access.key(:entries),
        Access.key(destination, [])
      ],
      &update_destination_routes(&1, offered_route)
    )
  end

  @spec update_route!(t(), destination(), route()) :: t()
  def update_route!(%__MODULE__{} = routes, destination, route) do
    case update_route(routes, destination, route) do
      {:ok, routes} -> routes
      _ -> raise StaleRouteError, {destination, route}
    end
  end

  defp update_destination_routes([], offered_route), do: {:ok, [offered_route]}

  defp update_destination_routes(destination_routes, offered_route) do
    destination_routes
    |> get_and_update_in(
      [Access.filter(&(&1.gateway == offered_route.gateway))],
      &update_current_route(&1, offered_route)
    )
    |> maybe_inject_destination_route(offered_route)
    |> sort_destination_routes()
  end

  defp update_current_route(current_route, offered_route)
       when current_route.serial < offered_route.serial do
    {:ok, offered_route}
  end

  defp update_current_route(current_route, _offered_route) do
    {:stale, current_route}
  end

  defp maybe_inject_destination_route({[], destination_routes}, offered_route),
    do: {:ok, [offered_route | destination_routes]}

  defp maybe_inject_destination_route({[result], destination_routes}, _offered_route),
    do: {result, destination_routes}

  defp sort_destination_routes({:stale, destination_routes}),
    do: {:stale, destination_routes}

  defp sort_destination_routes({result, destination_routes}) do
    {
      result,
      Enum.sort(
        destination_routes,
        fn r1, r2 ->
          r1.weight < r2.weight ||
            (r1.weight == r2.weight && r1.serial > r2.serial) ||
            (r1.weight == r2.weight && r1.serial == r2.serial && r1.gateway <= r2.gateway)
        end
      )
    }
  end
end
