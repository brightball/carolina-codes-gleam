import carolina_codes_gleam.{
  type StartedPool, db_pool_size, ensure_pool, handle, listen_interface,
  open_pool, postgres_uses_ipv6, reset_pool,
}
import carolina_codes_gleam/catalog
import carolina_codes_gleam/counters
import envoy
import gleam/bit_array
import gleam/bytes_tree
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleeunit
import mist
import pog

const fixture_name = "carolina_codes_gleam_fixture"

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

pub fn fly_postgres_urls_use_ipv6_test() {
  assert postgres_uses_ipv6("postgres://u:p@app.flycast:5432/db")
  assert postgres_uses_ipv6("postgres://u:p@db.internal:5432/db")
  assert postgres_uses_ipv6("postgres://u:p@db.fly.io:5432/db")
  assert !postgres_uses_ipv6(
    "postgres://postgres:postgres@127.0.0.1:5432/carolina_dev",
  )
}

pub fn db_pool_size_fits_one_shared_cpu_test() {
  assert db_pool_size >= 1
  assert db_pool_size <= 4
  let src = must_read("src/carolina_codes_gleam.gleam")
  assert string.contains(src, "pog.pool_size(config, db_pool_size)")
  assert !string.contains(src, "pool_size(config, 8)")
  assert !string.contains(src, "pool_size(config, 10)")
}

pub fn health_does_not_open_postgres_or_run_sql_test() {
  counters.reset()
  let req = get("/health")
  let resp = handle(fn() { panic as "health opened the database" }, req)
  assert resp.status == 200
  assert response.get_header(resp, "content-type") == Ok("application/json")
  assert response.get_header(resp, "x-polyglot-language") == Ok("Gleam")
  assert response.get_header(resp, "x-polyglot-framework") == Ok("mist")
  assert json_bool(resp, "ok")
  assert counters.sql_count() == 0
  assert counters.connect_count() == 0
}

pub fn root_ignores_database_failure_test() {
  counters.reset()
  let resp = handle(fn() { panic as "root opened the database" }, get("/"))
  assert resp.status == 200
  let #(language, framework, paths) = identity(resp)
  assert language == "Gleam"
  assert framework == "mist"
  assert paths
    == [
      "/",
      "/health",
      "/v1/years",
      "/v1/speakers",
      "/v1/speakers/:slug",
      "/v1/speakers/:year/:slug",
      "/v1/sponsors",
      "/v1/sponsors/:slug",
      "/v1/sponsors/:year/:slug",
    ]
  assert counters.sql_count() == 0
  assert counters.connect_count() == 0
}

pub fn catalog_failure_is_http_500_test() {
  let resp = handle(fn() { Error("database_unavailable") }, get("/v1/years"))
  assert resp.status == 500
  assert json_string(resp, "error") == "database_unavailable"
  let speakers =
    handle(fn() { Error("database_unavailable") }, get("/v1/speakers/ada"))
  assert speakers.status == 500
}

pub fn non_numeric_year_is_404_without_database_test() {
  let resp =
    handle(
      fn() { panic as "non-numeric year opened the database" },
      get("/v1/speakers/nope/ada-lovelace"),
    )
  assert resp.status == 404
  assert json_string(resp, "error") == "not_found"
  let sponsors =
    handle(
      fn() { panic as "non-numeric year opened the database" },
      get("/v1/sponsors/nope/acme"),
    )
  assert sponsors.status == 404
  assert json_string(sponsors, "error") == "not_found"
}

pub fn unknown_routes_are_not_found_without_database_test() {
  let missing =
    handle(fn() { panic as "unknown path opened the database" }, get("/nope"))
  assert missing.status == 404
  assert json_string(missing, "error") == "not_found"
  let posted =
    handle(
      fn() { panic as "non-GET opened the database" },
      request.new()
        |> request.set_method(http.Post)
        |> request.set_path("/health"),
    )
  assert posted.status == 404
  assert json_string(posted, "error") == "not_found"
}

