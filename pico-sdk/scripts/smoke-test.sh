#!/usr/bin/env bash
# pico-smoke-test: build Pico firmware the ways a task will.
#   - the hello template for the Pico 2 (USB CDC console, LED blink)
#   - pico-examples for the Pico 2: hello_usb, blink, a PIO program (pioasm),
#     and Wi-Fi blink for the Pico 2 W (cyw43-driver and lwIP)
#   - hello for the RP2040 Pico (the Armv6-M libraries)
#   - hello again with a Python venv first on PATH (as in a grader)
# Prints PASS/FAIL per build and exits non-zero on any failure.
set -uo pipefail

E=$PICO_EXAMPLES_PATH
work=$(mktemp -d /tmp/pico-smoke-XXXX)
trap 'rm -rf "$work"' EXIT
pass=() fail=()

# a one-example project out of pico-examples (its own CMakeLists.txt needs the top-level helpers)
example() {   # example NAME SUBDIR TARGET
  local d="$work/src-$1"
  mkdir -p "$d"
  cp -r "$E/$2/." "$d/"
  { echo 'cmake_minimum_required(VERSION 3.13)'
    echo 'include($ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)'
    echo "project($1 C CXX ASM)"
    echo 'pico_sdk_init()'
    echo 'function(example_auto_set_url TARGET)'
    echo 'endfunction()'
    cat "$E/$2/CMakeLists.txt"; } > "$d/CMakeLists.txt"
  echo "$d"
}

try() {   # try NAME BOARD PROJECT TARGET
  local name=$1 board=$2 project=$3 target=$4 out="$work/out-$1"
  echo "==== $name ($board)"
  if pico-build -b "$board" -o "$out" "$project" > "$work/$name.log" 2>&1 \
     && [ -s "$out/$target.uf2" ] && [ -s "$out/$target.elf" ]; then
    pass+=("$name"); grep -E '^\s+[0-9]+\s+[0-9]+' "$work/$name.log" | tail -1
  else
    fail+=("$name"); tail -40 "$work/$name.log"
  fi
}

try hello          pico2   /opt/pico/templates/hello                     hello
try hello_usb      pico2   "$(example hello_usb hello_world/usb hello_usb)" hello_usb
try blink          pico2   "$(example blink blink blink)"                 blink
try pio_blink      pico2   "$(example pio_blink pio/pio_blink pio_blink)" pio_blink
try picow_blink    pico2_w "$(example picow_blink pico_w/wifi/blink picow_blink)" picow_blink
try hello_rp2040   pico    /opt/pico/templates/hello                     hello

# hello's binary info says it has a USB console (what the bench checks before flashing)
picotool info -a "$work/out-hello/hello.uf2" | grep -q 'USB stdin / stdout' \
  && pass+=(hello_bininfo) || { fail+=(hello_bininfo); picotool info -a "$work/out-hello/hello.uf2"; }

echo "==== hello with a venv first on PATH"
python3 -m venv "$work/venv"
( PATH="$work/venv/bin:$PATH"; VIRTUAL_ENV="$work/venv"; export PATH VIRTUAL_ENV
  pico-build -o "$work/out-venv" /opt/pico/templates/hello > "$work/venv.log" 2>&1 \
  && [ -s "$work/out-venv/hello.uf2" ] ) \
  && pass+=(hello_venv) || { fail+=(hello_venv); tail -30 "$work/venv.log"; }

echo
echo "PASS (${#pass[@]}): ${pass[*]}"
echo "FAIL (${#fail[@]}): ${fail[*]:-}"
[ ${#fail[@]} -eq 0 ]
