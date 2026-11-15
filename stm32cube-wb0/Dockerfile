# syntax=docker/dockerfile:1.7
#
# STM32CubeWB0 image for STM32WB09 firmware, built headless with CMake and the
# Arm GNU Toolchain: the agent box and the grader box of a task for the ST
# NUCLEO-WB09KE (MB2032, STM32WB09KEV6: Cortex-M0+ at 64 MHz, 512 kB flash,
# 64 kB RAM, Bluetooth LE 5.4 radio).
#   SDK     : STM32CubeWB0 1.5.0: CMSIS, the HAL and LL drivers, the NUCLEO
#             BSP, the STM32_BLE stack (prebuilt), the radio and BLE common
#             modules, the sequencer/LPM/trace utilities, FreeRTOS (Cortex-M0
#             port), and every NUCLEO-WB09KE example, application and
#             demonstration (STM32CubeIDE layout)
#   Tools   : Arm GNU Toolchain 14.3.Rel1 (Armv6-M libraries only), CMake,
#             Ninja, and stm32wb0-build, which builds a project folder for the
#             board: a CMakeLists.txt that calls stm32wb0_firmware(), or an ST
#             example folder as it is (from its STM32CubeIDE project files)
#   Arches  : linux/arm64 and linux/amd64
#
# STM32CubeWB0 comes from ST's GitHub repository at its v1.5.0 tag, with the
# driver and middleware submodules at the commits that tag pins; the compiler
# from developer.arm.com. Each file is checked against its sha256.
#
# Not in it: STM32CubeMX and STM32CubeProgrammer (ST serves them behind a
# login), and no debug probe tools: the bench that flashes the kit has its own
# (probe-rs). Nothing here needs the internet at run time.
#
# Build (native): docker build -t stm32cube-wb0 .

# Declared once, before any stage: the publish workflow reads the version tag from this line
ARG STM32CUBEWB0_VERSION=1.5.0

FROM ubuntu:24.04 AS fetch

