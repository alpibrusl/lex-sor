# lex-sor tests — strategy and route construction
#
# Covers strategy_to_str, single_route, and sweep_routes.

import "std.list" as list

import "std.str" as str

import "std.int" as int

import "../src/strategy" as strategy

import "../src/route" as route

import "lex-fix/src/venue" as vn

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

# ---- Tests --------------------------------------------------------
fn test_strategy_to_str_best_price() -> Result[Unit, Str] {
  assert_true(strategy.strategy_to_str(BestPrice(())) == "BestPrice", "BestPrice display")
}

fn test_strategy_to_str_min_cost() -> Result[Unit, Str] {
  assert_true(strategy.strategy_to_str(MinCost(())) == "MinCost", "MinCost display")
}

fn test_strategy_to_str_direct_to() -> Result[Unit, Str] {
  let s := strategy.strategy_to_str(DirectTo(Nasdaq(())))
  assert_true(str.contains(s, "NASDAQ"), "DirectTo(Nasdaq) contains NASDAQ")
}

fn test_strategy_to_str_sweep() -> Result[Unit, Str] {
  let s := strategy.strategy_to_str(Sweep([Nyse(()), Nasdaq(())]))
  assert_true(str.contains(s, "NYSE") and str.contains(s, "NASDAQ"), "Sweep display contains both venues")
}

fn test_single_route() -> Result[Unit, Str] {
  let d := route.single_route(Nyse(()), 100)
  match assert_eq_int(d.total_qty, 100, "single_route total_qty") {
    Err(e) => Err(e),
    Ok(_) => assert_eq_int(list.len(d.routes), 1, "single_route has 1 route"),
  }
}

fn test_sweep_even() -> Result[Unit, Str] {
  let d := route.sweep_routes([Nyse(()), Nasdaq(())], 100)
  match assert_eq_int(list.len(d.routes), 2, "sweep_even: 2 routes") {
    Err(e) => Err(e),
    Ok(_) => {
      let first_qty := list.fold(d.routes, 0, fn (acc :: Int, r :: route.Route) -> Int {
        match acc {
          0 => r.quantity,
          _ => acc,
        }
      })
      match assert_eq_int(first_qty, 50, "sweep_even: first route qty 50") {
        Err(e) => Err(e),
        Ok(_) => assert_eq_int(d.total_qty, 100, "sweep_even: total_qty 100"),
      }
    },
  }
}

fn test_sweep_uneven() -> Result[Unit, Str] {
  let d := route.sweep_routes([Nyse(()), Nasdaq(()), Lse(())], 100)
  match assert_eq_int(list.len(d.routes), 3, "sweep_uneven: 3 routes") {
    Err(e) => Err(e),
    Ok(_) => {
      let total_check := list.fold(d.routes, 0, fn (acc :: Int, r :: route.Route) -> Int {
        acc + r.quantity
      })
      assert_eq_int(total_check, 100, "sweep_uneven: routes sum to 100")
    },
  }
}

fn test_sweep_single() -> Result[Unit, Str] {
  let d := route.sweep_routes([Nyse(())], 75)
  match assert_eq_int(list.len(d.routes), 1, "sweep_single: 1 route") {
    Err(e) => Err(e),
    Ok(_) => assert_eq_int(d.total_qty, 75, "sweep_single: total_qty 75"),
  }
}

fn suite() -> List[Result[Unit, Str]] {
  [test_strategy_to_str_best_price(), test_strategy_to_str_min_cost(), test_strategy_to_str_direct_to(), test_strategy_to_str_sweep(), test_single_route(), test_sweep_even(), test_sweep_uneven(), test_sweep_single()]
}

fn run_all() -> Int {
  list.fold(suite(), 0, fn (n :: Int, r :: Result[Unit, Str]) -> Int {
    match r {
      Ok(_) => n,
      Err(_) => n + 1,
    }
  })
}

