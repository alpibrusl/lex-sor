# lex-sor — venue selection for a routing strategy
#
# select_venues validates that the venues implied by a strategy are
# available before the router commits to routing. BestPrice and MinCost
# pass the full available list through unchanged (caller pre-ranks).
# Sweep validates each venue in the sweep list. DirectTo validates the
# single target venue.
#
# Effects: none.

import "std.list" as list

import "std.str" as str

import "lex-fix/src/venue" as vn

import "./strategy" as strategy

fn venue_in_list(v :: vn.Venue, vs :: List[vn.Venue]) -> Bool {
  let target := vn.venue_to_str(v)
  list.fold(vs, false, fn (acc :: Bool, candidate :: vn.Venue) -> Bool {
    if acc {
      true
    } else {
      vn.venue_to_str(candidate) == target
    }
  })
}

# Check that every venue in `sweep` is present in `available`.
# Returns Err with the first missing venue name, or Ok(sweep) if all present.
type SweepCheckAcc = { ok :: Bool, error :: Str, available :: List[vn.Venue] }

fn check_sweep_venues(sweep :: List[vn.Venue], available :: List[vn.Venue]) -> Result[List[vn.Venue], Str] {
  let acc := list.fold(sweep, { ok: true, error: "", available: available }, fn (a :: SweepCheckAcc, v :: vn.Venue) -> SweepCheckAcc {
    if a.ok {
      if venue_in_list(v, a.available) {
        a
      } else {
        { ok: false, error: "venue " + vn.venue_to_str(v) + " not available for routing", available: a.available }
      }
    } else {
      a
    }
  })
  if acc.ok {
    Ok(sweep)
  } else {
    Err(acc.error)
  }
}

fn select_venues(strat :: strategy.RoutingStrategy, available :: List[vn.Venue]) -> Result[List[vn.Venue], Str] {
  match strat {
    BestPrice(_) => Ok(available),
    MinCost(_) => Ok(available),
    Sweep(venues) => check_sweep_venues(venues, available),
    DirectTo(v) => if venue_in_list(v, available) {
      Ok([v])
    } else {
      Err("venue " + vn.venue_to_str(v) + " not available")
    },
  }
}

