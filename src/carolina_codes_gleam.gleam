import carolina_codes_gleam/catalog
import carolina_codes_gleam/counters
import envoy
import gleam/bytes_tree
import gleam/erlang/process.{type Name, type Pid}
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/httpc
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import logging
import mist.{type Connection, type ResponseData}
import pog

const language = "Gleam"

const language_version = "1.18.1"

const api_version = "0.2.0"

const framework = "mist"

const created_year = 2026

const schema_version = 1

const default_db = "postgres://postgres:postgres@127.0.0.1:5432/carolina_dev"

/// One shared CPU. Two sessions are enough for this read API and avoid eight
/// Postgres handshakes competing with the listener during a cold boot.
pub const db_pool_size = 2

/// IPv6 any-address. Pair with `mist.with_ipv6` for dual-stack where supported.
pub const listen_interface = "::"

/// A pool process and the connection name queries use.
pub type StartedPool {
  StartedPool(pid: Pid, db: pog.Connection)
}

/// Fly Postgres hostnames are IPv6-only on the private network.
pub fn postgres_uses_ipv6(url: String) -> Bool {
  string.contains(url, "flycast")
  || string.contains(url, ".internal")
  || string.contains(url, ".fly.io")
}

/// Open one pool for `url`. Does not cache it. A bad URL or a pool that
/// cannot start returns an error instead of crashing the caller.
pub fn open_pool(url: String) -> Result(StartedPool, String) {
  open_named(process.new_name("pog"), url)
}

/// Shared production pool. Successful starts are reused. Failures are not
/// cached, so a later request can connect after Postgres becomes reachable.
pub fn ensure_pool() -> Result(pog.Connection, String) {
  case pool_get() {
    Some(db) -> Ok(db)
    None ->
      case open_named(production_pool_name(), database_url()) {
        Ok(pool) -> {
          pool_put(pool.db)
          Ok(pool.db)
        }
        Error(err) ->
          case pool_get() {
            Some(db) -> Ok(db)
            None -> Error(err)
          }
      }
  }
}

/// Drop the cached production connection so the next `ensure_pool` starts again.
pub fn reset_pool() -> Nil {
  pool_clear()
}

/// Start a pool from `DATABASE_URL`, or the local default when that is unset.
pub fn start_db() -> Result(pog.Connection, String) {
  use pool <- result.try(open_pool(database_url()))
  Ok(pool.db)
}

pub fn main() -> Nil {
  logging.configure()
  let port =
    envoy.get("PORT")
    |> result.try(int.parse)
    |> result.unwrap(4008)

  // Bind before any Postgres work. Fly's /health check must not wait on
  // Flycast DNS or pool handshakes, and a down database must not kill the VM.
  let assert Ok(_) =
    fn(req: Request(Connection)) { handle(ensure_pool, req) }
    |> mist.new
    |> mist.bind(listen_interface)
    |> mist.with_ipv6
    |> mist.port(port)
    |> mist.start

  process.spawn_unlinked(fn() {
    let _ = ensure_pool()
  })
  process.spawn_unlinked(fn() { register(port) })

  io.println("carolina-codes-gleam listening on :" <> int.to_string(port))
  process.sleep_forever()
}

