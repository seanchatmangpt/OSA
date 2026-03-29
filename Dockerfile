FROM elixir:1.17-alpine AS builder

RUN apk add --no-cache build-base git

# Set HOME to /home/osa so Path.expand("~/.osa/osa.db") bakes in
# /home/osa/.osa/osa.db at compile time (not /root/.osa/osa.db).
ENV HOME=/home/osa
RUN mkdir -p /home/osa

WORKDIR /app

COPY mix.exs mix.lock ./
COPY VERSION ./
RUN mix local.hex --force && mix local.rebar --force
RUN mix deps.get --only prod
RUN MIX_ENV=prod mix deps.compile

COPY config config
COPY lib lib
COPY priv priv
COPY rel rel

RUN MIX_ENV=prod mix compile
RUN MIX_ENV=prod mix release osagent

FROM alpine:3.22 AS runner

RUN apk add --no-cache libstdc++ openssl ncurses-libs wget
RUN addgroup -S osa && adduser -S -h /home/osa -G osa osa && \
    mkdir -p /home/osa/.osa && \
    chown -R osa:osa /home/osa
ENV HOME=/home/osa

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/osagent ./
RUN chown -R osa:osa /app
USER osa

ENV MIX_ENV=prod

EXPOSE 8089
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=5 \
  CMD wget -q -O /dev/null http://localhost:8089/health || exit 1

CMD ["bin/osagent", "serve"]
