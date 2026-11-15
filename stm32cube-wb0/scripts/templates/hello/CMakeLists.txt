cmake_minimum_required(VERSION 3.22)
project(hello C ASM)
include($ENV{STM32WB0_CMAKE}/stm32wb0.cmake)

# Startup, system_stm32wb0x.c, newlib stubs, the HAL and the linker script
# come from the SDK; see $STM32WB0_CMAKE/stm32wb0.cmake for the options.
stm32wb0_firmware(hello
  SOURCES Src/main.c
  INCLUDES Inc)
