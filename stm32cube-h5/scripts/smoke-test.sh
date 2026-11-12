#!/usr/bin/env bash
# stm32h5-smoke-test: build NUCLEO-H503RB firmware the ways a task will.
#   - the hello template (CMake, stm32h5_firmware)
#   - ST examples as they are: HAL (UART printf, GPIO), LL (USART VCP)
#   - the ThreadX + CMSIS-RTOS2 application (the heaviest stack the H503 runs)
#   - hello again with a Python venv first on PATH (as in a grader)
# Prints PASS/FAIL per build and exits non-zero on any failure.
set -uo pipefail

P=$STM32CUBEH5/Projects/NUCLEO-H503RB
work=$(mktemp -d /tmp/stm32h5-smoke-XXXX)
trap 'rm -rf "$work"' EXIT
pass=() fail=()

try() {   # try NAME PROJECT [expected .elf]
  local name=$1 project=$2 out="$work/out-$1"
  echo "==== $name"
  if stm32h5-build -o "$out" "$project" > "$work/$name.log" 2>&1 \
     && [ -n "$(find "$out" -name '*.hex' -size +1k)" ] && [ -n "$(find "$out" -name '*.elf')" ]; then
    pass+=("$name"); arm-none-eabi-size "$out"/*.elf | tail -1
  else
    fail+=("$name"); tail -30 "$work/$name.log"
  fi
}

try hello              /opt/st/templates/hello
try uart_printf        $P/Examples/UART/UART_Printf
try gpio_iotoggle      $P/Examples/GPIO/GPIO_IOToggle
try ll_usart_vcp       $P/Examples_LL/USART/USART_Communication_Tx_VCP_Init
try threadx_cmsis_rtos $P/Applications/ThreadX/Tx_CMSIS_Wrapper

echo "==== hello with a venv first on PATH"
python3 -m venv "$work/venv"
( PATH="$work/venv/bin:$PATH"; try_out="$work/out-venv"
  stm32h5-build -o "$try_out" /opt/st/templates/hello > "$work/venv.log" 2>&1 && [ -f "$try_out/hello.hex" ] ) \
  && pass+=(hello_venv) || { fail+=(hello_venv); tail -30 "$work/venv.log"; }

echo
echo "PASS (${#pass[@]}): ${pass[*]}"
echo "FAIL (${#fail[@]}): ${fail[*]:-}"
[ ${#fail[@]} -eq 0 ]
