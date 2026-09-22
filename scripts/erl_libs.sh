# Sourced by mise ([env]._.source). Puts elixir.app on ERL_LIBS so pgo's
# opentelemetry_api OTP application can start under gleam test / gleam run.
_elixir_root="$(mise where elixir 2>/dev/null || true)"
_elixir_lib="${_elixir_root}/lib"
if [ -f "${_elixir_lib}/elixir/ebin/elixir.app" ]; then
  export ERL_LIBS="${_elixir_lib}${ERL_LIBS:+:$ERL_LIBS}"
fi
unset _elixir_root _elixir_lib
