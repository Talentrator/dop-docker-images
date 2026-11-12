/* hello: prints over the ST-LINK virtual COM port (USART3, 115200 8N1) and
 * blinks the green user LED LD2. Runs on the reset clock (HSI, 32 MHz). */
#include <stdio.h>
#include "main.h"

static UART_HandleTypeDef huart3;

/* printf -> _write (the SDK's syscalls.c) -> __io_putchar -> USART3 */
int __io_putchar(int ch)
{
  uint8_t c = (uint8_t)ch;
  HAL_UART_Transmit(&huart3, &c, 1, HAL_MAX_DELAY);
  return ch;
}

void SysTick_Handler(void)
{
  HAL_IncTick();
}

static void console_init(void)
{
  GPIO_InitTypeDef gpio = {0};

  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_USART3_CLK_ENABLE();
  gpio.Pin = GPIO_PIN_3 | GPIO_PIN_4;
  gpio.Mode = GPIO_MODE_AF_PP;
  gpio.Pull = GPIO_NOPULL;
  gpio.Speed = GPIO_SPEED_FREQ_LOW;
  gpio.Alternate = GPIO_AF13_USART3;
  HAL_GPIO_Init(GPIOA, &gpio);

  huart3.Instance = USART3;
  huart3.Init.BaudRate = 115200;
  huart3.Init.WordLength = UART_WORDLENGTH_8B;
  huart3.Init.StopBits = UART_STOPBITS_1;
  huart3.Init.Parity = UART_PARITY_NONE;
  huart3.Init.Mode = UART_MODE_TX_RX;
  huart3.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart3.Init.OverSampling = UART_OVERSAMPLING_16;
  if (HAL_UART_Init(&huart3) != HAL_OK) {
    for (;;) {}
  }
}

static void led_init(void)
{
  GPIO_InitTypeDef gpio = {0};

  __HAL_RCC_GPIOA_CLK_ENABLE();
  gpio.Pin = LED_PIN;
  gpio.Mode = GPIO_MODE_OUTPUT_PP;
  gpio.Pull = GPIO_NOPULL;
  gpio.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(LED_PORT, &gpio);
}

int main(void)
{
  HAL_Init();
  console_init();
  led_init();

  printf("hello from the NUCLEO-H503RB, SystemCoreClock=%lu\r\n", (unsigned long)SystemCoreClock);
  for (int i = 1; i <= 5; i++) {
    HAL_GPIO_TogglePin(LED_PORT, LED_PIN);
    printf("blink %d\r\n", i);
    HAL_Delay(200);
  }
  printf("done\r\n");
  for (;;) {
    HAL_Delay(1000);
  }
}
