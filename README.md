# zephyr-dev Docker image

Zephyr **v4.4.2** (latest stable) + Zephyr SDK **1.0.1** for:

| Family  | Toolchain                         | Example boards                                   | Flash / debug tools in image          |
|---------|-----------------------------------|--------------------------------------------------|---------------------------------------|
| QEMU    | arm, x86_64, riscv64, aarch64     | `qemu_cortex_m3`, `qemu_x86`, `qemu_riscv32`, `qemu_cortex_a53` | SDK QEMU (`west build -t run`) |
| Nordic  | arm-zephyr-eabi                   | `nrf52840dk/nrf52840`, `nrf5340dk/nrf5340/cpuapp` | nrfutil (+ device), SEGGER J-Link, pyOCD, OpenOCD |
| STM32   | arm-zephyr-eabi                   | `nucleo_f401re`, `nucleo_h743zi`                 | OpenOCD, stlink-tools, pyOCD, dfu-util |
| ESP32   | xtensa esp32/s2/s3, riscv64       | `esp32_devkitc/esp32/procpu`, `esp32s3_devkitc/esp32s3/procpu`, `esp32c3_devkitm` | esptool (`west flash`) |

Builds for `linux/arm64` (Apple Silicon, ARM servers) and `linux/amd64`. Tested so far on arm64 only.

## Build

```bash
# native architecture (e.g. arm64 on an Apple Silicon Mac)
docker build -t zephyr-dev .

# multi-arch, pushed to a registry
docker buildx build --platform linux/amd64,linux/arm64 -t <registry>/zephyr-dev:4.4.2 --push .
```

Build arguments:

| ARG                  | Default    | Purpose |
|----------------------|------------|---------|
| `ZEPHYR_VERSION`     | `v4.4.2`   | Zephyr git tag |
| `ZEPHYR_SDK_VERSION` | `1.0.1`    | Must match `zephyr/SDK_VERSION` of the release |
| `ZEPHYR_TOOLCHAINS`  | arm, riscv64, xtensa esp32/s2/s3, x86_64, aarch64 | SDK GNU toolchains to install |
| `ZEPHYR_MODULES`     | HALs for nRF/STM32/ESP + common libs | West modules to fetch |
| `INSTALL_NRFUTIL`    | `true`     | Install Nordic nrfutil + `device` command |
| `INSTALL_JLINK`      | `true`     | Install SEGGER J-Link tools. **Building with `true` means you accept the SEGGER J-Link license.** Use `false` to skip. |
| `USER_UID`/`USER_GID`| `1000`     | Match your Linux host user to avoid permission issues on mounts |

## Use

```bash
# interactive shell, your app folder mounted at /workdir
docker run --rm -it -v "$PWD":/workdir zephyr-dev

# inside the container
west build -b qemu_cortex_m3 $ZEPHYR_BASE/samples/hello_world -t run   # Ctrl-A x to quit QEMU
west build -p -b nrf52840dk/nrf52840 app/
west build -p -b nucleo_f401re app/
west build -p -b esp32_devkitc/esp32/procpu app/
```

Keep build caches between runs:

```bash
docker run --rm -it -v "$PWD":/workdir -v zephyr-ccache:/home/zephyr/.cache zephyr-dev
```

Self-test (builds hello_world for every family and runs it in QEMU):

```bash
docker run --rm zephyr-dev zephyr-smoke-test
```

## Flashing on a Linux host

Docker Desktop / Colima on macOS **cannot** pass USB devices into containers. On a Linux host:

```bash
docker run --rm -it --privileged -v /dev:/dev \
  -v "$PWD":/workdir zephyr-dev
# or, narrower:  --device /dev/ttyUSB0 --device /dev/bus/usb
```

Install the probe udev rules **on the host** (once), e.g. OpenOCD's `60-openocd.rules`,
Nordic's `nrf-udev` package, and SEGGER J-Link's rules, then replug the board.

