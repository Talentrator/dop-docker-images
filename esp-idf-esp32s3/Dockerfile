# syntax=docker/dockerfile:1.7
#
# ESP-IDF image for the ESP32-S3: the agent box and the grader box of a task
# for the Adafruit Feather ESP32-S3 Reverse TFT (product 5691: ESP32-S3,
# 4 MB flash, 2 MB PSRAM, 240x135 ST7789 TFT).
#   SDK     : ESP-IDF v5.5.6 (git tag, checked against its commit), with its
#             submodules and examples; the Wi-Fi, PHY, coexistence and
#             Bluetooth blobs of the other chips are removed
#   Tools   : the xtensa-esp-elf GCC and esp-rom-elfs for the esp32s3 (from
#             idf_tools.py, which checks each archive against the sha256 in the
#             release's tools/tools.json), IDF's Python env, CMake and Ninja
#   Helper  : esp32s3-build, which builds a project and writes one merged
#             image (bootloader + partition table + app) to flash at 0x0
#   Arches  : linux/arm64 and linux/amd64
#
# Nothing is fetched at runtime: DOP boxes run with internet off. So no
# component manager dependencies either (no idf_component.yml with
# dependencies): projects use what is in ESP-IDF (esp_lcd has the ST7789).
#
# Not in it: OpenOCD, GDB and the ULP toolchains. The board is flashed with
# esptool by the bench that holds it.
#
# Build (native): docker build -t esp-idf-esp32s3 .

# Declared once, before any stage: the publish workflow reads the version tag from this line
ARG IDF_VERSION=5.5.6

FROM ubuntu:24.04 AS fetch

ARG IDF_VERSION
ARG IDF_COMMIT=880a203ae603d08a94d06aa01e0d6761958e5e9e

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    IDF_PATH=/opt/esp/idf \
    IDF_TOOLS_PATH=/opt/esp/tools \
    IDF_PYTHON_ENV_PATH=/opt/esp/python

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git python3 python3-venv python3-pip \
    && rm -rf /var/lib/apt/lists/*

# ESP-IDF at its release tag, checked against the tag's commit, without its git history
RUN set -eux; \
    git clone -q --depth 1 --branch v${IDF_VERSION} --recurse-submodules --shallow-submodules -j8 \
        https://github.com/espressif/esp-idf.git $IDF_PATH; \
    cd $IDF_PATH; \
    test "$(git rev-parse HEAD)" = "$IDF_COMMIT"; \
    # IDF reads its version from version.txt when it isn't a git checkout
    echo "v${IDF_VERSION}" > version.txt; \
    find . -name .git -prune -exec rm -rf {} +; \
    rm -rf docs; \
    # blobs for the other chips (the S3's own stay)
    for d in components/esp_wifi/lib components/esp_phy/lib components/esp_coex/lib; do \
      [ -d $d ] && find $d -mindepth 1 -maxdepth 1 -type d ! -name esp32s3 -exec rm -rf {} +; \
    done; \
    find components/bt/controller/lib_esp32* -maxdepth 0 -type d 2>/dev/null | grep -v 'lib_esp32c3_family$' | xargs -r rm -rf; \
    du -sh $IDF_PATH

# the esp32s3 compiler and ROM ELFs only, and IDF's Python environment
RUN set -eux; \
    cd $IDF_PATH; \
    python3 tools/idf_tools.py --non-interactive install xtensa-esp-elf esp-rom-elfs; \
    mkdir -p $IDF_PYTHON_ENV_PATH; \
    python3 tools/idf_tools.py --non-interactive install-python-env; \
    rm -rf $IDF_TOOLS_PATH/dist /root/.cache; \
    # stable paths for the runtime ENV, whatever the tool versions
    ln -s $(dirname $(find $IDF_TOOLS_PATH/tools/xtensa-esp-elf -path '*/bin/xtensa-esp32s3-elf-gcc' | head -1)) /opt/esp/toolchain-bin; \
    ln -s $(find $IDF_TOOLS_PATH/tools/esp-rom-elfs -mindepth 1 -maxdepth 1 -type d | head -1) /opt/esp/rom-elfs; \
    ls -l /opt/esp; du -sh $IDF_TOOLS_PATH $IDF_PYTHON_ENV_PATH; \
    chmod -R a+rX /opt/esp

# ---------------------------------------------------------------------------
FROM ubuntu:24.04

ARG IDF_VERSION

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    IDF_VERSION=${IDF_VERSION} \
    IDF_PATH=/opt/esp/idf \
    IDF_TOOLS_PATH=/opt/esp/tools \
    IDF_PYTHON_ENV_PATH=/opt/esp/python \
    IDF_TARGET=esp32s3 \
    ESP_ROM_ELF_DIR=/opt/esp/rom-elfs/ \
    IDF_COMPONENT_MANAGER=1 \
    IDF_CCACHE_ENABLE=0 \
    PATH=/opt/esp/idf/tools:/opt/esp/toolchain-bin:/opt/esp/python/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# cmake and ninja for idf.py, python3 for IDF's env, python3-venv for a venv
# of your own (graders make one), git and make for whoever wants them
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates cmake ninja-build git make python3 python3-venv libusb-1.0-0 \
        less vim-tiny file xxd \
    && rm -rf /var/lib/apt/lists/*

COPY --from=fetch /opt/esp /opt/esp

COPY --chmod=755 scripts/esp32s3-build /usr/local/bin/esp32s3-build
COPY --chmod=755 scripts/smoke-test.sh /usr/local/bin/esp32s3-smoke-test
COPY scripts/templates /opt/esp/templates

# idf.py works for any user: it writes only to the project's build folder
RUN set -eux; \
    idf.py --version; \
    xtensa-esp32s3-elf-gcc --version | head -1; \
    esptool.py version | tail -1

LABEL org.opencontainers.image.title="esp-idf-esp32s3" \
      org.opencontainers.image.description="ESP-IDF v${IDF_VERSION} for the ESP32-S3 (Adafruit Feather ESP32-S3 Reverse TFT), with esp32s3-build"

WORKDIR /workdir
CMD ["/bin/bash"]
