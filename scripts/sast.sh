#!/bin/sh
# PEST SAST of this app's Erlang/Gleam-compiled Erlang only (not Hex packages).
set -eu
ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
gleam build
PEST="$ROOT/tools/pest/pest.erl"
echo "PEST src/"
"$PEST" -e -r src
artefacts="build/dev/erlang/carolina_codes_gleam/_gleam_artefacts"
if [ -d "$artefacts" ]; then
  echo "PEST ${artefacts} (this app only)"
  "$PEST" -e -r "$artefacts"
fi
echo "PEST: no findings"
