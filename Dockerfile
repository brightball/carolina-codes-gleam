# Gleam 1.18.1 supports OTP 28 and 29. Compile and run on the same pinned
# OTP 29 image. The compiler stays in the build stage.
FROM erlang:29.1.0.0-alpine AS build
COPY --from=ghcr.io/gleam-lang/gleam:v1.18.1-erlang-alpine /bin/gleam /bin/gleam
WORKDIR /app
COPY gleam.toml manifest.toml ./
COPY src src
COPY scripts/strip-otel-elixir.sh scripts/strip-otel-elixir.sh
RUN gleam export erlang-shipment \
  && sh scripts/strip-otel-elixir.sh build/erlang-shipment

FROM erlang:29.1.0.0-alpine
WORKDIR /app
COPY --from=build /app/build/erlang-shipment /app
ENV PORT=8080
ENV ERL_AFLAGS="+S 1:1"
EXPOSE 8080
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