/// `db` is called only for routes that query the catalog. `/`, `/health`,
/// unknown paths, and a non-numeric year segment never call it.
pub fn handle(
  db: fn() -> Result(pog.Connection, String),
  req: Request(t),
) -> Response(ResponseData) {
  case req.method, request.path_segments(req) {
    http.Get, [] -> send_json(200, identity_json())
    http.Get, ["health"] ->
      send_json(200, json.object([#("ok", json.bool(True))]))
    http.Get, ["v1", "years"] -> with_db(db, catalog.list_years)
    http.Get, ["v1", "speakers"] ->
      with_db(db, fn(conn) { catalog.list_speakers(conn, query_year(req)) })
    http.Get, ["v1", "speakers", year, slug] ->
      case int.parse(year) {
        Ok(y) ->
          with_db_optional(db, fn(conn) {
            catalog.speaker_by_year(conn, y, slug)
          })
        Error(_) -> not_found()
      }
    http.Get, ["v1", "speakers", slug] ->
      with_db_optional(db, fn(conn) { catalog.speaker_by_slug(conn, slug) })
    http.Get, ["v1", "sponsors"] ->
      with_db(db, fn(conn) { catalog.list_sponsors(conn, query_year(req)) })
    http.Get, ["v1", "sponsors", year, slug] ->
      case int.parse(year) {
        Ok(y) ->
          with_db_optional(db, fn(conn) {
            catalog.sponsor_by_year(conn, y, slug)
          })
        Error(_) -> not_found()
      }
    http.Get, ["v1", "sponsors", slug] ->
      with_db_optional(db, fn(conn) { catalog.sponsor_by_slug(conn, slug) })
    _, _ -> not_found()
  }
}

fn database_url() -> String {
  envoy.get("DATABASE_URL") |> result.unwrap(default_db)
}

fn production_pool_name() -> Name(pog.Message) {
  case name_get() {
    Some(name) -> name
    None -> {
      let name = process.new_name("carolina_db")
      name_put(name)
      name
    }
  }
}

fn open_named(
  name: Name(pog.Message),
  url: String,
) -> Result(StartedPool, String) {
  case pog.url_config(name, url) {
    Error(_) -> Error("database_unconfigured")
    Ok(config) -> {
      let _ = counters.inc_connect()
      let config = pog.pool_size(config, db_pool_size)
      let config = case postgres_uses_ipv6(url) {
        True -> pog.ip_version(config, pog.Ipv6)
        False -> config
      }
      case pog.start(config) {
        Ok(started) -> {
          // pog starts the pool linked to the caller. Callers include a
          // one-shot warmup process and individual HTTP requests; either
          // exiting would take the pool down. The listener keeps it alive.
          process.unlink(started.pid)
          Ok(StartedPool(pid: started.pid, db: started.data))
        }
        Error(_) -> Error("database_unavailable")
      }
    }
  }
}

fn with_db(
  db: fn() -> Result(pog.Connection, String),
  query: fn(pog.Connection) -> Result(json.Json, String),
) -> Response(ResponseData) {
  case db() {
    Ok(conn) ->
      case protect(fn() { query(conn) }) {
        Ran(result) -> catalog_json(result)
        Crashed(reason) -> {
          io.println("catalog query failed: " <> reason)
          reset_pool()
          server_error("database_unavailable")
        }
      }
    Error(err) -> server_error(err)
  }
}

fn with_db_optional(
  db: fn() -> Result(pog.Connection, String),
  query: fn(pog.Connection) -> Result(option.Option(json.Json), String),
) -> Response(ResponseData) {
  case db() {
    Ok(conn) ->
      case protect(fn() { query(conn) }) {
        Ran(result) -> catalog_optional(result)
        Crashed(reason) -> {
          io.println("catalog query failed: " <> reason)
          reset_pool()
          server_error("database_unavailable")
        }
      }
    Error(err) -> server_error(err)
  }
}

type Attempt(value) {
  Ran(value)
  Crashed(String)
}

fn query_year(req: Request(t)) -> option.Option(Int) {
  request.get_query(req)
  |> result.unwrap([])
  |> list.key_find("year")
  |> result.try(int.parse)
  |> option.from_result
}

fn catalog_json(result: Result(json.Json, String)) -> Response(ResponseData) {
  case result {
    Ok(body) -> send_json(200, body)
    Error(err) -> server_error(err)
  }
}

fn catalog_optional(
  result: Result(option.Option(json.Json), String),
) -> Response(ResponseData) {
  case result {
    Ok(Some(body)) -> send_json(200, body)
    Ok(None) -> not_found()
    Error(err) -> server_error(err)
  }
}

fn server_error(err: String) -> Response(ResponseData) {
  send_json(500, json.object([#("error", json.string(err))]))
}

fn not_found() -> Response(ResponseData) {
  send_json(404, json.object([#("error", json.string("not_found"))]))
}

fn send_json(status: Int, body: json.Json) -> Response(ResponseData) {
  response.new(status)
  |> response.set_header("content-type", "application/json")
  |> response.set_header("x-polyglot-language", language)
  |> response.set_header("x-polyglot-framework", framework)
  |> response.set_body(mist.Bytes(bytes_tree.from_string(json.to_string(body))))
}

fn identity_json() -> json.Json {
  json.object([
    #("language", json.string(language)),
    #("language_version", json.string(language_version)),
    #("api_version", json.string(api_version)),
    #("framework", json.string(framework)),
    #("created_year", json.int(created_year)),
    #("schema_version", json.int(schema_version)),
    #("endpoints", json.preprocessed_array(endpoints_json())),
  ])
}

fn endpoints_json() -> List(json.Json) {
  [
    endpoint("GET", "/", []),
    endpoint("GET", "/health", []),
    endpoint("GET", "/v1/years", []),
    endpoint("GET", "/v1/speakers", ["year"]),
    endpoint("GET", "/v1/speakers/:slug", []),
    endpoint("GET", "/v1/speakers/:year/:slug", []),
    endpoint("GET", "/v1/sponsors", ["year"]),
    endpoint("GET", "/v1/sponsors/:slug", []),
    endpoint("GET", "/v1/sponsors/:year/:slug", []),
  ]
}

fn endpoint(method: String, path: String, query: List(String)) -> json.Json {
  json.object([
    #("method", json.string(method)),
    #("path", json.string(path)),
    #("query", json.array(query, json.string)),
  ])
}

fn register(port: Int) -> Nil {
  let carolina = envoy.get("CAROLINA_URL")
  let token = envoy.get("POLYGLOT_REGISTER_TOKEN")
  case carolina, token {
    Ok(url), Ok(secret) -> {
      let base =
        envoy.get("PUBLIC_BASE_URL")
        |> result.unwrap("http://127.0.0.1:" <> int.to_string(port))
      let body =
        json.object([
          #("language", json.string(language)),
          #("language_version", json.string(language_version)),
          #("api_version", json.string(api_version)),
          #("framework", json.string(framework)),
          #("created_year", json.int(created_year)),
          #("schema_version", json.int(schema_version)),
          #("base_url", json.string(base)),
          #("endpoints", json.preprocessed_array(endpoints_json())),
        ])
        |> json.to_string
      let target = join_url(url, "/internal/api-endpoints/register")
      case request.to(target) {
        Error(_) -> io.println("register: invalid CAROLINA_URL")
        Ok(req) -> {
          let req =
            req
            |> request.set_method(http.Post)
            |> request.set_header("authorization", "Bearer " <> secret)
            |> request.set_header("content-type", "application/json")
            |> request.set_body(body)
          case
            httpc.configure()
            |> httpc.timeout(5000)
            |> httpc.dispatch(req)
          {
            Ok(resp) ->
              io.println(
                "registered with elixir: " <> int.to_string(resp.status),
              )
            Error(err) -> io.println("register: " <> string.inspect(err))
          }
        }
      }
    }
    _, _ -> Nil
  }
}

fn join_url(url: String, path: String) -> String {
  case string.ends_with(url, "/") {
    True -> string.drop_end(url, 1) <> path
    False -> url <> path
  }
}

@external(erlang, "carolina_codes_gleam_counters", "pool_get")
fn pool_get() -> option.Option(pog.Connection)

@external(erlang, "carolina_codes_gleam_counters", "pool_put")
fn pool_put(conn: pog.Connection) -> Nil

@external(erlang, "carolina_codes_gleam_counters", "pool_clear")
fn pool_clear() -> Nil

@external(erlang, "carolina_codes_gleam_counters", "name_get")
fn name_get() -> option.Option(Name(pog.Message))

@external(erlang, "carolina_codes_gleam_counters", "name_put")
fn name_put(name: Name(pog.Message)) -> Nil

@external(erlang, "carolina_codes_gleam_counters", "protect")
fn protect(run: fn() -> value) -> Attempt(value)
