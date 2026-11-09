#!/usr/bin/env bash
# Builds three SDK samples for the xG24 Dev Kit with sisdk-build: a bare-metal
# VCOM echo (the platform), Bluetooth SoC Empty (the Bluetooth stack's
# prebuilt LTO libraries, which only a zstd-capable GCC links) and the AppLoader
# bootloader, and the VCOM echo once more with a Python venv active.
# Usage: sisdk-smoke-test [board]
set -uo pipefail

board=${1:-brd2601b}
OUT=${SMOKE_OUT:-/tmp/sisdk-smoke}
mkdir -p "$OUT"
pass=(); fail=()

build() {   # build NAME SLCP
  echo "==> $1"
  if sisdk-build -b "$board" -o "$OUT/$1" "$2" >"$OUT/$1.log" 2>&1 && ls "$OUT/$1"/*.hex >/dev/null 2>&1; then
    pass+=("$1")
  else
    fail+=("$1"); tail -n 30 "$OUT/$1.log"
  fi
}

build iostream "$SISDK/platform_sample_app/app/common/example/iostream_usart_baremetal/iostream_usart_baremetal.slcp"
build bt_soc_empty "$SISDK/bluetooth_le_app/example/bt_soc_empty/bt_soc_empty.slcp"
build bootloader "$SISDK/bluetooth_le_app/bootloader/bootloader-apploader.slcp"

# again with a Python venv first on PATH, as a grader's pytest venv is: slc's
# generators once failed under one ("No module named 'jinja2'")
python3 -m venv "$OUT/venv"
PATH="$OUT/venv/bin:$PATH" build iostream_in_venv "$SISDK/platform_sample_app/app/common/example/iostream_usart_baremetal/iostream_usart_baremetal.slcp"

echo
echo "PASS (${#pass[@]}): ${pass[*]}"
echo "FAIL (${#fail[@]}): ${fail[*]}"
[ ${#fail[@]} -eq 0 ]
