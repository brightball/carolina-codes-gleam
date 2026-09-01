import carolina_codes_gleam.{handle, listen_interface, start_db}
import carolina_codes_gleam/catalog
import carolina_codes_gleam/counters
import gleam/bit_array
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleeunit
import pog

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn unique_preserves_order_test() {
  assert catalog.unique(["elixir", "go", "elixir", "ruby"])
    == ["elixir", "go", "ruby"]
}

pub fn listen_interface_is_ipv6_test() {
  assert listen_interface == "::"
}

pub fn health_does_not_open_postgres_or_run_sql_test() {
  counters.reset()
  let db = pog.named_connection(process.new_name("unused-health"))
  let req =
    request.new()
    |> request.set_method(http.Get)
    |> request.set_path("/health")
  let resp = handle(db, req)
  assert resp.status == 200
  assert counters.sql_count() == 0
  assert counters.connect_count() == 0
}

pub fn register_once_does_not_query_catalog_test() {
  let src = case read_utf8("src/carolina_codes_gleam.gleam") {
    Ok(s) -> s
    Error(_) -> panic as "missing src/carolina_codes_gleam.gleam"
  }
  let fn_body = case string.split(src, "fn register(") {
    [_, rest, ..] -> rest
    _ -> ""
  }
  assert string.contains(src, "mist.bind(listen_interface)")
  assert string.contains(src, "mist.with_ipv6")
  assert !string.contains(src, "mist.bind(\"0.0.0.0\")")
  assert !string.contains(fn_body, "catalog.")
  assert !string.contains(fn_body, "pog.execute")
  assert !string.contains(fn_body, "start_db")
}

pub fn year_listing_sql_is_bounded_and_pool_is_reused_test() {
  counters.reset()
  let db = start_db()
  assert counters.connect_count() == 1
  let assert Ok(body) = catalog.list_speakers(db, Some(2026))
  let sql = counters.sql_count()
  let text = json.to_string(body)
  let speakers = count_needle(text, "\"talks\":")
  io.println(
    "year list sql="
    <> int.to_string(sql)
    <> " speakers="
    <> int.to_string(speakers)
    <> " connects="
    <> int.to_string(counters.connect_count()),
  )
  assert speakers >= 3
  assert sql > 0
  assert sql < speakers * 2
  assert sql <= 4
  let years_lists = years_arrays(text)
  let assert Ok(multi) =
    list.find(years_lists, fn(ys) { list.length(ys) >= 2 })
  assert is_descending(multi)
  let connects = counters.connect_count()
  let assert Ok(_) = catalog.list_speakers(db, Some(2026))
  assert counters.connect_count() == connects
}

fn years_arrays(text: String) -> List(List(Int)) {
  string.split(text, "\"years\":")
  |> list.drop(1)
  |> list.map(fn(chunk) {
    chunk
    |> string.split("]")
    |> list.first
    |> fn(r) {
      case r {
        Ok(arr) -> parse_ints(arr)
        Error(_) -> []
      }
    }
  })
}

fn parse_ints(arr: String) -> List(Int) {
  arr
  |> string.replace("[", "")
  |> string.replace(" ", "")
  |> string.split(",")
  |> list.filter_map(int.parse)
}

fn is_descending(years: List(Int)) -> Bool {
  case years {
    [] | [_] -> True
    [a, b, ..rest] -> a >= b && is_descending([b, ..rest])
  }
}

fn count_needle(hay: String, needle: String) -> Int {
  case string.split(hay, needle) {
    [] -> 0
    parts -> list.length(parts) - 1
  }
}

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(BitArray, String)

fn read_utf8(path: String) -> Result(String, Nil) {
  case read_file(path) {
    Ok(bits) ->
      case bit_array.to_string(bits) {
        Ok(s) -> Ok(s)
        Error(_) -> Error(Nil)
      }
    Error(_) -> Error(Nil)
  }
}
