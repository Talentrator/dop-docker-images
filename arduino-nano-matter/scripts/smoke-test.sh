#!/usr/bin/env bash
# Builds sketches for the Arduino Nano Matter with nano-matter-build, offline: a Serial + RGB
# LED sketch with no radio stack, the core's Matter lightbulb example (Matter stack), its BLE
# example (Silabs BLE stack), and the first one again with a Python venv first on PATH, as a
# grader's pytest venv is. Checks each makes a .hex holding bootloader and sketch.
# Usage: nano-matter-smoke-test
set -uo pipefail

OUT=${SMOKE_OUT:-/tmp/nano-matter-smoke}
rm -rf "$OUT"; mkdir -p "$OUT"
pass=(); fail=()

build() {   # build NAME STACK SKETCH_DIR
  echo "==> $1 ($2)"
  if nano-matter-build -s "$2" -o "$OUT/$1" "$3" >"$OUT/$1.log" 2>&1 \
     && hex=$(ls "$OUT/$1"/*.hex | grep -v '\.sketch\.hex$') \
     && grep -q '^:100000' "$hex" && grep -q '^:1060000' "$hex"; then
    pass+=("$1")
  else
    fail+=("$1"); tail -n 30 "$OUT/$1.log"
  fi
}

copy() {    # copy SRC_DIR NAME: a sketch folder named NAME from an example
  mkdir -p "$OUT/src/$2"
  cp -r "$1"/. "$OUT/src/$2/"
  [ -f "$OUT/src/$2/$2.ino" ] || mv "$OUT/src/$2"/*.ino "$OUT/src/$2/$2.ino"
  echo "$OUT/src/$2"
}

mkdir -p "$OUT/src/rgb"
cat > "$OUT/src/rgb/rgb.ino" <<'INO'
void setup() {
  pinMode(LEDR, OUTPUT); pinMode(LEDG, OUTPUT); pinMode(LEDB, OUTPUT);
  Serial.begin(115200);
  Serial.println("Hello World");
}
void loop() {
  static int n = 0;
  digitalWrite(LEDR, n % 3 == 0 ? LED_BUILTIN_ACTIVE : LED_BUILTIN_INACTIVE);
  digitalWrite(LEDG, n % 3 == 1 ? LED_BUILTIN_ACTIVE : LED_BUILTIN_INACTIVE);
  digitalWrite(LEDB, n % 3 == 2 ? LED_BUILTIN_ACTIVE : LED_BUILTIN_INACTIVE);
  n++;
  delay(500);
}
INO
build rgb none "$OUT/src/rgb"

matter=$(dirname "$(find "$ARDUINO_CORE/libraries/Matter/examples" -name 'matter_lightbulb.ino' | head -1)")
build matter_lightbulb matter "$(copy "$matter" matter_lightbulb)"

ble=$(dirname "$(find "$ARDUINO_CORE/libraries" -path '*examples*' -name 'ble_blinky.ino' | head -1)")
build ble_blinky ble_silabs "$(copy "$ble" ble_blinky)"

python3 -m venv "$OUT/venv"
PATH="$OUT/venv/bin:$PATH" build rgb_in_venv none "$OUT/src/rgb"

echo
echo "PASS (${#pass[@]}): ${pass[*]}"
echo "FAIL (${#fail[@]}): ${fail[*]}"
[ ${#fail[@]} -eq 0 ]