| Board family | Command |
|--------------|---------|
| nRF (J-Link OB) | `west flash` (nrfutil + J-Link) or `west flash -r jlink` / `-r pyocd` |
| STM32 Nucleo    | `west flash` (OpenOCD) or `west flash -r stm32cubeprogrammer` if installed |
| ESP32           | `west flash --esp-device /dev/ttyUSB0` then `west espressif monitor` |

## Local setup on macOS (Apple Silicon)

```bash
brew install colima docker docker-buildx
colima start --cpu 8 --memory 16 --disk 100 --vm-type vz --vz-rosetta
```

`--vz-rosetta` lets the same VM build/run `linux/amd64` images quickly.

Colima only shares your home folder (`~`) with containers by default, so keep projects under `~`.
After a reboot run `colima start` again before using `docker`.

Image size (arm64): ~3.65 GB compressed (registry push/pull) / ~10.4 GB unpacked.
`docker images` on the Mac shows ~14 GB because it stores both the compressed and the unpacked copy.

<!-- BOARDS:BEGIN (generated: every target below was built with samples/hello_world) -->
## 🧩 Supported boards

Every board target listed here was **verified by building `samples/hello_world`** in this image.

| Family | Boards | Build targets |
|:--|--:|--:|
| 🖥️ QEMU | 14 | 24 |
| 🔵 Nordic Semiconductor | 22 | 66 |
| 🟢 STMicroelectronics STM32 | 136 | 156 |
| 🔴 Espressif ESP32 | 15 | 23 |
| **Total** | **187** | **269** |

### 📖 How to read the lists

```text
nucleo_f401re                       ← single target: use the name as is

nrf5340dk  ✋ pick one:               ← several targets, you MUST give the full name
├── nrf5340dk/nrf5340/cpuapp         ←   board / SoC / CPU core
├── nrf5340dk/nrf5340/cpuapp/ns      ←   …/ns = non-secure (built with TF-M)
└── nrf5340dk/nrf5340/cpunet

qemu_x86  ★ name alone works (= qemu_x86/atom)   ← several targets, the bare name
├── qemu_x86/atom                                   picks the default one
├── qemu_x86/atom/nommu
└── …
```

```bash
west build -p -b <target> $ZEPHYR_BASE/samples/hello_world
west boards --format '{name}: {qualifiers}' -n <part-of-name>   # look up targets in the container
```

### 🖥️ QEMU — emulated, no hardware needed

> Run with `west build -t run` · quit with `Ctrl-A` then `X`

<details open><summary><b>Arm Cortex-M / R / A</b> — 6 boards</summary>

```text
qemu_cortex_a53  ★ name alone works (= qemu_cortex_a53/qemu_cortex_a53)
├── qemu_cortex_a53/qemu_cortex_a53
├── qemu_cortex_a53/qemu_cortex_a53/smp
└── qemu_cortex_a53/qemu_cortex_a53/xip
qemu_cortex_a9
qemu_cortex_m0
qemu_cortex_m3
qemu_cortex_r5
qemu_kvm_arm64
```

</details>

<details open><summary><b>x86</b> — 4 boards</summary>

```text
qemu_x86           ★ name alone works (= qemu_x86/atom)
├── qemu_x86/atom
├── qemu_x86/atom/nokpti
├── qemu_x86/atom/nommu
├── qemu_x86/atom/nopae
├── qemu_x86/atom/virt
└── qemu_x86/atom/xip
qemu_x86_64        ★ name alone works (= qemu_x86_64/atom)
├── qemu_x86_64/atom
└── qemu_x86_64/atom/nokpti
qemu_x86_lakemont
qemu_x86_tiny
```

</details>

<details open><summary><b>RISC-V</b> — 4 boards</summary>

```text
qemu_riscv32      ★ name alone works (= qemu_riscv32/qemu_virt_riscv32)
├── qemu_riscv32/qemu_virt_riscv32
└── qemu_riscv32/qemu_virt_riscv32/smp
qemu_riscv32_xip
qemu_riscv32e
qemu_riscv64      ★ name alone works (= qemu_riscv64/qemu_virt_riscv64)
├── qemu_riscv64/qemu_virt_riscv64
└── qemu_riscv64/qemu_virt_riscv64/smp
```

