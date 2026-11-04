# syntax=docker/dockerfile:1.7
# zephyr-renode-v2-renesas: hal_renesas (Renesas FSP), for ek_ra6m5 (RA6M5, Renode runs its sister
# board ck_ra6m5) and rzt2m_rsk (RZ/T2M, build only).
ARG BASE=zephyr-renode-v2:dev
FROM ${BASE}
USER zephyr
WORKDIR /opt/zephyrproject
RUN set -eux; \
    west config manifest.project-filter -- "$(west config manifest.project-filter),+hal_renesas"; \
    west update --narrow --fetch-opt=--depth=1 hal_renesas; \
    find /opt/zephyrproject/modules/hal/renesas -name .git -prune -exec rm -rf {} +; \
    du -sh /opt/zephyrproject/modules/hal/renesas
WORKDIR /workdir
