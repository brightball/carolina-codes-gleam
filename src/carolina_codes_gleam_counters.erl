-module(carolina_codes_gleam_counters).
-export([reset/0, inc_sql/0, sql_count/0, inc_connect/0, connect_count/0]).

reset() ->
    persistent_term:put({carolina_codes_gleam, sql}, 0),
    persistent_term:put({carolina_codes_gleam, connect}, 0),
    nil.

inc_sql() ->
    put_add({carolina_codes_gleam, sql}).

sql_count() ->
    persistent_term:get({carolina_codes_gleam, sql}, 0).

inc_connect() ->
    put_add({carolina_codes_gleam, connect}).

connect_count() ->
    persistent_term:get({carolina_codes_gleam, connect}, 0).

put_add(Key) ->
    N = persistent_term:get(Key, 0) + 1,
    persistent_term:put(Key, N),
    N.
