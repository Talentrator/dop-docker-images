# esp-idf-atoms3r Docker image

**ESP-IDF v5.5.6** for the **M5Stack AtomS3R** (C126: ESP32-S3-PICO-1-N8R8, 8 MB flash, 8 MB octal PSRAM,
0.85" 128x128 GC9107 LCD) on an **Atomic Echo Base** (A149: ES8311 codec, MEMS mic, NS4150B amp, 1 W
speaker), for building its firmware headless: the agent box and the grader box of a task for that board.
About **2.6 GB unpacked** (the `esp-idf-esp32s3` image plus under 1 MB).

## Included

| Part | Version | From |
|------|---------|------|
| Everything in [`esp-idf-esp32s3`](../esp-idf-esp32s3): ESP-IDF, the `xtensa-esp32s3-elf` GCC, IDF's Python env, `esp32s3-build` | v5.5.6 | `FROM` that image, pinned by digest |
| `esp_codec_dev` (Espressif's codec drivers: ES8311 and others), as an IDF component in `$IDF_PATH/components` | 1.6.2 | ESP component registry, sha256-pinned zip |
| `atoms3r-build`, `atoms3r-smoke-test`, the board's `sdkconfig.board`, templates `hello`, `lcd`, `echo` | | this folder's `scripts/` |

Builds work with the network off, and as any user. `esp_codec_dev` lives with IDF's own components, so a
project gets it with `REQUIRES esp_codec_dev`, from `atoms3r-build` or plain `idf.py`, without the
component manager.

## Building a project

```bash
atoms3r-build [-o OUT_DIR] PROJECT [idf.py options ...]
```

`esp32s3-build` with the board's defaults (`/opt/esp/atoms3r/sdkconfig.board`: 8 MB flash, console on the
USB-C port's USB Serial/JTAG) placed before the project's own `sdkconfig.defaults`, which wins where they
differ. The project folder is never written to. `OUT_DIR` (default `./build/atoms3r`) gets `<name>.bin`
(bootloader + partition table + app, merged; flash it at `0x0`), `<name>.app.bin`, `<name>.elf`,
`<name>.map` and `flash_args`.

## The board

Checked on a real AtomS3R + Echo Base (the bench's, MAC `98:88:e0:0f:32:d4`):

- **LCD:** GC9107 (RDDID `00 91 07`), 128x128 visible in a 128x160 RAM from row 32. SPI MOSI GPIO21,
  SCK GPIO15, CS GPIO14, DC GPIO42, RST GPIO48, no MISO. MADCTL `0x08` (BGR) is upright with USB-C down.
  ESP-IDF has no GC9107 driver: the `lcd` template sends its init sequence through `esp_lcd`'s panel IO.
  M5Stack builds AtomS3Rs made after May 2026 with an ST7735 instead; this one is a GC9107.
- **Backlight:** the W channel of an LP5562 at I2C `0x30` on the internal bus (SDA GPIO45, SCL GPIO0),
  with the BMI270 at `0x68`. Enable: `0x00`=`0x40`, 1 ms, `0x08`=`0x01`, `0x70`=`0x00`, then
  `0x0E`=brightness.
- **PSRAM:** 8 MB octal (`CONFIG_SPIRAM=y`, `CONFIG_SPIRAM_MODE_OCT=y`); off by default.
- **Echo Base:** I2C SDA GPIO38, SCL GPIO39 with the ES8311 at `0x18` and a PI4IOE5V6408 IO expander at
  `0x43` (its outputs enable the amplifier). I2S BCLK GPIO8, LRCK GPIO6, DOUT GPIO5, DIN GPIO7, no MCLK
  (the ES8311 clocks from BCLK: 16-bit stereo frames).
- **Console:** USB Serial/JTAG on the USB-C port (`303a:1001`, serial = MAC).

Templates in `/opt/esp/atoms3r/templates`:
- `hello`: prints on the console once a second;
- `lcd`: brings up the LCD and backlight and draws four colored squares;
- `echo`: plays 1 kHz on the speaker while recording the mic, and prints both levels. On the bench board it
  prints `mic rms: silence 50, 1 kHz tone 4584` and `echo loopback OK`, so audio tasks can be graded from
  the console.

## Smoke test

```bash
docker run --rm --network none esp-idf-atoms3r atoms3r-smoke-test
```

Builds the three templates, a project with no `sdkconfig.defaults` (and checks it got 8 MB flash), IDF's
`hello_world` and Wi-Fi station, then `echo` again with a Python venv first on `PATH`.