</details>

### 🔵 Nordic Semiconductor

> Flash with `west flash` (nrfutil + J-Link) · `-r jlink` · `-r pyocd`

<details open><summary><b>nRF70 / nRF71 Wi-Fi</b> — 2 boards</summary>

```text
nrf7002dk  ✋ pick one:
├── nrf7002dk/nrf5340/cpuapp
├── nrf7002dk/nrf5340/cpuapp/nrf7001
└── nrf7002dk/nrf5340/cpunet
nrf7120dk  ✋ pick one:
├── nrf7120dk/nrf7120/cpuapp
├── nrf7120dk/nrf7120/cpuapp/ns
├── nrf7120dk/nrf7120/cpuflpr
└── nrf7120dk/nrf7120/cpuflpr/xip
```

</details>

<details open><summary><b>nRF51 Series</b> — 2 boards</summary>

```text
nrf51dk
nrf51dongle
```

</details>

<details open><summary><b>nRF52 Series</b> — 6 boards</summary>

```text
nrf21540dk
nrf52833dk      ✋ pick one:
├── nrf52833dk/nrf52820
└── nrf52833dk/nrf52833
nrf52840dk      ✋ pick one:
├── nrf52840dk/nrf52840
└── nrf52840dk/nrf52811
nrf52840dongle  ★ name alone works (= nrf52840dongle/nrf52840)
├── nrf52840dongle/nrf52840
└── nrf52840dongle/nrf52840/bare
nrf52dk         ✋ pick one:
├── nrf52dk/nrf52805
├── nrf52dk/nrf52810
└── nrf52dk/nrf52832
thingy52
```

</details>

<details open><summary><b>nRF53 Series</b> — 3 boards</summary>

```text
nrf5340_audio_dk  ✋ pick one:
├── nrf5340_audio_dk/nrf5340/cpuapp
├── nrf5340_audio_dk/nrf5340/cpuapp/ns
└── nrf5340_audio_dk/nrf5340/cpunet
nrf5340dk         ✋ pick one:
├── nrf5340dk/nrf5340/cpuapp
├── nrf5340dk/nrf5340/cpuapp/ns
└── nrf5340dk/nrf5340/cpunet
thingy53          ✋ pick one:
├── thingy53/nrf5340/cpuapp
├── thingy53/nrf5340/cpuapp/ns
└── thingy53/nrf5340/cpunet
```

</details>

<details open><summary><b>nRF54L Series</b> — 3 boards</summary>

```text
nrf54l15dk   ✋ pick one:
├── nrf54l15dk/nrf54l05/cpuapp
├── nrf54l15dk/nrf54l05/cpuflpr
├── nrf54l15dk/nrf54l10/cpuapp
├── nrf54l15dk/nrf54l10/cpuapp/ns
├── nrf54l15dk/nrf54l10/cpuflpr
├── nrf54l15dk/nrf54l15/cpuapp
├── nrf54l15dk/nrf54l15/cpuapp/ns
├── nrf54l15dk/nrf54l15/cpuflpr
└── nrf54l15dk/nrf54l15/cpuflpr/xip
nrf54l15tag  ✋ pick one:
├── nrf54l15tag/nrf54l15/cpuapp
├── nrf54l15tag/nrf54l15/cpuapp/ns
├── nrf54l15tag/nrf54l15/cpuflpr
└── nrf54l15tag/nrf54l15/cpuflpr/xip
nrf54lm20dk  ✋ pick one:
├── nrf54lm20dk/nrf54lm20a/cpuapp
├── nrf54lm20dk/nrf54lm20a/cpuapp/ns
├── nrf54lm20dk/nrf54lm20a/cpuflpr
├── nrf54lm20dk/nrf54lm20b/cpuapp
├── nrf54lm20dk/nrf54lm20b/cpuapp/ns
└── nrf54lm20dk/nrf54lm20b/cpuflpr
```

