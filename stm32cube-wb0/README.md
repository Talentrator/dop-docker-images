# stm32cube-wb0 Docker image

ST **STM32CubeWB0 1.5.0** with the **Arm GNU Toolchain 14.3.Rel1**, CMake and Ninja, for building
STM32WB09 firmware headless: the agent box and the grader box of a task for the **NUCLEO-WB09KE**
(MB2032, STM32WB09KEV6: Cortex-M0+ at up to 64 MHz, 512 kB flash, 64 kB RAM, Bluetooth LE 5.4). About
**0.9 GB unpacked**.

## Included

| Part | Version | Size | From |
|------|---------|------|------|
| STM32CubeWB0, trimmed (below) | 1.5.0 | 83 MB | GitHub `STMicroelectronics/STM32CubeWB0` tag, submodules at the commits it pins |
| Arm GNU Toolchain (`arm-none-eabi`), Armv6-M libraries only, no GDB | 14.3.Rel1 | 213 MB | developer.arm.com |
| Ubuntu 24.04 + CMake, Ninja, make, git, python3, python3-venv, poppler-utils | 24.04 | the rest | apt |
| `stm32wb0-build`, `stm32wb0-smoke-test`, `$STM32WB0_CMAKE/stm32wb0.cmake`, `/opt/st/templates/hello` | | | this folder's `scripts/` |

Of STM32CubeWB0, at `$STM32CUBEWB0` (`/opt/st/STM32CubeWB0`):

| Part | Where |
|------|-------|
| CMSIS Core, RTOS2 headers, STM32WB0x device headers, GCC startup files and linker scripts | `Drivers/CMSIS` |
| HAL and LL drivers (radio and radio timer included) | `Drivers/STM32WB0x_HAL_Driver` |
| NUCLEO BSP (`BSP_LED_*`, `BSP_PB_*`, `BSP_COM_*`) | `Drivers/BSP/STM32WB0x-nucleo` |
| STM32_BLE: the prebuilt BLE stack libraries, cryptolib, event handler, queued writes | `Middlewares/ST/STM32_BLE` |
| FreeRTOS (Cortex-M0 GCC port) and its CMSIS-RTOS2 wrapper | `Middlewares/Third_Party/FreeRTOS` |
| Sequencer, tiny LPM, advanced trace, misc | `Utilities` |
| The BLE applications' shared modules (NVM DB, PKA manager, profiles, flash manager ...) | `Projects/Common/BLE` |
| Every NUCLEO-WB09KE example, LL example, application, demonstration and template, in their STM32CubeIDE layout | `Projects/NUCLEO-WB09KE` |

Every download is checked against its sha256.

## Not included

| Left out | Why |
|----------|-----|
| The NUCLEO-WB05KZ and NUCLEO-WB07CC projects, IAR (`EWARM`) and Keil (`MDK-ARM`) project files, prebuilt `Binary/` images | the NUCLEO-WB09KE only, with GCC |
| FatFs, Windows PC tools (`Utilities/PC_Software`, `create_sym_lib.exe`), CMSIS DSP/NN, ARM/IAR startups | not used by any NUCLEO-WB09KE project, or not for Linux/GCC |
| FreeRTOS ports for other cores | the STM32WB09 is a Cortex-M0+ |
| GCC libraries for every core but Armv6-M, GDB | no probe in the box |
| STM32CubeMX, STM32CubeProgrammer, STM32CubeCLT | ST serves them behind a login. Nothing in a build needs them; the bench flashes the kit with probe-rs |

## Building a project

```bash
stm32wb0-build [-o OUT_DIR] [-t BUILD_TYPE] PROJECT [cmake -D options ...]
```

`PROJECT` is a folder. It is copied to a fresh folder and built there with CMake and Ninja; the sources
are never written to. `NAME.elf`, `.hex`, `.bin` and `.map` land in `OUT_DIR` (default `./build`).
`BUILD_TYPE` is `Release` (`-Os -g`, the default) or `Debug` (`-Og -g3`).

**With a `CMakeLists.txt`**, it is built as it is. `stm32wb0_firmware()` does the board's part:

