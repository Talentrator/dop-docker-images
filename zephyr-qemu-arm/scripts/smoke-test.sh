#!/usr/bin/env bash
# Builds hello_world for each Arm QEMU board and runs it on QEMU, then has
# twister build and run it once, as a check that its Python tooling is in.
# Usage: zephyr-smoke-test [board ...]
set -uo pipefail

BOARDS=("$@")
if [ ${#BOARDS[@]} -eq 0 ]; then
  BOARDS=(qemu_cortex_m3 qemu_cortex_r5 qemu_cortex_a9)
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

echo "==> twister: hello_world on qemu_cortex_m3"
if west twister -p qemu_cortex_m3 -T "$ZEPHYR_BASE/samples/hello_world" -O "$OUT/twister" >"$OUT/twister.log" 2>&1; then
  pass+=("twister")
else
  fail+=("twister"); tail -n 30 "$OUT/twister.log"
fi

echo
echo "PASS (${#pass[@]}): ${pass[*]}"
echo "FAIL (${#fail[@]}): ${fail[*]}"
[ ${#fail[@]} -eq 0 ]
