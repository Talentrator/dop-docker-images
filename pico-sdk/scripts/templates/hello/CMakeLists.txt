cmake_minimum_required(VERSION 3.13)

# the SDK first: it sets up the cross compiler before project()
include($ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)

project(hello C CXX ASM)
pico_sdk_init()

add_executable(hello main.c)
target_link_libraries(hello pico_stdlib)

# the console is the board's USB port (USB CDC), not a UART
pico_enable_stdio_usb(hello 1)
pico_enable_stdio_uart(hello 0)

# hello.uf2, .bin, .hex, .dis next to hello.elf
pico_add_extra_outputs(hello)
