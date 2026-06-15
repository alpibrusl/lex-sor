# lex-sor — top-level order router
#
# route_order        — original entry point; BestPrice/MinCost pick the first
#                      available venue (venue ordering is caller-determined).
# route_order_quoted — preferred entry point; BestPrice and MinCost compare
#                      live bid/ask/fee across venues and pick the optimal one.
#
# VenueQuote carries the per-venue prices needed for execution quality:
#   BestPrice (buy)  → lowest ask
#   BestPrice (sell) → highest bid
#   MinCost   (buy)  → lowest ask + fee
#   MinCost   (sell) → highest bid − fee
#
# Effects: none.

import "std.list" as list

import "lex-fix/src/venue" as vn

import "lex-trade/src/order" as order

import "lex-money/src/decimal" as d

import "./strategy" as strategy

import "./route" as route

import "./selector" as selector

# ---- VenueQuote ------------------------------------------------------
type VenueQuote = { venue :: vn.Venue, bid :: d.Decimal, ask :: d.Decimal, fee :: d.Decimal }

# ---- Helpers ---------------------------------------------------------
fn first_venue(vs :: List[vn.Venue]) -> vn.Venue {
  list.fold(vs, vn.Unknown("none"), fn (acc :: vn.Venue, v :: vn.Venue) -> vn.Venue {
    match acc {
      Unknown(_) => v,
      _ => acc,
    }
  })
}

# pick_venue returns the venue with the smallest effective_price across quotes.
# effective_price(q, BestPrice, buy)  = ask
# effective_price(q, BestPrice, sell) = −bid   (negate so fold minimises)
# effective_price(q, MinCost,   buy)  = ask + fee
# effective_price(q, MinCost,   sell) = −(bid − fee)
fn effective_price(q :: VenueQuote, strat :: strategy.RoutingStrategy, side :: order.OrderSide) -> d.Decimal {
  match strat {
    BestPrice(_) => match side {
      OrderBuy(_) => q.ask,
      OrderSell(_) => d.negate(q.bid),
    },
    MinCost(_) => match side {
      OrderBuy(_) => d.add(q.ask, q.fee),
      OrderSell(_) => d.negate(d.sub(q.bid, q.fee)),
    },
    _ => q.ask,
  }
}

type BestAcc = { found :: Bool, venue :: vn.Venue, price :: d.Decimal }

fn pick_venue(quotes :: List[VenueQuote], strat :: strategy.RoutingStrategy, side :: order.OrderSide) -> Result[vn.Venue, Str] {
  let init := { found: false, venue: vn.Unknown("none"), price: d.zero() }
  let acc := list.fold(quotes, init, fn (best :: BestAcc, q :: VenueQuote) -> BestAcc {
    let ep := effective_price(q, strat, side)
    if not best.found {
      { found: true, venue: q.venue, price: ep }
    } else {
      if d.lt(ep, best.price) {
        { found: true, venue: q.venue, price: ep }
      } else {
        best
      }
    }
  })
  if acc.found {
    Ok(acc.venue)
  } else {
    Err("no quotes available for routing")
  }
}

# ---- Original entry point (venue-list only) --------------------------
fn route_order(o :: order.Order, strat :: strategy.RoutingStrategy, available :: List[vn.Venue]) -> Result[route.RoutingDecision, Str] {
  if o.quantity <= 0 {
    Err("order quantity must be positive")
  } else {
    match selector.select_venues(strat, available) {
      Err(e) => Err(e),
      Ok(selected) => match strat {
        Sweep(venues) => Ok(route.sweep_routes(venues, o.quantity)),
        BestPrice(_) => Ok(route.single_route(first_venue(selected), o.quantity)),
        MinCost(_) => Ok(route.single_route(first_venue(selected), o.quantity)),
        DirectTo(v) => Ok(route.single_route(v, o.quantity)),
      },
    }
  }
}

# ---- Quote-aware entry point (BestPrice and MinCost compare prices) --
fn route_order_quoted(o :: order.Order, strat :: strategy.RoutingStrategy, quotes :: List[VenueQuote]) -> Result[route.RoutingDecision, Str] {
  if o.quantity <= 0 {
    Err("order quantity must be positive")
  } else {
    let available := list.map(quotes, fn (q :: VenueQuote) -> vn.Venue {
      q.venue
    })
    match selector.select_venues(strat, available) {
      Err(e) => Err(e),
      Ok(_) => match strat {
        Sweep(venues) => Ok(route.sweep_routes(venues, o.quantity)),
        DirectTo(v) => Ok(route.single_route(v, o.quantity)),
        BestPrice(_) => match pick_venue(quotes, strat, o.side) {
          Err(e) => Err(e),
          Ok(v) => Ok(route.single_route(v, o.quantity)),
        },
        MinCost(_) => match pick_venue(quotes, strat, o.side) {
          Err(e) => Err(e),
          Ok(v) => Ok(route.single_route(v, o.quantity)),
        },
      },
    }
  }
}

