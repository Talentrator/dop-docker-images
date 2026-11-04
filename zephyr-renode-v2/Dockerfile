# syntax=docker/dockerfile:1.7
#
# Zephyr + Renode V2: ../zephyr-renode with what scored scenario tasks need on top.
#   - hal_st and hal_tdk: without them the ST MEMS sensors (LIS2DW12, LSM6DSO, IIS2MDC, ...) and
#     ICP-101xx do not build (Kconfig stops at HAS_STMEMSC / USE_EMD_ICP101XX)
#   - /opt/zephyr-v2: the scenario runner (zr-scenario, events and checks in RUNNER.md), the step-list
#     replay tool (zr-replay), and the Renode files they load: patched models where Renode's differ from
#     the chip (STMCANZephyr.cs, LIS2DW12Fixed.cs, boards/*.cs), recorders (CANRecorder.cs,
#     GPIORecorder.cs, ZRScenarioTools.cs), and per-board platform files with local SVDs under boards/
#     (the grader box has no network)
#   - zbuild: the unprivileged user the grader builds a model's project as (no sudo, no home)
#
# Build: docker build -t zephyr-renode-v2 .   (BASE pins ../zephyr-renode by digest: the 29 Oct build)

# the version tag the publish workflow gives the image
ARG ZEPHYR_RENODE_V2_VERSION=v2.0.0
ARG BASE=ghcr.io/talentrator/dop-docker-images/zephyr-renode@sha256:33c8bd54608f0a95854abdbfb7924acdf675caf86c9b0e8a060a35b49ef2a2c9
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
# DOP runs every agent command as `su - <user> -c ...`, a login shell that drops the image's ENV
# (no /opt/venv/bin on PATH, no ZEPHYR_BASE or SDK): west and zr-scenario then fail. Login shells
# read /etc/profile.d, so the image's environment is written there.
RUN { env | grep -E '^(ZEPHYR_[A-Z_]*|RENODE_[A-Z_]*|VIRTUAL_ENV|CCACHE_DIR|LANG|LC_ALL)=' | sort | sed 's/^/export /'; \
      echo 'export PATH="/opt/venv/bin:$PATH"'; } > /etc/profile.d/zephyr-renode.sh \
 && cat /etc/profile.d/zephyr-renode.sh
COPY opt/ /opt/zephyr-v2/
RUN chown -R root:root /opt/zephyr-v2 \
    && chmod -R u=rwX,go=rX /opt/zephyr-v2 \
    && chmod 755 /opt/zephyr-v2/bin/* \
    && ln -s /opt/zephyr-v2/bin/zr-scenario /usr/local/bin/zr-scenario \
    && ln -s /opt/zephyr-v2/bin/zr-replay /usr/local/bin/zr-replay

USER zephyr
WORKDIR /workdir
