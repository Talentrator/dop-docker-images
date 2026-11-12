cmake_minimum_required(VERSION 3.22)
project(hello C ASM)
include($ENV{STM32H5_CMAKE}/stm32h5.cmake)

# Startup, system_stm32h5xx.c, newlib stubs, the HAL and the linker script
# come from the SDK; see $STM32H5_CMAKE/stm32h5.cmake for the options.
stm32h5_firmware(hello
  SOURCES Src/main.c
  INCLUDES Inc)
