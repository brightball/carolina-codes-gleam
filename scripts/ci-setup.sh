#!/bin/sh
# Install mise tools pinned in mise.toml (gleam, rebar, erlang, gitleaks).
set -eu
if ! command -v mise >/dev/null 2>&1; then
  curl -fsSL https://mise.run | sh
  export PATH="${HOME}/.local/bin:${PATH}"
fi
if command -v mise >/dev/null 2>&1; then
  :
elif [ -x "${HOME}/.local/bin/mise" ]; then
  export PATH="${HOME}/.local/bin:${PATH}"
fi
mise trust --yes 2>/dev/null || mise trust || true
mise install
if [ -n "${GITHUB_PATH:-}" ]; then
  echo "${HOME}/.local/bin" >> "${GITHUB_PATH}"
  echo "${HOME}/.local/share/mise/shims" >> "${GITHUB_PATH}"
fi
elixir_lib="$(mise where elixir 2>/dev/null || true)/lib"
if [ -f "${elixir_lib}/elixir/ebin/elixir.app" ]; then
  export ERL_LIBS="${elixir_lib}${ERL_LIBS:+:$ERL_LIBS}"
  if [ -n "${GITHUB_ENV:-}" ]; then
    echo "ERL_LIBS=${ERL_LIBS}" >> "${GITHUB_ENV}"
  fi
fi
