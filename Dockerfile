FROM debian:trixie-slim AS build
ARG DYNAMIPS_VERSION=0.2.25

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive DEBCONF_NOWARNINGS=yes \
        apt-get install -y --no-install-recommends \
        build-essential ca-certificates cmake git libelf-dev libpcap-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "v${DYNAMIPS_VERSION}" \
        https://github.com/GNS3/dynamips.git /src \
    && cmake -S /src -B /build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DDYNAMIPS_CODE=stable \
        -DBUILD_NVRAM_EXPORT=ON \
    && cmake --build /build --parallel "$(nproc)" \
    && cmake --install /build \
    && strip --strip-unneeded /usr/local/bin/dynamips /usr/local/bin/nvram_export

FROM debian:trixie-slim
ENV PATH="/usr/local/bin:${PATH}"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive DEBCONF_NOWARNINGS=yes \
        apt-get install -y --no-install-recommends \
        libelf1t64 libpcap0.8t64 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/bin/dynamips /usr/local/bin/dynamips
COPY --from=build /usr/local/bin/nvram_export /usr/local/bin/nvram_export

EXPOSE 7200
STOPSIGNAL SIGINT

CMD ["dynamips", "-H", "0.0.0.0:7200"]
