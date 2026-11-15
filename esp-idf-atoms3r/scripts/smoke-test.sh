#!/usr/bin/env bash
# atoms3r-smoke-test: build AtomS3R firmware the ways a task will.
#   - the hello, lcd (GC9107 + LP5562 backlight) and echo (ES8311 through esp_codec_dev)
#     templates
#   - a project with no sdkconfig.defaults (the board's defaults alone: 8 MB flash)
#   - IDF examples: hello_world and the Wi-Fi station (links the Wi-Fi and PHY blobs)
#   - echo again with a Python venv first on PATH (as in a grader)
# Prints PASS/FAIL per build and exits non-zero on any failure.
set -uo pipefail

T=/opt/esp/atoms3r/templates
E=$IDF_PATH/examples
work=$(mktemp -d /tmp/atoms3r-smoke-XXXX)
trap 'rm -rf -- "${work:?}"' EXIT
pass=() fail=()

try() {   # try NAME PROJECT [CHECK]
  local name=$1 project=$2 out="$work/out-$1"
  echo "==== $name"
  if atoms3r-build -o "$out" "$project" > "$work/$name.log" 2>&1 \
     && [ -n "$(find "$out" -name '*.bin' ! -name '*.app.bin' -size +16k)" ] \
     && { [ -z "${3:-}" ] || eval "$3"; }; then
    pass+=("$name")
  else
    fail+=("$name"); tail -40 "$work/$name.log"
  fi
}

try hello        $T/hello
try lcd          $T/lcd
try echo         $T/echo
# the board's defaults reach a project without its own
mkdir -p "$work/bare"
cp -r $T/hello/. "$work/bare/"
mv "$work/bare/sdkconfig.defaults" "$work/bare-sdkconfig.defaults"
try bare_8mb     "$work/bare" 'grep -q -- "--flash_size 8MB" "$out/flash_args"'
try hello_world  $E/get-started/hello_world
try wifi_station $E/wifi/getting_started/station

echo "==== echo with a venv first on PATH"
python3 -m venv "$work/venv"
( PATH="$work/venv/bin:$PATH"; VIRTUAL_ENV="$work/venv"; export PATH VIRTUAL_ENV
  atoms3r-build -o "$work/out-venv" $T/echo > "$work/venv.log" 2>&1 \
  && [ -f "$work/out-venv/echo.bin" ] ) \
  && pass+=(echo_venv) || { fail+=(echo_venv); tail -30 "$work/venv.log"; }

echo
echo "PASS (${#pass[@]}): ${pass[*]}"
echo "FAIL (${#fail[@]}): ${fail[*]:-}"
[ ${#fail[@]} -eq 0 ]
