import carolina_codes_gleam/catalog
import envoy
import gleam/bytes_tree
import gleam/erlang/process
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

pub fn main() -> Nil {
  logging.configure()
  let port =
    envoy.get("PORT")
    |> result.try(int.parse)
    |> result.unwrap(4008)

  let db_url = envoy.get("DATABASE_URL") |> result.unwrap(default_db)
  let pool_name = process.new_name("pog")
  let assert Ok(config) = pog.url_config(pool_name, db_url)
  let config = pog.pool_size(config, 8)
  let assert Ok(_) = pog.start(config)
  let db = pog.named_connection(pool_name)

  process.spawn_unlinked(fn() { register(port) })

  let assert Ok(_) =
    fn(req: Request(Connection)) -> Response(ResponseData) {
      handle(db, req)
    }
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(port)
    |> mist.start

  io.println("carolina-codes-gleam listening on :" <> int.to_string(port))
  process.sleep_forever()
}

fn handle(
  db: pog.Connection,
  req: Request(Connection),
) -> Response(ResponseData) {
  case req.method, request.path_segments(req) {
    http.Get, [] -> send_json(200, identity_json())
    http.Get, ["health"] ->
      send_json(200, json.object([#("ok", json.bool(True))]))
    http.Get, ["v1", "years"] -> catalog_json(catalog.list_years(db))
    http.Get, ["v1", "speakers"] ->
      catalog_json(catalog.list_speakers(db, query_year(req)))
    http.Get, ["v1", "speakers", year, slug] ->
      case int.parse(year) {
        Ok(y) -> catalog_optional(catalog.speaker_by_year(db, y, slug))
        Error(_) -> not_found()
      }
    http.Get, ["v1", "speakers", slug] ->
      catalog_optional(catalog.speaker_by_slug(db, slug))
    http.Get, ["v1", "sponsors"] ->
      catalog_json(catalog.list_sponsors(db, query_year(req)))
    http.Get, ["v1", "sponsors", year, slug] ->
      case int.parse(year) {
        Ok(y) -> catalog_optional(catalog.sponsor_by_year(db, y, slug))
        Error(_) -> not_found()
      }
    http.Get, ["v1", "sponsors", slug] ->
      catalog_optional(catalog.sponsor_by_slug(db, slug))
    _, _ -> not_found()
  }
}

fn query_year(req: Request(Connection)) -> option.Option(Int) {
  request.get_query(req)
  |> result.unwrap([])
  |> list.key_find("year")
  |> result.try(int.parse)
  |> option.from_result
}

fn catalog_json(result: Result(json.Json, String)) -> Response(ResponseData) {
  case result {
    Ok(body) -> send_json(200, body)
    Error(err) -> send_json(500, json.object([#("error", json.string(err))]))
  }
}

fn catalog_optional(
  result: Result(option.Option(json.Json), String),
) -> Response(ResponseData) {
  case result {
    Ok(Some(body)) -> send_json(200, body)
    Ok(None) -> not_found()
    Error(err) -> send_json(500, json.object([#("error", json.string(err))]))
  }
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