</details>

<details open><summary><b>nRF54H Series</b> — 1 board</summary>

```text
nrf54h20dk  ✋ pick one:
├── nrf54h20dk/nrf54h20/cpuapp
├── nrf54h20dk/nrf54h20/cpurad
├── nrf54h20dk/nrf54h20/cpuppr
├── nrf54h20dk/nrf54h20/cpuppr/xip
├── nrf54h20dk/nrf54h20/cpuflpr
└── nrf54h20dk/nrf54h20/cpuflpr/xip
```

</details>

<details open><summary><b>nRF91 Series (cellular)</b> — 4 boards</summary>

```text
nrf9131ek  ★ name alone works (= nrf9131ek/nrf9131)
├── nrf9131ek/nrf9131
└── nrf9131ek/nrf9131/ns
nrf9151dk  ★ name alone works (= nrf9151dk/nrf9151)
├── nrf9151dk/nrf9151
└── nrf9151dk/nrf9151/ns
nrf9160dk  ✋ pick one:
├── nrf9160dk/nrf9160
├── nrf9160dk/nrf9160/ns
└── nrf9160dk/nrf52840
nrf9161dk  ★ name alone works (= nrf9161dk/nrf9161)
├── nrf9161dk/nrf9161
└── nrf9161dk/nrf9161/ns
```

</details>

<details open><summary><b>nRF92 Series (cellular)</b> — 1 board</summary>

```text
nrf9280pdk  ✋ pick one:
├── nrf9280pdk/nrf9280/cpuapp
├── nrf9280pdk/nrf9280/cpurad
└── nrf9280pdk/nrf9280/cpuppr/xip
```

</details>

### 🟢 STMicroelectronics STM32

> Flash with `west flash` (OpenOCD / ST-Link) · `-r jlink` · `-r pyocd`

<details open><summary><b>STM32C0</b> — 4 boards</summary>

```text
nucleo_c031c6
nucleo_c071rb
nucleo_c092rc
stm32c0116_dk
```

</details>

<details open><summary><b>STM32C5</b> — 3 boards</summary>

```text
nucleo_c542rc
nucleo_c562re
nucleo_c5a3zg
```

</details>

<details open><summary><b>STM32F0</b> — 9 boards</summary>

```text
nucleo_f030r8
nucleo_f031k6
nucleo_f042k6
nucleo_f070rb
nucleo_f072rb
nucleo_f091rc
stm32f072_eval
stm32f072b_disco
stm32f0_disco
```

</details>

<details open><summary><b>STM32F1</b> — 3 boards</summary>

```text
nucleo_f103rb
stm3210c_eval
stm32vl_disco
```

</details>

<details open><summary><b>STM32F2</b> — 1 board</summary>

```text
nucleo_f207zg
```

</details>

<details open><summary><b>STM32F3</b> — 6 boards</summary>

```text
nucleo_f302r8
nucleo_f303k8
nucleo_f303re
nucleo_f334r8
stm32373c_eval
stm32f3_disco
```

</details>

<details open><summary><b>STM32F4</b> — 17 boards</summary>

```text
nucleo_f401re
nucleo_f410rb
nucleo_f411re
nucleo_f412zg
nucleo_f413zh
nucleo_f429zi
nucleo_f439zi
nucleo_f446re
nucleo_f446ze
st25dv_mb1283_disco
steval_fcu001v1
stm32f411e_disco
stm32f412g_disco
stm32f413h_disco
stm32f429i_disc1
stm32f469i_disco     ★ name alone works (= stm32f469i_disco/stm32f469xx)
├── stm32f469i_disco/stm32f469xx
└── stm32f469i_disco/stm32f469xx/au1
stm32f4_disco
```

</details>

<details open><summary><b>STM32F7</b> — 8 boards</summary>

```text
nucleo_f722ze
nucleo_f746zg
nucleo_f756zg
nucleo_f767zi
stm32f723e_disco
stm32f746g_disco
stm32f7508_dk
stm32f769i_disco
```

</details>

