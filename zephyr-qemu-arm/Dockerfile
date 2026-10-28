# syntax=docker/dockerfile:1.7
#
# Zephyr RTOS image for the Arm QEMU boards only: ../zephyr-qemu with one
# compiler (arm-zephyr-eabi) and the two emulators those boards run on
# (qemu-system-arm; Xilinx's qemu-system-aarch64 for R5 and A9), and without
# what neither building nor running on them needs.
#   Targets : qemu_cortex_m3, qemu_cortex_r5, qemu_cortex_a9 (not
#             qemu_cortex_m0: an nRF51, it needs hal_nordic, 287 MB)
#   Arches  : linux/arm64 and linux/amd64 (SDK picked from TARGETARCH)
#
# Build (native): docker build -t zephyr-qemu-arm .

FROM ubuntu:24.04

ARG TARGETARCH
ARG ZEPHYR_VERSION=v4.4.2
ARG ZEPHYR_SDK_VERSION=1.0.1
# arm-zephyr-eabi alone: Cortex-M, Cortex-R and the 32-bit Cortex-A
ARG ZEPHYR_TOOLCHAINS="arm-zephyr-eabi"
# What Cortex-M needs (cmsis, cmsis_6), the C library, and the small libraries
# the kernel and subsystem samples use; not cmsis-dsp or cmsis-nn
ARG ZEPHYR_MODULES="cmsis cmsis_6 littlefs mbedtls nanopb picolibc zcbor"
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
    PATH=/opt/venv/bin:$PATH \
    CCACHE_DIR=/home/zephyr/.cache/ccache

# ---------------------------------------------------------------------------
# System packages (Zephyr "Getting Started" list, without the flash/debug
# helpers, and without gcc-multilib: that is native_sim's, not QEMU's)
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        git cmake ninja-build gperf ccache device-tree-compiler \
        wget curl ca-certificates xz-utils bzip2 unzip file make gcc g++ \
        python3 python3-dev python3-venv python3-pip \
        libmagic1 libncurses6 \
        sudo locales bash-completion vim-tiny less \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Non-root user (uid 1000 matches the default user on most Linux hosts)
# ---------------------------------------------------------------------------
RUN if getent passwd ubuntu >/dev/null; then userdel -r ubuntu; fi \
    && groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
    && usermod -aG sudo ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && mkdir -p /opt/venv ${ZEPHYR_WORKSPACE} /workdir \
    && chown -R ${USERNAME}:${USERNAME} /opt/venv ${ZEPHYR_WORKSPACE} /workdir

# ---------------------------------------------------------------------------
# Zephyr SDK: the minimal bundle, the Arm toolchain and the host tools, then
# of the host tools only what an Arm QEMU board runs on. In one layer, so what
# is taken out is not in the image underneath:
#   - every qemu-system-* but qemu-system-arm, and of Xilinx's QEMU (usr/xilinx)
#     every one but qemu-system-aarch64, which qemu_cortex_r5 and _a9 run on
#     (board.cmake: QEMU_ARCH xilinx-aarch64); Synopsys's ARC QEMU
#   - the host sysroot's glibc locales (about 500 MB; QEMU runs in C.UTF-8)
#   - the host tools' own installer, left behind by setup.sh
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
    HOST="$(echo hosttools/sysroots/*-pokysdk-linux)"; \
    find "$HOST/usr/bin" -name 'qemu-system-*' ! -name 'qemu-system-arm' ! -name 'qemu-system-xilinx-aarch64' -delete; \
    find "$HOST/usr/xilinx/bin" -name 'qemu-system-*' ! -name 'qemu-system-aarch64' -delete; \
    rm -rf "$HOST/usr/synopsys" "$HOST/usr/lib/locale" hosttools/zephyr-sdk-*-hosttools-standalone-*.sh; \
    cp -r /root/.cmake /home/${USERNAME}/ && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.cmake

USER ${USERNAME}
WORKDIR ${ZEPHYR_WORKSPACE}

# ---------------------------------------------------------------------------
# Python venv + west + Zephyr source tree (pinned release, shallow, filtered).
# In the same layer, what a build never reads: the git history, and the
# tree's doc/ and tests/ (its samples/ stay), but for tests/test_config.yaml,
# which twister reads at start.
# ---------------------------------------------------------------------------
RUN set -eux; \
    python3 -m venv ${VIRTUAL_ENV}; \
    pip install --no-cache-dir --upgrade pip wheel; \
    pip install --no-cache-dir west; \
    west init -m https://github.com/zephyrproject-rtos/zephyr --mr ${ZEPHYR_VERSION} ${ZEPHYR_WORKSPACE}; \
    FILTER="-.*"; for m in ${ZEPHYR_MODULES}; do FILTER="${FILTER},+${m}"; done; \
    west config manifest.project-filter -- "${FILTER}"; \
    west update --narrow --fetch-opt=--depth=1; \
    find ${ZEPHYR_WORKSPACE} -name .git -prune -exec rm -rf {} +; \
    mv ${ZEPHYR_BASE}/tests/test_config.yaml /tmp/; \
    rm -rf ${ZEPHYR_BASE}/doc ${ZEPHYR_BASE}/tests; \
    mkdir ${ZEPHYR_BASE}/tests && mv /tmp/test_config.yaml ${ZEPHYR_BASE}/tests/

# Building, and running on QEMU with twister: Zephyr's base requirements and
# its test tooling, without the run-test extras (OpenCV, numpy, pyocd,
# python-can, spdx-tools) and mypy, which only hardware or CI checks use.
RUN pip install --no-cache-dir -r ${ZEPHYR_BASE}/scripts/requirements-base.txt \
        colorama ply gcovr coverage pytest junitparser python-dotenv tabulate natsort cbor \
    && west zephyr-export

# Convenience: source Zephyr env + west completion in interactive shells
RUN { \
      echo 'source "$ZEPHYR_BASE/zephyr-env.sh"'; \
      echo 'eval "$(west completion bash 2>/dev/null)"'; \
      echo 'export PS1="\[\e[1;36m\](zephyr-qemu-arm ${ZEPHYR_VERSION:-})\[\e[0m\] \w \$ "'; \
    } >> /home/${USERNAME}/.bashrc \
    && touch /home/${USERNAME}/.sudo_as_admin_successful

COPY --chmod=755 scripts/smoke-test.sh /usr/local/bin/zephyr-smoke-test

ENV ZEPHYR_VERSION=${ZEPHYR_VERSION}
LABEL org.opencontainers.image.title="zephyr-qemu-arm" \
      org.opencontainers.image.description="Zephyr ${ZEPHYR_VERSION} + SDK ${ZEPHYR_SDK_VERSION} for the Arm QEMU boards only"

WORKDIR /workdir
CMD ["/bin/bash"]
