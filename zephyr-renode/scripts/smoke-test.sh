#!/usr/bin/env bash
# Builds hello_world for each Renode board and runs it on Renode, has
# renode-test check one board's UART from a Robot test, then has twister
# build and run hello_world once on the board Zephyr itself runs on Renode.
# Usage: zephyr-smoke-test [board ...]
set -uo pipefail

BOARDS=("$@")
if [ ${#BOARDS[@]} -eq 0 ]; then
  BOARDS=(stm32f4_disco nucleo_f767zi stm32f072b_disco nrf52840dk/nrf52840 cortex_r8_virtual)
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
  echo "==> Running $b on Renode"
  if zephyr-renode-run -t 2 "$dir" >"$dir.run.log" 2>&1 && grep -q "Hello World" "$dir.run.log"; then
    pass+=("$b")
  else
    fail+=("$b (run)"); tail -n 20 "$dir.run.log"
  fi
done

echo "==> renode-test: a Robot test on stm32f4_disco's UART"
elf="$OUT/stm32f4_disco/zephyr/zephyr.elf"
cat >"$OUT/hello.robot" <<EOF
*** Settings ***
Suite Setup       Setup
Suite Teardown    Teardown
Test Teardown     Test Teardown
Resource          \${RENODEKEYWORDS}

*** Test Cases ***
Should Print Hello
    Execute Command           mach create
    Execute Command           machine LoadPlatformDescription @platforms/boards/stm32f4_discovery.repl
    Execute Command           sysbus LoadELF @$elf
    Create Terminal Tester    sysbus.usart2
    Start Emulation
    Wait For Line On Uart     Hello World!    timeout=2
EOF
if [ -f "$elf" ] && (cd "$OUT" && renode-test "$OUT/hello.robot") >"$OUT/robot.log" 2>&1; then
  pass+=("renode-test")
else
  fail+=("renode-test"); tail -n 30 "$OUT/robot.log"
fi

echo "==> twister: hello_world on cortex_r8_virtual"
if west twister -p cortex_r8_virtual -T "$ZEPHYR_BASE/samples/hello_world" -O "$OUT/twister" >"$OUT/twister.log" 2>&1 \
   && grep -q "1 of 1 executed test configurations passed" "$OUT/twister.log"; then
  pass+=("twister")
else
  fail+=("twister"); tail -n 30 "$OUT/twister.log"
fi

echo
echo "PASS (${#pass[@]}): ${pass[*]}"
echo "FAIL (${#fail[@]}): ${fail[*]}"
[ ${#fail[@]} -eq 0 ]
