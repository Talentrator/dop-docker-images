# syntax=docker/dockerfile:1.7
#
# Arduino Nano Matter image: sketches for the Arduino Nano Matter (ABX00112, Silicon Labs
# MGM240SD22VNA = EFR32MG24B210, Cortex-M33), built headless with arduino-cli. The agent box and
# the grader box of a task for the Nano Matter.
#   Core    : SiliconLabs:silabs 5.0.0 (Silicon Labs' Arduino core), the nano_matter variant only,
#             with every protocol stack it offers (None, Matter, Zigbee, BLE Arduino/Silabs) and
#             the Gecko bootloader image for the board
#   GCC     : gcc-arm-none-eabi 12.2.rel1, as the core pulls it in
#   Tools   : arduino-cli 1.6.0, and nano-matter-build, which compiles a sketch and writes one
#             .hex holding the bootloader and the sketch
#   Arches  : linux/arm64 and linux/amd64
#
# arduino-cli is checked against its release sha256; the core and its tools come through
# arduino-cli, which checks every archive against the sha256 in Silicon Labs' package index.
# Nothing is fetched at runtime: DOP boxes run with internet off.
#
# Not in it: the flashers (OpenOCD, Simplicity Commander) and the other boards' variants. The
# board is flashed by the bench that holds it.
#
# Build (native): docker build -t arduino-nano-matter .

# Declared once, before any stage: the publish workflow reads the version tag from this line
ARG NANO_MATTER_CORE_VERSION=5.0.0

FROM ubuntu:24.04 AS fetch

ARG TARGETARCH
ARG NANO_MATTER_CORE_VERSION
ARG ARDUINO_CLI_VERSION=1.6.0

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    ARDUINO_DIRECTORIES_DATA=/opt/arduino/data \
    ARDUINO_DIRECTORIES_DOWNLOADS=/tmp/arduino-dl \
    ARDUINO_DIRECTORIES_USER=/opt/arduino/user \
    ARDUINO_BOARD_MANAGER_ADDITIONAL_URLS=https://siliconlabs.github.io/arduino/package_arduinosilabs_index.json

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
    $A core install SiliconLabs:silabs@${NANO_MATTER_CORE_VERSION}; \
    P=/opt/arduino/data/packages/SiliconLabs; \
    C=$P/hardware/silabs/${NANO_MATTER_CORE_VERSION}; \
    # upload-only tools: the board is flashed on the bench, not from here
    rm -rf $P/tools/openocd $P/tools/simplicitycommander; \
    # the other boards' prebuilt SDKs and bootloaders (each 50-430 MB)
    find $C/variants -mindepth 1 -maxdepth 1 ! -name nano_matter -exec rm -rf {} +; \
    find $C/bootloaders -type f ! -name 'arduino-nano-matter-*' -delete; \
    rm -rf $P/tools/gcc-arm-none-eabi/*/share/doc; \
    rm -rf /tmp/arduino-dl; \
    # any user builds: arduino-cli writes nothing under its data folder when compiling
    chmod -R a+rX /opt/arduino; \
    $A core list

# ---------------------------------------------------------------------------
FROM ubuntu:24.04

ARG NANO_MATTER_CORE_VERSION

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    NANO_MATTER_CORE_VERSION=${NANO_MATTER_CORE_VERSION} \
    NANO_MATTER_FQBN=SiliconLabs:silabs:nano_matter \
    ARDUINO_DIRECTORIES_DATA=/opt/arduino/data \
    ARDUINO_DIRECTORIES_USER=/opt/arduino/user \
    ARDUINO_DIRECTORIES_DOWNLOADS=/tmp/arduino-dl \
    ARDUINO_BOARD_MANAGER_ADDITIONAL_URLS=https://siliconlabs.github.io/arduino/package_arduinosilabs_index.json \
    ARDUINO_UPDATER_ENABLE_NOTIFICATION=false \
    ARDUINO_CORE=/opt/arduino/data/packages/SiliconLabs/hardware/silabs/${NANO_MATTER_CORE_VERSION} \
    PATH=/opt/arduino/bin:$PATH

# python3 for whatever wants it, python3-venv for a venv of your own (graders make one),
# make and git for whoever wants them
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates git make python3 python3-venv less vim-tiny file xxd \
    && rm -rf /var/lib/apt/lists/*

COPY --from=fetch /opt/arduino /opt/arduino

COPY --chmod=755 scripts/nano-matter-build /usr/local/bin/nano-matter-build
COPY --chmod=755 scripts/smoke-test.sh /usr/local/bin/nano-matter-smoke-test

LABEL org.opencontainers.image.title="arduino-nano-matter" \
      org.opencontainers.image.description="arduino-cli 1.6.0 + SiliconLabs:silabs ${NANO_MATTER_CORE_VERSION} (nano_matter) for the Arduino Nano Matter (MGM240S, EFR32MG24)"

WORKDIR /workdir
CMD ["/bin/bash"]
