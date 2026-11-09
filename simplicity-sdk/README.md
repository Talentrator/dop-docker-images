# simplicity-sdk Docker image

Silicon Labs **Simplicity SDK 2026.6.2** with **slc-cli 6.0.22** and Silicon Labs' **GCC 14.2.Rel1**, for
building EFR32 Series 2 firmware headless: the agent box and the grader box of a task for the
**xG24 Dev Kit** (BRD2601B, EFR32MG24B310F1536IM48). About **4.1 GB unpacked**.

| Part | Version | From |
|------|---------|------|
| Simplicity SDK | 2026.6.2 | Silicon Labs' conan server, by content revision |
| GCC (`arm-none-eabi`) | 14.2.Rel1, Silicon Labs' build | Silicon Labs' conan server, by content revision |
| slc-cli | 6.0.22 | Simplicity Studio update site |
| Java (for slc) | 21.0.6 | Simplicity Studio update site |
| Python adapter pack (for the SDK's generators: GATT, …) | 3.10 | Simplicity Studio update site |
| CMake, Ninja, make, git, poppler-utils | Ubuntu 24.04 | apt |

Every download is checked against its sha256. SLT, Silicon Labs' installer, is not used: its Linux build
is x86_64 only. Silicon Labs' GCC is used rather than Arm's: the SDK's prebuilt libraries carry
zstd-compressed LTO bytecode, which Arm's aarch64 build cannot read.

Left out:

- the Zigbee, OpenThread, Wi-SUN, Z-Wave, Connect and multiprotocol stacks and their apps (Bluetooth LE,
  Bluetooth Mesh, RAIL, the platform and the bootloader stay);
- the Security Engine images for every chip but the xG24;
- GCC's libraries for every core but Armv8-M (every EFR32 Series 2 is a Cortex-M33);
- Simplicity Commander: silabs.com does not serve it to scripts. Nothing in a build needs it (`.hex`,
  `.s37` and `.bin` come from objcopy); the bench that flashes the kit has its own.

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
