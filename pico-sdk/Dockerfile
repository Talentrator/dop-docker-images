# syntax=docker/dockerfile:1.7
#
# Raspberry Pi Pico SDK image: the agent box and the grader box of a task for
# the Raspberry Pi Pico 2 (RP2350A: two Cortex-M33 cores at 150 MHz, 520 kB
# SRAM, 4 MB flash, user LED on GPIO 25). The RP2040 boards (pico, pico_w)
# and the Pico 2 W build too.
#   SDK     : pico-sdk 2.3.1 with its submodules (TinyUSB, cyw43-driver,
#             lwIP, btstack, mbedtls), and pico-examples sdk-2.3.1
#   Tools   : Arm GNU Toolchain 14.3.Rel1 (Armv6-M and Armv8-M Mainline
#             libraries only), picotool 2.3.1 (built here, the SDK uses it to
#             make UF2s), CMake, Ninja, and pico-build, which builds a project
#             folder for a board
#   Arches  : linux/arm64 and linux/amd64
#
# The SDK, picotool and the examples are git tags, checked against the tags'
# commits; the compiler comes from developer.arm.com, checked by sha256.
# Nothing is fetched at build time of a project: DOP boxes run with internet
# off, and the SDK finds picotool through picotool_DIR instead of fetching it.
#
# Not in it: the RISC-V toolchain (projects build for the RP2350's Arm cores),
# OpenOCD and GDB. The bench that holds the board flashes it with its own
# picotool over USB.
#
# Build (native): docker build -t pico-sdk .

# Declared once, before any stage: the publish workflow reads the version tag from this line
ARG PICO_SDK_VERSION=2.3.1

FROM ubuntu:24.04 AS fetch

