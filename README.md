# carolina-codes-gleam

Read-only v1 polyglot API for Carolina Code Conference. Queries `v1_*` SQL
views using Gleam on the Erlang VM, [mist](https://hexdocs.pm/mist/), and
[pog](https://hexdocs.pm/pog/).

Register once on boot and keep serving if `CAROLINA_URL` is empty or the
POST fails. There is no heartbeat. Query `v1_*` views only; leave Ash tables
unread. Binding choices are in `DECISIONS.md`. `MEMORY.md` is non-binding
working memory. Agent rules are in `AGENTS.md`.

## Versions

These are the versions pinned in this tree. A newer upstream release is not
the version this service builds.

| Piece | Version | Owner |
| --- | --- | --- |
| Gleam | 1.18.1 | `mise.toml`, `Dockerfile` (`ghcr.io/gleam-lang/gleam:v1.18.1-erlang-alpine`), `language_version` in `src/carolina_codes_gleam.gleam` |
| Erlang/OTP | 29 (image `erlang:29.1.0.0-alpine`) | `mise.toml`, `Dockerfile` |
| rebar3 | 3.25.1 | `mise.toml` (builds Hex Erlang deps such as `pgo`) |
| mist | 6.0.3 | `gleam.toml`, `manifest.toml` |
| pog | 4.1.0 | `gleam.toml`, `manifest.toml` |
| go_over | 3.3.1 | dev dependency; `make audit` |
| cactus | 1.4.0 | dev dependency; Gleam pre-commit installer |
| gitleaks | 8.30.1 | `mise.toml`; `make secrets` |
| Elixir | 1.20.4 | dev and CI only, on `ERL_LIBS` (below) |

Locked runtime packages are mist 6.0.3 and pog 4.1.0. Dev packages of note
are go_over 3.3.1 and cactus 1.4.0. `GET /health` returns `{"ok": true}` and
does not open Postgres.

### Elixir on the dev VM, stripped from the shipment

`pog` depends on `pgo`, and `pgo` depends on `opentelemetry_api`. The Hex
build of that OTP application requires the `elixir` application and embeds
`Elixir.*` modules. `gleam test` and `gleam run` need those beams, so mise
puts Elixir 1.20.4 on `ERL_LIBS` via `scripts/erl_libs.sh`.

The runtime image is Erlang only. After `gleam export erlang-shipment`,
`scripts/strip-otel-elixir.sh` drops the Elixir dependency and the `Elixir.*`
beams from `opentelemetry_api`, and removes any copied `elixir`, `eex`,
`mix`, and `logger` apps. The final image does not contain the Gleam
compiler.

## Run

```
DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/carolina_dev \
CAROLINA_URL=http://127.0.0.1:4000 \
POLYGLOT_REGISTER_TOKEN=dev \
PUBLIC_BASE_URL=http://127.0.0.1:4008 \
PORT=4008 \
gleam run
```

Requires Gleam 1.18.1, Erlang/OTP 29, and rebar 3.25.1 on `PATH`. With mise:

```
mise exec gleam@1.18.1 rebar@3.25.1 -- gleam run
```

## Quality gates

Same commands locally, as pre-commit hooks, and as CI jobs. CI installs the
mise toolchain and fetches Hex/Gleam packages once in a prepare job, then
runs these five checks in parallel. The test job uses Postgres 16.

```
make test      # gleam test (gleeunit; shipped handlers)
make sast      # PEST static security scan of this app's source
make audit     # go_over Hex/Gleam dependency advisories
make secrets   # gitleaks detect --source .
make format    # gleam format --check
make hooks     # install Cactus + python pre-commit hooks
```

Pre-commit runs those five as distinct checks. Install once with `make hooks`
(needs `pre-commit` on PATH). Emergency skip:
`SKIP=local-tests,sast,audit,gitleaks,format git commit`. Cactus is the
Gleam-native installer (`gleam run --target erlang -m cactus`);
`pre-commit run --all-files` runs the same Makefile entries.
