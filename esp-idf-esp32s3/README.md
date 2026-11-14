# esp-idf-esp32s3 Docker image

**ESP-IDF v5.5.6** for the **ESP32-S3**, for building firmware for the **Adafruit Feather ESP32-S3
Reverse TFT** (product 5691: ESP32-S3, 4 MB flash, 2 MB PSRAM, 240x135 ST7789 TFT) headless: the agent
box and the grader box of a task for that board. About **2.0 GB unpacked**.

## Included

| Part | Version | Size | From |
|------|---------|------|------|
| ESP-IDF, with its submodules and examples (no docs, no git history) | v5.5.6 (`880a203a`) | 452 MB | git tag, checked against its commit |
| `xtensa-esp-elf` GCC (`xtensa-esp32s3-elf-*`) | esp-14.2.0_20260121 | ~1 GB | `idf_tools.py`, sha256 from the release's `tools/tools.json` |
| `esp-rom-elfs` (ROM symbols for panic backtraces) | 20260528 | | `idf_tools.py` |
| IDF's Python env (`idf.py`, `esptool.py`, kconfgen, ...) | | 94 MB | `idf_tools.py install-python-env` |
| Ubuntu 24.04 + cmake, ninja, python3, python3-venv, git, make | 24.04 | | apt |
| `esp32s3-build`, `esp32s3-smoke-test`, templates `hello` and `tft` | | | this folder's `scripts/` |

The Wi-Fi, PHY, coexistence and Bluetooth controller blobs of the other chips are removed; the
ESP32-S3's stay (Wi-Fi and NimBLE build). Builds work with the network off, and as any user.

## Not included

- OpenOCD, GDB, the ULP toolchains (`riscv32-esp-elf`, `esp32ulp-elf`): the board is flashed by the
  bench that holds it, with esptool over its USB Serial/JTAG.
- Components from the ESP component registry: DOP boxes run with the internet off, so a project's
  `idf_component.yml` dependencies (lvgl, esp_jpeg, ...) can't be fetched. That includes most of IDF's
  own LCD examples; `esp_lcd` itself, with its ST7789 driver, is here.

## Building a project

```bash
esp32s3-build [-o OUT_DIR] PROJECT [idf.py options ...]
```

`PROJECT` is an ESP-IDF project folder. It is copied to a fresh folder and built there with
`idf.py set-target esp32s3 build`, so the project folder is never written to (a `build/` or `sdkconfig`
in it is ignored: settings go in `sdkconfig.defaults`). `OUT_DIR` (default `./build/esp32s3`) gets:

| File | What |
|------|------|
| `<name>.bin` | the whole flash image: bootloader, partition table and app, merged from `0x0`. Flash this one at `0x0` |
| `<name>.app.bin` | the app alone |
| `<name>.elf`, `<name>.map` | the app's ELF and link map |
| `flash_args` | what `idf.py flash` would write, for `esptool.py write_flash @flash_args` |

It runs IDF's own Python first on `PATH`, so it works with another venv active (a grader's pytest venv).

## The board

Templates in `/opt/esp/templates`:
- `hello`: prints on the console once a second;
- `tft`: powers the TFT and fills it with colors through `esp_lcd`.

Both set the console to the USB-C port (`CONFIG_ESP_CONSOLE_USB_SERIAL_JTAG=y`); UART0 isn't wired to
USB on the Feather.

TFT: ST7789, 135x240 native. SPI on MOSI GPIO35 and SCK GPIO36; CS GPIO42, DC GPIO40, RST GPIO41;
backlight GPIO45; TFT power GPIO7 (`TFT_I2C_POWER`, drive it high first). In landscape (swap_xy and
mirror y, Adafruit's `setRotation(3)`) the window sits at gap x 40, y 53, with color inversion on.

## Smoke test

```bash
docker run --rm --network none esp-idf-esp32s3 esp32s3-smoke-test
```

Builds the `hello` and `tft` templates, IDF's `hello_world`, the Wi-Fi station example (links the Wi-Fi
and PHY blobs) and the NimBLE peripheral (the BLE controller), then `hello` again with a Python venv
first on `PATH`.