ARG TARGETARCH
ARG PICO_SDK_VERSION
ARG PICO_SDK_COMMIT=079c6f39023649b154152db30f1d781e884879bc
ARG PICOTOOL_COMMIT=2041936441b48a3cc53ae3da9e805229fe8f4e18
ARG PICO_EXAMPLES_COMMIT=0d62f75bafc2c8120d3276c3343d1a9195e909e9
ARG ARM_GCC_VERSION=14.3.rel1

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl xz-utils git cmake ninja-build g++ pkg-config libusb-1.0-0-dev python3 \
    && rm -rf /var/lib/apt/lists/*

# get URL SHA256 FILE: download and check one file
RUN printf '#!/bin/sh\nset -eu\ncurl -fsSL --retry 5 -o "$3" "$1"\necho "$2  $3" | sha256sum -c -\n' > /usr/local/bin/get \
    && chmod +x /usr/local/bin/get

# Arm GNU Toolchain, per host architecture
RUN set -eux; \
    U=https://developer.arm.com/-/media/Files/downloads/gnu/${ARM_GCC_VERSION}/binrel; \
    case "$TARGETARCH" in \
      amd64) get $U/arm-gnu-toolchain-${ARM_GCC_VERSION}-x86_64-arm-none-eabi.tar.xz 8f6903f8ceb084d9227b9ef991490413014d991874a1e34074443c2a72b14dbd gcc.tar.xz ;; \
      arm64) get $U/arm-gnu-toolchain-${ARM_GCC_VERSION}-aarch64-arm-none-eabi.tar.xz 2d465847eb1d05f876270494f51034de9ace9abe87a4222d079f3360240184d3 gcc.tar.xz ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    mkdir -p /opt/pico/gcc; \
    tar -xJf gcc.tar.xz --strip-components=1 -C /opt/pico/gcc; \
    rm gcc.tar.xz; \
    cd /opt/pico/gcc; \
    # RP2040 is a Cortex-M0+ (Armv6-M), RP2350 a Cortex-M33 (Armv8-M Mainline): only their multilibs
    for d in arm-none-eabi/lib/thumb lib/gcc/arm-none-eabi/*/thumb; do \
      find "$d" -mindepth 1 -maxdepth 1 -type d ! -name 'v6-m*' ! -name 'v8-m.main*' -exec rm -rf {} +; \
    done; \
    rm -rf arm-none-eabi/lib/arm lib/gcc/arm-none-eabi/*/arm share/doc share/info share/man share/gdb \
           bin/arm-none-eabi-gdb* bin/arm-none-eabi-lto-dump libexec/gcc/arm-none-eabi/*/f951 \
           arm-none-eabi/include/c++/*/experimental lib/python* include/gdb

# pico-sdk at its release tag with its submodules, checked against the tag's commit, without git history
RUN set -eux; \
    git clone -q --depth 1 --branch ${PICO_SDK_VERSION} --recurse-submodules --shallow-submodules -j8 \
        https://github.com/raspberrypi/pico-sdk.git /opt/pico/pico-sdk; \
    cd /opt/pico/pico-sdk; \
    test "$(git rev-parse HEAD)" = "$PICO_SDK_COMMIT"; \
    git submodule status; \
    find . -name .git -prune -exec rm -rf {} +; \
    # TinyUSB: the RP2040/RP2350 port and its sources, not every other MCU's BSP, examples or docs
    cd lib/tinyusb; \
    find hw/bsp -mindepth 1 -maxdepth 1 -type d ! -name rp2040 -exec rm -rf {} +; \
    find hw/mcu -mindepth 1 -maxdepth 1 -type d ! -name raspberry_pi -exec rm -rf {} +; \
    rm -rf docs examples test; \
    cd ../..; \
    rm -rf lib/btstack/port lib/btstack/example lib/btstack/test lib/btstack/doc lib/lwip/doc lib/lwip/test \
           lib/mbedtls/tests lib/mbedtls/docs; \
    du -sh /opt/pico/pico-sdk

# picotool, built against this SDK and installed where the SDK's find_package finds it
RUN set -eux; \
    git clone -q --depth 1 --branch ${PICO_SDK_VERSION} https://github.com/raspberrypi/picotool.git /tmp/picotool; \
    cd /tmp/picotool; \
    test "$(git rev-parse HEAD)" = "$PICOTOOL_COMMIT"; \
    cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DPICO_SDK_PATH=/opt/pico/pico-sdk \
          -DPICOTOOL_FLAT_INSTALL=1 -DCMAKE_INSTALL_PREFIX=/opt/pico/picotool; \
    cmake --build build; \
    cmake --install build; \
    cd /; rm -rf /tmp/picotool; \
    find /opt/pico/picotool -name 'picotoolConfig.cmake'; \
    /opt/pico/picotool/picotool/picotool version; \
    # pioasm too, so PIO projects need no host compiler
    cmake -S /opt/pico/pico-sdk/tools/pioasm -B /tmp/pioasm -G Ninja -DCMAKE_BUILD_TYPE=Release \
          -DPIOASM_FLAT_INSTALL=1 -DPIOASM_VERSION_STRING=${PICO_SDK_VERSION} -DCMAKE_INSTALL_PREFIX=/opt/pico/pioasm; \
    cmake --build /tmp/pioasm; \
    cmake --install /tmp/pioasm; \
    cd /; rm -rf /tmp/pioasm; \
    find /opt/pico/pioasm -name 'pioasmConfig.cmake'

# pico-examples, the reference projects
RUN set -eux; \
    git clone -q --depth 1 --branch sdk-${PICO_SDK_VERSION} https://github.com/raspberrypi/pico-examples.git /opt/pico/pico-examples; \
    cd /opt/pico/pico-examples; \
    test "$(git rev-parse HEAD)" = "$PICO_EXAMPLES_COMMIT"; \
    rm -rf .git .github; \
    chmod -R a+rX /opt/pico

# ---------------------------------------------------------------------------
FROM ubuntu:24.04

ARG PICO_SDK_VERSION

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PICO_SDK_VERSION=${PICO_SDK_VERSION} \
    PICO_SDK_PATH=/opt/pico/pico-sdk \
    PICO_EXAMPLES_PATH=/opt/pico/pico-examples \
    PICO_TOOLCHAIN_PATH=/opt/pico/gcc \
    PICO_BOARD=pico2 \
    PICO_PLATFORM=rp2350-arm-s \
    picotool_DIR=/opt/pico/picotool/picotool \
    pioasm_DIR=/opt/pico/pioasm/pioasm \
    PATH=/opt/pico/gcc/bin:/opt/pico/picotool/picotool:$PATH

# CMake and Ninja for the builds, python3 (the SDK's build scripts),
# python3-venv for a venv of your own (graders make one), libusb for picotool.
# No host C/C++ compiler: picotool and pioasm are prebuilt.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates git make cmake ninja-build python3 python3-venv libusb-1.0-0 \
        less vim-tiny file xxd \
    && rm -rf /var/lib/apt/lists/*

COPY --from=fetch /opt/pico /opt/pico
COPY scripts/templates/ /opt/pico/templates/
COPY --chmod=755 scripts/pico-build /usr/local/bin/pico-build
COPY --chmod=755 scripts/smoke-test.sh /usr/local/bin/pico-smoke-test

RUN set -eux; \
    arm-none-eabi-gcc --version | head -1; \
    picotool version; \
    cmake --version | head -1

LABEL org.opencontainers.image.title="pico-sdk" \
      org.opencontainers.image.description="Raspberry Pi pico-sdk ${PICO_SDK_VERSION} + picotool + Arm GNU Toolchain 14.3.Rel1 for the Raspberry Pi Pico 2 (RP2350), with pico-build"

WORKDIR /workdir
CMD ["/bin/bash"]
