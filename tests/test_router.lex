# lex-sor tests — route_order integration
#
# Exercises the top-level router with all strategies, available/
# unavailable venues, and edge cases (zero quantity).

import "std.list" as list

import "std.str" as str

import "std.int" as int

import "lex-fix/src/venue" as vn

import "lex-trade/src/order" as order

import "../src/strategy" as strategy

import "../src/route" as route

import "../src/router" as router

fn pass() -> Result[Unit, Str] {
  Ok(())
}

fn fail(why :: Str) -> Result[Unit, Str] {
  Err(why)
}

fn assert_true(cond :: Bool, label :: Str) -> Result[Unit, Str] {
  if cond {
    pass()
  } else {
    fail(label)
  }
}

fn assert_eq_int(a :: Int, b :: Int, label :: Str) -> Result[Unit, Str] {
  assert_true(a == b, label + ": expected " + int.to_str(b) + " got " + int.to_str(a))
}

fn sample_order(qty :: Int) -> order.Order {
  order.order("ORD-SOR-001", "AAPL", OrderBuy(()), qty, MarketOrder(()), "0", "ACC-1", "TRADER-1", "20260531-09:00:00.000")
}

# ---- Tests --------------------------------------------------------
fn test_direct_available() -> Result[Unit, Str] {
  let o := sample_order(200)
  let available := [Nyse(()), Nasdaq(())]
  match router.route_order(o, DirectTo(Nyse(())), available) {
    Err(e) => fail("expected Ok, got Err: " + e),
    Ok(d) => {
      match assert_eq_int(list.len(d.routes), 1, "direct: 1 route") {
        Err(e) => Err(e),
        Ok(_) => {
          let venue_name := list.fold(d.routes, "", fn (acc :: Str, r :: route.Route) -> Str {
            if str.is_empty(acc) {
              vn.venue_to_str(r.venue)
            } else {
              acc
            }
          })
          assert_true(venue_name == "NYSE", "direct: venue is NYSE")
        },
      }
    },
  }
}

fn test_direct_unavailable() -> Result[Unit, Str] {
  let o := sample_order(100)
  let available := [Nyse(()), Nasdaq(())]
  match router.route_order(o, DirectTo(Lse(())), available) {
    Ok(_) => fail("expected Err for unavailable venue"),
    Err(_) => pass(),
  }
}

fn test_sweep_all_available() -> Result[Unit, Str] {
  let o := sample_order(200)
  let available := [Nyse(()), Nasdaq(()), Lse(())]
  match router.route_order(o, Sweep([Nyse(()), Nasdaq(())]), available) {
    Err(e) => fail("expected Ok, got Err: " + e),
    Ok(d) => assert_eq_int(list.len(d.routes), 2, "sweep: 2 routes"),
  }
}

fn test_sweep_missing() -> Result[Unit, Str] {
  let o := sample_order(100)
  let available := [Nyse(()), Nasdaq(())]
  match router.route_order(o, Sweep([Nyse(()), Cboe(())]), available) {
    Ok(_) => fail("expected Err for missing venue in sweep"),
    Err(_) => pass(),
  }
}

fn test_zero_qty() -> Result[Unit, Str] {
  let o := sample_order(0)
  let available := [Nyse(())]
  match router.route_order(o, DirectTo(Nyse(())), available) {
    Ok(_) => fail("expected Err for zero quantity"),
    Err(e) => assert_true(str.contains(e, "positive"), "zero qty error mentions positive"),
  }
}

fn test_best_price_routes_to_first() -> Result[Unit, Str] {
  let o := sample_order(50)
  let available := [Nasdaq(()), Nyse(())]
  match router.route_order(o, BestPrice(()), available) {
    Err(e) => fail("expected Ok, got Err: " + e),
    Ok(d) => {
      match assert_eq_int(list.len(d.routes), 1, "best_price: 1 route") {
        Err(e) => Err(e),
        Ok(_) => {
          let venue_name := list.fold(d.routes, "", fn (acc :: Str, r :: route.Route) -> Str {
            if str.is_empty(acc) {
              vn.venue_to_str(r.venue)
            } else {
              acc
            }
          })
          assert_true(venue_name == "NASDAQ", "best_price: routes to first available (Nasdaq)")
        },
      }
    },
  }
}

fn suite() -> List[Result[Unit, Str]] {
  [test_direct_available(), test_direct_unavailable(), test_sweep_all_available(), test_sweep_missing(), test_zero_qty(), test_best_price_routes_to_first()]
}

fn run_all() -> Int {
  list.fold(suite(), 0, fn (n :: Int, r :: Result[Unit, Str]) -> Int {
    match r {
      Ok(_) => n,
      Err(_) => n + 1,
    }
  })
}

