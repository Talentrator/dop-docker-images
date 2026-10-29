# syntax=docker/dockerfile:1.7
#
# Zephyr RTOS image for boards that run on Renode: ../zephyr-qemu-arm with
# Renode in place of QEMU, and the STM32 and Nordic HALs those boards build
# against.
#   Targets : stm32f4_disco, nucleo_f767zi, stm32f072b_disco,
#             nrf52840dk/nrf52840, cortex_r8_virtual
#   Emulator: Renode 1.17.0 (portable, .NET included), with renode-test
#             (Robot Framework) for scripted checks
#   Arches  : linux/arm64 and linux/amd64 (SDK and Renode picked from TARGETARCH)
#
# Build (native): docker build -t zephyr-renode .

FROM ubuntu:24.04

ARG TARGETARCH
ARG ZEPHYR_VERSION=v4.4.2
ARG ZEPHYR_SDK_VERSION=1.0.1
ARG RENODE_VERSION=1.17.0
# arm-zephyr-eabi alone: every board above is a Cortex-M or Cortex-R
ARG ZEPHYR_TOOLCHAINS="arm-zephyr-eabi"
# ../zephyr-qemu-arm's modules, and the HALs of the STM32 and nRF boards
ARG ZEPHYR_MODULES="cmsis cmsis_6 littlefs mbedtls nanopb picolibc zcbor hal_stm32 hal_nordic"
# Of hal_stm32's 30 series (1.1 GB), the ones the STM32 boards above are
ARG STM32_SERIES="f0 f4 f7"
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
    RENODE_ROOT=/opt/renode \
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:$PATH \
    CCACHE_DIR=/home/zephyr/.cache/ccache

# ---------------------------------------------------------------------------
# System packages (Zephyr "Getting Started" list, without the flash/debug
# helpers and gcc-multilib), and socat to put a Renode UART on a terminal
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        git cmake ninja-build gperf ccache device-tree-compiler \
        wget curl ca-certificates xz-utils bzip2 unzip file make gcc g++ \
        python3 python3-dev python3-venv python3-pip \
        libmagic1 libncurses6 socat \
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
# Renode: one release, pinned, checked against its sha256 for each CPU (the
# same release and sums as DOP's firmware shell). The portable build carries
# its own .NET, so nothing else is installed for it.
# ---------------------------------------------------------------------------
RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) a= s=4ba7c68b59e2447f188ef4b4b112fcccd2802582c460beedceb63b84e5605a5f ;; \
      arm64) a=-arm64 s=e9051578411441bfb47b77de0381cfba3badce03663367fab561472fd7807f1f ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/renode.tar.gz "https://github.com/renode/renode/releases/download/v${RENODE_VERSION}/renode-${RENODE_VERSION}.linux${a}-portable.tar.gz"; \
    echo "$s  /tmp/renode.tar.gz" | sha256sum -c -; \
    mkdir -p ${RENODE_ROOT}; \
    tar -xzf /tmp/renode.tar.gz -C ${RENODE_ROOT} --strip-components=1; \
    rm /tmp/renode.tar.gz; \
    ln -s ${RENODE_ROOT}/renode /usr/local/bin/renode; \
    ln -s ${RENODE_ROOT}/renode-test /usr/local/bin/renode-test

# ---------------------------------------------------------------------------
# Zephyr SDK: the minimal bundle and the Arm toolchain, without the host tools
# (QEMU, OpenOCD): Renode runs the boards, and dtc comes from apt. In one
# layer, so the archives taken out are not in the image underneath.
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
    ./setup.sh ${TC_ARGS} -c; \
    find "${ZEPHYR_SDK_INSTALL_DIR}" -name '*.tar.xz' -delete; \
    cp -r /root/.cmake /home/${USERNAME}/ && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}/.cmake

USER ${USERNAME}
WORKDIR ${ZEPHYR_WORKSPACE}

# ---------------------------------------------------------------------------
# Python venv + west + Zephyr source tree (pinned release, shallow, filtered).
# In the same layer, what a build never reads: the git history, the tree's
# doc/ and tests/ (its samples/ stay), but for tests/test_config.yaml, which
# twister reads at start, and of hal_stm32 every series but STM32_SERIES.
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
    mkdir ${ZEPHYR_BASE}/tests && mv /tmp/test_config.yaml ${ZEPHYR_BASE}/tests/; \
    STM32=${ZEPHYR_WORKSPACE}/modules/hal/stm32; \
    for d in ${STM32}/stm32cube/stm32*; do \
      s=${d##*/stm32}; keep=; for k in ${STM32_SERIES}; do case "$s" in ${k}*) keep=1 ;; esac; done; \
      [ -n "$keep" ] || rm -rf "$d"; \
    done; \
    for d in ${STM32}/dts/st/*/; do \
      s=$(basename "$d"); keep=; for k in ${STM32_SERIES}; do [ "$s" = "$k" ] && keep=1; done; \
      [ -n "$keep" ] || rm -rf "$d"; \
    done

# Building, running on Renode with twister, and renode-test: Zephyr's base
# requirements, its test tooling, and Renode's Robot Framework requirements;
# not the run-test extras (OpenCV, numpy, pyocd, python-can, spdx-tools) and
# mypy, which only hardware or CI checks use.
RUN pip install --no-cache-dir -r ${ZEPHYR_BASE}/scripts/requirements-base.txt \
        -r ${RENODE_ROOT}/tests/requirements.txt \
        colorama ply gcovr coverage pytest junitparser python-dotenv tabulate natsort cbor \
    && west zephyr-export

# Convenience: source Zephyr env + west completion in interactive shells
RUN { \
      echo 'source "$ZEPHYR_BASE/zephyr-env.sh"'; \
      echo 'eval "$(west completion bash 2>/dev/null)"'; \
      echo 'export PS1="\[\e[1;36m\](zephyr-renode ${ZEPHYR_VERSION:-})\[\e[0m\] \w \$ "'; \
    } >> /home/${USERNAME}/.bashrc \
    && touch /home/${USERNAME}/.sudo_as_admin_successful

COPY --chmod=755 scripts/zephyr-renode-run /usr/local/bin/zephyr-renode-run
COPY --chmod=755 scripts/smoke-test.sh /usr/local/bin/zephyr-smoke-test

ENV ZEPHYR_VERSION=${ZEPHYR_VERSION} \
    RENODE_VERSION=${RENODE_VERSION}
LABEL org.opencontainers.image.title="zephyr-renode" \
      org.opencontainers.image.description="Zephyr ${ZEPHYR_VERSION} + SDK ${ZEPHYR_SDK_VERSION} + Renode ${RENODE_VERSION} for the STM32, nRF52 and Cortex-R8 boards Renode runs"

WORKDIR /workdir
CMD ["/bin/bash"]
