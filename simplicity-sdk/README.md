# simplicity-sdk Docker image

Silicon Labs **Simplicity SDK 2026.6.2** with **slc-cli 6.0.22** and Silicon Labs' **GCC 14.2.Rel1**, for
building EFR32 Series 2 firmware headless: the agent box and the grader box of a task for the
**xG24 Dev Kit** (BRD2601B, EFR32MG24B310F1536IM48). About **4.1 GB unpacked**.

## Included

| Part | Version | Size | From |
|------|---------|------|------|
| Simplicity SDK, trimmed (below) | 2026.6.2 | 1.5 GB | Silicon Labs' conan server, by content revision |
| GCC (`arm-none-eabi`), Armv8-M libraries only | 14.2.Rel1, Silicon Labs' build | 472 MB | Silicon Labs' conan server, by content revision |
| Python adapter pack (runs the SDK's generators: GATT, …) | 3.10 | 451 MB | Simplicity Studio update site |
| Java (runs slc) | 21.0.6 | 126 MB | Simplicity Studio update site |
| slc-cli | 6.0.22 | 97 MB | Simplicity Studio update site |
| Ubuntu 24.04 + CMake, Ninja, make, git, python3, poppler-utils | 24.04 | 344 MB | apt |
| `sisdk-build`, `sisdk-smoke-test` | | | this folder's `scripts/` |

Of the SDK, what a BG24/MG24 firmware task uses:

| SDK part | Folders | Size |
|----------|---------|------|
| Bluetooth LE and Bluetooth Mesh: host, controller, apps and samples, AppLoader | `bluetooth_*`, `bgapi_protocol` | 303 MB |
| Platform, boards, bootloader, RAIL (proprietary radio) | `platform_*`, `boards`, `bootloader*`, `rail_*` | 932 MB |
| Libraries | `cmsis*`, `mbedtls`, `freertos`, `micriumos`, `security_*`, `segger`, `printf`, `usb`, `cpc*`, `delta_dfu`, `coremark`, `unity_test_framework` | the rest |
| Security Engine firmware for the xG24 | `se_firmware_xg24` | |
| `generative_ai` | kept: its `agents_md` component (the `AGENTS.md` in every generated project) is required by every device | |

Every download is checked against its sha256. SLT, Silicon Labs' installer, is not used: its Linux build
is x86_64 only. Silicon Labs' GCC is used rather than Arm's: the SDK's prebuilt libraries carry
zstd-compressed LTO bytecode, which Arm's aarch64 build cannot read.

## Not included

About **1.9 GB** is left out; with it all the image would be about 6 GB. Sizes are unpacked.

| Left out | Size | Why |
|----------|------|-----|
| Zigbee stack and apps (`zigbee*`) | 553 MB | 802.15.4 mesh: not a Bluetooth task |
| OpenThread stack and apps (`openthread*`) | 319 MB | Thread (and the base of Matter over Thread) |
| Wi-SUN stack, apps and config tools (`wisun*`) | 317 MB | sub-GHz; the xG24 is 2.4 GHz only |
| Multiprotocol (`multiprotocol*`) | 38 MB | dynamic multiprotocol with Zigbee or Thread |
| Z-Wave (`zwave*`) | 36 MB | sub-GHz |
| Connect (`connect_*`, `common_15_4`) | 4 MB | proprietary 802.15.4 |
| Security Engine firmware for other chips (`se_firmware_*` but xG24) | 3 MB | other chips |
| `compute*`, `rail_library_alpha_chips` | 1 MB | other chips |
| GCC libraries for every core but Armv8-M | 600 MB | every EFR32 Series 2 is a Cortex-M33 |
| Simplicity Commander | | silabs.com does not serve it to scripts. Nothing in a build needs it (`.hex`, `.s37` and `.bin` come from objcopy); the bench that flashes the kit has its own |
| Matter, Wi-Fi (WiSeConnect), Sidewalk, AI/ML extensions | | separate SDK extensions, never in the Simplicity SDK package |

The EFR32**MG**24 on the kit does run Zigbee and Thread. A task on those needs their folders back: delete
them from the `rm -rf` line of the SDK step in the [`Dockerfile`](Dockerfile) (Zigbee and OpenThread
together take the image to about 5 GB). slc skips component paths that are not there, so a project that
uses a removed stack fails at `slc generate` with a missing component, not later.

## Building a project

```bash
sisdk-build [-b BOARD] [-o OUT_DIR] PROJECT [slc generate options ...]
```

`PROJECT` is a `.slcp` or the folder holding one. It is copied to a fresh folder and generated there
(`slc generate -o cmake`, GCC), then built with CMake; the sources are never written to. The `.out`,
`.hex`, `.s37`, `.bin` and `.map` land in `OUT_DIR` (default `./build/<board>`). `BOARD` defaults to
`brd2601b`. Anything after `PROJECT` goes to `slc generate`, for example `--with iostream_usart:vcom`.

```bash
cp -r $SISDK/platform_sample_app/app/common/example/iostream_usart_baremetal /workdir/app
sisdk-build /workdir/app                     # -> /workdir/build/brd2601b/iostream_usart_baremetal.hex
```

The kit's serial port (VCOM, 115200 8N1) is USART0 through the board controller: the
`iostream_usart` component with the `vcom` instance.

To run slc yourself: `slc generate ... --tt --tool-path=/opt/silabs/python --toolchain-locations=gcc:$ARM_GCC_DIR`,
and build with `NINJA_EXE_PATH=$(command -v ninja) POST_BUILD_EXE=$(command -v true) cmake --workflow --preset project`
in the generated `cmake_gcc/`. The SDK's own `ninja` is x86_64 only, and its post-build step wants Commander.

## Prebuilt image

Built, smoke-tested on amd64 and arm64, and published by
[`.github/workflows/simplicity-sdk.yml`](../.github/workflows/simplicity-sdk.yml):

```bash
docker pull ghcr.io/talentrator/dop-docker-images/simplicity-sdk:latest
```

Tags: `latest`, `2026.6.2`, `sha-<commit>`. **For DOP** use the pinned digest the workflow run summary prints:
`ghcr.io/talentrator/dop-docker-images/simplicity-sdk@sha256:<digest>`.

## Build and test

```bash
docker build -t simplicity-sdk .
docker run --rm simplicity-sdk sisdk-smoke-test   # VCOM echo, Bluetooth SoC Empty, AppLoader bootloader for brd2601b
```
