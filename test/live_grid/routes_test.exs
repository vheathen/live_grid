defmodule LiveGrid.RoutesTest do
  use LiveGrid.Case

  alias LiveGrid.Routes
  alias LiveGrid.Routes.{Route, StaleRouteError}

  # Test grid
  # {1, 1}  {1, 2} {1, 3} {1, 4}
  # {2, 1}  {2, 2} {2, 3} {2, 4}
  # {3, 1}  {3, 2} {3, 3} {3, 4}
  # {4, 1}  {4, 2} {4, 3} {4, 4}

  # current node {1, 1}

  setup do
    [routes: Routes.new()]
  end

  test "new/0 should create a Routes struct", %{routes: empty_routes} do
    assert %Routes{} == empty_routes
  end

  describe "update_route/3 and update_route!/3" do
    test "should add a route if destination route list is empty", %{routes: empty_routes} do
      destination = {3, 3}
      route = Route.new(gateway: {2, 2}, weight: 2, serial: 100)

      assert {:ok, routes} = Routes.update_route(empty_routes, destination, route)
      assert routes == Routes.update_route!(empty_routes, destination, route)
      assert %{destination => [route]} == routes.entries

      nil_route = Route.new(gateway: {2, 2}, weight: nil, serial: 100)
      assert {:ok, routes} = Routes.update_route(empty_routes, destination, nil_route)
      assert routes == Routes.update_route!(empty_routes, destination, nil_route)
      assert %{destination => [nil_route]} == routes.entries
    end

    test "should add a route if destination linked with another gateways in route list", %{
      routes: empty_routes
    } do
      destination = {3, 3}
      another_route = Route.new(gateway: {2, 2}, weight: 2, serial: 100)
      route = Route.new(gateway: {1, 2}, weight: 3, serial: 100)

      assert {:ok, routes} =
               empty_routes
               |> Routes.update_route!(destination, another_route)
               |> Routes.update_route(destination, route)

      assert routes ==
               empty_routes
               |> Routes.update_route!(destination, another_route)
               |> Routes.update_route!(destination, route)

      assert %{destination => [another_route, route]} == routes.entries
    end

    test "should update a route if new value serial is bigger than the current one", %{
      routes: empty_routes
    } do
      destination = {4, 4}
      another_route = Route.new(gateway: {1, 2}, weight: 4, serial: 100)

      current_route = Route.new(gateway: {2, 2}, weight: 3, serial: 101)
      new_route = %{current_route | weight: 4, serial: 102}

      assert {:ok, routes} =
               empty_routes
               |> Routes.update_route!(destination, another_route)
               |> Routes.update_route!(destination, current_route)
               |> Routes.update_route(destination, new_route)

      assert routes ==
               empty_routes
               |> Routes.update_route!(destination, another_route)
               |> Routes.update_route!(destination, current_route)
               |> Routes.update_route!(destination, new_route)

      assert %{destination => [new_route, another_route]} == routes.entries
    end

    test "should keep a route if new value serial is less or the same as the current one", %{
      routes: empty_routes
    } do
      destination = {4, 4}
      another_route = Route.new(gateway: {1, 2}, weight: 4, serial: 100)

      current_route = Route.new(gateway: {2, 2}, weight: 3, serial: 101)
      stale_route = %{current_route | weight: 4, serial: 99}

      assert routes =
               %Routes{} =
               empty_routes
               |> Routes.update_route!(destination, another_route)
               |> Routes.update_route!(destination, current_route)

      assert {:stale, ^routes} = Routes.update_route(routes, destination, stale_route)

      assert_raise StaleRouteError, fn ->
        Routes.update_route!(routes, destination, stale_route)
      end

      assert %{destination => [current_route, another_route]} == routes.entries
    end

    test "should sort destination routes depending on: 1. {:asc, weight}, 2. {:desc, serial}, 3. {:desc, gateway}",
         %{routes: empty_routes} do
      _current_node = {2, 2}
      destination = {4, 4}

      routes = empty_routes

      route12 = Route.new(gateway: {1, 2}, weight: 4, serial: 100)
      assert {:ok, routes} = Routes.update_route(routes, destination, route12)
      assert %{destination => [route12]} == routes.entries

      route21 = Route.new(gateway: {2, 1}, weight: 4, serial: 50)
      assert {:ok, routes} = Routes.update_route(routes, destination, route21)
      assert %{destination => [route12, route21]} == routes.entries

      route33 = Route.new(gateway: {3, 3}, weight: 2, serial: 50)
      assert {:ok, routes} = Routes.update_route(routes, destination, route33)
      assert %{destination => [route33, route12, route21]} == routes.entries

      route11 = Route.new(gateway: {1, 1}, weight: 5, serial: 100)
      assert {:ok, routes} = Routes.update_route(routes, destination, route11)
      assert %{destination => [route33, route12, route21, route11]} == routes.entries

      route31 = Route.new(gateway: {3, 1}, weight: 4, serial: 100)
      assert {:ok, routes} = Routes.update_route(routes, destination, route31)
      assert %{destination => [route33, route12, route31, route21, route11]} == routes.entries

      nil_route33 = Route.new(gateway: {3, 3}, weight: nil, serial: 150)
      assert {:ok, routes} = Routes.update_route(routes, destination, nil_route33)
      assert %{destination => [route12, route31, route21, route11, nil_route33]} == routes.entries
    end
  end

  describe "get_next_hop/2" do
    test "should return the next hop gateway with the lowest weight or nil",
         %{routes: empty_routes} do
      _current_node = {2, 2}

      route_11_to_11 = Route.new(gateway: {1, 1}, weight: 1, serial: 100)

      route_32_to_42 = Route.new(gateway: {3, 2}, weight: 2, serial: 100)
      route_23_to_42 = Route.new(gateway: {2, 3}, weight: 3, serial: 200)

      route_32_to_43 = Route.new(gateway: {3, 2}, weight: 2, serial: 50)
      route_33_to_43 = Route.new(gateway: {3, 3}, weight: 2, serial: 100)

      route_32_to_44 = Route.new(gateway: {3, 2}, weight: 3, serial: 100)
      route_33_to_44 = Route.new(gateway: {3, 3}, weight: 2, serial: 100)
      route_12_to_44 = Route.new(gateway: {1, 2}, weight: 4, serial: 150)

      route_31_to_41 = Route.new(gateway: {3, 1}, weight: nil, serial: 50)
      route_32_to_41 = Route.new(gateway: {3, 2}, weight: nil, serial: 150)

      _route_13_to_14 = nil

      route_23_to_34 = Route.new(gateway: {2, 3}, weight: nil, serial: 50)
      route_32_to_34 = Route.new(gateway: {3, 2}, weight: 3, serial: 50)

      routes =
        empty_routes
        # to {1, 1}
        |> Routes.update_route!({1, 1}, route_11_to_11)
        # to {4, 2}
        |> Routes.update_route!({4, 2}, route_32_to_42)
        |> Routes.update_route!({4, 2}, route_23_to_42)
        # to {4, 3}
        |> Routes.update_route!({4, 3}, route_32_to_43)
        |> Routes.update_route!({4, 3}, route_33_to_43)
        # to {4, 4}
        |> Routes.update_route!({4, 4}, route_32_to_44)
        |> Routes.update_route!({4, 4}, route_33_to_44)
        |> Routes.update_route!({4, 4}, route_12_to_44)
        # to {4, 1}
        |> Routes.update_route!({4, 1}, route_31_to_41)
        |> Routes.update_route!({4, 1}, route_32_to_41)
        # to {1, 4}
        # none

        # to {3, 4}
        |> Routes.update_route!({3, 4}, route_23_to_34)
        |> Routes.update_route!({3, 4}, route_32_to_34)

      assert %Routes{
               entries: %{
                 {1, 1} => [^route_11_to_11],
                 #
                 {4, 2} => [^route_32_to_42, ^route_23_to_42],
                 #
                 {4, 3} => [^route_33_to_43, ^route_32_to_43],
                 #
                 {4, 4} => [^route_33_to_44, ^route_32_to_44, ^route_12_to_44],
                 #
                 {4, 1} => [^route_32_to_41, ^route_31_to_41],
                 #
                 {3, 4} => [^route_32_to_34, ^route_23_to_34]
               }
             } = routes

      assert {1, 1} == Routes.get_next_hop(routes, {1, 1})
      #
      assert {3, 2} == Routes.get_next_hop(routes, {4, 2})
      #
      assert {3, 3} == Routes.get_next_hop(routes, {4, 3})
      #
      assert {3, 3} == Routes.get_next_hop(routes, {4, 4})
      #
      assert nil == Routes.get_next_hop(routes, {4, 1})
      #
      assert nil == Routes.get_next_hop(routes, {1, 4})
      #
      assert {3, 2} == Routes.get_next_hop(routes, {3, 4})

      #
    end
  end
end
