# syntax=docker/dockerfile:1.7
# zephyr-renode-v2-nxp-s32: hal_nxp (the S32 RTD drivers and pinctrl headers are in it), for the
# automotive S32 boards: mr_canhubk3 (S32K344), s32k148_evb, ucans32k1sic and s32z2xxdc2 (S32Z270).
# Build only: no simulator pairing checked (Renode 1.17 has an s32k388 platform, not tried).
ARG BASE=zephyr-renode-v2:dev
FROM ${BASE}
USER zephyr
WORKDIR /opt/zephyrproject
RUN set -eux; \
    west config manifest.project-filter -- "$(west config manifest.project-filter),+hal_nxp"; \
    west update --narrow --fetch-opt=--depth=1 hal_nxp; \
    find /opt/zephyrproject/modules/hal/nxp -name .git -prune -exec rm -rf {} +; \
    du -sh /opt/zephyrproject/modules/hal/nxp
WORKDIR /workdir
