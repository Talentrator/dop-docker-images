# CMake toolchain file: Arm GNU Toolchain (arm-none-eabi) for the STM32WB0's Cortex-M0+.
# stm32wb0-build passes it as CMAKE_TOOLCHAIN_FILE; to build by hand:
#   cmake -G Ninja -B build -DCMAKE_TOOLCHAIN_FILE=$STM32WB0_CMAKE/arm-none-eabi.cmake

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(CMAKE_C_COMPILER arm-none-eabi-gcc)
set(CMAKE_CXX_COMPILER arm-none-eabi-g++)
set(CMAKE_ASM_COMPILER arm-none-eabi-gcc)
set(CMAKE_OBJCOPY arm-none-eabi-objcopy CACHE FILEPATH "")
set(CMAKE_SIZE arm-none-eabi-size CACHE FILEPATH "")

# no host executables can run: test the compiler with a static library
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

set(STM32WB0_CPU_FLAGS "-mcpu=cortex-m0plus -mthumb -mfloat-abi=soft")
set(CMAKE_C_FLAGS_INIT "${STM32WB0_CPU_FLAGS} -ffunction-sections -fdata-sections -Wall")
set(CMAKE_CXX_FLAGS_INIT "${STM32WB0_CPU_FLAGS} -ffunction-sections -fdata-sections -Wall -fno-exceptions -fno-rtti")
set(CMAKE_ASM_FLAGS_INIT "${STM32WB0_CPU_FLAGS} -x assembler-with-cpp")
set(CMAKE_EXE_LINKER_FLAGS_INIT "${STM32WB0_CPU_FLAGS} --specs=nano.specs -Wl,--gc-sections")

set(CMAKE_C_FLAGS_DEBUG "-Og -g3")
set(CMAKE_C_FLAGS_RELEASE "-Os -g")
set(CMAKE_CXX_FLAGS_DEBUG "-Og -g3")
set(CMAKE_CXX_FLAGS_RELEASE "-Os -g")
set(CMAKE_ASM_FLAGS_DEBUG "-g3")
set(CMAKE_ASM_FLAGS_RELEASE "-g")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
