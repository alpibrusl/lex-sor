# lex-sor

Smart order routing for Lex. Pure — no effects, no network calls.

Routes an `Order` to one or more venues under a typed `RoutingStrategy`. The result is a `RoutingDecision` (list of `Route` records, each a venue + quantity pair) that the caller hands to the exchange transport.

---

## Strategies

| Strategy | Behaviour |
|---|---|
| `BestPrice` | Pick venue with lowest ask (buy) or highest bid (sell). Requires quotes — use `route_order_quoted`. |
| `MinCost` | Pick venue with lowest all-in cost: ask + fee (buy), or highest bid − fee (sell). Requires quotes. |
| `Sweep(venues)` | Split quantity evenly across venues; remainder to first venue. |
| `DirectTo(venue)` | Route full quantity to a single named venue. |

---

## Entry points

### `route_order` — venue-list only

```lex
import "lex-sor/src/router"   as router
import "lex-sor/src/strategy" as strategy

match router.route_order(order, DirectTo(Nasdaq(())), [Nyse(()), Nasdaq(())]) {
  Ok(decision) => # decision.routes — per-venue allocations
  Err(msg)     => # venue unavailable, qty <= 0, etc.
}
```

`BestPrice` and `MinCost` fall back to `first_venue(available)` when using this entry point — no price comparison is performed.

### `route_order_quoted` — with live bid/ask/fee (recommended for BestPrice/MinCost)

```lex
import "lex-sor/src/router" as router

let quotes := [
  { venue: Nyse(()),    bid: d.decimal(17499, -2), ask: d.decimal(17501, -2), fee: d.decimal(1, -3) },
  { venue: Nasdaq(()), bid: d.decimal(17498, -2), ask: d.decimal(17500, -2), fee: d.decimal(2, -3) },
]

match router.route_order_quoted(order, BestPrice(()), quotes) {
  Ok(decision) => # routes to Nasdaq — lowest ask $175.00 vs NYSE $175.01
  Err(msg)     => # no quotes, qty <= 0, etc.
}
```

For `MinCost` with the same quotes:
- NYSE: ask + fee = $175.01 + $0.001 = $175.011
- Nasdaq: ask + fee = $175.00 + $0.002 = $175.002 → Nasdaq wins on total cost

---

## Sweep example

```lex
router.route_order(order, Sweep([Nyse(()), Nasdaq(())]), [Nyse(()), Nasdaq(())])
# qty=1000 → NYSE 500, Nasdaq 500
# qty=1001 → NYSE 501 (remainder to first), Nasdaq 500
```

---

## In the stack

```
lex-money · lex-fix · lex-trade
    ↓
lex-sor  ←  venue selection and order splitting
    ↓
lex-finance · lex-oms
```

---

## Install

```toml
[dependencies]
"lex-sor" = { git = "https://github.com/alpibrusl/lex-sor" }
```
