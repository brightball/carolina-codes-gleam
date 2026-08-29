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
