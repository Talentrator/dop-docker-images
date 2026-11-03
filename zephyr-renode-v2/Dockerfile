# syntax=docker/dockerfile:1.7
#
# Zephyr + Renode V2: ../zephyr-renode with what scored scenario tasks need on top.
#   - hal_st and hal_tdk: without them the ST MEMS sensors (LIS2DW12, LSM6DSO, IIS2MDC, ...) and
#     ICP-101xx do not build (Kconfig stops at HAS_STMEMSC / USE_EMD_ICP101XX)
#   - /opt/zephyr-v2: the scenario runner (zr-scenario) and the Renode files it loads: a patched
#     bxCAN model (STMCANZephyr.cs), a CAN hub recorder (CANRecorder.cs), the nucleo_f767zi
#     platform using both, and that platform's SVD (the grader box has no network)
#   - zbuild: the unprivileged user the grader builds a model's project as (no sudo, no home)
#
# Build: docker build -t zephyr-renode-v2 .   (BASE pins ../zephyr-renode)

ARG BASE=ghcr.io/talentrator/dop-docker-images/zephyr-renode:latest
FROM ${BASE}

USER zephyr
WORKDIR /opt/zephyrproject
RUN set -eux; \
    west config manifest.project-filter -- "-.*,+cmsis,+cmsis_6,+littlefs,+mbedtls,+nanopb,+picolibc,+zcbor,+hal_stm32,+hal_nordic,+hal_st,+hal_tdk"; \
    west update --narrow --fetch-opt=--depth=1 hal_st hal_tdk; \
    find /opt/zephyrproject/modules -name .git -prune -exec rm -rf {} +; \
    du -sh /opt/zephyrproject/modules/hal/st /opt/zephyrproject/modules/hal/tdk

USER root
RUN useradd --uid 1001 --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin zbuild
COPY opt/ /opt/zephyr-v2/
RUN chown -R root:root /opt/zephyr-v2 \
    && chmod -R u=rwX,go=rX /opt/zephyr-v2 \
    && chmod 755 /opt/zephyr-v2/bin/* \
    && ln -s /opt/zephyr-v2/bin/zr-scenario /usr/local/bin/zr-scenario

USER zephyr
WORKDIR /workdir
