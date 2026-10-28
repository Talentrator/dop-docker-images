# zephyr-qemu-arm Docker image

Zephyr **v4.4.2** + Zephyr SDK **1.0.1** for the **Arm QEMU boards** only: [`../zephyr-qemu`](../zephyr-qemu)
with one compiler and the two emulators those boards run on. About **2.3 GB unpacked**, against 5.2 GB for
`zephyr-qemu` and about 10 GB for `zephyr`.

| Board | CPU | Runs on |
|-------|-----|---------|
| `qemu_cortex_m3` | Cortex-M3 (TI LM3S6965) | `qemu-system-arm` |
| `qemu_cortex_r5` | Cortex-R5 (Xilinx ZynqMP) | Xilinx's `qemu-system-aarch64` |
| `qemu_cortex_a9` | Cortex-A9 (Xilinx Zynq-7000) | Xilinx's `qemu-system-aarch64` |

`qemu_cortex_m0` is not supported: it is an nRF51, and building it needs `hal_nordic` (287 MB). Use
`../zephyr` for it.

## What is in it

| Part | Size |
|------|------|
| Arm compiler (`arm-zephyr-eabi`) | 752 MB |
| Ubuntu 24.04 + build packages (`/usr`) | 632 MB |
| Zephyr tree, samples included | 365 MB |
| SDK host tools: `qemu-system-arm`, Xilinx's QEMU (261 MB, most of it its firmware and device files), dtc, OpenOCD | 340 MB |
| Python environment: west, Zephyr's base requirements, twister's tooling | 83 MB |
| West modules: `cmsis cmsis_6 littlefs mbedtls nanopb picolibc zcbor` | 77 MB |

Left out, against `../zephyr-qemu`:

- the RISC-V, x86 and AArch64 compilers (1.6 GB) and every other QEMU (`qemu-system-*`, Xilinx's
  RISC-V and MicroBlaze, Synopsys's ARC);
- the SDK host sysroot's glibc locales (about 500 MB) and the host tools' leftover installer;
- the `cmsis-dsp` and `cmsis-nn` modules: only the DSP and neural-network samples use them;
- Zephyr's `doc/` and `tests/` (but for `tests/test_config.yaml`, which twister reads);
- the run-test Python extras (OpenCV, numpy, pyocd, python-can, spdx-tools) and mypy;
- `gcc-multilib`, which only `native_sim` uses.

## Prebuilt image

Built, smoke-tested on amd64 and arm64, and published by
[`.github/workflows/zephyr-qemu-arm.yml`](../.github/workflows/zephyr-qemu-arm.yml):

```bash
docker pull ghcr.io/talentrator/dop-docker-images/zephyr-qemu-arm:latest
```

Tags: `latest`, `v4.4.2`, `sha-<commit>`. **For DOP** use the pinned digest the workflow run summary prints:
`ghcr.io/talentrator/dop-docker-images/zephyr-qemu-arm@sha256:<digest>`.

## Build and use

From this folder:

```bash
docker build -t zephyr-qemu-arm .
docker run --rm zephyr-qemu-arm zephyr-smoke-test     # hello_world on the three boards, and once through twister

docker run --rm -it -v "$PWD":/workdir zephyr-qemu-arm
west build -b qemu_cortex_m3 $ZEPHYR_BASE/samples/hello_world -t run   # Ctrl-A x to quit QEMU
```
