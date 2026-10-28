# syntax=docker/dockerfile:1.7
#
# Zephyr RTOS image for QEMU only: the build tools, west, the Zephyr tree and
# the SDK's QEMU, with no vendor HALs, flashing tools or git history.
#   Targets : qemu_cortex_m3 and the other Arm, RISC-V, x86 and AArch64 QEMU boards
#   Arches  : linux/arm64 and linux/amd64 (SDK picked from TARGETARCH)
#   Size    : about a third of ../zephyr, so it fits a 10 GB sandbox (Daytona's limit)
#
# Build (native): docker build -t zephyr-qemu .

FROM ubuntu:24.04

ARG TARGETARCH
ARG ZEPHYR_VERSION=v4.4.2
ARG ZEPHYR_SDK_VERSION=1.0.1
# GNU toolchains to install from the SDK, one per QEMU architecture:
#   arm      -> qemu_cortex_m0/m3, qemu_cortex_r5, qemu_cortex_a9
#   riscv64  -> qemu_riscv32/64
#   x86_64   -> qemu_x86 / qemu_x86_64
#   aarch64  -> qemu_cortex_a53
ARG ZEPHYR_TOOLCHAINS="arm-zephyr-eabi riscv64-zephyr-elf x86_64-zephyr-elf aarch64-zephyr-elf"
# Only the west modules QEMU boards and the samples run on them use; no vendor HALs.
ARG ZEPHYR_MODULES="cmsis cmsis_6 cmsis-dsp cmsis-nn littlefs mbedtls nanopb picolibc zcbor"
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
# System packages (Zephyr "Getting Started" list, without the flash/debug helpers)
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        git cmake ninja-build gperf ccache device-tree-compiler \
        wget curl ca-certificates xz-utils bzip2 unzip file make gcc g++ \
        python3 python3-dev python3-venv python3-pip \
        libmagic1 libncurses6 \
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
    && usermod -aG sudo ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && mkdir -p /opt/venv ${ZEPHYR_WORKSPACE} /workdir \
    && chown -R ${USERNAME}:${USERNAME} /opt/venv ${ZEPHYR_WORKSPACE} /workdir

# ---------------------------------------------------------------------------
# Zephyr SDK (minimal bundle + the QEMU toolchains + host tools, QEMU among them)
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

USER ${USERNAME}
WORKDIR ${ZEPHYR_WORKSPACE}

# ---------------------------------------------------------------------------
# Python venv + west + Zephyr source tree (pinned release, shallow, filtered).
# The git history goes in the same layer: west build does not need it, and the
# tree's own is about 1 GB even shallow.
# ---------------------------------------------------------------------------
RUN set -eux; \
    python3 -m venv ${VIRTUAL_ENV}; \
    pip install --no-cache-dir --upgrade pip wheel; \
    pip install --no-cache-dir west; \
    west init -m https://github.com/zephyrproject-rtos/zephyr --mr ${ZEPHYR_VERSION} ${ZEPHYR_WORKSPACE}; \
    FILTER="-.*"; for m in ${ZEPHYR_MODULES}; do FILTER="${FILTER},+${m}"; done; \
    west config manifest.project-filter -- "${FILTER}"; \
    west update --narrow --fetch-opt=--depth=1; \
    find ${ZEPHYR_WORKSPACE} -name .git -prune -exec rm -rf {} +

# What building and running on QEMU needs (twister included); not the extras or compliance tools
RUN pip install --no-cache-dir -r ${ZEPHYR_BASE}/scripts/requirements-base.txt \
        -r ${ZEPHYR_BASE}/scripts/requirements-build-test.txt \
        -r ${ZEPHYR_BASE}/scripts/requirements-run-test.txt \
    && west zephyr-export

# Convenience: source Zephyr env + west completion in interactive shells
RUN { \
      echo 'source "$ZEPHYR_BASE/zephyr-env.sh"'; \
      echo 'eval "$(west completion bash 2>/dev/null)"'; \
      echo 'export PS1="\[\e[1;36m\](zephyr-qemu ${ZEPHYR_VERSION:-})\[\e[0m\] \w \$ "'; \
    } >> /home/${USERNAME}/.bashrc \
    && touch /home/${USERNAME}/.sudo_as_admin_successful

COPY --chmod=755 scripts/smoke-test.sh /usr/local/bin/zephyr-smoke-test

ENV ZEPHYR_VERSION=${ZEPHYR_VERSION}
LABEL org.opencontainers.image.title="zephyr-qemu" \
      org.opencontainers.image.description="Zephyr ${ZEPHYR_VERSION} + SDK ${ZEPHYR_SDK_VERSION} for QEMU boards only"

WORKDIR /workdir
CMD ["/bin/bash"]
