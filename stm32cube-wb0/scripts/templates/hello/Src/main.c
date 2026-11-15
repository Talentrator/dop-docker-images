/* hello: prints over the ST-LINK virtual COM port (USART1, 115200 8N1) and
 * blinks the blue user LED LD1. Runs at 64 MHz from the 32 MHz HSE, with
 * the clock setup STM32CubeMX writes for the NUCLEO-WB09KE. */
#include <stdio.h>
#include "main.h"

static UART_HandleTypeDef huart1;

/* printf -> _write (the SDK's syscalls.c) -> __io_putchar -> USART1 */
int __io_putchar(int ch)
{
  uint8_t c = (uint8_t)ch;
  HAL_UART_Transmit(&huart1, &c, 1, HAL_MAX_DELAY);
  return ch;
}

void SysTick_Handler(void)
{
  HAL_IncTick();
}

static void fail(void)
{
  __disable_irq();
  for (;;) {}
}

static void clock_init(void)
{
  RCC_OscInitTypeDef osc = {0};
  RCC_ClkInitTypeDef clk = {0};
  RCC_PeriphCLKInitTypeDef periph = {0};

  osc.OscillatorType = RCC_OSCILLATORTYPE_HSE;
  osc.HSEState = RCC_HSE_ON;
  if (HAL_RCC_OscConfig(&osc) != HAL_OK) fail();
  clk.SYSCLKSource = RCC_SYSCLKSOURCE_RC64MPLL;
  clk.SYSCLKDivider = RCC_RC64MPLL_DIV1;
  if (HAL_RCC_ClockConfig(&clk, FLASH_WAIT_STATES_1) != HAL_OK) fail();
  periph.PeriphClockSelection = RCC_PERIPHCLK_SMPS;
  periph.SmpsDivSelection = RCC_SMPSCLK_DIV4;
  if (HAL_RCCEx_PeriphCLKConfig(&periph) != HAL_OK) fail();
}

static void console_init(void)
{
  GPIO_InitTypeDef gpio = {0};

  __HAL_RCC_USART1_CLK_ENABLE();
  __HAL_RCC_GPIOA_CLK_ENABLE();
  __HAL_RCC_GPIOB_CLK_ENABLE();
  gpio.Mode = GPIO_MODE_AF_PP;
  gpio.Pull = GPIO_PULLUP;
  gpio.Speed = GPIO_SPEED_FREQ_LOW;
  gpio.Pin = GPIO_PIN_1;                   /* TX */
  gpio.Alternate = GPIO_AF2_USART1;
  HAL_GPIO_Init(GPIOA, &gpio);
  gpio.Pin = GPIO_PIN_0;                   /* RX */
  gpio.Alternate = GPIO_AF0_USART1;
  HAL_GPIO_Init(GPIOB, &gpio);

  huart1.Instance = USART1;
  huart1.Init.BaudRate = 115200;
  huart1.Init.WordLength = UART_WORDLENGTH_8B;
  huart1.Init.StopBits = UART_STOPBITS_1;
  huart1.Init.Parity = UART_PARITY_NONE;
  huart1.Init.Mode = UART_MODE_TX_RX;
  huart1.Init.HwFlowCtl = UART_HWCONTROL_NONE;
  huart1.Init.OverSampling = UART_OVERSAMPLING_16;
  huart1.Init.OneBitSampling = UART_ONE_BIT_SAMPLE_DISABLE;
  huart1.Init.ClockPrescaler = UART_PRESCALER_DIV1;
  huart1.AdvancedInit.AdvFeatureInit = UART_ADVFEATURE_NO_INIT;
  if (HAL_UART_Init(&huart1) != HAL_OK) fail();
}

static void led_init(void)
{
  GPIO_InitTypeDef gpio = {0};

  __HAL_RCC_GPIOB_CLK_ENABLE();
  gpio.Pin = LED_PIN;
  gpio.Mode = GPIO_MODE_OUTPUT_PP;
  gpio.Pull = GPIO_NOPULL;
  gpio.Speed = GPIO_SPEED_FREQ_LOW;
  HAL_GPIO_Init(LED_PORT, &gpio);
}

int main(void)
{
  HAL_Init();
  clock_init();
  console_init();
  led_init();

  printf("hello from the NUCLEO-WB09KE, SystemCoreClock=%lu\r\n", (unsigned long)SystemCoreClock);
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
