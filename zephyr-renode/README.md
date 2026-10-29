# zephyr-renode Docker image

Zephyr **v4.4.2** + Zephyr SDK **1.0.1** + **Renode 1.17.0** for the boards Renode runs: [`../zephyr-qemu-arm`](../zephyr-qemu-arm)
with Renode in place of QEMU, and the STM32 and Nordic HALs those boards build against. About **2.6 GB unpacked**.

Renode runs in virtual time, so the same image prints the same bytes on every run, and a grader can set a
sensor's value, watch a GPIO or count instructions from a Robot test (`renode-test`) or a Monitor command.

| Board | CPU | Renode platform | Console |
|-------|-----|-----------------|---------|
| `stm32f4_disco` | Cortex-M4 (STM32F407) | `platforms/boards/stm32f4_discovery.repl` | `usart2` |
| `nucleo_f767zi` | Cortex-M7 (STM32F767) | `platforms/boards/nucleo_f767zi.repl` | `usart3` |
| `stm32f072b_disco` | Cortex-M0 (STM32F072) | `platforms/boards/stm32f072b_discovery.repl` | `usart1` |
| `nrf52840dk/nrf52840` | Cortex-M4F (nRF52840) | `platforms/boards/nrf52840dk_nrf52840.repl` | `uart0` |
| `cortex_r8_virtual` | Cortex-R8 | Zephyr's own `boards/renode/cortex_r8_virtual/support/` | `uart0` |

On `stm32f4_disco` a GPIO interrupt from the user button did not reach Zephyr in our test (Renode does not
model SYSCFG's EXTI routing on the F4); `nucleo_f767zi`'s button and LEDs work, so use it for GPIO tasks.

`cortex_r8_virtual` is the one board Zephyr itself runs on Renode, so `west build -t run` and twister work on
it. The others run with `zephyr-renode-run`.

## What is in it

- Renode 1.17.0, the portable build with its own .NET (188 MB), in `/opt/renode`; `renode` and `renode-test`
  on the `PATH`, and Robot Framework in the Python environment.
- `zephyr-renode-run`: runs a build on its board, headless, for a span of virtual time, and prints the console
  UART. `-e` adds Monitor commands before the board starts; `--resc` prints the Renode script it would run.
- The Arm compiler (`arm-zephyr-eabi`), the Zephyr tree with its samples, west and twister.
- West modules: `cmsis cmsis_6 littlefs mbedtls nanopb picolibc zcbor`, `hal_nordic`, and `hal_stm32` cut to
  the F0, F4 and F7 series (`STM32_SERIES`).

Left out, against `../zephyr-qemu-arm`: the SDK host tools (QEMU, OpenOCD; dtc comes from apt).

## Prebuilt image

Built, smoke-tested on amd64 and arm64, and published by
[`.github/workflows/zephyr-renode.yml`](../.github/workflows/zephyr-renode.yml):

```bash
docker pull ghcr.io/talentrator/dop-docker-images/zephyr-renode:latest
```

Tags: `latest`, `v4.4.2`, `sha-<commit>`. **For DOP** use the pinned digest the workflow run summary prints:
`ghcr.io/talentrator/dop-docker-images/zephyr-renode@sha256:<digest>`.

## Build and use

From this folder:

```bash
docker build -t zephyr-renode .
docker run --rm zephyr-renode zephyr-smoke-test     # hello_world on the five boards, renode-test, twister

docker run --rm -it -v "$PWD":/workdir zephyr-renode
west build -b stm32f4_disco $ZEPHYR_BASE/samples/hello_world
zephyr-renode-run -t 2 build                         # *** Booting Zephyr OS ... Hello World! stm32f4_disco
```
