# syntax=docker/dockerfile:1.7
#
# Silicon Labs Simplicity SDK image for EFR32 Series 2 firmware, built
# headless with slc-cli and CMake: the agent box and the grader box of a task
# for the xG24 Dev Kit (BRD2601B, EFR32MG24) and its siblings.
#   SDK     : Simplicity SDK 2026.6.2: platform, Bluetooth LE and Mesh,
#             bootloader, RAIL; not Zigbee, OpenThread, Wi-SUN, Z-Wave or
#             Connect
#   Tools   : slc-cli 6.0.22 + its Java 21 and Python adapter pack, Silicon
#             Labs' GCC 14.2.Rel1 (Armv8-M libraries only), CMake, Ninja, and
#             sisdk-build, which runs the two of them for one board
#   Arches  : linux/arm64 and linux/amd64
#
# Everything is fetched from Silicon Labs' own servers, without SLT (its Linux
# build is x86_64 only): slc-cli, Java and Python from the Studio update site,
# the SDK and GCC from its conan server by their content revisions. Each file
# is checked against its sha256.
#
# Not in it: Simplicity Commander (silabs.com does not serve it to scripts).
# The bench that flashes the kit has its own.
#
# Build (native): docker build -t simplicity-sdk .

# Declared once, before any stage: the publish workflow reads the version tag from this line
ARG SISDK_VERSION=2026.6.2

FROM ubuntu:24.04 AS fetch

ARG TARGETARCH
ARG SISDK_VERSION

