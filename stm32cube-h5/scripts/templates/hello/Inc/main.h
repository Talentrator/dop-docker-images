#ifndef MAIN_H
#define MAIN_H

#include "stm32h5xx_hal.h"

/* NUCLEO-H503RB: user LED LD2 (green) on PA5, user button B1 on PC13,
 * ST-LINK virtual COM port on USART3: TX PA4, RX PA3, alternate function 13 */
#define LED_PORT      GPIOA
#define LED_PIN       GPIO_PIN_5
#define BUTTON_PORT   GPIOC
#define BUTTON_PIN    GPIO_PIN_13

#endif
