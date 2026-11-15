# STM32CubeWB0 firmware for the STM32WB09 (NUCLEO-WB09KE), with CMake.
#
# In a project's CMakeLists.txt:
#
#   cmake_minimum_required(VERSION 3.22)
#   project(hello C ASM)
#   include($ENV{STM32WB0_CMAKE}/stm32wb0.cmake)
#   stm32wb0_firmware(hello
#     SOURCES Src/main.c Src/stm32wb0x_it.c Src/stm32wb0x_hal_msp.c
#     INCLUDES Inc)
#
# and build it with `stm32wb0-build <project folder>`, which passes the toolchain
# file and writes hello.elf, hello.hex, hello.bin and hello.map.
#
# stm32wb0_firmware(<name>
#     SOURCES ...         the project's .c/.cpp/.s/.S files
#     [INCLUDES ...]      include folders (Inc/, Core/Inc/ ... are not added for you)
#     [DEFINES ...]       extra compile definitions
#     [LIBS ...]          extra static libraries (paths) to link
#     [LINKER_SCRIPT f]   default: CMSIS's stm32wb09_flash.ld (512 kB flash at 0x10040000, 64 kB RAM)
#     [BSP]               add the NUCLEO BSP (stm32wb0x_nucleo.c: BSP_LED_*, BSP_PB_*, BSP_COM_*)
#     [BLE]               add the STM32_BLE stack: its prebuilt library, libcrypto, the event
#                         handler and the include folders ST's BLE applications use (the
#                         application still brings its own ble_stack_user_cfg, bleplat, ...)
#     [FREERTOS]          add FreeRTOS (Cortex-M0 GCC port, heap_4) and its CMSIS-RTOS2 wrapper;
#                         the project needs a FreeRTOSConfig.h in one of its INCLUDES
#     [LL]                define USE_FULL_LL_DRIVER, for LL init functions
#     [NO_HAL]            do not compile or link the HAL/LL drivers
#     [RAW])              add nothing at all: SOURCES, INCLUDES, DEFINES and LIBS are the whole
#                         build (what stm32wb0-build uses for ST's STM32CubeIDE examples)
#
# Added for you unless the project has its own (matched by file name in SOURCES):
#   startup_*.s           -> CMSIS gcc startup_stm32wb09.s
#   system_stm32wb0x.c    -> CMSIS system_stm32wb0x.c
#   syscalls.c, sysmem.c  -> ST's newlib stubs: _write() sends each byte to
#                            __io_putchar(), which your code must define to reach a UART
#   stm32wb0x_hal_conf.h  -> the HAL template's (every module on), when no INCLUDES folder has one
#   stm32wb0x_nucleo_conf.h (BSP) -> the NUCLEO-WB09KE examples' (BSP COM off)
#   stm32_assert.h        -> the LL template's (the LL sources include it)

if(NOT DEFINED ENV{STM32CUBEWB0} AND NOT DEFINED STM32CUBEWB0)
  set(STM32CUBEWB0 /opt/st/STM32CubeWB0)
elseif(NOT DEFINED STM32CUBEWB0)
  set(STM32CUBEWB0 $ENV{STM32CUBEWB0})
endif()
set(STM32WB0_SUPPORT ${CMAKE_CURRENT_LIST_DIR}/support)

set(_CMSIS_DEV ${STM32CUBEWB0}/Drivers/CMSIS/Device/ST/STM32WB0X)
set(_HAL ${STM32CUBEWB0}/Drivers/STM32WB0x_HAL_Driver)
set(_BSP ${STM32CUBEWB0}/Drivers/BSP/STM32WB0x-nucleo)
set(_BLE ${STM32CUBEWB0}/Middlewares/ST/STM32_BLE)
set(_FRT ${STM32CUBEWB0}/Middlewares/Third_Party/FreeRTOS/Source)

