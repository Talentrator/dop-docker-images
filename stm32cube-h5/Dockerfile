# syntax=docker/dockerfile:1.7
#
# STM32CubeH5 image for STM32H503 firmware, built headless with CMake and the
# Arm GNU Toolchain: the agent box and the grader box of a task for the ST
# NUCLEO-H503RB (MB1814, STM32H503RBT6, Cortex-M33, 128 kB flash, 32 kB RAM).
#   SDK     : STM32CubeH5 1.7.0: CMSIS, the HAL and LL drivers, the NUCLEO BSP,
#             ThreadX + its CMSIS-RTOS2 wrapper, USBX (device side), and the
#             NUCLEO-H503RB examples and applications (STM32CubeIDE layout)
#   Tools   : Arm GNU Toolchain 14.3.Rel1 (Armv8-M libraries only), CMake,
#             Ninja, and stm32h5-build, which builds a project folder for the
#             board, either a CMakeLists.txt that calls stm32h5_firmware() or
#             an ST example folder as it is
#   Arches  : linux/arm64 and linux/amd64
#
# STM32CubeH5 comes from ST's GitHub repository at its v1.7.0 tag, with the
# driver and middleware submodules at the commits that tag pins; the compiler
# from developer.arm.com. Each file is checked against its sha256.
#
# Not in it: STM32CubeMX and STM32CubeProgrammer (ST serves them behind a
# login), and no debug probe tools: the bench that flashes the kit has its own
# (probe-rs). Nothing here needs the internet at run time.
#
# Build (native): docker build -t stm32cube-h5 .

# Declared once, before any stage: the publish workflow reads the version tag from this line
ARG STM32CUBEH5_VERSION=1.7.0

FROM ubuntu:24.04 AS fetch

ARG TARGETARCH
ARG STM32CUBEH5_VERSION
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
    # the STM32H5 is a Cortex-M33: of the multilibs, only Armv8-M Mainline's
    for d in arm-none-eabi/lib/thumb lib/gcc/arm-none-eabi/*/thumb; do \
      find "$d" -mindepth 1 -maxdepth 1 -type d ! -name 'v8-m.main*' -exec rm -rf {} +; \
    done; \
    rm -rf arm-none-eabi/lib/arm lib/gcc/arm-none-eabi/*/arm share/doc share/info share/man share/gdb \
           bin/arm-none-eabi-gdb* bin/arm-none-eabi-lto-dump libexec/gcc/arm-none-eabi/*/f951 \
           arm-none-eabi/include/c++/*/experimental lib/python* include/gdb

