/*
 * blinky_freertos: CY8CKIT-062S2-AI (PSoC 62S2) FreeRTOS sample.
 *
 * Two tasks: one toggles LED1 every 250 ms, the other LED2 every 1000 ms
 * and prints a tick count on the KitProg3 USB-UART (115200 8N1).
 * Built with COMPONENTS=FREERTOS RTOS_AWARE (see the Makefile).
 * FreeRTOSConfig.h is the freertos library's CM4 template.
 */
#include "cyhal.h"
#include "cybsp.h"
#include "cy_retarget_io.h"
#include "FreeRTOS.h"
#include "task.h"
#include <stdio.h>

static void led1_task(void *arg)
{
    (void)arg;
    for (;;)
    {
        cyhal_gpio_toggle(CYBSP_USER_LED1);
        vTaskDelay(pdMS_TO_TICKS(250));
    }
}

static void led2_task(void *arg)
{
    (void)arg;
    for (unsigned n = 0;; n++)
    {
        cyhal_gpio_toggle(CYBSP_USER_LED2);
        printf("tick %u\r\n", n);
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

int main(void)
{
    cy_rslt_t result = cybsp_init();
    CY_ASSERT(result == CY_RSLT_SUCCESS);
    __enable_irq();

    result = cy_retarget_io_init(CYBSP_DEBUG_UART_TX, CYBSP_DEBUG_UART_RX, CY_RETARGET_IO_BAUDRATE);
    CY_ASSERT(result == CY_RSLT_SUCCESS);
    cyhal_gpio_init(CYBSP_USER_LED1, CYHAL_GPIO_DIR_OUTPUT, CYHAL_GPIO_DRIVE_STRONG, CYBSP_LED_STATE_OFF);
    cyhal_gpio_init(CYBSP_USER_LED2, CYHAL_GPIO_DIR_OUTPUT, CYHAL_GPIO_DRIVE_STRONG, CYBSP_LED_STATE_OFF);

    printf("\r\nFreeRTOS blinky\r\n");
    xTaskCreate(led1_task, "led1", configMINIMAL_STACK_SIZE * 4, NULL, tskIDLE_PRIORITY + 1, NULL);
    xTaskCreate(led2_task, "led2", configMINIMAL_STACK_SIZE * 4, NULL, tskIDLE_PRIORITY + 1, NULL);
    vTaskStartScheduler();
    CY_ASSERT(0);
}
