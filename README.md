# carolina-codes-gleam

Read-only v1 polyglot API for Carolina Code Conference. Queries `v1_*` SQL views
using Gleam, [mist](https://hexdocs.pm/mist/), and [pog](https://hexdocs.pm/pog/).

```
DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/carolina_dev \
CAROLINA_URL=http://127.0.0.1:4000 \
POLYGLOT_REGISTER_TOKEN=dev \
PUBLIC_BASE_URL=http://127.0.0.1:4008 \
PORT=4008 \
gleam run
```

Requires Gleam and `rebar3` on `PATH` (Erlang deps such as `pgo`). With mise:

```
mise exec gleam@1.18.1 rebar@3.25.1 -- gleam run
```

Quality gates (same commands locally, as pre-commit hooks, and as Gitea jobs). Gitea clones, installs the mise toolchain, and fetches Hex/Gleam packages once in a prepare job, then runs these five checks in parallel against that environment:

```
make test      # gleam test (gleeunit; shipped handlers)
make sast      # PEST static security scan of this app's source
make audit     # go_over Hex/Gleam dependency advisories
make secrets   # gitleaks detect --source .
make format    # gleam format --check
make hooks     # install Cactus + python pre-commit hooks
```

Pre-commit runs those five as distinct checks. Install once with `make hooks` (needs `pre-commit` on PATH). Emergency skip: `SKIP=local-tests,sast,audit,gitleaks,format git commit`. Cactus is the Gleam-native installer (`gleam run --target erlang -m cactus`); `pre-commit run --all-files` runs the same Makefile entries.
