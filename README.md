# dop-docker-images

Docker images for DOP environments (agent boxes and grader boxes), one folder each.
Every folder is built and smoke-tested for `linux/amd64` and `linux/arm64` by GitHub Actions and
published to GHCR as `ghcr.io/talentrator/dop-docker-images/<folder>`.

| Image | What it is | Unpacked |
|-------|------------|----------|
| [`zephyr`](zephyr) | Zephyr v4.4.2 + SDK 1.0.1 for QEMU, Nordic nRF, STM32 and ESP32, with the flashing tools | ~10 GB |
| [`zephyr-qemu`](zephyr-qemu) | Zephyr v4.4.2 + SDK 1.0.1 for QEMU boards only; fits a 10 GB Daytona sandbox | ~5.2 GB |
| [`zephyr-qemu-arm`](zephyr-qemu-arm) | Zephyr v4.4.2 + SDK 1.0.1 for the Arm QEMU boards only (`qemu_cortex_m3`, `_r5`, `_a9`) | ~2.3 GB |

For DOP, always use the pinned digest a workflow run prints in its summary, not a tag:
`ghcr.io/talentrator/dop-docker-images/<image>@sha256:<digest>`.

## Adding an image

1. Put its `Dockerfile` (and anything it copies) in a new folder, with a smoke test installed in the
   image as a command that exits non-zero on a failure.
2. Copy `.github/workflows/zephyr-qemu.yml` to `.github/workflows/<folder>.yml` and change the folder name,
   the version ARG, the smoke-test command and the description. The build, test and publish steps are shared in
   `.github/workflows/image.yml`.

This repo was `Talentrator/zephyr_env_dop`; images published before the rename stay at
`ghcr.io/talentrator/zephyr_env_dop`.
