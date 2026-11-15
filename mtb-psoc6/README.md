# mtb-psoc6 Docker image

Infineon's **ModusToolbox libraries** for the **CY8CKIT-062S2-AI** (PSoC 62S2 AI Evaluation Kit,
CY8C624ABZI-S2D44: Cortex-M4F at 150 MHz + Cortex-M0+, 2 MB flash, 1 MB SRAM) with the **Arm GNU
Toolchain 14.3.Rel1** and Ninja, for building PSoC 6 firmware headless: the agent box and the grader
box of a task for that kit. About **0.9 GB unpacked**.

It is not the ModusToolbox tools package. That is Linux x86_64 only and Infineon serves it behind a
login, so it can't go into a multi-arch image. Everything a build needs is open source on Infineon's
GitHub. `psoc6-build` stands in for ModusToolbox's make flow.

## Included

| Part | Version | From |
|------|---------|------|
| BSP `TARGET_CY8CKIT-062S2-AI` | 5.0.1 | GitHub `Infineon/TARGET_CY8CKIT-062S2-AI` |
| BSP generated configuration (`config/GeneratedSource`: `cycfg_pins.h`, clocks, peripherals…) | Device Configurator 3.60, for PDL 3.19.0 | GitHub `Infineon/arduino-core-psoc6` 1.1.0, `variants/CY8CKIT-062S2-AI` (same `design.modus` as BSP 5.0.1) |
| `mtb-pdl-cat1` (PDL) | 3.19.0 | GitHub `Infineon/mtb-pdl-cat1` |
| `mtb-hal-cat1` (HAL) | 2.7.4 | GitHub |
| `core-lib`, `cmsis`, `cat1cm0p` (CM0+ sleep image), `retarget-io` | 1.6.0, 6.1.0, 1.9.0, 1.9.0 | GitHub |
| `freertos`, `abstraction-rtos`, `clib-support` | 10.6.202, 1.12.0, 1.8.0 | GitHub |
| Code examples: `hal-hello-world`, `hal-gpio-interrupt`, `hal-uart-transmit-receive`, `hal-pwm-square-wave` | 4.10.0, 3.4.0, 3.5.0, 3.4.0 | GitHub `Infineon/mtb-example-*` |
| Arm GNU Toolchain (`arm-none-eabi`), Armv7E-M libraries only, no GDB | 14.3.Rel1 | developer.arm.com |
| `psoc6-build`, `psoc6-smoke-test`, templates `blinky` and `blinky_freertos`, a stand-in `start.mk` | | this folder's `scripts/` |

The library set is the one Infineon's Arduino core 1.1.0 pins (its generated BSP code matches PDL
3.19.0). Every download is checked against its sha256. Libraries are in `$MTB_LIBS`
(`/opt/mtb/libs`), examples in `/opt/mtb/examples`, templates in `/opt/mtb/templates`.

## Not included

| Left out | Why |
|----------|-----|
| ModusToolbox tools package: Device Configurator, BSP Assistant, Library Manager, project-creator, OpenOCD | Linux x86_64 only, behind an Infineon login. Pins and clocks come from the BSP's generated code; change them at run time with the HAL/PDL |
| Wi-Fi and Bluetooth stacks (WHD, lwIP, btstack), CAPSENSE, emWin, ML libraries | not used by a console/LED task; the radio needs firmware blobs |
| Other chips' PDL device headers, CAT1B/C/D, IAR/Arm/LLVM toolchain files, CMSIS-NN, docs | the CY8C624ABZI-S2D44 with GCC only |
| GCC libraries for every core but Armv7E-M, GDB | the application core is a Cortex-M4F, and there is no probe in the box |

## Building an application

```bash
psoc6-build [-o OUT_DIR] [-c Debug|Release] [-v] PROJECT
```

`PROJECT` is a folder laid out like a ModusToolbox code example: sources anywhere under it and,
optionally, a ModusToolbox `Makefile`. It is copied to a fresh folder and built there with Ninja; the
sources are never written to. `APPNAME.elf`, `.hex`, `.bin` and `.map` land in `OUT_DIR`
(default `./build`).

