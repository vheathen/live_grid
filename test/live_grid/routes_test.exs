defmodule LiveGrid.RoutesTest do
  use LiveGrid.Case

  alias LiveGrid.Routes
  alias LiveGrid.Routes.Route

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

  describe "update_route/3 should correctly fill updated destinations and" do
    test "add a route if destination route list is empty", %{routes: empty_routes} do
      destination = {3, 3}

      route = Route.new(destination: destination, gateway: {2, 2}, weight: 2, serial: 100)

      assert routes = Routes.update_route(empty_routes, route)
      assert %{destination => [route]} == routes.entries
      assert [destination] == routes.updated_destinations

      nil_route = Route.new(destination: destination, gateway: {2, 2}, weight: nil, serial: 100)

      assert routes = Routes.update_route(empty_routes, nil_route)
      assert %{destination => [nil_route]} == routes.entries
      assert [destination] == routes.updated_destinations
    end

    test "add a route if destination linked with another gateways in route list", %{
      routes: empty_routes
    } do
      destination = {3, 3}
      another_route = Route.new(destination: destination, gateway: {2, 2}, weight: 2, serial: 100)
      route = Route.new(destination: destination, gateway: {1, 2}, weight: 3, serial: 100)

      assert routes =
               empty_routes
               |> Routes.update_route(another_route)
               |> Routes.update_route(route)

      assert %{destination => [another_route, route]} == routes.entries

      # route has greater weight that previous one so we don't need to send it as update
      assert [destination] == routes.updated_destinations
    end

    test "update a route if new value serial is bigger than the current one", %{
      routes: empty_routes
    } do
      destination = {4, 4}
      another_route = Route.new(destination: destination, gateway: {1, 2}, weight: 4, serial: 100)

      current_route = Route.new(destination: destination, gateway: {2, 2}, weight: 3, serial: 101)
      new_route = %{current_route | weight: 4, serial: 102}

      assert routes =
               empty_routes
               |> Routes.update_route(another_route)
               |> Routes.update_route(current_route)
               |> Routes.update_route(new_route)

      assert %{destination => [new_route, another_route]} == routes.entries
      assert [destination] == routes.updated_destinations
    end

    test "update a route if new value serial is equal to the current one but weight is lower", %{
      routes: empty_routes
    } do
      destination = {4, 4}
      another_route = Route.new(destination: destination, gateway: {1, 2}, weight: 4, serial: 100)

      current_route = Route.new(destination: destination, gateway: {2, 2}, weight: 3, serial: 101)
      new_route = %{current_route | weight: 1, serial: 101}

      assert routes =
               empty_routes
               |> Routes.update_route(another_route)
               |> Routes.update_route(current_route)
               |> Routes.update_route(new_route)

      assert %{destination => [new_route, another_route]} == routes.entries
      assert [destination] == routes.updated_destinations
    end

    test "keep a route if new value serial is less or the same as the current one", %{
      routes: empty_routes
    } do
      destination = {4, 4}
      another_route = Route.new(destination: destination, gateway: {1, 2}, weight: 4, serial: 100)

      current_route = Route.new(destination: destination, gateway: {2, 2}, weight: 3, serial: 101)
      stale_route = %{current_route | weight: 4, serial: 99}

      assert routes =
               %Routes{} =
               empty_routes
               |> Routes.update_route(another_route)
               |> Routes.update_route(current_route)

      assert routes = Routes.update_route(%{routes | updated_destinations: []}, stale_route)

      assert %{destination => [current_route, another_route]} == routes.entries
      assert [] == routes.updated_destinations
    end

    test "should sort destination routes depending on: 1. {:asc, weight}, 2. {:desc, serial}, 3. {:desc, gateway}",
         %{routes: empty_routes} do
      _current_node = {2, 2}
      destination = {4, 4}

      routes = empty_routes

      route12 = Route.new(destination: destination, gateway: {1, 2}, weight: 4, serial: 100)
      assert routes = Routes.update_route(routes, route12)
      assert %{destination => [route12]} == routes.entries

      route21 = Route.new(destination: destination, gateway: {2, 1}, weight: 4, serial: 50)
      assert routes = Routes.update_route(routes, route21)
      assert %{destination => [route12, route21]} == routes.entries

      route33 = Route.new(destination: destination, gateway: {3, 3}, weight: 2, serial: 50)
      assert routes = Routes.update_route(routes, route33)
      assert %{destination => [route33, route12, route21]} == routes.entries

      route11 = Route.new(destination: destination, gateway: {1, 1}, weight: 5, serial: 100)
      assert routes = Routes.update_route(routes, route11)
      assert %{destination => [route33, route12, route21, route11]} == routes.entries

      route31 = Route.new(destination: destination, gateway: {3, 1}, weight: 4, serial: 100)
      assert routes = Routes.update_route(routes, route31)
      assert %{destination => [route33, route12, route31, route21, route11]} == routes.entries

      nil_route33 = Route.new(destination: destination, gateway: {3, 3}, weight: nil, serial: 150)
      assert routes = Routes.update_route(routes, nil_route33)
      assert %{destination => [route12, route31, route21, route11, nil_route33]} == routes.entries
    end
  end

  describe "remove_neighbor_routes/2 should return new Routes.t() with" do
    setup %{routes: empty_routes} do
      d32 = {3, 2}
      r32 = Route.new(destination: d32, gateway: d32, weight: 1)

      d31 = {3, 1}
      r31 = Route.new(destination: d31, gateway: d32, weight: 2)

      _me = {3, 3}

      gw34 = {3, 4}
      rgw34 = Route.new(destination: gw34, gateway: gw34, weight: 1)

      d15 = {1, 5}
      r15 = Route.new(destination: d15, gateway: gw34, weight: 3)

      d25 = {2, 5}
      r25 = Route.new(destination: d25, gateway: gw34, weight: 2)

      d35 = {3, 5}
      r35 = Route.new(destination: d35, gateway: gw34, weight: 2)

      d45 = {4, 5}
      r45 = Route.new(destination: d45, gateway: gw34, weight: 2)

      routes =
        [r31, r32, rgw34, r15, r25, r35, r45]
        |> Enum.reduce(empty_routes, &Routes.update_route(&2, &1))
        |> then(&%{&1 | updated_destinations: []})
        |> Routes.remove_neighbor_routes(gw34)

      [routes: routes]
    end

    test "all routes to the given neighbor nillefied", %{routes: routes} do
      assert %LiveGrid.Routes{
               entries: %{
                 {1, 5} => [
                   %LiveGrid.Routes.Route{
                     destination: {1, 5},
                     gateway: {3, 4},
                     serial: _,
                     weight: nil
                   }
                 ],
                 {2, 5} => [
                   %LiveGrid.Routes.Route{
                     destination: {2, 5},
                     gateway: {3, 4},
                     serial: _,
                     weight: nil
                   }
                 ],
                 {3, 1} => [
                   %LiveGrid.Routes.Route{
                     destination: {3, 1},
                     gateway: {3, 2},
                     serial: _,
                     weight: 2
                   }
                 ],
                 {3, 2} => [
                   %LiveGrid.Routes.Route{
                     destination: {3, 2},
                     gateway: {3, 2},
                     serial: _,
                     weight: 1
                   }
                 ],
                 {3, 4} => [
                   %LiveGrid.Routes.Route{
                     destination: {3, 4},
                     gateway: {3, 4},
                     serial: _,
                     weight: nil
                   }
                 ],
                 {3, 5} => [
                   %LiveGrid.Routes.Route{
                     destination: {3, 5},
                     gateway: {3, 4},
                     serial: _,
                     weight: nil
                   }
                 ],
                 {4, 5} => [
                   %LiveGrid.Routes.Route{
                     destination: {4, 5},
                     gateway: {3, 4},
                     serial: _,
                     weight: nil
                   }
                 ]
               }
             } = routes
    end

    test "updated_destinations contains all changed destinations", %{routes: routes} do
      assert Enum.sort([{4, 5}, {3, 5}, {3, 4}, {2, 5}, {1, 5}]) ==
               Enum.sort(routes.updated_destinations)
    end
  end

  describe "get_next_hop/2" do
    setup :test_grid

    test "should return the next hop gateway with the lowest weight or nil",
         %{routes: routes} do
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

  describe "get_updates_for/2" do
    setup :test_grid

    test "should return correct updates", %{routes: routes} do
      routes = %{routes | updated_destinations: [{4, 2}, {4, 1}, {3, 4}]}

      assert [
               Route.new(destination: {4, 2}, gateway: {2, 3}, weight: 3, serial: 200),
               Route.new(destination: {4, 1}, gateway: {3, 1}, weight: nil, serial: 50),
               Route.new(destination: {3, 4}, gateway: {2, 3}, weight: nil, serial: 50)
             ] == Routes.get_updates_for(routes, {3, 2})

      assert [
               Route.new(destination: {4, 2}, gateway: {3, 2}, weight: 2, serial: 100),
               Route.new(destination: {4, 1}, gateway: {3, 2}, weight: nil, serial: 150),
               Route.new(destination: {3, 4}, gateway: {3, 2}, weight: 3, serial: 50)
             ] == Routes.get_updates_for(routes, {3, 1})
    end
  end

  def test_grid(%{routes: empty_routes}) do
    _current_node = {2, 2}

    route_11_to_11 = Route.new(destination: {1, 1}, gateway: {1, 1}, weight: 1, serial: 100)

    route_32_to_42 = Route.new(destination: {4, 2}, gateway: {3, 2}, weight: 2, serial: 100)
    route_23_to_42 = Route.new(destination: {4, 2}, gateway: {2, 3}, weight: 3, serial: 200)

    route_32_to_43 = Route.new(destination: {4, 3}, gateway: {3, 2}, weight: 2, serial: 50)
    route_33_to_43 = Route.new(destination: {4, 3}, gateway: {3, 3}, weight: 2, serial: 100)

    route_32_to_44 = Route.new(destination: {4, 4}, gateway: {3, 2}, weight: 3, serial: 100)
    route_33_to_44 = Route.new(destination: {4, 4}, gateway: {3, 3}, weight: 2, serial: 100)
    route_12_to_44 = Route.new(destination: {4, 4}, gateway: {1, 2}, weight: 4, serial: 150)

    route_31_to_41 = Route.new(destination: {4, 1}, gateway: {3, 1}, weight: nil, serial: 50)
    route_32_to_41 = Route.new(destination: {4, 1}, gateway: {3, 2}, weight: nil, serial: 150)

    _route_13_to_14 = nil

    route_23_to_34 = Route.new(destination: {3, 4}, gateway: {2, 3}, weight: nil, serial: 50)
    route_32_to_34 = Route.new(destination: {3, 4}, gateway: {3, 2}, weight: 3, serial: 50)

    routes =
      empty_routes
      # to {1, 1}
      |> Routes.update_route(route_11_to_11)
      # to {4, 2}
      |> Routes.update_route(route_32_to_42)
      |> Routes.update_route(route_23_to_42)
      # to {4, 3}
      |> Routes.update_route(route_32_to_43)
      |> Routes.update_route(route_33_to_43)
      # to {4, 4}
      |> Routes.update_route(route_32_to_44)
      |> Routes.update_route(route_33_to_44)
      |> Routes.update_route(route_12_to_44)
      # to {4, 1}
      |> Routes.update_route(route_31_to_41)
      |> Routes.update_route(route_32_to_41)
      # to {1, 4}
      # none

      # to {3, 4}
      |> Routes.update_route(route_23_to_34)
      |> Routes.update_route(route_32_to_34)

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

    [routes: routes]
  end
end
