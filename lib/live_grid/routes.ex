defmodule LiveGrid.Routes do
  alias LiveGrid.Routes.Route

  @type t :: %__MODULE__{
          me: peer(),
          entries: entries(),
          updated_destinations: [route()]
        }

  @type entries :: %{destination() => [entry()]}
  @type entry :: Route.t()

  @type peer :: LiveGrid.Node.peer()
  @type destination :: peer()
  @type gateway :: peer()

  @type route :: LiveGrid.Routes.Route.t()
  @type route_updates :: [route()]

  defstruct entries: %{}, updated_destinations: [], me: nil

  @spec new(Enum.t()) :: t()
  def new(attrs \\ []), do: struct(__MODULE__, attrs)

  @spec get_updates_for(t(), peer()) :: route_updates()
  def get_updates_for(%__MODULE__{} = routes, neighbor) do
    routes.updated_destinations
    |> Stream.map(fn destination ->
      routes.entries
      |> Map.get(destination, [])
      |> Enum.find(&(&1.gateway != neighbor))
    end)
    |> Stream.filter(& &1)
    |> Enum.to_list()
  end

  @spec remove_neighbor_routes(t(), gateway()) :: t()
  def remove_neighbor_routes(%__MODULE__{} = routes, gateway),
    do: do_remove_neighbor_routes(routes, gateway)

  @spec get_next_hop(t(), destination()) :: gateway() | nil
  def get_next_hop(%__MODULE__{entries: entries}, destination) do
    entries
    |> Map.get(destination)
    |> case do
      [route | _rest_routes] when not is_nil(route.weight) -> route.gateway
      _ -> nil
    end
  end

  @spec update_route(t(), route()) :: t()
  def update_route(%__MODULE__{} = routes, %Route{destination: destination} = offered_route) do
    routes
    |> get_and_update_in(
      [
        Access.key(:entries),
        Access.key(destination, [])
      ],
      &update_destination_routes(&1, offered_route)
    )
    |> handle_updates()
  end

  defp update_destination_routes([], %Route{} = offered_route),
    do: {offered_route.destination, [offered_route]}

  defp update_destination_routes(destination_routes, %Route{} = offered_route) do
    destination_routes
    |> get_and_update_in(
      [Access.filter(&(&1.gateway == offered_route.gateway))],
      &update_current_route(&1, offered_route)
    )
    |> maybe_inject_destination_route(offered_route)
    |> sort_destination_routes()
  end

  defp update_current_route(
         %Route{serial: serial} = current_route,
         %Route{serial: serial} = offered_route
       )
       when current_route.weight > offered_route.weight,
       do: {offered_route.destination, offered_route}

  defp update_current_route(
         %Route{serial: current_serial} = _current_route,
         %Route{serial: offered_serial} = offered_route
       )
       when current_serial < offered_serial,
       do: {offered_route.destination, offered_route}

  defp update_current_route(current_route, _offered_route),
    do: {nil, current_route}

  defp maybe_inject_destination_route({[], destination_routes}, %Route{} = offered_route),
    do: {offered_route.destination, [offered_route | destination_routes]}

  defp maybe_inject_destination_route({_updates, _destination_routes} = results, _offered_route),
    do: results

  defp sort_destination_routes({updated_destinations, destination_routes}) do
    destination_routes
    |> Enum.sort(fn r1, r2 ->
      r1.weight < r2.weight ||
        (r1.weight == r2.weight && r1.serial > r2.serial) ||
        ({r1.weight, r1.serial} == {r2.weight, r2.serial} && r1.gateway <= r2.gateway)
    end)
    |> then(fn sorted_destination_routes -> {updated_destinations, sorted_destination_routes} end)
  end

  defp handle_updates({nil, routes}), do: routes
  defp handle_updates({[], routes}), do: routes

  defp handle_updates({updates, %__MODULE__{} = routes}) do
    updates
    |> List.wrap()
    |> List.flatten()
    |> Stream.filter(& &1)
    |> Enum.reduce(routes.updated_destinations, &[&1 | &2])
    |> Enum.uniq_by(& &1)
    |> then(&%{routes | updated_destinations: &1})
  end

  defp do_remove_neighbor_routes(%__MODULE__{} = routes, gateway) do
    routes.entries
    |> Map.keys()
    |> Enum.reduce(routes, &remove_neighbor_destination_routes(&1, &2, gateway))
  end

  defp remove_neighbor_destination_routes(destination, %__MODULE__{} = routes, gateway) do
    routes
    |> get_and_update_in(
      [
        Access.key(:entries),
        Access.key(destination, []),
        Access.filter(&(&1.gateway == gateway && !is_nil(&1.weight)))
      ],
      fn _current_route ->
        nillified_route = Route.new(destination: destination, gateway: gateway, weight: nil)
        {destination, nillified_route}
      end
    )
    |> handle_updates()
  end
end