<details open><summary><b>STM32G0</b> — 7 boards</summary>

```text
nucleo_g031k8
nucleo_g070rb
nucleo_g071rb
nucleo_g0b1re
stm32g0316_disco
stm32g071b_disco
stm32g081b_eval
```

</details>

<details open><summary><b>STM32G4</b> — 4 boards</summary>

```text
b_g474e_dpow1
nucleo_g431kb
nucleo_g431rb
nucleo_g474re
```

</details>

<details open><summary><b>STM32H5</b> — 5 boards</summary>

```text
nucleo_h503rb
nucleo_h533re
nucleo_h563zi
stm32h573i_dk  ★ name alone works (= stm32h573i_dk/stm32h573xx)
├── stm32h573i_dk/stm32h573xx
├── stm32h573i_dk/stm32h573xx/ext_flash_app
└── stm32h573i_dk/stm32h573xx/ns
stm32h5f5j_dk  ★ name alone works (= stm32h5f5j_dk/stm32h5f5xx)
└── stm32h5f5j_dk/stm32h5f5xx
```

</details>

<details open><summary><b>STM32H7</b> — 14 boards</summary>

```text
nucleo_h723zg
nucleo_h743zi
nucleo_h745zi_q   ✋ pick one:
├── nucleo_h745zi_q/stm32h745xx/m7
└── nucleo_h745zi_q/stm32h745xx/m4
nucleo_h753zi
nucleo_h755zi_q   ✋ pick one:
├── nucleo_h755zi_q/stm32h755xx/m7
└── nucleo_h755zi_q/stm32h755xx/m4
nucleo_h7a3zi_q
nucleo_h7s3l8     ★ name alone works (= nucleo_h7s3l8/stm32h7s3xx)
├── nucleo_h7s3l8/stm32h7s3xx
└── nucleo_h7s3l8/stm32h7s3xx/ext_flash_app
stm32h735g_disco
stm32h745i_disco  ✋ pick one:
├── stm32h745i_disco/stm32h745xx/m7
└── stm32h745i_disco/stm32h745xx/m4
stm32h747i_disco  ✋ pick one:
├── stm32h747i_disco/stm32h747xx/m7
└── stm32h747i_disco/stm32h747xx/m4
stm32h750b_dk     ★ name alone works (= stm32h750b_dk/stm32h750xx)
├── stm32h750b_dk/stm32h750xx
└── stm32h750b_dk/stm32h750xx/ext_flash_app
stm32h757i_eval   ✋ pick one:
├── stm32h757i_eval/stm32h757xx/m7
└── stm32h757i_eval/stm32h757xx/m4
stm32h7b3i_dk
stm32h7s78_dk     ★ name alone works (= stm32h7s78_dk/stm32h7s7xx)
├── stm32h7s78_dk/stm32h7s7xx
└── stm32h7s78_dk/stm32h7s7xx/ext_flash_app
```

</details>

<details open><summary><b>STM32L0</b> — 5 boards</summary>

```text
b_l072z_lrwan1
nucleo_l011k4
nucleo_l031k6
nucleo_l053r8
nucleo_l073rz
```

</details>

<details open><summary><b>STM32L1</b> — 3 boards</summary>

```text
nucleo_l152re
stm32l152c_disco
stm32l1_disco
```

</details>

<details open><summary><b>STM32L4</b> — 14 boards</summary>

```text
b_l4s5i_iot01a
disco_l475_iot1
nucleo_l412rb_p
nucleo_l432kc
nucleo_l433rc_p
nucleo_l452re     ★ name alone works (= nucleo_l452re/stm32l452xx)
├── nucleo_l452re/stm32l452xx
└── nucleo_l452re/stm32l452xx/p
nucleo_l476rg
nucleo_l496zg
nucleo_l4a6zg
nucleo_l4r5zi
sensortile_box
stm32l476g_disco
stm32l496g_disco
stm32l4r9i_disco
```

</details>

<details open><summary><b>STM32L5</b> — 2 boards</summary>

