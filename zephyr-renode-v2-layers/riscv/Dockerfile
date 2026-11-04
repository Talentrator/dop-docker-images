# syntax=docker/dockerfile:1.7
# zephyr-renode-v2-riscv: the SDK's riscv64-zephyr-elf toolchain (the base image has only
# arm-zephyr-eabi), for litex_vexriscv, hifive1 and mpfs_icicle, which Renode 1.17 has platforms for.
ARG BASE=zephyr-renode-v2:dev
FROM ${BASE}
ARG TARGETARCH
ARG ZEPHYR_SDK_VERSION=1.0.1
USER root
RUN set -eux; \
    case "$TARGETARCH" in amd64) h=linux-x86_64 ;; arm64) h=linux-aarch64 ;; *) exit 1 ;; esac; \
    f=toolchain_gnu_${h}_riscv64-zephyr-elf.tar.xz; \
    base=https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_VERSION}; \
    cd ${ZEPHYR_SDK_INSTALL_DIR}/gnu; \
    wget -q "$base/$f" "$base/sha256.sum"; \
    grep " $f\$" sha256.sum | sha256sum -c -; \
    tar -xf "$f"; rm -f "$f" sha256.sum; \
    du -sh riscv64-zephyr-elf
USER zephyr
WORKDIR /workdir
