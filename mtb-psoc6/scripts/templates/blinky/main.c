/*
 * blinky: CY8CKIT-062S2-AI (PSoC 62S2) sample.
 *
 * Prints "Hello World" on the KitProg3 USB-UART (115200 8N1), then for
 * 10 seconds switches between the two user LEDs (LED1 on P5_3, LED2 on
 * P5_4) every 500 ms, printing which one is lit, and turns both off.
 */
#include "cyhal.h"
#include "cybsp.h"
#include "cy_retarget_io.h"
#include <stdio.h>

#define RUN_MS      10000u
#define SWITCH_MS   500u

int main(void)
{
    cy_rslt_t result = cybsp_init();
    CY_ASSERT(result == CY_RSLT_SUCCESS);
    __enable_irq();

    result = cy_retarget_io_init(CYBSP_DEBUG_UART_TX, CYBSP_DEBUG_UART_RX, CY_RETARGET_IO_BAUDRATE);
    CY_ASSERT(result == CY_RSLT_SUCCESS);

    cyhal_gpio_init(CYBSP_USER_LED1, CYHAL_GPIO_DIR_OUTPUT, CYHAL_GPIO_DRIVE_STRONG, CYBSP_LED_STATE_OFF);
    cyhal_gpio_init(CYBSP_USER_LED2, CYHAL_GPIO_DIR_OUTPUT, CYHAL_GPIO_DRIVE_STRONG, CYBSP_LED_STATE_OFF);

    printf("\r\nHello World\r\n");

    for (uint32_t t = 0, n = 0; t < RUN_MS; t += SWITCH_MS, n++)
    {
        bool first = (n % 2u) == 0u;
        cyhal_gpio_write(CYBSP_USER_LED1, first ? CYBSP_LED_STATE_ON : CYBSP_LED_STATE_OFF);
        cyhal_gpio_write(CYBSP_USER_LED2, first ? CYBSP_LED_STATE_OFF : CYBSP_LED_STATE_ON);
        printf("LED%u\r\n", first ? 1u : 2u);
        cyhal_system_delay_ms(SWITCH_MS);
    }

    cyhal_gpio_write(CYBSP_USER_LED1, CYBSP_LED_STATE_OFF);
    cyhal_gpio_write(CYBSP_USER_LED2, CYBSP_LED_STATE_OFF);
    printf("Done\r\n");

    for (;;)
    {
        cyhal_syspm_sleep();
    }
}