```text
nucleo_l552ze_q  ★ name alone works (= nucleo_l552ze_q/stm32l552xx)
├── nucleo_l552ze_q/stm32l552xx
└── nucleo_l552ze_q/stm32l552xx/ns
stm32l562e_dk    ★ name alone works (= stm32l562e_dk/stm32l562xx)
├── stm32l562e_dk/stm32l562xx
└── stm32l562e_dk/stm32l562xx/ns
```

</details>

<details open><summary><b>STM32U0</b> — 3 boards</summary>

```text
nucleo_u031r8
nucleo_u083rc
stm32u083c_dk
```

</details>

<details open><summary><b>STM32U3</b> — 2 boards</summary>

```text
nucleo_u385rg_q
nucleo_u3c5zi_q
```

</details>

<details open><summary><b>STM32U5</b> — 8 boards</summary>

```text
b_u585i_iot02a      ★ name alone works (= b_u585i_iot02a/stm32u585xx)
├── b_u585i_iot02a/stm32u585xx
└── b_u585i_iot02a/stm32u585xx/ns
nucleo_u575zi_q
nucleo_u5a5zj_q
sensortile_box_pro
steval_stwinbx1
stm32u5a9j_dk
stm32u5g9j_dk1
stm32u5g9j_dk2
```

</details>

<details open><summary><b>STM32N6 (AI/NPU)</b> — 2 boards</summary>

```text
nucleo_n657x0_q  ★ name alone works (= nucleo_n657x0_q/stm32n657xx)
├── nucleo_n657x0_q/stm32n657xx
└── nucleo_n657x0_q/stm32n657xx/sb
stm32n6570_dk    ★ name alone works (= stm32n6570_dk/stm32n657xx)
├── stm32n6570_dk/stm32n657xx
├── stm32n6570_dk/stm32n657xx/sb
└── stm32n6570_dk/stm32n657xx/fsbl
```

</details>

<details open><summary><b>STM32WB0</b> — 3 boards</summary>

```text
nucleo_wb05kz
nucleo_wb07cc
nucleo_wb09ke
```

</details>

<details open><summary><b>STM32WB (BLE)</b> — 3 boards</summary>

```text
nucleo_wb55rg
stm32wb5mm_dk
stm32wb5mmg
```

</details>

<details open><summary><b>STM32WBA (BLE)</b> — 4 boards</summary>

```text
nucleo_wba25ce1
nucleo_wba55cg
nucleo_wba65ri   ★ name alone works (= nucleo_wba65ri/stm32wba65xx)
├── nucleo_wba65ri/stm32wba65xx
└── nucleo_wba65ri/stm32wba65xx/ns
stm32wba65i_dk1  ★ name alone works (= stm32wba65i_dk1/stm32wba65xx)
├── stm32wba65i_dk1/stm32wba65xx
└── stm32wba65i_dk1/stm32wba65xx/ns
```

</details>

<details open><summary><b>STM32WL (LoRa)</b> — 1 board</summary>

```text
nucleo_wl55jc
```

</details>

<details open><summary><b>STM32MP1 (MPU)</b> — 2 boards</summary>

```text
stm32mp135f_dk
stm32mp157c_dk2
```

</details>

<details open><summary><b>STM32MP2 (MPU)</b> — 3 boards</summary>

```text
stm32mp215f_dk
stm32mp257f_dk
stm32mp257f_ev1
```

</details>

### 🔴 Espressif ESP32

> Flash with `west flash --esp-device /dev/ttyUSB0` · monitor with `west espressif monitor`

<details open><summary><b>ESP32 (Xtensa)</b> — 3 boards</summary>

```text
esp32_devkitc       ✋ pick one:
├── esp32_devkitc/esp32/procpu
└── esp32_devkitc/esp32/appcpu
esp32_ethernet_kit  ✋ pick one:
├── esp32_ethernet_kit/esp32/procpu
└── esp32_ethernet_kit/esp32/appcpu
esp_wrover_kit      ✋ pick one:
├── esp_wrover_kit/esp32/procpu
└── esp_wrover_kit/esp32/appcpu
```

