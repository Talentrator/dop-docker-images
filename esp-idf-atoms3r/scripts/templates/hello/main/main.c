// Prints on the AtomS3R's console (the USB-C port's USB Serial/JTAG) once a second.
#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

void app_main(void)
{
    for (int n = 1;; n++) {
        printf("hello %d\n", n);
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
