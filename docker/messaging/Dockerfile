ARG SERVER_BUILDER_IMAGE_VERSION=1.18.3-erlang-27.3.4-debian-bookworm-20250428-slim
ARG SERVER_RUNTIME_IMAGE_VERSION=bookworm-slim

FROM hexpm/elixir:${SERVER_BUILDER_IMAGE_VERSION} AS builder

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV="prod"

COPY mix.exs mix.lock ./
COPY config/config.exs config/prod.exs config/runtime.exs config/
COPY lib lib
COPY priv priv
COPY rel rel

RUN --mount=type=cache,target=/app/deps \
    --mount=type=cache,target=/app/_build/prod \
    mix do deps.get --only prod, release && \
    cp -r /app/_build/prod/rel/messaging ./release

FROM debian:${SERVER_RUNTIME_IMAGE_VERSION}

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN apt-get update -y && \
    apt-get install --no-install-recommends -y \
    libstdc++6 openssl libncurses5 locales postgresql-client && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN adduser --uid 1000 --disabled-password --gecos "" nonroot

WORKDIR "/app"
RUN chown -R nonroot:nonroot /app

ENV MIX_ENV="prod"

COPY --from=builder --chown=nonroot:nonroot /app/release ./

USER nonroot

ENTRYPOINT ["/app/bin/entrypoint"]
CMD ["start"]
