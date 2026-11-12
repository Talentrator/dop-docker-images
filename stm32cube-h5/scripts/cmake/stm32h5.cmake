# STM32CubeH5 firmware for the STM32H503 (NUCLEO-H503RB), with CMake.
#
# In a project's CMakeLists.txt:
#
#   cmake_minimum_required(VERSION 3.22)
#   project(hello C ASM)
#   include($ENV{STM32H5_CMAKE}/stm32h5.cmake)
#   stm32h5_firmware(hello
#     SOURCES Src/main.c Src/stm32h5xx_it.c Src/stm32h5xx_hal_msp.c
#     INCLUDES Inc)
#
# and build it with `stm32h5-build <project folder>`, which passes the toolchain
# file and writes hello.elf, hello.hex, hello.bin and hello.map.
#
# stm32h5_firmware(<name>
#     SOURCES ...         the project's .c/.cpp/.s/.S files
#     [INCLUDES ...]      include folders (Inc/, Core/Inc/ ... are not added for you)
#     [DEFINES ...]       extra compile definitions
#     [LINKER_SCRIPT f]   default: CMSIS's STM32H503xx_FLASH.ld (128 kB flash, 32 kB RAM)
#     [BSP]               add the NUCLEO-64 BSP (stm32h5xx_nucleo.c: BSP_LED_*, BSP_PB_*, BSP_COM_*)
#     [THREADX]           add ThreadX (common + Cortex-M33 GNU port, non-secure)
#     [CMSIS_RTOS2]       add the CMSIS-RTOS2 wrapper over ThreadX (implies THREADX)
#     [LL]                define USE_FULL_LL_DRIVER, for LL init functions
#     [NO_HAL])           do not compile or link the HAL/LL drivers
#
# Added for you unless the project has its own (matched by file name in SOURCES):
#   startup_*.s           -> CMSIS gcc startup_stm32h503xx.s
#   system_stm32h5xx.c    -> CMSIS system_stm32h5xx.c
#   syscalls.c, sysmem.c  -> ST's newlib stubs: _write() sends each byte to
#                            __io_putchar(), which your code must define to reach a UART
#   stm32h5xx_hal_conf.h  -> the NUCLEO-H503RB template's (all modules on), when no INCLUDES folder has one
#   stm32h5xx_nucleo_conf.h (BSP) -> the NUCLEO-H503RB template's

if(NOT DEFINED ENV{STM32CUBEH5} AND NOT DEFINED STM32CUBEH5)
  set(STM32CUBEH5 /opt/st/STM32CubeH5)
elseif(NOT DEFINED STM32CUBEH5)
  set(STM32CUBEH5 $ENV{STM32CUBEH5})
endif()
set(STM32H5_SUPPORT ${CMAKE_CURRENT_LIST_DIR}/support)

set(_CMSIS_DEV ${STM32CUBEH5}/Drivers/CMSIS/Device/ST/STM32H5xx)
set(_HAL ${STM32CUBEH5}/Drivers/STM32H5xx_HAL_Driver)
set(_BSP ${STM32CUBEH5}/Drivers/BSP/STM32H5xx_Nucleo)
set(_TX ${STM32CUBEH5}/Middlewares/ST/threadx)