```cmake
cmake_minimum_required(VERSION 3.22)
project(hello C ASM)
include($ENV{STM32WB0_CMAKE}/stm32wb0.cmake)
stm32wb0_firmware(hello
  SOURCES Src/main.c
  INCLUDES Inc)          # options: DEFINES, LIBS, LINKER_SCRIPT, BSP, BLE, FREERTOS, LL, NO_HAL, RAW
```

It adds the CMSIS startup file and `system_stm32wb0x.c`, ST's newlib stubs (`_write()` sends each
byte to `__io_putchar()`, which the project must define to reach a UART), all HAL/LL sources (a
module builds only when its `HAL_*_MODULE_ENABLED` is set in `stm32wb0x_hal_conf.h`), a default
`stm32wb0x_hal_conf.h` (every module on) when the project has none, and CMSIS's `stm32wb09_flash.ld`.
A project's own startup, system file, syscalls or linker script win. See
[`scripts/cmake/stm32wb0.cmake`](scripts/cmake/stm32wb0.cmake).

**With an `STM32CubeIDE/.project` and `.cproject`** (every ST example), its Release configuration is
built as STM32CubeIDE would: the same linked sources, include folders, defines, libraries (the BLE
stack) and linker script, read by [`scripts/cubeide2cmake.py`](scripts/cubeide2cmake.py). Paths into the
SDK are found again when the example has been copied out of it:

```bash
cp -r $STM32CUBEWB0/Projects/NUCLEO-WB09KE/Applications/BLE/BLE_p2pServer /workdir/app
stm32wb0-build /workdir/app                    # -> /workdir/build/app.hex
```

128 of the 141 NUCLEO-WB09KE projects build this way. The other 13 (`BLE_ESL`, `BLE_ESL_AP`,
`BLE_StaticStack*`, `BLE_p2pServer_StaticStack*`, `BLE_p2pServer_FreeRTOS`, `BLE_TransparentMode_SPI*`,
`BLE_TransparentMode_*Updater*`) refer to folders or settings that ST's GitHub release doesn't ship
(`System/Modules`, a WB05 linker script, `RESET_MANAGER_SIZE`), so they don't build in STM32CubeIDE
from this tree either.

**With neither**, every `.c`/`.s` under the folder is built with the HAL and the BSP, plus LL, the
BLE stack or FreeRTOS when its sources include them.

`/opt/st/templates/hello` is a minimal project: `printf` over the ST-LINK virtual COM port and a
blinking LED, at 64 MHz.

## The NUCLEO-WB09KE

| | |
|---|---|
| Console | USART1, TX PA1 (AF2) / RX PB0 (AF0), through the STLINK-V3's virtual COM port, 115200 8N1 (ST's `UART_Printf` example uses 7 bits + odd parity) |
| User LEDs | LD1 blue PB1, LD2 green PB4, LD3 red PB2, active low |
| User buttons | B1 PA0, B2 PB5, B3 PB14, pressed reads 0 |
| Clock | 16 MHz from the HSI at reset (`SystemCoreClock`); ST's projects run 64 MHz from the 32 MHz HSE through the RC64MPLL, with the SMPS on |
| Flash | 512 kB at 0x10040000 |
| Flashing | not in the image. The bench flashes `.hex`, `.elf` or `.bin` with probe-rs (`--chip STM32WB09KE`) |

## Smoke test

```bash
docker run --rm ghcr.io/talentrator/dop-docker-images/stm32cube-wb0:latest stm32wb0-smoke-test
```

It builds the hello template, ST's `UART_Printf`, `GPIO_IOToggle`, LL `USART_Communication_Tx_IT_Init`,
the `FreeRTOS_Mutex` application, `RADIO_Beep`, the `BLE_p2pServer` and `BLE_HeartRate` applications
(the prebuilt BLE stack and cryptolib), `BLE_Beacon` copied out of the SDK, then hello and `UART_Printf`
again with a Python venv first on PATH, and exits non-zero on any failure.

## Build

```bash
docker build -t stm32cube-wb0 .
```

CI builds it natively for `linux/amd64` and `linux/arm64` and publishes
`ghcr.io/talentrator/dop-docker-images/stm32cube-wb0:{latest,1.5.0,sha-<short>}`. In DOP, use the
multi-arch index digest from the run summary.
