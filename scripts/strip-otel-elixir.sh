#!/bin/sh
# pgo depends on opentelemetry_api. Hex ships a Mix build of that app whose
# .app file requires the elixir application and embeds Elixir.* beams.
# The Erlang modules pgo actually calls do not. Drop the elixir dependency
# from the exported shipment so the runtime image does not need Elixir.
set -eu
root="${1:?shipment directory}"
found=0
# shellcheck disable=SC2044
for app in $(find "$root" -name opentelemetry_api.app); do
  found=1
  sed -i \
    -e 's/,elixir//g' \
    -e "s/'Elixir[^']*',//g" \
    "$app"
  rm -f "$(dirname "$app")"/Elixir.*.beam
  if grep -q elixir "$app"; then
    echo "strip-otel-elixir: elixir still referenced in $app" >&2
    exit 1
  fi
done
if [ "$found" != 1 ]; then
  echo "strip-otel-elixir: opentelemetry_api.app not found under $root" >&2
  exit 1
fi
# A dev machine with Elixir on ERL_LIBS makes gleam copy elixir, eex, mix,
# and Elixir's logger into the shipment. None of them are required at runtime.
rm -rf "$root/elixir" "$root/eex" "$root/mix" "$root/logger"

# Gleam writes the shebang below SPDX comments. Docker's exec form requires
# the shebang on line 1, or the kernel returns "exec format error".
entrypoint="${root}/entrypoint.sh"
if [ -f "$entrypoint" ]; then
  tmp="$(mktemp)"
  {
    printf '%s\n' '#!/bin/sh'
    grep -v '^#!/bin/sh$' "$entrypoint" || true
  } >"$tmp"
  mv "$tmp" "$entrypoint"
  chmod +x "$entrypoint"
fi
