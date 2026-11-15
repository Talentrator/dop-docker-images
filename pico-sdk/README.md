# pico-sdk Docker image

The Raspberry Pi **pico-sdk 2.3.1** with **picotool 2.3.1** and the **Arm GNU Toolchain 14.3.Rel1**, CMake
and Ninja, for building Pico firmware headless: the agent box and the grader box of a task for the
**Raspberry Pi Pico 2** (RP2350A: two Cortex-M33 cores at 150 MHz, 520 kB SRAM, 4 MB flash, user LED on
GPIO 25). The RP2040 boards (`pico`, `pico_w`) and the Pico 2 W build too. About **1.1 GB unpacked**.

## Included

| Part | Version | Size | From |
|------|---------|------|------|
| pico-sdk, with TinyUSB (RP2040/RP2350 port only), cyw43-driver, lwIP, btstack, mbedtls | 2.3.1 | 124 MB | GitHub `raspberrypi/pico-sdk` tag, checked against its commit |
| pico-examples | sdk-2.3.1 | 16 MB | GitHub `raspberrypi/pico-examples` tag, checked against its commit |
| picotool (the SDK uses it to make UF2s and add binary info) and pioasm, built here | 2.3.1 | 3 MB | GitHub `raspberrypi/picotool` tag, checked against its commit |
| Arm GNU Toolchain (`arm-none-eabi`), Armv6-M and Armv8-M Mainline libraries only, no GDB | 14.3.Rel1 | 329 MB | developer.arm.com, by sha256 |
| Ubuntu 24.04 + CMake, Ninja, make, git, python3, python3-venv, libusb | 24.04 | the rest | apt |
| `pico-build`, `pico-smoke-test`, `/opt/pico/templates/hello` | | | this folder's `scripts/` |

Environment: `PICO_SDK_PATH=/opt/pico/pico-sdk`, `PICO_EXAMPLES_PATH=/opt/pico/pico-examples`,
`PICO_TOOLCHAIN_PATH=/opt/pico/gcc`, `PICO_BOARD=pico2`, and `picotool_DIR` / `pioasm_DIR`, so the SDK
finds the prebuilt tools instead of fetching and building them. Nothing needs the internet at run time,
and there is no host C/C++ compiler.

## Not included

| Left out | Why |
|----------|-----|
| The RISC-V toolchain | projects build for the RP2350's Arm cores (`rp2350-arm-s`) |
| OpenOCD, GDB | no probe in the box; the bench flashes the board with its own picotool over USB |
| TinyUSB's other MCUs, its examples and docs; btstack's ports and examples; test suites | not used by a Pico build |

## Building a project

```bash
pico-build [-b BOARD] [-o OUT_DIR] [-t BUILD_TYPE] PROJECT [cmake -D options ...]
```

`PROJECT` is a pico-sdk project folder. It is copied to a fresh folder and built there with CMake and
Ninja; the sources are never written to. For each executable, `<target>.uf2`, `.elf`, `.bin`, `.hex`,
`.map` and `.dis` land in `OUT_DIR` (default `./build/<board>`). `BOARD` is a pico-sdk board name
(`pico2` by default); the platform follows from it.

```cmake
cmake_minimum_required(VERSION 3.13)
include($ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)
project(hello C CXX ASM)
pico_sdk_init()
add_executable(hello main.c)
target_link_libraries(hello pico_stdlib)
pico_enable_stdio_usb(hello 1)      # the console: the board's USB port
pico_enable_stdio_uart(hello 0)
pico_add_extra_outputs(hello)       # the .uf2
```

Every build gets `PICO_ENTER_USB_BOOT_ON_EXIT=1`: returning from `main()`, `exit()` or `panic()`
reboots the chip into its USB bootloader instead of halting, so a board on a bench that has no debug
probe can always be flashed again.

## The template

`/opt/pico/templates/hello` prints `hello world` on the USB console, blinks the LED for 10 s (on/off
every 0.5 s, printing `LED on` / `LED off`), prints `done` and idles. It waits for the host to open the
USB serial port before printing, since what is printed before that is lost.

## Smoke test

`pico-smoke-test` builds the template for the Pico 2, pico-examples' `hello_usb`, `blink` and
`pio_blink` (pioasm) for the Pico 2, `picow_blink` for the Pico 2 W (cyw43-driver, lwIP), the template
for the RP2040 Pico (Armv6-M libraries), checks the template's binary info lists `USB stdin / stdout`,
and builds it again with a Python venv first on PATH.

## Local use

```bash
docker build -t pico-sdk .
docker run --rm pico-sdk pico-smoke-test
docker run --rm -v "$PWD/proj":/app -v "$PWD/out":/out pico-sdk pico-build -o /out /app/<project>
picotool load -x -f out/<target>.uf2        # on the host, with the board on USB
```