function(_stm32wb0_abs out)
  set(r "")
  foreach(i IN LISTS ARGN)
    get_filename_component(a ${i} ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
    list(APPEND r ${a})
  endforeach()
  set(${out} ${r} PARENT_SCOPE)
endfunction()

function(stm32wb0_firmware name)
  cmake_parse_arguments(F "BSP;BLE;FREERTOS;LL;NO_HAL;RAW" "LINKER_SCRIPT" "SOURCES;INCLUDES;DEFINES;LIBS" ${ARGN})
  if(F_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "stm32wb0_firmware(${name}): unknown arguments ${F_UNPARSED_ARGUMENTS}")
  endif()
  if(NOT F_SOURCES)
    message(FATAL_ERROR "stm32wb0_firmware(${name}): no SOURCES")
  endif()

  set(srcs ${F_SOURCES})
  _stm32wb0_abs(incs ${F_INCLUDES})
  _stm32wb0_abs(libs ${F_LIBS})
  set(defs ${F_DEFINES})

  if(NOT F_RAW)
    set(names "")
    foreach(s IN LISTS F_SOURCES)
      get_filename_component(n ${s} NAME)
      list(APPEND names ${n})
    endforeach()
    set(startups ${names})
    list(FILTER startups INCLUDE REGEX "^startup_.*\\.[sS]$")
    if(NOT startups)
      list(APPEND srcs ${_CMSIS_DEV}/Source/Templates/gcc/startup_stm32wb09.s)
    endif()
    if(NOT "system_stm32wb0x.c" IN_LIST names)
      list(APPEND srcs ${_CMSIS_DEV}/Source/Templates/system_stm32wb0x.c)
    endif()
    foreach(f syscalls.c sysmem.c)
      if(NOT f IN_LIST names)
        list(APPEND srcs ${STM32WB0_SUPPORT}/${f})
      endif()
    endforeach()

    # the project's include folders, then the fallback configuration headers
    set(have_conf OFF)
    foreach(i IN LISTS incs)
      if(EXISTS ${i}/stm32wb0x_hal_conf.h)
        set(have_conf ON)
      endif()
    endforeach()
    if(NOT have_conf)
      list(APPEND incs ${STM32WB0_SUPPORT}/conf)
    elseif(F_BSP)
      list(APPEND incs ${STM32WB0_SUPPORT}/conf_bsp)   # stm32wb0x_nucleo_conf.h only, after the project's
    endif()
    list(APPEND incs
      ${_CMSIS_DEV}/Include
      ${STM32CUBEWB0}/Drivers/CMSIS/Include
      ${_HAL}/Inc
      ${_HAL}/Inc/Legacy
      ${STM32WB0_SUPPORT}/fallback)     # stm32_assert.h for the LL sources, when the project has none

    list(APPEND defs STM32WB09 NUCLEO_WB09KE USE_HAL_DRIVER)
    if(F_LL)
      list(APPEND defs USE_FULL_LL_DRIVER)
    endif()

    if(NOT F_NO_HAL)
      file(GLOB hal_srcs ${_HAL}/Src/*.c)
      list(FILTER hal_srcs EXCLUDE REGEX "_template\\.c$")
      list(APPEND srcs ${hal_srcs})
    endif()
    if(F_BSP)
      list(APPEND srcs ${_BSP}/stm32wb0x_nucleo.c)
      list(APPEND incs ${_BSP})
    endif()
    if(F_BLE)
      list(APPEND srcs ${_BLE}/evt_handler/src/ble_evt.c)
      list(APPEND incs ${_BLE} ${_BLE}/stack/include ${_BLE}/evt_handler/inc ${_BLE}/queued_writes/inc
                       ${_BLE}/cryptolib/Inc ${_BLE}/cryptolib/Inc/Common ${_BLE}/cryptolib/Inc/AES
                       ${_BLE}/cryptolib/Inc/AES/CBC ${_BLE}/cryptolib/Inc/AES/CMAC
                       ${_BLE}/cryptolib/Inc/AES/Common ${_BLE}/cryptolib/Inc/AES/ECB)
      list(APPEND libs ${_BLE}/stack/lib/stm32wb0x_ble_stack.a ${_BLE}/cryptolib/libcrypto.a)
    endif()
    if(F_FREERTOS)
      file(GLOB frt_srcs ${_FRT}/*.c)
      list(APPEND srcs ${frt_srcs} ${_FRT}/portable/GCC/ARM_CM0/port.c ${_FRT}/portable/MemMang/heap_4.c
                       ${_FRT}/CMSIS_RTOS_V2/cmsis_os2.c)
      list(APPEND incs ${_FRT}/include ${_FRT}/portable/GCC/ARM_CM0 ${_FRT}/CMSIS_RTOS_V2
                       ${STM32CUBEWB0}/Drivers/CMSIS/RTOS2/Include)
    endif()
  endif()

  set(ld ${F_LINKER_SCRIPT})
  if(NOT ld)
    set(ld ${_CMSIS_DEV}/Source/Templates/gcc/linker/stm32wb09_flash.ld)
  endif()
  get_filename_component(ld ${ld} ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})

  add_executable(${name} ${srcs})
  set_target_properties(${name} PROPERTIES SUFFIX .elf)
  target_include_directories(${name} PRIVATE ${incs})
  target_compile_definitions(${name} PRIVATE ${defs})
  target_link_options(${name} PRIVATE -T${ld} -Wl,-Map=${CMAKE_CURRENT_BINARY_DIR}/${name}.map,--cref
                      -Wl,--print-memory-usage -Wl,--no-warn-rwx-segments)
  target_link_libraries(${name} PRIVATE -Wl,--start-group ${libs} c m -Wl,--end-group)
  set_property(TARGET ${name} APPEND PROPERTY LINK_DEPENDS ${ld})
  add_custom_command(TARGET ${name} POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -O ihex $<TARGET_FILE:${name}> ${CMAKE_CURRENT_BINARY_DIR}/${name}.hex
    COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:${name}> ${CMAKE_CURRENT_BINARY_DIR}/${name}.bin
    COMMAND ${CMAKE_SIZE} $<TARGET_FILE:${name}>
    VERBATIM)
endfunction()
