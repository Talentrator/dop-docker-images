# syntax=docker/dockerfile:1.7
#
# Zephyr RTOS development image
#   Targets : QEMU, Nordic nRF, STM32, Espressif ESP32 (Xtensa + RISC-V)
#   Arches  : linux/arm64 and linux/amd64 (SDK + tools picked from TARGETARCH)
#
# Build (native):     docker build -t zephyr-dev .
# Build (multi-arch): docker buildx build --platform linux/amd64,linux/arm64 -t <repo>/zephyr-dev --push .

FROM ubuntu:24.04

ARG TARGETARCH
ARG ZEPHYR_VERSION=v4.4.2
ARG ZEPHYR_SDK_VERSION=1.0.1
# GNU toolchains to install from the SDK:
#   arm      -> nRF, STM32, qemu_cortex_m3
#   riscv64  -> ESP32-C3/C6/H2, qemu_riscv32/64
#   xtensa   -> ESP32, ESP32-S2, ESP32-S3
#   x86_64   -> qemu_x86 / qemu_x86_64
#   aarch64  -> qemu_cortex_a53
ARG ZEPHYR_TOOLCHAINS="arm-zephyr-eabi riscv64-zephyr-elf xtensa-espressif_esp32_zephyr-elf xtensa-espressif_esp32s2_zephyr-elf xtensa-espressif_esp32s3_zephyr-elf x86_64-zephyr-elf aarch64-zephyr-elf"
# Only these west modules are fetched (keeps the image small).
ARG ZEPHYR_MODULES="cmsis cmsis_6 cmsis-dsp cmsis-nn dhara fatfs hal_espressif hal_nordic hal_st hal_stm32 hal_xtensa hostap libmetal littlefs lvgl mbedtls mbedtls-3.6 mcuboot mipi-sys-t nanopb net-tools nrf_hw_models nrf_wifi open-amp openthread picolibc psa-arch-tests segger tf-m-tests tf-psa-crypto trusted-firmware-m zcbor"
ARG INSTALL_NRFUTIL=true
# SEGGER J-Link (JLinkExe, JLinkGDBServer, RTT viewer...), used by nrfutil and
# `west flash` for Nordic DKs and J-Link probes. Building with INSTALL_JLINK=true
# means YOU accept the SEGGER J-Link license terms (https://www.segger.com/purchase/licensing/license-sfl/).
ARG INSTALL_JLINK=true
ARG USERNAME=zephyr
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    ZEPHYR_WORKSPACE=/opt/zephyrproject \
    ZEPHYR_BASE=/opt/zephyrproject/zephyr \
    ZEPHYR_SDK_INSTALL_DIR=/opt/zephyr-sdk-${ZEPHYR_SDK_VERSION} \
    ZEPHYR_TOOLCHAIN_VARIANT=zephyr \
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:/opt/nrfutil/bin:$PATH \
    CCACHE_DIR=/home/zephyr/.cache/ccache

# ---------------------------------------------------------------------------
# System packages (Zephyr "Getting Started" list + flash/debug helpers)
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        git cmake ninja-build gperf ccache dfu-util device-tree-compiler \
        wget curl ca-certificates xz-utils bzip2 unzip file make gcc g++ \
        python3 python3-dev python3-venv python3-pip python3-tk \
        libsdl2-dev libmagic1 libusb-1.0-0 libudev1 libncurses6 \
        usbutils udev stlink-tools picocom minicom \
        sudo locales bash-completion vim-tiny less \
    && if [ "$TARGETARCH" = "amd64" ]; then \
         apt-get install -y --no-install-recommends gcc-multilib g++-multilib; \
       fi \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Non-root user (uid 1000 matches the default user on most Linux hosts)
# ---------------------------------------------------------------------------
RUN if getent passwd ubuntu >/dev/null; then userdel -r ubuntu; fi \
    && groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
    && usermod -aG dialout,plugdev,sudo ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && mkdir -p /opt/venv ${ZEPHYR_WORKSPACE} /workdir \
    && chown -R ${USERNAME}:${USERNAME} /opt/venv ${ZEPHYR_WORKSPACE} /workdir

# ---------------------------------------------------------------------------
# Zephyr SDK (minimal bundle + selected toolchains + host tools: QEMU, OpenOCD)
# ---------------------------------------------------------------------------
RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) SDK_ARCH=x86_64 ;; \
      arm64) SDK_ARCH=aarch64 ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    BASE_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_VERSION}"; \
    SDK_FILE="zephyr-sdk-${ZEPHYR_SDK_VERSION}_linux-${SDK_ARCH}_minimal.tar.xz"; \
    cd /tmp; \
    wget -q "${BASE_URL}/${SDK_FILE}" "${BASE_URL}/sha256.sum"; \
    grep " ${SDK_FILE}\$" sha256.sum | sha256sum -c -; \
    tar -xf "${SDK_FILE}" -C /opt; \
    rm -f "${SDK_FILE}" sha256.sum; \
    cd "${ZEPHYR_SDK_INSTALL_DIR}"; \
    TC_ARGS=""; for t in ${ZEPHYR_TOOLCHAINS}; do TC_ARGS="$TC_ARGS -t $t"; done; \
    ./setup.sh ${TC_ARGS} -h -c; \
    find "${ZEPHYR_SDK_INSTALL_DIR}" -name '*.tar.xz' -delete; \
    cp -r /root/.cmake /home/${USERNAME}/ && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.cmake

