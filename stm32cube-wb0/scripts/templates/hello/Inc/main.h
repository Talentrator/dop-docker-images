#ifndef MAIN_H
#define MAIN_H

#include "stm32wb0x_hal.h"

/* NUCLEO-WB09KE (MB2032): user LEDs LD1 blue PB1, LD2 green PB4, LD3 red PB2
 * (active low: 0 = on); user buttons B1 PA0, B2 PB5, B3 PB14 (pressed = 0);
 * ST-LINK virtual COM port on USART1: TX PA1 (AF2), RX PB0 (AF0) */
#define LED_PORT      GPIOB
#define LED_PIN       GPIO_PIN_1
#define BUTTON_PORT   GPIOA
#define BUTTON_PIN    GPIO_PIN_0

#endif
