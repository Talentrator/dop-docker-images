# CMake toolchain file: Arm GNU Toolchain (arm-none-eabi) for the STM32H5's Cortex-M33.
# stm32h5-build passes it as CMAKE_TOOLCHAIN_FILE; to build by hand:
#   cmake -G Ninja -B build -DCMAKE_TOOLCHAIN_FILE=$STM32H5_CMAKE/arm-none-eabi.cmake

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(CMAKE_C_COMPILER arm-none-eabi-gcc)
set(CMAKE_CXX_COMPILER arm-none-eabi-g++)
set(CMAKE_ASM_COMPILER arm-none-eabi-gcc)
set(CMAKE_OBJCOPY arm-none-eabi-objcopy CACHE FILEPATH "")
set(CMAKE_SIZE arm-none-eabi-size CACHE FILEPATH "")

# no host executables can run: test the compiler with a static library
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

set(STM32H5_CPU_FLAGS "-mcpu=cortex-m33 -mthumb -mfpu=fpv5-sp-d16 -mfloat-abi=hard")
set(CMAKE_C_FLAGS_INIT "${STM32H5_CPU_FLAGS} -ffunction-sections -fdata-sections -Wall")
set(CMAKE_CXX_FLAGS_INIT "${STM32H5_CPU_FLAGS} -ffunction-sections -fdata-sections -Wall -fno-exceptions -fno-rtti")
set(CMAKE_ASM_FLAGS_INIT "${STM32H5_CPU_FLAGS} -x assembler-with-cpp")
set(CMAKE_EXE_LINKER_FLAGS_INIT "${STM32H5_CPU_FLAGS} --specs=nano.specs -Wl,--gc-sections")

set(CMAKE_C_FLAGS_DEBUG "-Og -g3")
set(CMAKE_C_FLAGS_RELEASE "-Os -g")
set(CMAKE_CXX_FLAGS_DEBUG "-Og -g3")
set(CMAKE_CXX_FLAGS_RELEASE "-Os -g")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