pub fn unreachable_database_is_json_500_test() {
  let assert Ok(pool) =
    open_pool("postgres://postgres:postgres@127.0.0.1:1/none")
  let resp = handle(fn() { Ok(pool.db) }, get("/v1/years"))
  let text = response_text(resp)
  assert resp.status == 500
  assert response.get_header(resp, "content-type") == Ok("application/json")
  assert !string.contains(text, "Internal Server Error")
  assert json_string(resp, "error") != ""
}

pub fn ensure_pool_invalid_url_is_http_500_test() {
  let previous = envoy.get("DATABASE_URL")
  envoy.set("DATABASE_URL", "not-a-postgres-url")
  reset_pool()
  let resp = handle(ensure_pool, get("/v1/years"))
  assert resp.status == 500
  assert json_string(resp, "error") == "database_unconfigured"
  case previous {
    Ok(url) -> envoy.set("DATABASE_URL", url)
    Error(_) -> envoy.unset("DATABASE_URL")
  }
  reset_pool()
}

pub fn listener_starts_before_pool_warmup_test() {
  let src = must_read("src/carolina_codes_gleam.gleam")
  let main_body = function_body(src, "pub fn main(")
  let register_body = function_body(src, "fn register(")
  assert string.contains(src, "mist.bind(listen_interface)")
  assert string.contains(src, "mist.with_ipv6")
  assert !string.contains(src, "mist.bind(\"0.0.0.0\")")
  assert string.contains(main_body, "handle(ensure_pool, req)")
  assert !string.contains(main_body, "start_db()")
  let assert Ok(bound) = index_of(main_body, "mist.start")
  let assert Ok(warm) = index_of(main_body, "ensure_pool()")
  assert bound < warm
  assert !string.contains(register_body, "catalog.")
  assert !string.contains(register_body, "pog.execute")
  assert !string.contains(register_body, "start_db")
  assert !string.contains(register_body, "ensure_pool")
}

