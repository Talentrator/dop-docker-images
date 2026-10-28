# zephyr-qemu Docker image

Zephyr **v4.4.2** + Zephyr SDK **1.0.1** for **QEMU boards only**: the same Zephyr and SDK as
[`../zephyr`](../zephyr), without what only real hardware needs. About **5.2 GB unpacked** (against ~10 GB),
so a box built from it fits Daytona's 10 GB sandbox limit with room to build.

| QEMU architecture | Toolchain | Example boards |
|-------------------|-----------|----------------|
| Arm Cortex-M / R / A | arm-zephyr-eabi | `qemu_cortex_m0`, `qemu_cortex_m3`, `qemu_cortex_r5`, `qemu_cortex_a9` |
| AArch64 | aarch64-zephyr-elf | `qemu_cortex_a53` |
| RISC-V | riscv64-zephyr-elf | `qemu_riscv32`, `qemu_riscv64` |
| x86 | x86_64-zephyr-elf | `qemu_x86`, `qemu_x86_64` |

Left out, against `../zephyr`:

- the Xtensa (ESP32) toolchains;
- the vendor HALs (STM32, Nordic, Espressif) and the west modules only they use. Kept:
  `cmsis cmsis_6 cmsis-dsp cmsis-nn littlefs mbedtls nanopb picolibc zcbor`;
- nrfutil, J-Link, pyOCD, esptool, OpenOCD's udev rules, stlink-tools, dfu-util and the serial terminals;
- the git history of the Zephyr tree and its modules (`west build` does not need it; `west update` does not work);
- the Python extras and compliance tools: only Zephyr's base, build-test and run-test requirements are installed.

## Prebuilt image

Built, smoke-tested on amd64 and arm64, and published by
[`.github/workflows/zephyr-qemu.yml`](../.github/workflows/zephyr-qemu.yml):

```bash
docker pull ghcr.io/talentrator/dop-docker-images/zephyr-qemu:latest
```

| Tag | Meaning |
|-----|---------|
| `latest` | Newest build from `main` |
| `v4.4.2` | Newest build for that Zephyr release |
| `sha-<commit>` | Build of one exact commit |

**For DOP** use the pinned digest printed in the workflow run summary, not a tag:
`ghcr.io/talentrator/dop-docker-images/zephyr-qemu@sha256:<digest>`.

## Build and use

From this folder:

```bash
docker build -t zephyr-qemu .
docker run --rm zephyr-qemu zephyr-smoke-test     # hello_world built and run on four QEMU boards

docker run --rm -it -v "$PWD":/workdir zephyr-qemu
west build -b qemu_cortex_m3 $ZEPHYR_BASE/samples/hello_world -t run   # Ctrl-A x to quit QEMU
```

Build arguments: `ZEPHYR_VERSION`, `ZEPHYR_SDK_VERSION`, `ZEPHYR_TOOLCHAINS`, `ZEPHYR_MODULES` and
`USER_UID`/`USER_GID`, as in `../zephyr`.
