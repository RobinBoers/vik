# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
# Builder and runner must use the same Ubuntu release, otherwise the release
# links against libraries (OpenSSL, glibc) the runner doesn't have.
#
#   - https://hub.docker.com/r/hexpm/elixir/tags?name=ubuntu-noble
#   - https://hub.docker.com/_/ubuntu/tags?name=noble
#
# Chrome and chromedriver are pulled from Chrome for Testing, which publishes both at
# matching versions. Wallaby refuses (or at lease complains loudly) to run when they differ.
#
#   - https://googlechromelabs.github.io/chrome-for-testing/

ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=28.0.1
ARG UBUNTU_VERSION=noble-20260509.1
ARG CHROME_VERSION=156.0.8078.47

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-ubuntu-${UBUNTU_VERSION}"
ARG RUNNER_IMAGE="ubuntu:${UBUNTU_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git npm \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force \
  && mix local.rebar --force

ENV MIX_ENV="prod"

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY assets/package.json assets/package-lock.json assets/
RUN npm ci --prefix assets

COPY priv priv
COPY assets assets
COPY lib lib

RUN mix assets.deploy
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code.
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

FROM ${RUNNER_IMAGE} AS chrome

ARG CHROME_VERSION

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl unzip \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

RUN for pkg in chrome chromedriver; do \
    curl -fsSLo "$pkg.zip" "https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/$pkg-linux64.zip" \
    && unzip -q "$pkg.zip" \
    && mv "$pkg-linux64" "$pkg" \
    && rm "$pkg.zip"; \
  done

FROM ${RUNNER_IMAGE}

RUN --mount=type=bind,from=chrome,source=/opt/chrome/deb.deps,target=/tmp/deb.deps \
  apt-get update \
  && apt-get install -y --no-install-recommends \
    libstdc++6 openssl libncurses6 ca-certificates tzdata \
  && apt-get satisfy -y --no-install-recommends "$(paste -sd, /tmp/deb.deps)" \
  && rm -rf /var/lib/apt/lists/*

COPY --from=chrome /opt/chrome /opt/chrome
COPY --from=chrome /opt/chromedriver /opt/chromedriver
RUN ln -s /opt/chrome/chrome /usr/local/bin/google-chrome \
  && ln -s /opt/chromedriver/chromedriver /usr/local/bin/chromedriver

ENV LANG="en_US.UTF-8"
ENV LANGUAGE="en_US:en"
ENV LC_ALL="en_US.UTF-8"

WORKDIR /app
RUN chown nobody /app

ENV MIX_ENV="prod"

# Only copy the final release from the build stage.
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/vik ./

USER nobody

CMD ["/app/bin/server"]
