-module(carolina_codes_gleam_counters).
-export([reset/0, inc_sql/0, sql_count/0, inc_connect/0, connect_count/0]).
-export([pool_get/0, pool_put/1, pool_clear/0, name_get/0, name_put/1, protect/1]).

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

%% Gleam `Option`: `none` or `{some, Term}`.
pool_get() ->
    persistent_term:get({carolina_codes_gleam, pool}, none).

pool_put(Conn) ->
    persistent_term:put({carolina_codes_gleam, pool}, {some, Conn}),
    nil.

pool_clear() ->
    persistent_term:put({carolina_codes_gleam, pool}, none),
    nil.

name_get() ->
    persistent_term:get({carolina_codes_gleam, pool_name}, none).

name_put(Name) ->
    persistent_term:put({carolina_codes_gleam, pool_name}, {some, Name}),
    nil.

%% pgo exits the caller when the pool process is gone. Catch that so a
%% request becomes an error instead of killing the HTTP worker.
protect(Fun) ->
    try
        {ran, Fun()}
    catch
        Class:Reason:_Stack ->
            {crashed, unicode:characters_to_binary(io_lib:format("~p:~p", [Class, Reason]))}
    end.