ARG TARGETARCH
ARG STM32CUBEWB0_VERSION
ARG ARM_GCC_VERSION=14.3.rel1

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl xz-utils \
    && rm -rf /var/lib/apt/lists/*

# get URL SHA256 FILE: download and check one file
RUN printf '#!/bin/sh\nset -eu\ncurl -fsSL --retry 5 -o "$3" "$1"\necho "$2  $3" | sha256sum -c -\n' > /usr/local/bin/get \
    && chmod +x /usr/local/bin/get

# Arm GNU Toolchain, per host architecture
RUN set -eux; \
    U=https://developer.arm.com/-/media/Files/downloads/gnu/${ARM_GCC_VERSION}/binrel; \
    case "$TARGETARCH" in \
      amd64) get $U/arm-gnu-toolchain-${ARM_GCC_VERSION}-x86_64-arm-none-eabi.tar.xz 8f6903f8ceb084d9227b9ef991490413014d991874a1e34074443c2a72b14dbd gcc.tar.xz ;; \
      arm64) get $U/arm-gnu-toolchain-${ARM_GCC_VERSION}-aarch64-arm-none-eabi.tar.xz 2d465847eb1d05f876270494f51034de9ace9abe87a4222d079f3360240184d3 gcc.tar.xz ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    mkdir -p /opt/st/gcc; \
    tar -xJf gcc.tar.xz --strip-components=1 -C /opt/st/gcc; \
    rm gcc.tar.xz; \
    cd /opt/st/gcc; \
    # the STM32WB09 is a Cortex-M0+: of the multilibs, only Armv6-M's
    for d in arm-none-eabi/lib/thumb lib/gcc/arm-none-eabi/*/thumb; do \
      find "$d" -mindepth 1 -maxdepth 1 -type d ! -name 'v6-m' -exec rm -rf {} +; \
    done; \
    rm -rf arm-none-eabi/lib/arm lib/gcc/arm-none-eabi/*/arm share/doc share/info share/man share/gdb \
           bin/arm-none-eabi-gdb* bin/arm-none-eabi-lto-dump libexec/gcc/arm-none-eabi/*/f951 \
           arm-none-eabi/include/c++/*/experimental lib/python* include/gdb

# STM32CubeWB0 and the submodules it needs, at the commits v1.5.0 pins
#   sub PATH REPO COMMIT SHA256: fetch one submodule into the tree
RUN set -eux; \
    get https://github.com/STMicroelectronics/STM32CubeWB0/archive/refs/tags/v${STM32CUBEWB0_VERSION}.tar.gz \
        69c18c026e07963813ecce8c279d847db913e5ade68620c50bf31cd545901ee7 cube.tgz; \
    mkdir -p /opt/st/STM32CubeWB0; \
    tar -xzf cube.tgz --strip-components=1 -C /opt/st/STM32CubeWB0; \
    rm cube.tgz; \
    cd /opt/st/STM32CubeWB0; \
    sub() { get https://github.com/STMicroelectronics/$2/archive/$3.tar.gz $4 s.tgz; \
            rm -rf "$1"; mkdir -p "$1"; tar -xzf s.tgz --strip-components=1 -C "$1"; rm s.tgz; }; \
    sub Drivers/CMSIS/Device/ST/STM32WB0X    cmsis_device_wb0     f893ef4a3886f53f8042daca733cfcde9b708ed2 64fc4f6620b69c0710d7bdce19008bdb4ba1158987e0267ac29ac3b107b709ef; \
    sub Drivers/STM32WB0x_HAL_Driver         stm32wb0x_hal_driver 9469b33cff37a3c01cccdd9935a0fa7676aacc08 0a1a940bca9374ad495c7c9311af79fff5e7a50d9ed057d77c43600b749a613a; \
    sub Drivers/BSP/STM32WB0x-nucleo         stm32wb0x-nucleo-bsp 31245de37c9bc7f70c5fbd62e2c63885e8d8179a 29112091f820657c41732405e7aae53c51e5ac0ce20735448b4908a97fd4c280; \
    sub Middlewares/Third_Party/FreeRTOS     stm32-mw-freertos    b9beb62c79545d6ebef1a46dd3b54d96de4a1b8d aecc58e8de0fc98a6dc425060674e6517da63e0011e0a483984fb0f7459e939b; \
    # only the NUCLEO-WB09KE's projects, without their IAR/Keil copies or prebuilt binaries
    find Projects -mindepth 1 -maxdepth 1 ! -name NUCLEO-WB09KE ! -name Common -exec rm -rf {} +; \
    find Projects -type d \( -name EWARM -o -name MDK-ARM -o -name Binary \) -prune -exec rm -rf {} +; \
    # FatFs (no project uses it), Windows tools, CMSIS parts for other cores, other compilers' startups
    rm -rf Middlewares/Third_Party/FatFs Utilities/PC_Software Utilities/create_sym_lib.exe Documentation _htmresc \
           Drivers/CMSIS/DSP Drivers/CMSIS/NN Drivers/CMSIS/Core_A Drivers/CMSIS/DAP Drivers/CMSIS/Documentation \
           Drivers/CMSIS/Device/ST/STM32WB0X/Source/Templates/arm Drivers/CMSIS/Device/ST/STM32WB0X/Source/Templates/iar; \
    find Middlewares/Third_Party/FreeRTOS/Source/portable -mindepth 1 -maxdepth 1 ! -name GCC ! -name MemMang ! -name Common -exec rm -rf {} +; \
    find Middlewares/Third_Party/FreeRTOS/Source/portable/GCC -mindepth 1 -maxdepth 1 ! -name ARM_CM0 -exec rm -rf {} +; \
    find . \( -name '*.chm' -o -name '*.pdf' -o -name '_htmresc' \) -prune -exec rm -rf {} +; \
    # the fallbacks stm32wb0_firmware() adds: ST's newlib stubs, a HAL configuration with every
    # module on, and the stm32_assert.h the LL sources include
    mkdir -p /opt/st/cmake/support/conf /opt/st/cmake/support/conf_bsp /opt/st/cmake/support/fallback; \
    E=Projects/NUCLEO-WB09KE/Examples/UART/UART_Printf; \
    cp $E/STM32CubeIDE/Application/User/syscalls.c $E/STM32CubeIDE/Application/User/sysmem.c /opt/st/cmake/support/; \
    cp Drivers/STM32WB0x_HAL_Driver/Inc/stm32wb0x_hal_conf_template.h /opt/st/cmake/support/conf/stm32wb0x_hal_conf.h; \
    cp $E/Inc/stm32wb0x_nucleo_conf.h /opt/st/cmake/support/conf/; \
    cp $E/Inc/stm32wb0x_nucleo_conf.h /opt/st/cmake/support/conf_bsp/; \
    cp Projects/NUCLEO-WB09KE/Templates_LL/Inc/stm32_assert.h /opt/st/cmake/support/fallback/

# ---------------------------------------------------------------------------
FROM ubuntu:24.04

ARG STM32CUBEWB0_VERSION

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    STM32CUBEWB0=/opt/st/STM32CubeWB0 \
    STM32CUBEWB0_VERSION=${STM32CUBEWB0_VERSION} \
    STM32WB0_CMAKE=/opt/st/cmake \
    ARM_GCC_DIR=/opt/st/gcc \
    PATH=/opt/st/gcc/bin:$PATH

# CMake and Ninja for the builds, python3 for reading ST's STM32CubeIDE project
# files, python3-venv for a venv of your own, poppler-utils for datasheet PDFs
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates git make cmake ninja-build python3 python3-venv poppler-utils \
        less vim-tiny file xxd \
    && rm -rf /var/lib/apt/lists/*

COPY --from=fetch /opt/st /opt/st
COPY scripts/cmake/ /opt/st/cmake/
COPY scripts/templates/ /opt/st/templates/
COPY --chmod=755 scripts/cubeide2cmake.py /opt/st/cmake/cubeide2cmake.py
COPY --chmod=755 scripts/stm32wb0-build /usr/local/bin/stm32wb0-build
COPY --chmod=755 scripts/smoke-test.sh /usr/local/bin/stm32wb0-smoke-test

LABEL org.opencontainers.image.title="stm32cube-wb0" \
      org.opencontainers.image.description="STM32CubeWB0 ${STM32CUBEWB0_VERSION} + Arm GNU Toolchain 14.3.Rel1 + CMake for the NUCLEO-WB09KE (STM32WB09)"

WORKDIR /workdir
CMD ["/bin/bash"]