pub fn year_listing_sql_is_bounded_and_pool_is_reused_test() {
  let fix = fixture()
  counters.reset()
  let assert Ok(pool) = open_pool(fix.url)
  assert counters.connect_count() == 1
  let req =
    get("/v1/speakers")
    |> request.set_query([#("year", "2026")])
  let resp = handle(fn() { Ok(pool.db) }, req)
  assert resp.status == 200
  let text = response_text(resp)
  let slugs = data_slugs(resp)
  assert list.length(slugs) >= 3
  assert list.contains(slugs, "ada-lovelace")
  assert list.contains(slugs, "grace-hopper")
  assert list.contains(slugs, "katherine-johnson")
  assert !list.contains(slugs, "barbara-liskov")
  let sql = counters.sql_count()
  assert sql > 0
  assert sql < list.length(slugs) * 2
  assert sql <= 4
  let years_lists = years_arrays(text)
  let assert Ok(multi) = list.find(years_lists, fn(ys) { list.length(ys) >= 2 })
  assert is_descending(multi)
  let connects = counters.connect_count()
  let again = handle(fn() { Ok(pool.db) }, req)
  assert again.status == 200
  assert counters.connect_count() == connects
}

pub fn documented_routes_against_fixture_test() {
  let fix = fixture()
  let db = fn() { Ok(fix.db) }

  let root = handle(db, get("/"))
  assert root.status == 200
  let #(_, _, paths) = identity(root)
  assert list.length(paths) == 9

  let health = handle(db, get("/health"))
  assert health.status == 200
  assert json_bool(health, "ok")

  let years = handle(db, get("/v1/years"))
  assert years.status == 200
  assert data_years(years) == [2026, 2025, 2024]

  let speakers = handle(db, get("/v1/speakers"))
  assert speakers.status == 200
  let speaker_slugs = data_slugs(speakers)
  assert list.contains(speaker_slugs, "ada-lovelace")
  assert list.contains(speaker_slugs, "barbara-liskov")

  let year_speakers =
    handle(db, get("/v1/speakers") |> request.set_query([#("year", "2026")]))
  assert year_speakers.status == 200
  assert list.length(data_slugs(year_speakers)) >= 3

  let one = handle(db, get("/v1/speakers/ada-lovelace"))
  assert one.status == 200
  assert data_slug(one) == "ada-lovelace"

  let one_year = handle(db, get("/v1/speakers/2026/ada-lovelace"))
  assert one_year.status == 200
  assert data_slug(one_year) == "ada-lovelace"

  let sponsors = handle(db, get("/v1/sponsors"))
  assert sponsors.status == 200
  assert data_slugs(sponsors) == ["acme", "globex"]

  let year_sponsors =
    handle(db, get("/v1/sponsors") |> request.set_query([#("year", "2026")]))
  assert year_sponsors.status == 200
  assert data_slugs(year_sponsors) == ["acme", "globex"]

  let sponsor = handle(db, get("/v1/sponsors/acme"))
  assert sponsor.status == 200
  assert data_slug(sponsor) == "acme"

  let sponsor_year = handle(db, get("/v1/sponsors/2026/acme"))
  assert sponsor_year.status == 200
  assert data_slug(sponsor_year) == "acme"
}

pub fn unknown_resources_fail_closed_test() {
  let fix = fixture()
  let db = fn() { Ok(fix.db) }

  let speaker = handle(db, get("/v1/speakers/missing-speaker"))
  assert speaker.status == 404
  assert json_string(speaker, "error") == "not_found"

  let speaker_year = handle(db, get("/v1/speakers/2024/ada-lovelace"))
  assert speaker_year.status == 404
  assert json_string(speaker_year, "error") == "not_found"

  let sponsor = handle(db, get("/v1/sponsors/missing-sponsor"))
  assert sponsor.status == 404
  assert json_string(sponsor, "error") == "not_found"

  let sponsor_year = handle(db, get("/v1/sponsors/2019/acme"))
  assert sponsor_year.status == 404
  assert json_string(sponsor_year, "error") == "not_found"

  let path = handle(db, get("/v1/not-a-route"))
  assert path.status == 404
  assert json_string(path, "error") == "not_found"
}

pub fn fixture_preserves_other_databases_test() {
  let fix = fixture()
  assert string.ends_with(fix.url, "/" <> fixture_name)
  assert fixture_name != "carolina_dev"
  assert fixture_name != "postgres"
  let assert Ok(admin) = open_pool(admin_url_for(fix.url))
  assert scalar_text(admin.db, "SELECT current_database()") == "postgres"
  let names =
    column_text(
      admin.db,
      "SELECT datname FROM pg_database WHERE datname <> '"
        <> fixture_name
        <> "' ORDER BY datname",
    )
  assert list.contains(names, "postgres")
  assert names == fix.other_databases
}

fn fixture() -> Fix {
  case fix_get() {
    Some(fix) -> fix
    None -> {
      let fix = provision_fixture()
      fix_put(FixKey, Some(fix))
      fix
    }
  }
}

fn provision_fixture() -> Fix {
  assert fixture_name != "carolina_dev"
  assert fixture_name != "postgres"
  assert fixture_name != "template0"
  assert fixture_name != "template1"
  let #(admin_url, admin) = reachable_admin()
  assert scalar_text(admin.db, "SELECT current_database()") == "postgres"
  let others =
    column_text(
      admin.db,
      "SELECT datname FROM pg_database WHERE datname <> '"
        <> fixture_name
        <> "' ORDER BY datname",
    )
  let assert Ok(_) =
    exec(
      admin.db,
      "DROP DATABASE IF EXISTS " <> fixture_name <> " WITH (FORCE)",
    )
  let assert Ok(_) = exec(admin.db, "CREATE DATABASE " <> fixture_name)
  let after =
    column_text(
      admin.db,
      "SELECT datname FROM pg_database WHERE datname <> '"
        <> fixture_name
        <> "' ORDER BY datname",
    )
  assert after == others
  let url = set_database(admin_url, fixture_name)
  let assert Ok(pool) = open_pool(url)
  assert scalar_text(pool.db, "SELECT current_database()") == fixture_name
  apply_fixture(pool.db)
  Fix(url:, db: pool.db, other_databases: others)
}

fn reachable_admin() -> #(String, StartedPool) {
  reachable_admin_loop(30)
}

fn reachable_admin_loop(left: Int) -> #(String, StartedPool) {
  case first_ok(candidate_admin_urls()) {
    Ok(pair) -> pair
    Error(_) ->
      case left {
        0 -> panic as "postgres 16 is not reachable for the v1 fixture"
        _ -> {
          process.sleep(500)
          reachable_admin_loop(left - 1)
        }
      }
  }
}

fn first_ok(urls: List(String)) -> Result(#(String, StartedPool), Nil) {
  case urls {
    [] -> Error(Nil)
    [url, ..rest] ->
      case probe(url) {
        Ok(pool) -> Ok(#(url, pool))
        Error(_) -> first_ok(rest)
      }
  }
}

fn probe(url: String) -> Result(StartedPool, Nil) {
  case open_pool(url) {
    Error(_) -> Error(Nil)
    Ok(pool) ->
      case
        pog.query("SELECT 1")
        |> pog.returning({
          use n <- decode.field(0, decode.int)
          decode.success(n)
        })
        |> pog.timeout(1000)
        |> pog.execute(pool.db)
      {
        Ok(_) -> Ok(pool)
        Error(_) -> Error(Nil)
      }
  }
}

fn candidate_admin_urls() -> List(String) {
  let configured =
    envoy.get("DATABASE_URL")
    |> result.unwrap("postgres://postgres:postgres@127.0.0.1:5432/carolina_dev")
  let admin = set_database(configured, "postgres")
  unique_strings([
    admin,
    set_host(admin, "127.0.0.1"),
    set_host(admin, "postgres"),
    "postgres://postgres:postgres@127.0.0.1:5432/postgres",
    "postgres://postgres:postgres@postgres:5432/postgres",
  ])
}

fn apply_fixture(db: pog.Connection) -> Nil {
  let sql = must_read("test/fixture.sql")
  list.each(statements(sql), fn(statement) {
    let assert Ok(_) = exec(db, statement)
  })
}

fn statements(sql: String) -> List(String) {
  sql
  |> string.split(";")
  |> list.map(string.trim)
  |> list.filter(fn(statement) { statement != "" })
}

fn exec(db: pog.Connection, sql: String) -> Result(Nil, String) {
  case pog.query(sql) |> pog.execute(db) {
    Ok(_) -> Ok(Nil)
    Error(err) -> Error(string.inspect(err) <> " sql=" <> sql)
  }
}

fn scalar_text(db: pog.Connection, sql: String) -> String {
  let assert [value] = column_text(db, sql)
  value
}

fn column_text(db: pog.Connection, sql: String) -> List(String) {
  let assert Ok(pog.Returned(_, rows)) =
    pog.query(sql)
    |> pog.returning({
      use value <- decode.field(0, decode.string)
      decode.success(value)
    })
    |> pog.execute(db)
  rows
}

fn admin_url_for(fixture_url: String) -> String {
  set_database(fixture_url, "postgres")
}

fn set_database(url: String, database: String) -> String {
  let base = case string.split_once(url, "?") {
    Ok(#(before, _)) -> before
    Error(_) -> url
  }
  case string.split(base, "/") {
    [scheme, "", host, ..] -> scheme <> "//" <> host <> "/" <> database
    _ -> base
  }
}

fn set_host(url: String, host: String) -> String {
  case string.split_once(url, "@") {
    Error(_) -> url
    Ok(#(userinfo, rest)) -> {
      let #(hostport, database) = case string.split_once(rest, "/") {
        Ok(#(hostport, database)) -> #(hostport, database)
        Error(_) -> #(rest, "postgres")
      }
      let port = case string.split(hostport, ":") {
        [_, p] -> ":" <> p
        _ -> ""
      }
      userinfo <> "@" <> host <> port <> "/" <> database
    }
  }
}

fn unique_strings(items: List(String)) -> List(String) {
  unique_strings_loop(items, [])
}

fn unique_strings_loop(
  items: List(String),
  seen: List(String),
) -> List(String) {
  case items {
    [] -> list.reverse(seen)
    [item, ..rest] ->
      case list.contains(seen, item) {
        True -> unique_strings_loop(rest, seen)
        False -> unique_strings_loop(rest, [item, ..seen])
      }
  }
}

type Fix {
  Fix(url: String, db: pog.Connection, other_databases: List(String))
}

type FixKey {
  FixKey
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

fn get(path: String) -> request.Request(String) {
  request.new()
  |> request.set_method(http.Get)
  |> request.set_path(path)
}

fn response_text(resp: response.Response(mist.ResponseData)) -> String {
  let assert mist.Bytes(tree) = resp.body
  let assert Ok(text) = bit_array.to_string(bytes_tree.to_bit_array(tree))
  text
}

fn json_bool(resp: response.Response(mist.ResponseData), key: String) -> Bool {
  let assert Ok(value) =
    json.parse(response_text(resp), {
      use value <- decode.field(key, decode.bool)
      decode.success(value)
    })
  value
}

fn json_string(
  resp: response.Response(mist.ResponseData),
  key: String,
) -> String {
  let assert Ok(value) =
    json.parse(response_text(resp), {
      use value <- decode.field(key, decode.string)
      decode.success(value)
    })
  value
}

fn data_slugs(resp: response.Response(mist.ResponseData)) -> List(String) {
  let assert Ok(slugs) =
    json.parse(response_text(resp), {
      use slugs <- decode.field(
        "data",
        decode.list({
          use slug <- decode.field("slug", decode.string)
          decode.success(slug)
        }),
      )
      decode.success(slugs)
    })
  slugs
}

fn data_slug(resp: response.Response(mist.ResponseData)) -> String {
  let assert Ok(slug) =
    json.parse(response_text(resp), {
      use slug <- decode.field("data", {
        use slug <- decode.field("slug", decode.string)
        decode.success(slug)
      })
      decode.success(slug)
    })
  slug
}

fn data_years(resp: response.Response(mist.ResponseData)) -> List(Int) {
  let assert Ok(years) =
    json.parse(response_text(resp), {
      use years <- decode.field(
        "data",
        decode.list({
          use year <- decode.field("year", decode.int)
          decode.success(year)
        }),
      )
      decode.success(years)
    })
  years
}

fn identity(
  resp: response.Response(mist.ResponseData),
) -> #(String, String, List(String)) {
  let assert Ok(value) =
    json.parse(response_text(resp), {
      use language <- decode.field("language", decode.string)
      use framework <- decode.field("framework", decode.string)
      use paths <- decode.field(
        "endpoints",
        decode.list({
          use path <- decode.field("path", decode.string)
          decode.success(path)
        }),
      )
      decode.success(#(language, framework, paths))
    })
  value
}

fn function_body(src: String, header: String) -> String {
  case string.split(src, header) {
    [_, rest, ..] ->
      case string.split(rest, "\nfn ") {
        [body, ..] -> body
        _ -> rest
      }
    _ -> panic as "missing function"
  }
}

fn index_of(hay: String, needle: String) -> Result(Int, Nil) {
  case string.split_once(hay, needle) {
    Ok(#(before, _)) -> Ok(string.length(before))
    Error(_) -> Error(Nil)
  }
}

fn must_read(path: String) -> String {
  case read_file(path) {
    Ok(bits) ->
      case bit_array.to_string(bits) {
        Ok(s) -> s
        Error(_) -> panic as "not utf-8"
      }
    Error(_) -> panic as "missing file"
  }
}

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(BitArray, String)

@external(erlang, "persistent_term", "get")
fn fix_get_raw(key: FixKey, default: Option(Fix)) -> Option(Fix)

fn fix_get() -> Option(Fix) {
  fix_get_raw(FixKey, None)
}

@external(erlang, "persistent_term", "put")
fn fix_put(key: FixKey, value: Option(Fix)) -> Nil
