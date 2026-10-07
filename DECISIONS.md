# DECISIONS.md

Append-only decision log for this Gleam + mist + pog service.

Gleam has no standard decision-record package. This repo does not add one.
A single append-only file is the lightweight form of a Markdown Architectural
Decision Record, which is the right weight for a small Erlang-target service:

- Each entry has a date, a status, the decision, why, and the alternatives.
- Status is `accepted` or `superseded by <date> — <title>`.
- To change a ruling, append a new dated entry and point the old entry's
  status at it. Do not rewrite the old decision text and do not drop the entry.
- Toolchain pins live in `mise.toml`. Package constraints live in `gleam.toml`.
  The lock lives in `manifest.toml`. This file records why. Do not hand-edit
  `manifest.toml`.
- A comment in `src/` may explain a local constant. A choice another agent
  might undo belongs here: HTTP stack, listen address, pool size, health
  versus Postgres, the shipment Elixir strip, the CI Postgres major version.
- `MEMORY.md` is non-binding scratch for how to run the tree. If it
  disagrees with this file or the code, this file and the code win.
- No secrets, production database URLs, or private hostnames.

Read the accepted entries before changing those areas. `AGENTS.md` points here.

## 2026-08-28 — HTTP server is mist

- Status: accepted
- Decision: Serve HTTP with mist 6.0.3 on the Erlang target. The process reports framework `mist`.
- Why: The service is one router plus boot. mist is the Gleam HTTP server, and `framework` in the register body and in `GET /` is the string `mist` (`src/carolina_codes_gleam.gleam`). The constraint has been `>= 6.0.3 and < 7.0.0` since the initial import (3c6fd6c).
- Alternatives: Wisp, the usual Gleam web toolkit, itself runs on mist and would put a second name in the CMS register payload. A Cowboy or Elli binding would step outside `gleam_http` request types. Neither package is in `gleam.toml`.

## 2026-09-01 — Listen on IPv6 for Fly 6PN

- Status: accepted
- Decision: Bind `::` (`listen_interface`) and enable `mist.with_ipv6`. A Postgres URL whose host contains `flycast`, `.internal`, or `.fly.io` uses `pog.Ipv6`.
- Why: Fly's private network is IPv6. The machine must accept connections on that network, and the pool must dial Fly Postgres the same way. Landed in 55ff1e2.
- Alternatives: Bind `0.0.0.0` only. That accepts public IPv4 and misses the private network. Forcing IPv6 for every URL, including `127.0.0.1`, would break local and CI Postgres.

## 2026-09-22 — Bind the listener before any Postgres work

- Status: accepted
- Decision: `main` calls `mist.start` before pool warmup and before `register`. `GET /health` and `GET /` never call the database. The health body is `{"ok": true}`.
- Why: The platform health check is `GET /health`. Opening the pool first waits on DNS and handshakes, and a down database would stop the VM. The handler already skipped SQL for health in the initial import; 0529565 moved the bind ahead of `ensure_pool`.
- Alternatives: Connect in `main` and only then listen. Liveness would depend on Postgres. Also left unchanged: the starter document's `{"status":"ok"}` body. This service emits `{"ok": true}`.

## 2026-09-22 — pog pool size is 2

- Status: accepted
- Decision: `db_pool_size` is 2. `pog.start` is unlinked from the caller so a warmup process or a request process exiting does not shut the pool down. Failed starts are not cached.
- Why: Fly runs one shared CPU (`fly.toml`, `cpu_kind = "shared"`, `cpus = 1`). Two sessions cover this read-only API. Extra cold-start handshakes compete with the listener. The constant and the unlink landed with the runtime pin in 0529565. `db_pool_size_fits_one_shared_cpu_test` rejects sizes 8 and 10.
- Alternatives: pog's `default_config` pool size of 10, or a pool of 8. Both are more sessions than this VM needs during boot.

## 2026-09-22 — Strip Elixir out of the erlang-shipment

- Status: accepted
- Decision: Dev and CI put Elixir on `ERL_LIBS` so `gleam test` and `gleam run` can boot `opentelemetry_api`. The exported shipment does not. `scripts/strip-otel-elixir.sh` removes the `elixir` application requirement and `Elixir.*` beams from `opentelemetry_api`, and deletes copied `elixir`, `eex`, `mix`, and `logger` directories. `Dockerfile` runs that script before the runtime stage.
- Why: `pog` 4.1.0 depends on `pgo`, and `pgo` depends on `opentelemetry_api`. The Hex build is a Mix project: its `.app` file requires `elixir` even though the Erlang modules `pgo` calls do not. The runtime image is `erlang:29.1.0.0-alpine` with no Elixir and no Gleam compiler (0529565). mise pins Elixir 1.20.4 for the dev path only (`scripts/erl_libs.sh`).
- Alternatives: Install Elixir in the runtime image so the unmodified `.app` file starts. That ships a compiler toolchain the VM does not call. Dropping `pgo` would mean leaving pog, which is the SQL client above.

## 2026-09-22 — CI Postgres is 16

- Status: accepted
- Decision: The test job in `.gitea/workflows/precommit.yml` runs `postgres:16-alpine`. Catalog tests reach it on the job network at the service hostname `postgres`. They load `test/fixture.sql` into a throwaway database and do not use the CMS schema.
- Why: This service's CI standardizes on Postgres 16 (0529565). Publishing host port 5432 on the runner collides with a Postgres that is already bound there, so the job uses the service network (11c9ce9).
- Alternatives: Postgres 18, as in the language-starter compose file. This service's workflow and fixture tests are on 16. Matching the starter would be a separate change, recorded here first.
