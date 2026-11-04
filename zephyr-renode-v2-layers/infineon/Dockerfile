# syntax=docker/dockerfile:1.7
# zephyr-renode-v2-infineon: hal_infineon (XMClib, PDL), for xmc45_relax_kit, xmc47_relax_kit and
# kit_xmc72_evk. Build only: no simulator pairing.
ARG BASE=zephyr-renode-v2:dev
FROM ${BASE}
USER zephyr
WORKDIR /opt/zephyrproject
RUN set -eux; \
    west config manifest.project-filter -- "$(west config manifest.project-filter),+hal_infineon"; \
    west update --narrow --fetch-opt=--depth=1 hal_infineon; \
    find /opt/zephyrproject/modules/hal/infineon -name .git -prune -exec rm -rf {} +; \
    du -sh /opt/zephyrproject/modules/hal/infineon
WORKDIR /workdir
