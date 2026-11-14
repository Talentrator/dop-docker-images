// hello: the smallest app for the Feather ESP32-S3 Reverse TFT. Prints on the
// console (the USB-C port's USB Serial/JTAG) once a second.
#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

void app_main(void)
{
    for (int i = 0;; i++) {
        printf("hello %d\n", i);
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