function(stm32h5_firmware name)
  cmake_parse_arguments(F "BSP;THREADX;CMSIS_RTOS2;LL;NO_HAL" "LINKER_SCRIPT" "SOURCES;INCLUDES;DEFINES" ${ARGN})
  if(F_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "stm32h5_firmware(${name}): unknown arguments ${F_UNPARSED_ARGUMENTS}")
  endif()
  if(NOT F_SOURCES)
    message(FATAL_ERROR "stm32h5_firmware(${name}): no SOURCES")
  endif()
  if(F_CMSIS_RTOS2)
    set(F_THREADX ON)
  endif()

  set(srcs ${F_SOURCES})
  set(names "")
  foreach(s IN LISTS F_SOURCES)
    get_filename_component(n ${s} NAME)
    list(APPEND names ${n})
  endforeach()
  list(FILTER names INCLUDE REGEX "^startup_.*\\.[sS]$")
  if(NOT names)
    list(APPEND srcs ${_CMSIS_DEV}/Source/Templates/gcc/startup_stm32h503xx.s)
  endif()
  foreach(f system_stm32h5xx.c syscalls.c sysmem.c)
    set(have OFF)
    foreach(s IN LISTS F_SOURCES)
      get_filename_component(n ${s} NAME)
      if(n STREQUAL f)
        set(have ON)
      endif()
    endforeach()
    if(NOT have)
      if(f STREQUAL "system_stm32h5xx.c")
        list(APPEND srcs ${_CMSIS_DEV}/Source/Templates/system_stm32h5xx.c)
      else()
        list(APPEND srcs ${STM32H5_SUPPORT}/${f})
      endif()
    endif()
  endforeach()

  # the project's include folders, then the fallback configuration headers
  set(incs "")
  foreach(i IN LISTS F_INCLUDES)
    get_filename_component(a ${i} ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
    list(APPEND incs ${a})
  endforeach()
  set(have_conf OFF)
  foreach(i IN LISTS incs)
    if(EXISTS ${i}/stm32h5xx_hal_conf.h)
      set(have_conf ON)
    endif()
  endforeach()
  if(NOT have_conf)
    list(APPEND incs ${STM32H5_SUPPORT}/conf)
  elseif(F_BSP)
    list(APPEND incs ${STM32H5_SUPPORT}/conf_bsp)   # stm32h5xx_nucleo_conf.h only, after the project's
  endif()
  list(APPEND incs
    ${_CMSIS_DEV}/Include
    ${STM32CUBEH5}/Drivers/CMSIS/Include
    ${_HAL}/Inc
    ${_HAL}/Inc/Legacy)

  set(defs STM32H503xx USE_HAL_DRIVER USE_NUCLEO_64 ${F_DEFINES})
  if(F_LL)
    list(APPEND defs USE_FULL_LL_DRIVER)
  endif()

  if(NOT F_NO_HAL)
    file(GLOB hal_srcs ${_HAL}/Src/*.c)
    list(FILTER hal_srcs EXCLUDE REGEX "_template\\.c$")
    list(APPEND srcs ${hal_srcs})
  endif()
  if(F_BSP)
    list(APPEND srcs ${_BSP}/stm32h5xx_nucleo.c)
    list(APPEND incs ${_BSP})
  endif()
  if(F_THREADX)
    file(GLOB tx_srcs ${_TX}/common/src/*.c)
    foreach(p tx_thread_context_restore tx_thread_context_save tx_thread_interrupt_control
              tx_thread_interrupt_disable tx_thread_interrupt_restore tx_thread_schedule
              tx_thread_stack_build tx_thread_system_return tx_timer_interrupt)
      list(APPEND tx_srcs ${_TX}/ports/cortex_m33/gnu/src/${p}.S)
    endforeach()
    list(APPEND srcs ${tx_srcs})
    list(APPEND incs ${_TX}/common/inc ${_TX}/ports/cortex_m33/gnu/inc)
    list(APPEND defs TX_SINGLE_MODE_NON_SECURE=1)
    foreach(i IN LISTS incs)
      if(EXISTS ${i}/tx_user.h)
        list(APPEND defs TX_INCLUDE_USER_DEFINE_FILE)
        break()
      endif()
    endforeach()
  endif()
  if(F_CMSIS_RTOS2)
    list(APPEND srcs ${STM32CUBEH5}/Middlewares/ST/cmsis_rtos_threadx/cmsis_os2.c)
    list(APPEND incs ${STM32CUBEH5}/Middlewares/ST/cmsis_rtos_threadx ${STM32CUBEH5}/Drivers/CMSIS/RTOS2/Include)
  endif()

  set(ld ${F_LINKER_SCRIPT})
  if(NOT ld)
    set(ld ${_CMSIS_DEV}/Source/Templates/gcc/linker/STM32H503xx_FLASH.ld)
  endif()
  get_filename_component(ld ${ld} ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})

  add_executable(${name} ${srcs})
  set_target_properties(${name} PROPERTIES SUFFIX .elf)
  target_include_directories(${name} PRIVATE ${incs})
  target_compile_definitions(${name} PRIVATE ${defs})
  target_link_options(${name} PRIVATE -T${ld} -Wl,-Map=${CMAKE_CURRENT_BINARY_DIR}/${name}.map,--cref
                      -Wl,--print-memory-usage -Wl,--no-warn-rwx-segments)
  target_link_libraries(${name} PRIVATE -Wl,--start-group c m -Wl,--end-group)
  set_property(TARGET ${name} APPEND PROPERTY LINK_DEPENDS ${ld})
  add_custom_command(TARGET ${name} POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -O ihex $<TARGET_FILE:${name}> ${CMAKE_CURRENT_BINARY_DIR}/${name}.hex
    COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:${name}> ${CMAKE_CURRENT_BINARY_DIR}/${name}.bin
    COMMAND ${CMAKE_SIZE} $<TARGET_FILE:${name}>
    VERBATIM)
endfunction()
