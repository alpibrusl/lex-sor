# lex-sor

Smart order routing for the [Lex language](https://github.com/alpibrusl/lex-lang).

Routes a domain `Order` to one or more venues under a typed `RoutingStrategy`. All routing logic is pure — no effects, no network calls. The result is a `RoutingDecision` (list of `Route` records, each a venue + quantity pair) that the caller hands to the exchange transport.

## What it ships

- **`src/strategy.lex`** — `RoutingStrategy` ADT: `BestPrice` / `MinCost` / `Sweep(List[Venue])` / `DirectTo(Venue)`. `strategy_to_str` for logging.
- **`src/selector.lex`** — `select_venues` validates that the venues implied by a strategy are present in the `available` list before routing commits.
- **`src/route.lex`** — `Route` and `RoutingDecision` types. `single_route` (one venue, full qty). `sweep_routes` splits qty evenly across a venue list; remainder goes to the first venue.
- **`src/router.lex`** — `route_order`: top-level entry point. Validates positive qty, runs `select_venues`, then dispatches to `single_route` or `sweep_routes`. Returns `Result[RoutingDecision, Str]`.

## Usage

```lex
import "lex-sor/src/router"   as router
import "lex-sor/src/strategy" as strategy
import "lex-fix/src/venue"    as venue

let available := [Nyse(()), Nasdaq(())]
let strat     := Sweep([Nyse(()), Nasdaq(())])

match router.route_order(order, strat, available) {
  Err(msg)      => # routing failed (venue unavailable, qty <= 0)
  Ok(decision)  => # decision.routes — per-venue allocations
}
```

## Effects

None. All modules are pure.

## Dependencies

- **lex-fix** — `Venue` ADT and `venue_to_str`.
- **lex-trade** — `Order` domain type.
- **lex-money** — `Decimal` (via lex-trade; not directly used in routing logic).

---

Built under the principles of [Trust Without Comprehension](https://alpibru.com/manifesto).
