#!/usr/bin/env bash
# psoc6-smoke-test: build CY8CKIT-062S2-AI firmware the ways a task will.
#   - the blinky template (HAL, retarget-io)
#   - the blinky_freertos template (FreeRTOS + abstraction-rtos + clib-support)
#   - Infineon's HAL code examples as they are, with their own Makefiles
#   - `make build` in a code example (the stand-in start.mk)
#   - blinky again with a Python venv first on PATH (as in a grader)
# Prints PASS/FAIL per build and exits non-zero on any failure.
set -uo pipefail

work=$(mktemp -d /tmp/psoc6-smoke-XXXX)
trap 'rm -rf "$work"' EXIT
pass=() fail=()

try() {   # try NAME PROJECT
  local name=$1 project=$2 out="$work/out-$1"
  echo "==== $name"
  if psoc6-build -o "$out" "$project" > "$work/$name.log" 2>&1 \
     && [ -n "$(find "$out" -name '*.hex' -size +1k)" ] && [ -n "$(find "$out" -name '*.elf')" ]; then
    pass+=("$name"); arm-none-eabi-size "$out"/*.elf | tail -1
  else
    fail+=("$name"); tail -30 "$work/$name.log"
  fi
}

try blinky          /opt/mtb/templates/blinky
# the BSP's clock and pin setup must be linked in (cybsp_init -> cycfg_config_init -> init_cycfg_system)
echo "==== BSP configuration linked"
if arm-none-eabi-nm "$work/out-blinky/blinky.elf" 2>/dev/null | grep -q ' init_cycfg_system$'; then
  pass+=(bsp_config)
else
  fail+=(bsp_config); echo "init_cycfg_system is not in blinky.elf: cybsp_init() would skip the BSP clock setup"
fi
try blinky_freertos /opt/mtb/templates/blinky_freertos
for ex in /opt/mtb/examples/*/; do
  try "$(basename "$ex")" "$ex"
done

echo "==== make build in a code example"
cp -r /opt/mtb/examples/hal-hello-world "$work/mk"
( cd "$work/mk" && make build > "$work/make.log" 2>&1 && ls build/*/*/*.hex >/dev/null ) \
  && pass+=(make_build) || { fail+=(make_build); tail -30 "$work/make.log"; }

echo "==== blinky with a venv first on PATH"
python3 -m venv "$work/venv"
( PATH="$work/venv/bin:$PATH"
  psoc6-build -o "$work/out-venv" /opt/mtb/templates/blinky > "$work/venv.log" 2>&1 && [ -f "$work/out-venv/blinky.hex" ] ) \
  && pass+=(blinky_venv) || { fail+=(blinky_venv); tail -30 "$work/venv.log"; }

echo
echo "PASS (${#pass[@]}): ${pass[*]}"
echo "FAIL (${#fail[@]}): ${fail[*]:-}"
[ ${#fail[@]} -eq 0 ]
