#!/bin/sh
# Export the production Erlang shipment and drop the unused Elixir dependency
# that the Hex build of opentelemetry_api records.
set -eu
root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$root"
gleam export erlang-shipment
sh "$root/scripts/strip-otel-elixir.sh" "$root/build/erlang-shipment"