# the SDK has non-ASCII file names, which bsdtar refuses in the C locale
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl libarchive-tools \
    && rm -rf /var/lib/apt/lists/*

# get URL SHA256 FILE: download and check one file
RUN printf '#!/bin/sh\nset -eu\ncurl -fsSL --retry 5 -o "$3" "$1"\necho "$2  $3" | sha256sum -c -\n' > /usr/local/bin/get \
    && chmod +x /usr/local/bin/get

# slc-cli, the Java it runs on, and the Python its template generators run on
# (an adapter pack slc finds by --tool-path, not on PATH)
RUN set -eux; \
    U=https://updates.silabs.com/studio/v6/updates/update_site/archives; \
    case "$TARGETARCH" in \
      amd64) \
        get $U/slc-cli/6.0.22/slc-cli.linux.gtk.x86_64.zip f05e078b369d7e7dbfa31bdd2ad8edf61f04a9291393deab4702137639ba7d19 slc.zip; \
        get $U/java21/21.0.6/linux.x86_64_21.0.6.zip 5382fa98bcc66fc3aef48792a3e84328eca16afa9bf97517527e92812516ee50 jre.zip; \
        get $U/python/3.10.3/python.3.10.3.gtk.linux.x86_64.zip 26f56b1cfa05b2b3b7dafb2c2a5e3c19498389c34dfe68be800f71f476c86363 python.zip ;; \
      arm64) \
        get $U/slc-cli/6.0.22/slc-cli.linux.gtk.aarch64.zip 5d13e09e605e5dfb94abeb0773055647764bb30d746916f3fc3991a48282a6ba slc.zip; \
        get $U/java21/21.0.6/linux.aarch64_21.0.6.zip 61b4be111fe14d7a9138de920047489c679c7a697320cf69d28b23046edbaf73 jre.zip; \
        get $U/python/3.10.3/python.3.10.gtk.linux.aarch64.zip 0bd0334fead1e3c2647b6c09b9801b214ab3b999e9e6a9d13553ff57c1e04bb2 python.zip ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    mkdir -p /opt/silabs/slc-cli /opt/silabs/java21 /opt/silabs/python; \
    bsdtar -xf slc.zip --strip-components=1 -C /opt/silabs/slc-cli; \
    bsdtar -xf jre.zip --strip-components=1 -C /opt/silabs/java21; \
    bsdtar -xf python.zip --strip-components=1 -C /opt/silabs/python; \
    rm slc.zip jre.zip python.zip

# Silicon Labs' GCC 14.2.Rel1: the SDK's prebuilt libraries carry zstd-compressed
# LTO bytecode, which Arm's own aarch64 build cannot read
RUN set -eux; \
    G=https://conan.silabs.net/v2/conans/gcc-arm-none-eabi/14.2.rel1/silabs/_/revisions/7a5e7220af325e610937338dde99651b/packages; \
    case "$TARGETARCH" in \
      amd64) get $G/63fead0844576fc02943e16909f08fcdddd6f44b/revisions/8ed8dc1bfca3f906fb994b5d17f914d4/files/conan_package.tgz 8611633339da253836bee0c30b0db53daa371d7bf4bb253f326a7a69791b2c9c gcc.tgz ;; \
      arm64) get $G/c93719558cf197f1df5a7f1d071093e26f0e44a0/revisions/d15e203e46d519705ca4ef23e8e358f9/files/conan_package.tgz f15c3d814ae73c60b81a47ec630ab7052fa180ba29df364ad676d3d246cd0b03 gcc.tgz ;; \
    esac; \
    mkdir -p /opt/silabs/gcc; \
    bsdtar -xf gcc.tgz -C /opt/silabs/gcc; \
    rm gcc.tgz; \
    # every EFR32 Series 2 is a Cortex-M33: of the multilibs, only Armv8-M's
    for d in /opt/silabs/gcc/arm-none-eabi/lib/thumb /opt/silabs/gcc/lib/gcc/arm-none-eabi/*/thumb; do \
      find "$d" -mindepth 1 -maxdepth 1 -type d ! -name 'v8-m.*' -exec rm -rf {} +; \
    done; \
    rm -rf /opt/silabs/gcc/arm-none-eabi/lib/arm /opt/silabs/gcc/lib/gcc/arm-none-eabi/*/arm

# The SDK: one package for every host
RUN set -eux; \
    get https://conan.silabs.net/v2/conans/simplicity-sdk/${SISDK_VERSION}/silabs/_/revisions/01d3aa603a2e4de672a78e22a49af1d2/packages/d174c6c754e8f78a6f4119a6c96fdf96988f562b/revisions/6282063cc48b077ae94090d823619e99/files/conan_package.tgz fdf73bfb67c722c1654a73a86559d38a330e4dfc0fba580531c32b311793c192 sdk.tgz; \
    mkdir -p /opt/silabs/sdk; \
    bsdtar -xf sdk.tgz -C /opt/silabs/sdk; \
    rm sdk.tgz; \
    # the 15.4 and sub-GHz stacks, and Security Engine images for other chips
    # (1.3 GB); slc skips component paths that are not there. Not generative_ai:
    # its agents_md component (AGENTS.md in every project) is required by every device.
    cd /opt/silabs/sdk; \
    rm -rf zigbee* wisun* openthread* zwave* connect_* multiprotocol* common_15_4 \
           compute* rail_library_alpha_chips; \
    find . -maxdepth 1 -name 'se_firmware_*' ! -name se_firmware_xg24 -exec rm -rf {} +

# ---------------------------------------------------------------------------
FROM ubuntu:24.04

ARG SISDK_VERSION

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    SISDK=/opt/silabs/sdk \
    SISDK_VERSION=${SISDK_VERSION} \
    ARM_GCC_DIR=/opt/silabs/gcc \
    PATH=/opt/silabs/gcc/bin:/opt/silabs/java21/jre/bin:$PATH

# CMake and Ninja for the generated projects, python3-venv for a venv of your
# own (sisdk-build works with one active), poppler-utils for datasheet PDFs
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates git make cmake ninja-build python3 python3-venv poppler-utils \
        less vim-tiny file xxd \
    && rm -rf /var/lib/apt/lists/*

COPY --from=fetch /opt/silabs /opt/silabs

# slc finds slc.jar beside itself ($0), so a wrapper and not a symlink
RUN printf '#!/bin/sh\nexec /opt/silabs/slc-cli/slc "$@"\n' > /usr/local/bin/slc \
    && chmod 755 /usr/local/bin/slc

COPY --chmod=755 scripts/sisdk-build /usr/local/bin/sisdk-build
COPY --chmod=755 scripts/smoke-test.sh /usr/local/bin/sisdk-smoke-test

LABEL org.opencontainers.image.title="simplicity-sdk" \
      org.opencontainers.image.description="Simplicity SDK ${SISDK_VERSION} + slc-cli + GCC 14.2.Rel1 for EFR32 Series 2 (xG24 Dev Kit)"

WORKDIR /workdir
CMD ["/bin/bash"]
