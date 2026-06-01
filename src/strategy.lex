# lex-sor — routing strategy ADT and display
#
# Defines the strategies a smart order router can use when choosing
# venues for a given order. BestPrice and MinCost defer to caller-ranked
# venue lists; Sweep routes across an explicit venue list; DirectTo
# bypasses selection entirely.
#
# Effects: none.

import "std.list" as list

import "std.str" as str

import "lex-fix/src/venue" as vn

type RoutingStrategy = BestPrice(Unit) | MinCost(Unit) | Sweep(List[vn.Venue]) | DirectTo(vn.Venue)

fn join_venues(vs :: List[vn.Venue]) -> Str {
  let parts := list.fold(vs, [], fn (acc :: List[Str], v :: vn.Venue) -> List[Str] {
    list.concat(acc, [vn.venue_to_str(v)])
  })
  list.fold(parts, "", fn (acc :: Str, s :: Str) -> Str {
    if str.is_empty(acc) {
      s
    } else {
      acc + "," + s
    }
  })
}

fn strategy_to_str(s :: RoutingStrategy) -> Str {
  match s {
    BestPrice(_) => "BestPrice",
    MinCost(_) => "MinCost",
    Sweep(vs) => "Sweep([" + join_venues(vs) + "])",
    DirectTo(v) => "DirectTo(" + vn.venue_to_str(v) + ")",
  }
}