- Sources are found as ModusToolbox finds them: every `.c/.cpp/.S/.s` and every folder with headers,
  skipping `COMPONENT_X`, `TOOLCHAIN_X`, `TARGET_X` and `CONFIG_X` folders whose `X` is not in the
  build, and whatever a `.cyignore` lists. `build/`, `deps/`, `libs/` and `bsps/` are skipped.
- From the Makefile it reads `APPNAME`, `CONFIG` (default `Debug`), `COMPONENTS`,
  `DISABLE_COMPONENTS`, `DEFINES`, `SOURCES`, `INCLUDES`, `VFP_SELECT`, `CFLAGS`, `CXXFLAGS`,
  `ASFLAGS`, `LDFLAGS`, `LDLIBS` and `LINKER_SCRIPT`. `TARGET` is always `CY8CKIT-062S2-AI`; `CORE`
  must be CM4 (the CM0+ runs the prebuilt sleep image).
- Libraries: the BSP, PDL, HAL, core-lib, cmsis, cat1cm0p and retarget-io always; freertos,
  abstraction-rtos and clib-support when `COMPONENTS` has `FREERTOS` (put a `FreeRTOSConfig.h` in the
  project, e.g. the one in `/opt/mtb/templates/blinky_freertos`). A project's `deps/*.mtb` files are
  ignored: there is nothing to fetch.
- Flags match ModusToolbox's GCC_ARM recipe: `-mcpu=cortex-m4 -mfloat-abi=softfp -mfpu=fpv4-sp-d16
  --specs=nano.specs`, `-Og -DDEBUG` or `-Os -DNDEBUG`, the `COMPONENT_*`, `TARGET_*`, `CY_USING_HAL`
  and device defines, and the BSP's `linker.ld`.

`make build` also works in a code example: `CY_TOOLS_PATHS=/opt/mtb/tools_3.0` points its Makefile at
a stand-in `start.mk` that calls `psoc6-build -o build/<TARGET>/<CONFIG> .`.

```bash
cp -r /opt/mtb/templates/blinky /workdir/blinky
psoc6-build /workdir/blinky          # -> ./build/blinky.hex
```

## The CY8CKIT-062S2-AI

| | |
|---|---|
| Console | `CYBSP_DEBUG_UART_TX/RX` = P5_1/P5_0 (SCB5), through KitProg3's USB-UART. `cy_retarget_io_init(CYBSP_DEBUG_UART_TX, CYBSP_DEBUG_UART_RX, CY_RETARGET_IO_BAUDRATE)` routes `printf` there at 115200 8N1 |
| User LEDs | `CYBSP_USER_LED1` (= `CYBSP_USER_LED`) P5_3 and `CYBSP_USER_LED2` P5_4; on = `CYBSP_LED_STATE_ON` (1, active high) |
| User button | `CYBSP_USER_BTN` (SW12); pressed = `CYBSP_BTN_PRESSED` (0) |
| Clock | CM4 at 150 MHz after `cybsp_init()` (the BSP's generated clocks) |
| Flash layout | CM0+ sleep image at 0x10000000, CM4 application from 0x10002000 |
| Flashing | not in the image. The bench flashes the `.hex` with Infineon's OpenOCD through KitProg3 |

## Smoke test

```bash
docker run --rm ghcr.io/talentrator/dop-docker-images/mtb-psoc6:latest psoc6-smoke-test
```

It builds both templates and the four code examples as they are, runs `make build` in a code example,
then builds blinky again with a Python venv first on PATH, and exits non-zero on any failure.

## Build

```bash
docker build -t mtb-psoc6 .
```

CI builds it natively for `linux/amd64` and `linux/arm64` and publishes
`ghcr.io/talentrator/dop-docker-images/mtb-psoc6:{latest,3.19.0,sha-<short>}`. In DOP, use the
multi-arch index digest from the run summary.
