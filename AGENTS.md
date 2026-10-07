# carolina-codes-gleam

Finished read-only v1 HTTP API for a Carolina Code Conference Elixir site.
Gleam 1.18.1 on the Erlang VM (OTP 29), HTTP with mist 6.0.3, SQL with pog 4.1.0.

This repository is the workspace root. It is a finished service, not the
forkable starter at `carolina-codes-api-starter`, and not the Phoenix CMS
remote (`github.com/brightball/carolina-codes`). Do not assume `../elixir` or
any other sibling checkout exists. Do not fold this tree into the CMS git
remote.

The HTTP contract is the CMS OpenAPI: `priv/api/openapi.yaml` and
`priv/api/AGENTS.md` in that CMS repo. There is no `openapi.yaml` in this
tree. Responses are ordinary JSON. Do not implement Ash JSON:API
(`application/vnd.api+json`).

`GET /health` returns `{"ok": true}`. Leave that body as the code emits it.

## Decisions

Before changing the HTTP stack, the listen address, the pog pool size, health
versus Postgres, the erlang-shipment Elixir strip, or the CI Postgres major
version, read `DECISIONS.md`. Accepted entries are binding. To change one,
append a new dated entry and mark the old entry superseded. Do not silently
re-litigate it.

`MEMORY.md` is non-binding working memory for this Gleam + mist + pog tree.
It yields to `DECISIONS.md`, the source, `mise.toml`, `gleam.toml`, and
`manifest.toml`.

## Purpose

The Phoenix app (`Carolina.Polyglot`) keeps at most one language API warm and
reads speakers and sponsors from it. With no API registered, it falls back to
Ash. This process must:

1. Query PostgreSQL `v1_*` views, never Ash resource tables.
2. Expose the v1 routes from the CMS OpenAPI contract.
3. Register once on boot with the Elixir site (no heartbeat). If
   `CAROLINA_URL` is empty or the POST fails, log and keep serving.

## Environment

| Variable | Example | Role |
| --- | --- | --- |
| `DATABASE_URL` | `postgres://postgres:postgres@127.0.0.1:5432/carolina_dev` | CMS `v1_*` views |
| `CAROLINA_URL` | `http://127.0.0.1:4000` | Elixir site (optional; register no-ops if unset) |
| `POLYGLOT_REGISTER_TOKEN` | `dev` | Bearer token for register |
| `PUBLIC_BASE_URL` | `http://127.0.0.1:4008` | URL the Elixir site will call |
| `PORT` | `4008` | Listen port (container and Fly set `8080`) |

Unset `DATABASE_URL` falls back to the local example above. Registration
runs only when both `CAROLINA_URL` and `POLYGLOT_REGISTER_TOKEN` are set.

## SQL views (query these)

`catalog.gleam` reads `v1_years`, `v1_speakers`, `v1_talks`, `v1_sponsors`,
`v1_year_sponsors`, and `v1_sponsorships`. Those views live in the CMS
database. This repo does not ship `db/*.sql`.

Do not `SELECT` from Ash tables (`speakers`, `organizations`, `talks`, and
the other base tables). The views are the API.

`test/fixture.sql` creates throwaway tables with the same names so catalog
tests can run against Postgres 16. It is not the CMS schema.

## Required HTTP routes

List payloads are `{ "data": [ ... ] }` unless noted. Unknown slugs are 404
`{"error":"not_found"}`. A catalog database failure is 500 JSON
`{"error":"..."}`. Non-GET requests are 404.

- `GET /health` — liveness (`{"ok": true}`). Does not open Postgres or run SQL.
- `GET /` — identity (`language`, `language_version`, `api_version`, `framework`, `created_year`, `schema_version`, `endpoints`). Does not open Postgres.
- `GET /v1/years`
- `GET /v1/speakers` and `GET /v1/speakers?year=2025`
- `GET /v1/speakers/{slug}` and `GET /v1/speakers/{year}/{slug}`
- `GET /v1/sponsors` and `GET /v1/sponsors?year=2025`
- `GET /v1/sponsors/{slug}` and `GET /v1/sponsors/{year}/{slug}`

A non-numeric `{year}` segment is 404 and does not touch the database.

`photo_path` and `logo_path` are web paths. Return the path. This process
does not serve image bytes.

The listener binds on `::` with `mist.with_ipv6` before any pool warmup or
register call. A down database must not stop the VM. See `DECISIONS.md`.

## Register on boot (once)

`POST {CAROLINA_URL}/internal/api-endpoints/register`

```
Authorization: Bearer {POLYGLOT_REGISTER_TOKEN}
Content-Type: application/json
```

Body fields from `register` in `src/carolina_codes_gleam.gleam`: `language`,
`language_version`, `api_version`, `framework`, `created_year`,
`schema_version` (1), `base_url` (`PUBLIC_BASE_URL`, or
`http://127.0.0.1:{PORT}` when that is unset), `endpoints` (objects with
`method`, `path`, and `query`).

Do not heartbeat. The register call is one unlinked process after the
listener is up. If `CAROLINA_URL` or the token is empty, or the URL is
invalid, or the POST fails, log (or return) and keep serving.

## Layout

| Path | Role |
| --- | --- |
| `mise.toml` | Pins Gleam 1.18.1, Erlang/OTP 29, rebar 3.25.1, dev Elixir, gitleaks |
| `gleam.toml` | Package constraints, go_over, cactus pre-commit actions |
| `manifest.toml` | Locked versions (mist 6.0.3, pog 4.1.0, go_over 3.3.1, cactus 1.4.0) |
| `src/carolina_codes_gleam.gleam` | Routes, mist listener, pog pool, register-once |
| `src/carolina_codes_gleam/catalog.gleam` | SQL against `v1_*` views |
| `Dockerfile` | Build on Gleam 1.18.1, run on `erlang:29.1.0.0-alpine` (no compiler in the final image) |
| `scripts/strip-otel-elixir.sh` | Drop Elixir bits from the erlang-shipment |
| `scripts/erl_libs.sh` | Dev-only `ERL_LIBS` so `opentelemetry_api` can start |
| `fly.toml` | Fly service. Health check is `GET /health` |
| `Makefile` | `test`, `sast`, `audit`, `secrets`, `format` |
| `.gitea/workflows/precommit.yml` | CI. The test job uses Postgres 16, not Postgres 18 |
| `test/fixture.sql` | v1-shaped tables for catalog tests |
| `DECISIONS.md` | Append-only rulings |
| `MEMORY.md` | Non-binding agent notes |

## Tests

Handler tests call `handle` with a fake catalog function and do not need
Postgres. Catalog tests apply `test/fixture.sql` on a throwaway database and
need a reachable Postgres 16 (local, or the CI service `postgres:16`). Live
SQL against the real views uses the CMS database named by `DATABASE_URL`.

## Quality gates

Same commands locally, as pre-commit hooks, and as CI jobs:

```
make test      # gleam test (gleeunit)
make sast      # PEST static scan of this app's source
make audit     # go_over Hex/Gleam dependency advisories
make secrets   # gitleaks detect --source .
make format    # gleam format --check
```

## Checklist

- CMS OpenAPI paths return 200 with example-shaped JSON (404 on an unknown slug)
- `?year=` speaker rows include `languages` and `topics`; sponsor rows include `tier`
- Register once at process start; keep serving if the Elixir site is down
- No writes; query `v1_*` views, never Ash tables
- `GET /health` does not touch the database, including during boot
- Read `DECISIONS.md` before changing a recorded choice; append a new entry to change one
