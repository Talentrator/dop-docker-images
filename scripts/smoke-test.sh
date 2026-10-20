#!/usr/bin/env bash
# Builds hello_world for one board per supported family and runs it on QEMU.
# Usage: zephyr-smoke-test [board ...]
set -uo pipefail

BOARDS=("$@")
if [ ${#BOARDS[@]} -eq 0 ]; then
  BOARDS=(
    qemu_x86
    qemu_cortex_m3
    qemu_riscv32
    qemu_cortex_a53
    nrf52840dk/nrf52840
    nrf5340dk/nrf5340/cpuapp
    nucleo_f401re
    nucleo_h743zi
    esp32_devkitc/esp32/procpu
    esp32s3_devkitc/esp32s3/procpu
    esp32c3_devkitm
  )
fi

OUT=${SMOKE_OUT:-/tmp/zephyr-smoke}
mkdir -p "$OUT"
pass=(); fail=()

for b in "${BOARDS[@]}"; do
  dir="$OUT/${b//\//_}"
  echo "==> Building hello_world for $b"
  if west build -p always -b "$b" -d "$dir" "$ZEPHYR_BASE/samples/hello_world" >"$dir.log" 2>&1; then
    pass+=("$b")
  else
    fail+=("$b"); tail -n 20 "$dir.log"
  fi
done

if [ -d "$OUT/qemu_cortex_m3" ]; then
  echo "==> Running qemu_cortex_m3 in QEMU"
  # QEMU never exits on its own; stop it after a few seconds and check its output
  timeout 20 west build -d "$OUT/qemu_cortex_m3" -t run >"$OUT/qemu_run.log" 2>&1 </dev/null
  if grep -q "Hello World" "$OUT/qemu_run.log"; then
    pass+=("qemu_cortex_m3 (run)")
  else
    fail+=("qemu_cortex_m3 (run)")
  fi
fi

echo
echo "PASS (${#pass[@]}): ${pass[*]}"
echo "FAIL (${#fail[@]}): ${fail[*]}"
[ ${#fail[@]} -eq 0 ]
