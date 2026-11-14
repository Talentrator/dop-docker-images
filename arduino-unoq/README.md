# arduino-unoq Docker image

**arduino-cli 1.6.0** with the **arduino:zephyr 0.55.0** core ("Arduino UNO Q Board") and
**ArduinoGraphics 1.1.5**, for building sketches for the **Arduino UNO Q**'s microcontroller
(STM32U585, Cortex-M33) headless: the agent box and the grader box of a task for the UNO Q.
About **1.4 GB unpacked**.

## Included

| Part | Version | Size | From |
|------|---------|------|------|
| `arm-zephyr-eabi` GCC (Zephyr SDK) | 0.16.8 | 894 MB | arduino-cli, from Arduino's package index |
| arduino:zephyr core: UNO Q variant, Zephyr loader image, LLEXT EDK, Arduino_LED_Matrix, Wire, SPI, … | 0.55.0 | 62 MB | arduino-cli |
| Core tools: zephyr-sketch-tool, gen-rodata-ld, sync-zephyr-artifacts, Silicon Labs' OpenOCD (a core dependency) | | 40 MB | arduino-cli |
| Libraries: ArduinoGraphics, and Arduino_RouterBridge (`Bridge`, `Monitor`) with its dependencies | 1.1.5, 0.4.1 | 3 MB | arduino-cli, from Arduino's library index |
| arduino-cli | 1.6.0 | 37 MB | GitHub release, by sha256 |
| Ubuntu 24.04 + python3, python3-venv, make, git | 24.04 | | apt |
| `unoq-build`, `unoq-smoke-test` | | | this folder's `scripts/` |

arduino-cli is checked against its release sha256; the core, its tools and the libraries come through
arduino-cli, which checks every archive against the sha256 in Arduino's indexes. Builds work with the
network off, and as any user.

## Not included

- The upload tools (`adb`, `remoteocd`, `bossac`, `dfu-util`): the UNO Q's microcontroller is flashed by
  OpenOCD on the board's own Linux side, which the bench that holds the board drives.
- The UNO Q's Linux side (QRB2210, Debian): App Lab apps, Python bricks. This image is for the sketch only.

## Building a sketch

```bash
unoq-build [-o OUT_DIR] SKETCH [arduino-cli compile options ...]
```

`SKETCH` is a sketch folder whose main file is named after it (`hashlist/hashlist.ino`). It is copied to a
fresh folder and compiled there for `arduino:zephyr:unoq`, so the sketch folder is never written to.
`OUT_DIR` (default `./build/unoq`) gets:

| File | What |
|------|------|
| `<name>.hex` | the whole flash image: the core's Zephyr loader at `0x08000000` and the sketch in its slot (`0x08100000`). Flash this one, after a mass erase |
| `<name>.sketch.bin` | the sketch alone (`.elf-zsk.bin`), as the core's own upload writes it |
| `<name>.elf`, `<name>.map` | the sketch's ELF and link map |

The sketch is an LLEXT module that the Zephyr loader links and starts at boot, so the loader has to be on the
chip; the `.hex` carries both, so a blank chip runs it. Board options go in the FQBN:
`UNOQ_FQBN=arduino:zephyr:unoq:wait_linux_boot=no unoq-build ...`.

On the board, `Monitor` (and `Serial`) output goes over the MCU's UART to the Linux side's `arduino-router`,
which passes it to the board's USB serial port.

## Smoke test

```bash
docker run --rm --network none arduino-unoq unoq-smoke-test
```

Builds the core's LED matrix example (with ArduinoGraphics), Arduino_RouterBridge's Monitor example, a
sketch scrolling text with ArduinoGraphics, and that one again with a Python venv first on `PATH`; checks
each `.hex` holds both the loader and the sketch.
