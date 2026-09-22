#!/bin/sh
# Gitea act_runner often has an empty workspace and git HTTP needs the job token.
set -eu
if [ -d .git ] || [ -f gleam.toml ]; then
  exit 0
fi
token="${GITHUB_TOKEN:-${GITEA_TOKEN:-}}"
if [ -z "$token" ]; then
  echo "missing job token for git fetch" >&2
  exit 1
fi
host="${GITHUB_SERVER_URL#https://}"
host="${host#http://}"
git clone --depth 1 --no-checkout "https://x-access-token:${token}@${host}/${GITHUB_REPOSITORY}" .
git fetch --depth 1 origin "${GITHUB_SHA}"
git checkout --force FETCH_HEAD