# STM32CubeH5 and the submodules it needs, at the commits v1.7.0 pins
#   sub PATH REPO COMMIT SHA256: fetch one submodule into the tree
RUN set -eux; \
    get https://github.com/STMicroelectronics/STM32CubeH5/archive/refs/tags/v${STM32CUBEH5_VERSION}.tar.gz \
        cf35d2578a13ebf583f3ae50dea538321c3f748cfe0976b7a4efcda06b1c9a46 cube.tgz; \
    mkdir -p /opt/st/STM32CubeH5; \
    tar -xzf cube.tgz --strip-components=1 -C /opt/st/STM32CubeH5; \
    rm cube.tgz; \
    cd /opt/st/STM32CubeH5; \
    sub() { get https://github.com/STMicroelectronics/$2/archive/$3.tar.gz $4 s.tgz; \
            rm -rf "$1"; mkdir -p "$1"; tar -xzf s.tgz --strip-components=1 -C "$1"; rm s.tgz; }; \
    sub Drivers/CMSIS/Device/ST/STM32H5xx    cmsis_device_h5        884b8dc78e41cbfca008363342b17f4a9e8641f7 2635c4966ed9cb025aebe030d62e38972ae98ed362aa23cb8648cd21eabce909; \
    sub Drivers/STM32H5xx_HAL_Driver         stm32h5xx_hal_driver   56e28dbebd720e3df2866dfaf438b525e9e8af04 44e9db5bf7571745869b18ca7a80e03136595f96e962eb746571f7aa4440c065; \
    sub Drivers/BSP/STM32H5xx_Nucleo         stm32h5xx-nucleo-bsp   7122a2c59e3da6fafc7c7c50b492dca26794d275 192ebf307790abcc09cbfd74212656a9c803e7cc39656c9f64583fe93e728f2e; \
    sub Middlewares/ST/threadx               stm32-mw-threadx       b44bdbbbb5a9e4fb56728d2932236564c89db29a c0acdc5bf511d7b9a13d7290fd23e97e6fb42592e031eeb499979d3a7bd79c80; \
    sub Middlewares/ST/cmsis_rtos_threadx    stm32-mw-cmsis-rtos-tx 3b0b28a45c6eca4daaf6d640fefaa7a67aeead54 90f593517f0d178fd1a197eb4e2c431c1faa290cf3db37a682c05a0161535d55; \
    sub Middlewares/ST/usbx                  stm32-mw-usbx          9c353dc0767254d75ff6a11b29fad87f7d86502d 46825e12e35e563a3cfc952ad269c066e84e7b384adf658a6133e4ec54469c3b; \
    # only the NUCLEO-H503RB's projects, without their IAR/Keil copies or the
    # root-of-trust ones (they need mcuboot and ST's provisioning tools)
    find Projects -mindepth 1 -maxdepth 1 ! -name NUCLEO-H503RB -exec rm -rf {} +; \
    find Projects -type d \( -name EWARM -o -name MDK-ARM \) -prune -exec rm -rf {} +; \
    rm -rf Projects/NUCLEO-H503RB/ROT_Provisioning Projects/NUCLEO-H503RB/Templates_ROT Projects/NUCLEO-H503RB/Applications/ROT; \
    # other boards' BSPs, middleware without its submodule, CMSIS parts for other cores
    find Drivers/BSP -mindepth 1 -maxdepth 1 ! -name STM32H5xx_Nucleo -exec rm -rf {} +; \
    find Middlewares/ST -mindepth 1 -maxdepth 1 ! -name threadx ! -name cmsis_rtos_threadx ! -name usbx -exec rm -rf {} +; \
    rm -rf Middlewares/Third_Party Utilities Documentations _htmresc \
           Drivers/CMSIS/DSP Drivers/CMSIS/NN Drivers/CMSIS/Core_A Drivers/CMSIS/DAP Drivers/CMSIS/Documentation; \
    find Middlewares/ST/threadx/ports -mindepth 1 -maxdepth 1 ! -name cortex_m33 -exec rm -rf {} +; \
    rm -rf Middlewares/ST/threadx/docs Middlewares/ST/threadx/samples Middlewares/ST/threadx/test Middlewares/ST/threadx/utility \
           Middlewares/ST/usbx/docs Middlewares/ST/usbx/samples Middlewares/ST/usbx/test \
           Middlewares/ST/usbx/common/usbx_host_* Middlewares/ST/usbx/common/usbx_pictbridge \
           Middlewares/ST/usbx/common/usbx_stm32_host_controllers; \
    find . \( -name '*.chm' -o -name '*.pdf' -o -name '_htmresc' \) -prune -exec rm -rf {} +; \
    # the fallbacks stm32h5_firmware() adds: ST's newlib stubs and the template's config headers
    mkdir -p /opt/st/cmake/support/conf /opt/st/cmake/support/conf_bsp; \
    cp Projects/NUCLEO-H503RB/Examples/UART/UART_Printf/STM32CubeIDE/Application/User/syscalls.c \
       Projects/NUCLEO-H503RB/Examples/UART/UART_Printf/STM32CubeIDE/Application/User/sysmem.c /opt/st/cmake/support/; \
    cp Projects/NUCLEO-H503RB/Templates/Inc/stm32h5xx_hal_conf.h Projects/NUCLEO-H503RB/Templates/Inc/stm32h5xx_nucleo_conf.h \
       /opt/st/cmake/support/conf/; \
    cp Projects/NUCLEO-H503RB/Templates/Inc/stm32h5xx_nucleo_conf.h /opt/st/cmake/support/conf_bsp/

# ---------------------------------------------------------------------------
FROM ubuntu:24.04

ARG STM32CUBEH5_VERSION

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    STM32CUBEH5=/opt/st/STM32CubeH5 \
    STM32CUBEH5_VERSION=${STM32CUBEH5_VERSION} \
    STM32H5_CMAKE=/opt/st/cmake \
    ARM_GCC_DIR=/opt/st/gcc \
    PATH=/opt/st/gcc/bin:$PATH

# CMake and Ninja for the builds, python3-venv for a venv of your own,
# poppler-utils for datasheet PDFs
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates git make cmake ninja-build python3 python3-venv poppler-utils \
        less vim-tiny file xxd \
    && rm -rf /var/lib/apt/lists/*

COPY --from=fetch /opt/st /opt/st
COPY scripts/cmake/ /opt/st/cmake/
COPY scripts/templates/ /opt/st/templates/
COPY --chmod=755 scripts/stm32h5-build /usr/local/bin/stm32h5-build
COPY --chmod=755 scripts/smoke-test.sh /usr/local/bin/stm32h5-smoke-test

LABEL org.opencontainers.image.title="stm32cube-h5" \
      org.opencontainers.image.description="STM32CubeH5 ${STM32CUBEH5_VERSION} + Arm GNU Toolchain 14.3.Rel1 + CMake for the NUCLEO-H503RB (STM32H503)"

WORKDIR /workdir
CMD ["/bin/bash"]
