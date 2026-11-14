#!/usr/bin/env bash
# esp32s3-smoke-test: build ESP32-S3 firmware the ways a task will.
#   - the hello template (USB Serial/JTAG console, the board's own)
#   - the tft template (the board's ST7789 over SPI with esp_lcd)
#   - IDF examples: hello_world, Wi-Fi station
#     (links the Wi-Fi and PHY blobs), NimBLE peripheral (the BLE controller)
#   - hello again with a Python venv first on PATH (as in a grader)
# Prints PASS/FAIL per build and exits non-zero on any failure.
set -uo pipefail

E=$IDF_PATH/examples
work=$(mktemp -d /tmp/esp32s3-smoke-XXXX)
trap 'rm -rf "$work"' EXIT
pass=() fail=()

try() {   # try NAME PROJECT
  local name=$1 project=$2 out="$work/out-$1"
  echo "==== $name"
  if esp32s3-build -o "$out" "$project" > "$work/$name.log" 2>&1 \
     && [ -n "$(find "$out" -name '*.bin' ! -name '*.app.bin' -size +16k)" ]; then
    pass+=("$name"); tail -n 7 "$work/$name.log" | head -1
  else
    fail+=("$name"); tail -40 "$work/$name.log"
  fi
}

try hello         /opt/esp/templates/hello
try hello_world   $E/get-started/hello_world
try tft           /opt/esp/templates/tft
try wifi_station  $E/wifi/getting_started/station
try nimble_bleprph $E/bluetooth/nimble/bleprph

echo "==== hello with a venv first on PATH"
python3 -m venv "$work/venv"
( PATH="$work/venv/bin:$PATH"; VIRTUAL_ENV="$work/venv"; export PATH VIRTUAL_ENV
  esp32s3-build -o "$work/out-venv" /opt/esp/templates/hello > "$work/venv.log" 2>&1 \
  && [ -f "$work/out-venv/hello.bin" ] ) \
  && pass+=(hello_venv) || { fail+=(hello_venv); tail -30 "$work/venv.log"; }

echo
echo "PASS (${#pass[@]}): ${pass[*]}"
echo "FAIL (${#fail[@]}): ${fail[*]:-}"
[ ${#fail[@]} -eq 0 ]
