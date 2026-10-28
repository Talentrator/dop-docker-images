#!/usr/bin/env bash
# Builds hello_world for one QEMU board per architecture and runs each on QEMU.
# Usage: zephyr-smoke-test [board ...]
set -uo pipefail

BOARDS=("$@")
if [ ${#BOARDS[@]} -eq 0 ]; then
  BOARDS=(qemu_cortex_m3 qemu_riscv32 qemu_x86 qemu_cortex_a53)
fi

OUT=${SMOKE_OUT:-/tmp/zephyr-smoke}
mkdir -p "$OUT"
pass=(); fail=()

for b in "${BOARDS[@]}"; do
  dir="$OUT/${b//\//_}"
  echo "==> Building hello_world for $b"
  if ! west build -p always -b "$b" -d "$dir" "$ZEPHYR_BASE/samples/hello_world" >"$dir.log" 2>&1; then
    fail+=("$b"); tail -n 20 "$dir.log"; continue
  fi
  echo "==> Running $b in QEMU"
  # QEMU never exits on its own; stop it after a few seconds and check its output
  timeout 20 west build -d "$dir" -t run >"$dir.run.log" 2>&1 </dev/null
  if grep -q "Hello World" "$dir.run.log"; then
    pass+=("$b")
  else
    fail+=("$b (run)"); tail -n 20 "$dir.run.log"
  fi
done

echo
echo "PASS (${#pass[@]}): ${pass[*]}"
echo "FAIL (${#fail[@]}): ${fail[*]}"
[ ${#fail[@]} -eq 0 ]
