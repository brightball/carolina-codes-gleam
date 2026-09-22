/// Process-wide SQL and connect counters. Catalog queries and pool startup
/// bump the same counters the tests read.
@external(erlang, "carolina_codes_gleam_counters", "reset")
pub fn reset() -> Nil

@external(erlang, "carolina_codes_gleam_counters", "inc_sql")
pub fn inc_sql() -> Int

@external(erlang, "carolina_codes_gleam_counters", "sql_count")
pub fn sql_count() -> Int

@external(erlang, "carolina_codes_gleam_counters", "inc_connect")
pub fn inc_connect() -> Int

@external(erlang, "carolina_codes_gleam_counters", "connect_count")
pub fn connect_count() -> Int
