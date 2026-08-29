FROM ghcr.io/gleam-lang/gleam:nightly-erlang AS build
WORKDIR /app
COPY gleam.toml manifest.toml ./
COPY src src
RUN gleam export erlang-shipment

FROM ghcr.io/gleam-lang/gleam:nightly-erlang
RUN apt-get update && apt-get install -y --no-install-recommends postgresql-client curl \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/build/erlang-shipment ./
ENV PORT=8080
EXPOSE 8080
CMD ["./entrypoint.sh", "run"]
