# syntax=docker/dockerfile:1.7
#
# ESP-IDF image for the M5Stack AtomS3R on an Atomic Echo Base: the agent box and the
# grader box of a task for that board.
#   Board   : AtomS3R (C126): ESP32-S3-PICO-1-N8R8, 8 MB flash, 8 MB octal PSRAM,
#             0.85" 128x128 GC9107 LCD (LP5562 backlight), BMI270 IMU, IR LED, button
#   Base    : Atomic Echo Base (A149): ES8311 codec, MEMS mic, NS4150B amp, 1 W speaker
#   SDK     : ESP-IDF v5.5.6 and its esp32s3 toolchain, from the esp-idf-esp32s3 image
#             (this repo, pinned by digest)
#   Added   : esp_codec_dev 1.6.2 (Espressif's codec drivers, ES8311 among them) as an IDF
#             component, from the ESP component registry, pinned by sha256: the boxes have no
#             internet, so the component manager can't fetch it
#   Helper  : atoms3r-build, esp32s3-build with the board's sdkconfig defaults
#             (8 MB flash, console on USB Serial/JTAG) under the project's own
#   Arches  : linux/arm64 and linux/amd64 (the base image is multi-arch)
#
# Build (native): docker build -t esp-idf-atoms3r .

# Declared once, before any stage: the publish workflow reads the version tag from this line
ARG IDF_VERSION=5.5.6
ARG BASE=ghcr.io/talentrator/dop-docker-images/esp-idf-esp32s3@sha256:6b96698f5723296e66d9e15900544d848cab1cab7b4ec6abed78ca3db4f40baa

FROM ${BASE} AS fetch
ARG CODEC_DEV_VERSION=1.6.2
ARG CODEC_DEV_SHA256=50b5d2b7687fd7f6e93fda110aecf00cfe12e2bd34d77b90a01efb6dd904d88d
RUN apt-get update && apt-get install -y --no-install-recommends curl unzip && rm -rf /var/lib/apt/lists/*
RUN set -eux; \
    curl -fsSL -o /tmp/codec.zip \
      https://components-file.espressif.com/components/espressif/esp_codec_dev/${CODEC_DEV_VERSION}/espressif__esp_codec_dev-v${CODEC_DEV_VERSION}.zip; \
    echo "${CODEC_DEV_SHA256}  /tmp/codec.zip" | sha256sum -c -; \
    mkdir -p /out/esp_codec_dev; \
    unzip -q /tmp/codec.zip -d /out/esp_codec_dev; \
    # an IDF component now, not a managed one: its manifest would send the component manager online
    rm -rf /out/esp_codec_dev/test_apps /out/esp_codec_dev/idf_component.yml; \
    chmod -R a+rX /out

# ---------------------------------------------------------------------------
FROM ${BASE}

ARG IDF_VERSION

# in IDF's own components, so `REQUIRES esp_codec_dev` works in any project, with idf.py too
COPY --from=fetch /out/esp_codec_dev /opt/esp/idf/components/esp_codec_dev

COPY --chmod=755 scripts/atoms3r-build /usr/local/bin/atoms3r-build
COPY --chmod=755 scripts/smoke-test.sh /usr/local/bin/atoms3r-smoke-test
COPY scripts/sdkconfig.board /opt/esp/atoms3r/sdkconfig.board
COPY scripts/templates /opt/esp/atoms3r/templates

LABEL org.opencontainers.image.title="esp-idf-atoms3r" \
      org.opencontainers.image.description="ESP-IDF v${IDF_VERSION} for the M5Stack AtomS3R + Atomic Echo Base (ESP32-S3), with esp_codec_dev and atoms3r-build"

WORKDIR /workdir
CMD ["/bin/bash"]
