# syntax=docker/dockerfile:1.7
# zephyr-renode-v2-stm32wba: the STM32WBA series of hal_stm32, which the base image cuts (it keeps
# F0/F4/F7). For nucleo_wba55cg (and nucleo_wba65ri). Renode 1.17 runs nucleo_wba52cg, a sister board.
ARG BASE=zephyr-renode-v2:dev
FROM ${BASE}
ARG HAL_STM32_REV=fc11896dd39cfca37bf9b4aeaaa2df8861b81875
USER zephyr
RUN set -eux; \
    tmp=$(mktemp -d); cd "$tmp"; \
    git init -q hal; cd hal; \
    git remote add origin https://github.com/zephyrproject-rtos/hal_stm32; \
    git sparse-checkout set --no-cone /stm32cube/stm32wbaxx /dts/st/wba; \
    git fetch -q --depth 1 --filter=blob:none origin ${HAL_STM32_REV}; \
    git checkout -q FETCH_HEAD; \
    STM32=/opt/zephyrproject/modules/hal/stm32; \
    cp -r stm32cube/stm32wbaxx "$STM32/stm32cube/"; \
    cp -r dts/st/wba "$STM32/dts/st/"; \
    cd /; rm -rf "$tmp"; \
    du -sh "$STM32/stm32cube/stm32wbaxx" "$STM32/dts/st/wba"
WORKDIR /workdir
