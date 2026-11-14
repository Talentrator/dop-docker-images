# syntax=docker/dockerfile:1.7
#
# Arduino UNO Q image: sketches for the board's STM32U585 microcontroller,
# built headless with arduino-cli. The agent box and the grader box of a task
# for the Arduino UNO Q (ABX00162/ABX00173, STM32U585 + Qualcomm QRB2210).
#   Core    : arduino:zephyr 0.55.0 ("Arduino UNO Q Board"), with its Zephyr
#             loader image and the arm-zephyr-eabi 0.16.8 GCC it pulls in
#   Libs    : the core's own (Arduino_LED_Matrix, Arduino_RouterBridge, ...)
#             and ArduinoGraphics 1.1.5 (text and shapes on the LED matrix)
#   Tools   : arduino-cli 1.6.0, and unoq-build, which compiles a sketch and
#             writes one .hex holding the Zephyr loader and the sketch
#   Arches  : linux/arm64 and linux/amd64
#
# arduino-cli is checked against its release sha256; the core, its tools and
# the library come through arduino-cli, which checks every archive against the
# sha256 in Arduino's package and library indexes. Nothing is fetched at
# runtime: DOP boxes run with internet off.
#
# Not in it: the board's flasher. The MCU is flashed by OpenOCD on the board's
# own Linux side; the bench that holds the board does that.
#
# Build (native): docker build -t arduino-unoq .

# Declared once, before any stage: the publish workflow reads the version tag from this line
ARG UNOQ_CORE_VERSION=0.55.0

FROM ubuntu:24.04 AS fetch

ARG TARGETARCH
ARG UNOQ_CORE_VERSION
ARG ARDUINO_CLI_VERSION=1.6.0
ARG ARDUINOGRAPHICS_VERSION=1.1.5

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    ARDUINO_DIRECTORIES_DATA=/opt/arduino/data \
    ARDUINO_DIRECTORIES_DOWNLOADS=/tmp/arduino-dl \
    ARDUINO_DIRECTORIES_USER=/opt/arduino/user

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# get URL SHA256 FILE: download and check one file
RUN printf '#!/bin/sh\nset -eu\ncurl -fsSL --retry 5 -o "$3" "$1"\necho "$2  $3" | sha256sum -c -\n' > /usr/local/bin/get \
    && chmod +x /usr/local/bin/get

RUN set -eux; \
    U=https://github.com/arduino/arduino-cli/releases/download/v${ARDUINO_CLI_VERSION}; \
    case "$TARGETARCH" in \
      amd64) get $U/arduino-cli_${ARDUINO_CLI_VERSION}_Linux_64bit.tar.gz 321ee249f44c78053234fec0f36101092bc6021bf24939e15e0cc2449c5ed250 cli.tgz ;; \
      arm64) get $U/arduino-cli_${ARDUINO_CLI_VERSION}_Linux_ARM64.tar.gz 2ed4e1436bb3be1265966af8eba95dd25e28f3a9f92d0a58d371ed14dbaf550f cli.tgz ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    mkdir -p /opt/arduino/bin; \
    tar -xzf cli.tgz -C /opt/arduino/bin arduino-cli; \
    rm cli.tgz

RUN set -eux; \
    A=/opt/arduino/bin/arduino-cli; \
    $A core update-index; \
    $A core install arduino:zephyr@${UNOQ_CORE_VERSION}; \
    $A lib install ArduinoGraphics@${ARDUINOGRAPHICS_VERSION}; \
    # upload-only tools: the board is flashed on the bench, not from here
    cd /opt/arduino/data/packages/arduino/tools; \
    rm -rf adb bossac dfu-util remoteocd; \
    rm -rf /tmp/arduino-dl; \
    # any user builds: arduino-cli writes nothing under its data folder when compiling
    chmod -R a+rX /opt/arduino; \
    $A core list; $A lib list

# ---------------------------------------------------------------------------
FROM ubuntu:24.04

ARG UNOQ_CORE_VERSION

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    UNOQ_CORE_VERSION=${UNOQ_CORE_VERSION} \
    UNOQ_FQBN=arduino:zephyr:unoq \
    ARDUINO_DIRECTORIES_DATA=/opt/arduino/data \
    ARDUINO_DIRECTORIES_USER=/opt/arduino/user \
    ARDUINO_DIRECTORIES_DOWNLOADS=/tmp/arduino-dl \
    ARDUINO_UPDATER_ENABLE_NOTIFICATION=false \
    ARDUINO_CORE=/opt/arduino/data/packages/arduino/hardware/zephyr/${UNOQ_CORE_VERSION} \
    PATH=/opt/arduino/bin:$PATH

# python3 for unoq-build's .hex merge, python3-venv for a venv of your own
# (graders make one), make and git for whoever wants them
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates git make python3 python3-venv less vim-tiny file xxd \
    && rm -rf /var/lib/apt/lists/*

COPY --from=fetch /opt/arduino /opt/arduino

COPY --chmod=755 scripts/unoq-build /usr/local/bin/unoq-build
COPY --chmod=755 scripts/smoke-test.sh /usr/local/bin/unoq-smoke-test

LABEL org.opencontainers.image.title="arduino-unoq" \
      org.opencontainers.image.description="arduino-cli 1.6.0 + arduino:zephyr ${UNOQ_CORE_VERSION} + ArduinoGraphics 1.1.5 for the Arduino UNO Q (STM32U585)"

WORKDIR /workdir
CMD ["/bin/bash"]
