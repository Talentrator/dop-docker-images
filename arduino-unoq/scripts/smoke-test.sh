#!/usr/bin/env bash
# Builds sketches for the Arduino UNO Q with unoq-build, offline: the core's LED
# matrix example (with ArduinoGraphics), the Router Bridge's Monitor example, a
# sketch using both, and that one again with a Python venv first on PATH, as a
# grader's pytest venv is. Checks each makes a .hex holding loader and sketch.
# Usage: unoq-smoke-test
set -uo pipefail

OUT=${SMOKE_OUT:-/tmp/unoq-smoke}
rm -rf "$OUT"; mkdir -p "$OUT"
pass=(); fail=()

build() {   # build NAME SKETCH_DIR
  echo "==> $1"
  if unoq-build -o "$OUT/$1" "$2" >"$OUT/$1.log" 2>&1 \
     && hex=$(ls "$OUT/$1"/*.hex) && grep -q '^:020000040800' "$hex" && grep -q '^:020000040810' "$hex"; then
    pass+=("$1")
  else
    fail+=("$1"); tail -n 30 "$OUT/$1.log"
  fi
}

copy() {    # copy SRC_DIR NAME: a sketch folder named NAME from an example
  mkdir -p "$OUT/src/$2"
  cp -r "$1"/. "$OUT/src/$2/"
  mv "$OUT/src/$2"/*.ino "$OUT/src/$2/$2.ino"
  echo "$OUT/src/$2"
}

build matrix_basic "$(copy "$ARDUINO_CORE/libraries/Arduino_LED_Matrix/examples/Basic" matrix_basic)"
build monitor "$(copy "$ARDUINO_DIRECTORIES_USER/libraries/Arduino_RouterBridge/examples/monitor" monitor)"

mkdir -p "$OUT/src/scroll"
cat > "$OUT/src/scroll/scroll.ino" <<'INO'
#include <Arduino_RouterBridge.h>
#include <ArduinoGraphics.h>
#include "Arduino_LED_Matrix.h"
Arduino_LED_Matrix matrix;
void setup() {
  Monitor.begin();
  matrix.begin();
  matrix.textFont(Font_5x7);
  matrix.textScrollSpeed(100);
  matrix.beginText(13, 1, 0xFFFFFF);
  matrix.print("UNO Q");
  matrix.endText(SCROLL_LEFT);
  Monitor.println("done");
}
void loop() {}
INO
build scroll "$OUT/src/scroll"

python3 -m venv "$OUT/venv"
PATH="$OUT/venv/bin:$PATH" build scroll_in_venv "$OUT/src/scroll"

echo
echo "PASS (${#pass[@]}): ${pass[*]}"
echo "FAIL (${#fail[@]}): ${fail[*]}"
[ ${#fail[@]} -eq 0 ]
