#!/usr/bin/env bash
# stm32wb0-smoke-test: build NUCLEO-WB09KE firmware the ways a task will.
#   - the hello template (CMake, stm32wb0_firmware)
#   - ST examples as they are, from their STM32CubeIDE projects: HAL UART
#     printf, GPIO, LL USART, the FreeRTOS application
#   - the radio and the BLE stack (the prebuilt stack library and libcrypto)
#   - a BLE example copied out of the SDK, as an agent would
#   - hello again with a Python venv first on PATH (as in a grader)
# Prints PASS/FAIL per build and exits non-zero on any failure.
set -uo pipefail

P=$STM32CUBEWB0/Projects/NUCLEO-WB09KE
work=$(mktemp -d /tmp/stm32wb0-smoke-XXXX)
trap 'rm -rf "$work"' EXIT
pass=() fail=()

try() {   # try NAME PROJECT
  local name=$1 project=$2 out="$work/out-$1"
  echo "==== $name"
  if stm32wb0-build -o "$out" "$project" > "$work/$name.log" 2>&1 \
     && [ -n "$(find "$out" -name '*.hex' -size +1k)" ] && [ -n "$(find "$out" -name '*.elf')" ]; then
    pass+=("$name"); arm-none-eabi-size "$out"/*.elf | tail -1
  else
    fail+=("$name"); tail -30 "$work/$name.log"
  fi
}

try hello              /opt/st/templates/hello
try uart_printf        $P/Examples/UART/UART_Printf
try gpio_iotoggle      $P/Examples/GPIO/GPIO_IOToggle
try ll_usart           $P/Examples_LL/USART/USART_Communication_Tx_IT_Init
try freertos_mutex     $P/Applications/FreeRTOS/FreeRTOS_Mutex
try radio_beep         $P/Examples/RADIO/RADIO_Beep
try ble_p2pserver      $P/Applications/BLE/BLE_p2pServer
try ble_heartrate      $P/Applications/BLE/BLE_HeartRate
cp -r $P/Applications/BLE/BLE_Beacon "$work/BLE_Beacon_copy"
try ble_beacon_copied  "$work/BLE_Beacon_copy"

echo "==== hello with a venv first on PATH"
python3 -m venv "$work/venv"
( PATH="$work/venv/bin:$PATH"; try_out="$work/out-venv"
  stm32wb0-build -o "$try_out" /opt/st/templates/hello > "$work/venv.log" 2>&1 && [ -f "$try_out/hello.hex" ] \
  && stm32wb0-build -o "$try_out" $P/Examples/UART/UART_Printf > "$work/venv2.log" 2>&1 && [ -f "$try_out/UART_Printf.hex" ] ) \
  && pass+=(venv) || { fail+=(venv); tail -n 30 "$work/venv.log" "$work/venv2.log"; }

echo
echo "PASS (${#pass[@]}): ${pass[*]}"
echo "FAIL (${#fail[@]}): ${fail[*]:-}"
[ ${#fail[@]} -eq 0 ]