# Udev rules for OpenOCD probes (effective only when the container runs udev / on the host)
RUN cp "${ZEPHYR_SDK_INSTALL_DIR}"/hosttools/sysroots/*/usr/share/openocd/contrib/60-openocd.rules \
        /etc/udev/rules.d/ 2>/dev/null || true

# ---------------------------------------------------------------------------
# nrfutil (Nordic) and optional SEGGER J-Link
# ---------------------------------------------------------------------------
RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) NRF_TRIPLE=x86_64-unknown-linux-gnu; JLINK_PKG=JLink_Linux_x86_64.deb ;; \
      arm64) NRF_TRIPLE=aarch64-unknown-linux-gnu; JLINK_PKG=JLink_Linux_arm64.deb ;; \
    esac; \
    if [ "$INSTALL_NRFUTIL" = "true" ]; then \
      mkdir -p /opt/nrfutil/bin; \
      wget -q -O /opt/nrfutil/bin/nrfutil \
        "https://files.nordicsemi.com/artifactory/swtools/external/nrfutil/executables/${NRF_TRIPLE}/nrfutil"; \
      chmod +x /opt/nrfutil/bin/nrfutil; \
    fi; \
    if [ "$INSTALL_JLINK" = "true" ]; then \
      apt-get update; \
      wget -q --post-data 'accept_license_agreement=accepted&submit=Download+software' \
        -O /tmp/jlink.deb "https://www.segger.com/downloads/jlink/${JLINK_PKG}"; \
      apt-get install -y --no-install-recommends /tmp/jlink.deb || \
        (dpkg --unpack /tmp/jlink.deb && rm -f /var/lib/dpkg/info/jlink.postinst && dpkg --configure jlink && apt-get install -yf); \
      rm -f /tmp/jlink.deb; rm -rf /var/lib/apt/lists/*; \
    fi

USER ${USERNAME}
WORKDIR ${ZEPHYR_WORKSPACE}

# ---------------------------------------------------------------------------
# Python venv + west + Zephyr source tree (pinned release, shallow, filtered)
# ---------------------------------------------------------------------------
RUN set -eux; \
    python3 -m venv ${VIRTUAL_ENV}; \
    pip install --no-cache-dir --upgrade pip wheel; \
    pip install --no-cache-dir west; \
    west init -m https://github.com/zephyrproject-rtos/zephyr --mr ${ZEPHYR_VERSION} ${ZEPHYR_WORKSPACE}; \
    FILTER="-.*"; for m in ${ZEPHYR_MODULES}; do FILTER="${FILTER},+${m}"; done; \
    west config manifest.project-filter -- "${FILTER}"; \
    west update --narrow --fetch-opt=--depth=1

RUN pip install --no-cache-dir -r ${ZEPHYR_BASE}/scripts/requirements.txt esptool pyocd \
    && west zephyr-export

# Binary blobs (ESP32 Wi-Fi/BLE libs etc.); retried because the download host is flaky
RUN for m in hal_espressif hal_nordic; do \
      for i in 1 2 3 4 5; do west blobs fetch $m && break; echo "retry $i for $m"; sleep 5; done; \
    done \
    && ! west blobs list hal_espressif --format '{status} {path}' | grep -v '^A '

# nrfutil sub-commands are installed per user
RUN if command -v nrfutil >/dev/null; then nrfutil install device; fi

# Convenience: source Zephyr env + west completion in interactive shells
RUN { \
      echo 'source "$ZEPHYR_BASE/zephyr-env.sh"'; \
      echo 'eval "$(west completion bash 2>/dev/null)"'; \
      echo 'export PS1="\[\e[1;36m\](zephyr ${ZEPHYR_VERSION:-})\[\e[0m\] \w \$ "'; \
    } >> /home/${USERNAME}/.bashrc \
    && touch /home/${USERNAME}/.sudo_as_admin_successful

COPY --chmod=755 scripts/smoke-test.sh /usr/local/bin/zephyr-smoke-test

ENV ZEPHYR_VERSION=${ZEPHYR_VERSION}
LABEL org.opencontainers.image.title="zephyr-dev" \
      org.opencontainers.image.description="Zephyr ${ZEPHYR_VERSION} + SDK ${ZEPHYR_SDK_VERSION} for QEMU, nRF, STM32, ESP32"

WORKDIR /workdir
CMD ["/bin/bash"]