</details>

<details open><summary><b>ESP32-S2 (Xtensa)</b> — 2 boards</summary>

```text
esp32s2_devkitc
esp32s2_saola
```

</details>

<details open><summary><b>ESP32-S3 (Xtensa)</b> — 3 boards</summary>

```text
esp32s3_devkitc  ✋ pick one:
├── esp32s3_devkitc/esp32s3/procpu
└── esp32s3_devkitc/esp32s3/appcpu
esp32s3_eye      ✋ pick one:
├── esp32s3_eye/esp32s3/procpu
└── esp32s3_eye/esp32s3/appcpu
esp_threadbr     ✋ pick one:
├── esp_threadbr/esp32s3/procpu
└── esp_threadbr/esp32s3/appcpu
```

</details>

<details open><summary><b>ESP32-C2 (RISC-V)</b> — 1 board</summary>

```text
esp8684_devkitm
```

</details>

<details open><summary><b>ESP32-C3 (RISC-V)</b> — 3 boards</summary>

```text
esp32c3_devkitc
esp32c3_devkitm
esp32c3_rust
```

</details>

<details open><summary><b>ESP32-C5 (RISC-V)</b> — 1 board</summary>

```text
esp32c5_devkitc  ✋ pick one:
├── esp32c5_devkitc/esp32c5/hpcore
└── esp32c5_devkitc/esp32c5/lpcore
```

</details>

<details open><summary><b>ESP32-C6 (RISC-V)</b> — 1 board</summary>

```text
esp32c6_devkitc  ✋ pick one:
├── esp32c6_devkitc/esp32c6/hpcore
└── esp32c6_devkitc/esp32c6/lpcore
```

</details>

<details open><summary><b>ESP32-H2 (RISC-V)</b> — 1 board</summary>

```text
esp32h2_devkitm
```

</details>

<details><summary>⚠️ Targets that exist in Zephyr but did not build in this image (16)</summary>

| Target | First error |
|:--|:--|
| `nrf9280pdk/nrf9280/cpuppr` | Linker error (`ld`) when building `hello_world` for this coprocessor core |
| `qemu_arc/qemu_arc_em` | Toolchain for this CPU architecture is not installed in the image |
| `qemu_arc/qemu_arc_hs` | Toolchain for this CPU architecture is not installed in the image |
| `qemu_arc/qemu_arc_hs/xip` | Toolchain for this CPU architecture is not installed in the image |
| `qemu_arc/qemu_arc_hs5x` | Toolchain for this CPU architecture is not installed in the image |
| `qemu_arc/qemu_arc_hs6x` | Toolchain for this CPU architecture is not installed in the image |
| `qemu_leon3/leon3` | Toolchain for this CPU architecture is not installed in the image |
| `qemu_malta/qemu_malta` | Toolchain for this CPU architecture is not installed in the image |
| `qemu_malta/qemu_malta/be` | Toolchain for this CPU architecture is not installed in the image |
| `qemu_or1k/qemu_or1k` | Toolchain for this CPU architecture is not installed in the image |
| `qemu_rx/r5f562n8` | Toolchain for this CPU architecture is not installed in the image |
| `qemu_xtensa/dc233c` | Toolchain for this CPU architecture is not installed in the image |
| `qemu_xtensa/dc233c/mmu` | Toolchain for this CPU architecture is not installed in the image |
| `qemu_xtensa/sample_controller32` | Toolchain for this CPU architecture is not installed in the image |
| `qemu_xtensa/sample_controller32/mpu` | Toolchain for this CPU architecture is not installed in the image |
| `stm32h5f5j_dk/stm32h5f5xx/ext_flash_app` | CMake error in linker-script setup for this external-flash variant |

</details>

Boards from other vendors (NXP, Raspberry Pi, Silicon Labs, TI, …) appear in `west boards` but are **not supported**: their HAL modules are not in the image (add them to `ZEPHYR_MODULES`).

<!-- BOARDS:END -->
