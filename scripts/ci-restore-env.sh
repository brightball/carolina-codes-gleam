#!/bin/sh
# Restore the prepare-job workspace and mise toolchain. Do not clone
# or reinstall packages.
set -eu
workspace="$(find . -name prep-workspace.tar.gz -print | head -1)"
toolchain="$(find . -name prep-toolchain.tar.gz -print | head -1)"
test -n "$workspace"
test -n "$toolchain"
tar -xzf "$workspace"
tar -xzf "$toolchain" -C "${HOME}"
if [ -n "${GITHUB_PATH:-}" ]; then
  echo "${HOME}/.local/bin" >> "${GITHUB_PATH}"
  echo "${HOME}/.local/share/mise/shims" >> "${GITHUB_PATH}"
fi
export PATH="${HOME}/.local/bin:${HOME}/.local/share/mise/shims:${PATH}"
mise trust --yes 2>/dev/null || true
elixir_lib="$(mise where elixir 2>/dev/null || true)/lib"
if [ -n "${GITHUB_ENV:-}" ] && [ -f "${elixir_lib}/elixir/ebin/elixir.app" ]; then
  echo "ERL_LIBS=${elixir_lib}${ERL_LIBS:+:$ERL_LIBS}" >> "${GITHUB_ENV}"
fi
