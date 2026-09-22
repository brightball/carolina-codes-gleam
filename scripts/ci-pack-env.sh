#!/bin/sh
# Bundle the prepared workspace and mise toolchain for later Gitea jobs.
# Check jobs restore this archive instead of cloning or reinstalling.
#
# The workspace tar keeps .git so `gitleaks detect --source .` (no --no-git)
# scans commits. Strip HTTPS remote userinfo first so a token clone URL
# cannot leak into the artifact.
set -eu
root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$root"
mode="${1:-all}"

if [ ! -d .git ]; then
  echo "ci-pack-env: missing .git; gitleaks detect --source . would scan nothing" >&2
  exit 1
fi

remotes="$(git remote)"
for remote in $remotes; do
  url="$(git remote get-url "$remote")"
  stripped="$(printf '%s\n' "$url" | sed -E 's#(https?://)[^/@]+@#\1#')"
  if [ "$stripped" != "$url" ]; then
    git remote set-url "$remote" "$stripped"
  fi
done
if grep -R -q 'x-access-token:' .git 2>/dev/null; then
  echo "ci-pack-env: .git still contains x-access-token" >&2
  exit 1
fi

tmp="$(mktemp -d)"
cleanup() { rm -rf "$tmp"; }
trap cleanup EXIT
tar -czf "$tmp/prep-workspace.tar.gz" \
  --exclude=./prep-env.tar.gz \
  --exclude=./prep-workspace.tar.gz \
  --exclude=./prep-toolchain.tar.gz \
  .
if [ "$mode" = workspace ]; then
  mv "$tmp/prep-workspace.tar.gz" "$root/prep-workspace.tar.gz"
  exit 0
fi
tar -czf "$tmp/prep-toolchain.tar.gz" -C "${HOME}" .local/bin .local/share/mise
cp "$root/scripts/ci-restore-env.sh" "$tmp/ci-restore-env.sh"
chmod +x "$tmp/ci-restore-env.sh"
tar -czf "$tmp/prep-env.tar.gz" -C "$tmp" \
  prep-workspace.tar.gz \
  prep-toolchain.tar.gz \
  ci-restore-env.sh
mv "$tmp/prep-env.tar.gz" "$root/prep-env.tar.gz"
