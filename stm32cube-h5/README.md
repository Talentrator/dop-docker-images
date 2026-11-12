# stm32cube-h5 Docker image

ST **STM32CubeH5 1.7.0** with the **Arm GNU Toolchain 14.3.Rel1**, CMake and Ninja, for building
STM32H503 firmware headless: the agent box and the grader box of a task for the **NUCLEO-H503RB**
(MB1814, STM32H503RBT6: Cortex-M33 at up to 250 MHz, 128 kB flash, 32 kB RAM). About **1 GB unpacked**.

## Included

| Part | Version | Size | From |
|------|---------|------|------|
| STM32CubeH5, trimmed (below) | 1.7.0 | 107 MB | GitHub `STMicroelectronics/STM32CubeH5` tag, submodules at the commits it pins |
| Arm GNU Toolchain (`arm-none-eabi`), Armv8-M Mainline libraries only, no GDB | 14.3.Rel1 | 282 MB | developer.arm.com |
| Ubuntu 24.04 + CMake, Ninja, make, git, python3, python3-venv, poppler-utils | 24.04 | the rest | apt |
| `stm32h5-build`, `stm32h5-smoke-test`, `$STM32H5_CMAKE/stm32h5.cmake`, `/opt/st/templates/hello` | | | this folder's `scripts/` |

Of STM32CubeH5, at `$STM32CUBEH5` (`/opt/st/STM32CubeH5`):

| Part | Where |
|------|-------|
| CMSIS Core, RTOS2 headers, STM32H5 device headers, startup files, GCC linker scripts | `Drivers/CMSIS` |
| HAL and LL drivers | `Drivers/STM32H5xx_HAL_Driver` |
| NUCLEO BSP (`BSP_LED_*`, `BSP_PB_*`, `BSP_COM_*`) | `Drivers/BSP/STM32H5xx_Nucleo` |
| ThreadX (Cortex-M33 port), its CMSIS-RTOS2 wrapper, USBX (device side) | `Middlewares/ST` |
| Every NUCLEO-H503RB example, LL example, mixed example, template and application, in their STM32CubeIDE layout | `Projects/NUCLEO-H503RB` |

Every download is checked against its sha256.

## Not included

| Left out | Why |
|----------|-----|
| Other boards' projects and BSPs, IAR (`EWARM`) and Keil (`MDK-ARM`) project files | the NUCLEO-H503RB only, with GCC |
| Root-of-trust projects (`ROT_Provisioning`, `Templates_ROT`, `Applications/ROT`), mcuboot, mbed-crypto | they need ST's provisioning tools and a key-provisioned chip |
| NetX Duo, FileX, LevelX, USB-PD, OpenBootloader, CMSIS DSP/NN | the H503 has no Ethernet, no SD; not used by its projects |
| GCC libraries for every core but Armv8-M Mainline, GDB | the STM32H5 is a Cortex-M33, and there is no probe in the box |
| STM32CubeMX, STM32CubeProgrammer, STM32CubeCLT | ST serves them behind a login. Nothing in a build needs them; the bench flashes the kit with probe-rs |

## Building a project

```bash
stm32h5-build [-o OUT_DIR] [-t BUILD_TYPE] PROJECT [cmake -D options ...]
```

`PROJECT` is a folder. It is copied to a fresh folder and built there with CMake and Ninja; the sources
are never written to. `NAME.elf`, `.hex`, `.bin` and `.map` land in `OUT_DIR` (default `./build`).
`BUILD_TYPE` is `Release` (`-Os -g`, the default) or `Debug` (`-Og -g3`).

**With a `CMakeLists.txt`**, it is built as it is. `stm32h5_firmware()` does the board's part:

```cmake
cmake_minimum_required(VERSION 3.22)
project(hello C ASM)
include($ENV{STM32H5_CMAKE}/stm32h5.cmake)
stm32h5_firmware(hello
  SOURCES Src/main.c
  INCLUDES Inc)          # options: DEFINES, LINKER_SCRIPT, BSP, THREADX, CMSIS_RTOS2, LL, NO_HAL
```

It adds the CMSIS startup file and `system_stm32h5xx.c`, ST's newlib stubs (`_write()` sends each
byte to `__io_putchar()`, which the project must define to reach a UART), all HAL/LL sources (a
module builds only when its `HAL_*_MODULE_ENABLED` is set in `stm32h5xx_hal_conf.h`), a default
`stm32h5xx_hal_conf.h` (every module on) when the project has none, and CMSIS's
`STM32H503xx_FLASH.ld`. A project's own startup, system file, syscalls or linker script win. See
[`scripts/cmake/stm32h5.cmake`](scripts/cmake/stm32h5.cmake).

**Without one**, the folder is taken as an ST example (`Src/`, `Inc/`, `STM32CubeIDE/*.ld`, `syscalls.c`)
and built as it is, with ThreadX, CMSIS-RTOS2, the BSP and LL turned on when its sources include them:

```bash
cp -r $STM32CUBEH5/Projects/NUCLEO-H503RB/Examples/GPIO/GPIO_IOToggle /workdir/app
stm32h5-build /workdir/app                     # -> /workdir/build/GPIO_IOToggle.hex
```

`/opt/st/templates/hello` is a minimal project: `printf` over the ST-LINK virtual COM port and a
blinking LED.

## The NUCLEO-H503RB

| | |
|---|---|
| Console | USART3, TX PA4 / RX PA3, AF13, through the ST-LINK V3EC's virtual COM port. The bench reads it at 115200 8N1 (ST's `UART_Printf` example uses 7 bits + odd parity) |
| User LED | LD2, green, PA5, active high |
| User button | B1, PC13, active high (pressed = 1) |
| Clock | 32 MHz from HSI at reset (`SystemCoreClock`); ST's examples run the PLL from the 24 MHz ST-LINK MCO (HSE bypass) to 250 MHz |
| Flashing | not in the image. The bench flashes `.hex`, `.elf` or `.bin` with probe-rs |

## Smoke test

```bash
docker run --rm ghcr.io/talentrator/dop-docker-images/stm32cube-h5:latest stm32h5-smoke-test
```

It builds the hello template, ST's `UART_Printf`, `GPIO_IOToggle`, LL `USART_Communication_Tx_VCP_Init`
and the ThreadX `Tx_CMSIS_Wrapper` application, then hello again with a Python venv first on PATH, and
exits non-zero on any failure.

## Build

```bash
docker build -t stm32cube-h5 .
```

CI builds it natively for `linux/amd64` and `linux/arm64` and publishes
`ghcr.io/talentrator/dop-docker-images/stm32cube-h5:{latest,1.7.0,sha-<short>}`. In DOP, use the
multi-arch index digest from the run summary.
