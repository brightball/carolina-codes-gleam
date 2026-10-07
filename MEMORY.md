# MEMORY.md

This file is non-binding working memory for agents in this Gleam + mist + pog repository.
It yields to `DECISIONS.md`, the source, `mise.toml`, `gleam.toml`, and
`manifest.toml`. If this file disagrees with those, they win.

Do not record rulings here. Append them to `DECISIONS.md`. Do not put
secrets, production database URLs, or private hostnames in this file.

Gleam has no runtime agent-memory convention. This file is only a map of
how to run the tree and which files own versions.

## How to run

Toolchain from `mise.toml`: Gleam 1.18.1, Erlang/OTP 29, rebar 3.25.1.
Elixir 1.20.4 is dev-only (`scripts/erl_libs.sh` adds it to `ERL_LIBS`)
because `pgo` pulls `opentelemetry_api`. The shipment strips those Elixir
bits; see `DECISIONS.md`.

```
DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/carolina_dev \
CAROLINA_URL=http://127.0.0.1:4000 \
POLYGLOT_REGISTER_TOKEN=dev \
PUBLIC_BASE_URL=http://127.0.0.1:4008 \
PORT=4008 \
gleam run
```

`GET /health` returns `{"ok": true}` and does not open Postgres. The
listener binds before the pool.

Quality gates: `make test`, `make sast`, `make audit`, `make secrets`,
`make format`.

## Who owns versions

- Gleam, Erlang/OTP, rebar, dev Elixir, gitleaks: `mise.toml`
- mist, pog, go_over, cactus constraints: `gleam.toml`
- Locked package versions: `manifest.toml` (mist 6.0.3, pog 4.1.0, go_over 3.3.1, cactus 1.4.0)
- `language_version` string sent at register and on `GET /`: `src/carolina_codes_gleam.gleam`
- Image tags: `Dockerfile` (`erlang:29.1.0.0-alpine`, Gleam `v1.18.1`)
- CI Postgres image: `.gitea/workflows/precommit.yml` (`postgres:16`)

Change a pin in the owner file. If the reason changed, append a `DECISIONS.md`
entry. Do not hand-edit `manifest.toml`.

## Where behavior lives

- Routes, pool, IPv6 listen, register-once: `src/carolina_codes_gleam.gleam`
- `v1_*` SQL: `src/carolina_codes_gleam/catalog.gleam`
- Handler tests with a fake catalog (no Postgres): `test/carolina_codes_gleam_test.gleam` (`handle`)
- Catalog tests that need Postgres 16: same file, via `test/fixture.sql`
- File-contract tests: `test/precommit_gate_test.gleam`

The CMS OpenAPI is `priv/api/openapi.yaml` in the CMS repo. It is not in
this tree. This repo is the workspace root.
