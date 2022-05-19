FROM hexpm/elixir:1.13.4-erlang-25.0-alpine-3.15.4 AS builder
ADD ./ src/
RUN mix local.hex --force && mix local.rebar --force && cd src/ && mix deps.get && MIX_ENV=prod mix release


FROM alpine:3.15.4
RUN apk update && apk upgrade && apk add wget curl openssl ncurses libstdc++
COPY --from=builder src/_build/prod/rel/load /load

ENTRYPOINT ["/load/bin/load", "start"]

