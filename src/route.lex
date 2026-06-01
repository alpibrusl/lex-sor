# lex-sor — routing decision and construction
#
# A Route is a venue+quantity pair; a RoutingDecision collects all
# routes produced for a single parent order together with a human-
# readable summary of the strategy used.
#
# sweep_routes splits a quantity evenly across a list of venues; any
# remainder (qty mod len) is absorbed by the first venue.
#
# Effects: none.

import "std.list" as list

import "std.str" as str

import "std.int" as int

import "lex-fix/src/venue" as vn

import "./strategy" as strategy

type Route = { venue :: vn.Venue, quantity :: Int }

type RoutingDecision = { routes :: List[Route], strategy_used :: Str, total_qty :: Int }

fn single_route(venue :: vn.Venue, qty :: Int) -> RoutingDecision {
  { routes: [{ venue: venue, quantity: qty }], strategy_used: strategy.strategy_to_str(DirectTo(venue)), total_qty: qty }
}

# Internal accumulator for sweep construction.
type SweepAcc = { seq :: Int, routes :: List[Route], n :: Int, base :: Int, remainder :: Int }

fn sweep_routes(venues :: List[vn.Venue], qty :: Int) -> RoutingDecision {
  let n := list.len(venues)
  let base := qty / n
  let remainder := qty % n
  let acc := list.fold(venues, { seq: 0, routes: [], n: n, base: base, remainder: remainder }, fn (a :: SweepAcc, v :: vn.Venue) -> SweepAcc {
    let this_qty := if a.seq == 0 {
      a.base + a.remainder
    } else {
      a.base
    }
    { seq: a.seq + 1, routes: list.concat(a.routes, [{ venue: v, quantity: this_qty }]), n: a.n, base: a.base, remainder: a.remainder }
  })
  let strat_str := strategy.strategy_to_str(Sweep(venues))
  { routes: acc.routes, strategy_used: strat_str, total_qty: qty }
}

fn route_summary(d :: RoutingDecision) -> Str {
  let count := list.len(d.routes)
  int.to_str(count) + " routes, total qty " + int.to_str(d.total_qty) + " via " + d.strategy_used
}
