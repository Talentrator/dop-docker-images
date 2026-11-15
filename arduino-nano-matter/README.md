# arduino-nano-matter Docker image

**arduino-cli 1.6.0** with Silicon Labs' Arduino core **SiliconLabs:silabs 5.0.0** (its `nano_matter`
variant only), for building sketches for the **Arduino Nano Matter** (ABX00112: MGM240SD22VNA module,
EFR32MG24B210, Cortex-M33, 1536 kB flash) headless: the agent box and the grader box of a task for the
Nano Matter. About **1.5 GB** under `/opt/arduino`, 2.35 GB for the whole image.

## Included

| Part | Version | From |
|------|---------|------|
| SiliconLabs:silabs core, `nano_matter` variant: every protocol stack the board offers (None, Matter, Zigbee, BLE (Arduino), BLE (Silabs)), prebuilt Simplicity SDK libraries, the core's libraries (Matter, SiliconLabs BLE, Wire, SPI, …) and the board's Gecko bootloader | 5.0.0 | arduino-cli, from Silicon Labs' package index |
| gcc-arm-none-eabi | 12.2.rel1 | arduino-cli, as a core dependency |
| arduino-cli | 1.6.0 | GitHub release, by sha256 |
| Ubuntu 24.04 + python3, python3-venv, make, git | 24.04 | apt |
| `nano-matter-build`, `nano-matter-smoke-test` | | this folder's `scripts/` |

arduino-cli is checked against its release sha256; the core and its tools come through arduino-cli,
which checks every archive against the sha256 in Silicon Labs' package index. Builds work with the
network off, and as any user.

## Not included

- The flashers (Silicon Labs' OpenOCD and Simplicity Commander): the board is flashed by the bench
  that holds it, through its on-board SAMD11 CMSIS-DAP.
- The other boards' variants and bootloaders (xG24 Dev Kit, Thing Plus Matter, XIAO MG24, …), each
  50 to 430 MB.

## Building a sketch

```bash
nano-matter-build [-s STACK] [-o OUT_DIR] SKETCH [arduino-cli compile options ...]
```

`SKETCH` is a sketch folder whose main file is named after it (`hello_blink/hello_blink.ino`). It is
copied to a fresh folder and compiled there for `SiliconLabs:silabs:nano_matter:protocol_stack=STACK`,
so the sketch folder is never written to. `STACK` is the core's "Protocol stack" menu: `none` (the
default), `matter`, `zigbee`, `ble_arduino` or `ble_silabs`. `OUT_DIR` (default `./build/nano_matter`)
gets:

| File | What |
|------|------|
| `<name>.hex` | the whole flash image: the board's Gecko bootloader at `0x08000000` and the sketch at `0x08006000`. Flash this one, after a mass erase |
| `<name>.sketch.hex` | the sketch alone, as the Arduino IDE's upload writes it (needs the bootloader already on the chip) |
| `<name>.elf`, `<name>.map` | the sketch's ELF and link map |

On the board, `Serial` is USART0 (PC4/PC5), which the on-board SAMD11 passes to its USB serial port.
The RGB LED is `LEDR`, `LEDG`, `LEDB` (also `LED_BUILTIN`, `LED_BUILTIN_1`, `LED_BUILTIN_2`), lit when
the pin is `LOW` (`LED_BUILTIN_ACTIVE`).

## Smoke test

```bash
docker run --rm --network none arduino-nano-matter nano-matter-smoke-test
```

Builds a Serial + RGB LED sketch with no radio stack, the core's `matter_lightbulb` example (Matter),
its `ble_blinky` example (BLE (Silabs)), and the first one again with a Python venv first on `PATH`;
checks each `.hex` holds both the bootloader and the sketch.
