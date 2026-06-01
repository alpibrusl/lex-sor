# lex-sor — top-level order router
#
# route_order is the single entry point for routing a domain order.
# It validates the order quantity, runs venue selection, and dispatches
# to single_route or sweep_routes depending on the strategy.
#
# Effects: none.

import "std.list" as list

import "lex-fix/src/venue" as vn

import "lex-trade/src/order" as order

import "./strategy" as strategy

import "./route" as route

import "./selector" as selector

fn first_venue(vs :: List[vn.Venue]) -> vn.Venue {
  list.fold(vs, vn.Unknown("none"), fn (acc :: vn.Venue, v :: vn.Venue) -> vn.Venue {
    match acc {
      Unknown(_) => v,
      _ => acc,
    }
  })
}

fn route_order(o :: order.Order, strat :: strategy.RoutingStrategy, available :: List[vn.Venue]) -> Result[route.RoutingDecision, Str] {
  if o.quantity <= 0 {
    Err("order quantity must be positive")
  } else {
    match selector.select_venues(strat, available) {
      Err(e) => Err(e),
      Ok(selected) => {
        match strat {
          Sweep(venues) => Ok(route.sweep_routes(venues, o.quantity)),
          BestPrice(_) => Ok(route.single_route(first_venue(selected), o.quantity)),
          MinCost(_) => Ok(route.single_route(first_venue(selected), o.quantity)),
          DirectTo(v) => Ok(route.single_route(v, o.quantity)),
        }
      },
    }
  }
}
