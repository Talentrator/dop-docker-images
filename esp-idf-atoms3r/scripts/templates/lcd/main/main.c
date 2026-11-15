// The M5Stack AtomS3R's 0.85" 128x128 LCD (GC9107) with ESP-IDF's esp_lcd panel IO:
// powers it up, turns on the backlight (an LP5562 LED driver on the internal I2C bus),
// and fills the screen with four colored squares (red top-left, held with USB-C down).
//
// The frame is a W x H RGB565 buffer, byte-swapped (the panel takes the high byte first),
// sent in one DMA transfer with RAMWR (0x2C).

#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "driver/i2c_master.h"
#include "driver/spi_master.h"
#include "esp_err.h"
#include "esp_heap_caps.h"
#include "esp_lcd_panel_io.h"

// The AtomS3R's LCD wiring
#define PIN_LCD_MOSI   21
#define PIN_LCD_SCK    15
#define PIN_LCD_CS     14
#define PIN_LCD_DC     42
#define PIN_LCD_RST    48
// The backlight is the white channel of an LP5562 LED driver on the internal I2C bus
#define PIN_SYS_SDA    45
#define PIN_SYS_SCL    0
#define LP5562_ADDR    0x30

#define W 128
#define H 128
#define Y_GAP 32             // the 128x128 window sits 32 rows down the GC9107's 128x160 RAM
#define SPI_HZ (40 * 1000 * 1000)

// RGB565, byte-swapped: the panel takes the high byte first
#define RGB(r, g, b) ((uint16_t)(((((r) & 0xF8) << 8) | (((g) & 0xFC) << 3) | ((b) >> 3)) >> 8 | \
                                 ((((r) & 0xF8) << 8) | (((g) & 0xFC) << 3) | ((b) >> 3)) << 8))
#define BLACK  RGB(0, 0, 0)
#define RED    RGB(255, 0, 0)
#define GREEN  RGB(0, 255, 0)
#define BLUE   RGB(0, 0, 255)
#define WHITE  RGB(255, 255, 255)

static uint16_t *fb;         // the frame, W x H, row by row

static esp_lcd_panel_io_handle_t io;
static SemaphoreHandle_t sent;  // given when a frame's transfer is done, so the buffer is free

static bool on_sent(esp_lcd_panel_io_handle_t io, esp_lcd_panel_io_event_data_t *e, void *ctx)
{
    BaseType_t woken = pdFALSE;
    xSemaphoreGiveFromISR(sent, &woken);
    return woken == pdTRUE;
}

static void cmd(uint8_t c, const uint8_t *p, size_t n)
{
    ESP_ERROR_CHECK(esp_lcd_panel_io_tx_param(io, c, p, n));
}
#define CMD(c, ...) do { static const uint8_t _p[] = {__VA_ARGS__}; cmd(c, _p, sizeof _p); } while (0)
#define CMD0(c) cmd(c, NULL, 0)

static void backlight_on(uint8_t level)
{
    i2c_master_bus_handle_t bus;
    i2c_master_bus_config_t bc = {
        .i2c_port = I2C_NUM_0,
        .sda_io_num = PIN_SYS_SDA,
        .scl_io_num = PIN_SYS_SCL,
        .clk_source = I2C_CLK_SRC_DEFAULT,
        .glitch_ignore_cnt = 7,
        .flags.enable_internal_pullup = true,
    };
    ESP_ERROR_CHECK(i2c_new_master_bus(&bc, &bus));
    i2c_master_dev_handle_t lp;
    i2c_device_config_t dc = {
        .dev_addr_length = I2C_ADDR_BIT_LEN_7,
        .device_address = LP5562_ADDR,
        .scl_speed_hz = 400000,
    };
    ESP_ERROR_CHECK(i2c_master_bus_add_device(bus, &dc, &lp));
    const uint8_t enable[] = {0x00, 0x40};     // ENABLE: chip on
    ESP_ERROR_CHECK(i2c_master_transmit(lp, enable, 2, 100));
    vTaskDelay(pdMS_TO_TICKS(2));
    const uint8_t config[] = {0x08, 0x01};     // CONFIG: internal clock
    const uint8_t map[] = {0x70, 0x00};        // LED_MAP: every channel driven by its PWM register
    const uint8_t pwm[] = {0x0E, level};       // W_PWM: the backlight
    ESP_ERROR_CHECK(i2c_master_transmit(lp, config, 2, 100));
    ESP_ERROR_CHECK(i2c_master_transmit(lp, map, 2, 100));
    ESP_ERROR_CHECK(i2c_master_transmit(lp, pwm, 2, 100));
}

static void display_init(void)
{
    gpio_config_t out = { .pin_bit_mask = 1ULL << PIN_LCD_RST, .mode = GPIO_MODE_OUTPUT };
    ESP_ERROR_CHECK(gpio_config(&out));
    gpio_set_level(PIN_LCD_RST, 0);
    vTaskDelay(pdMS_TO_TICKS(20));
    gpio_set_level(PIN_LCD_RST, 1);
    vTaskDelay(pdMS_TO_TICKS(120));

    spi_bus_config_t bus = {
        .mosi_io_num = PIN_LCD_MOSI,
        .miso_io_num = -1,
        .sclk_io_num = PIN_LCD_SCK,
        .quadwp_io_num = -1,
        .quadhd_io_num = -1,
        .max_transfer_sz = W * H * sizeof(uint16_t),
    };
    ESP_ERROR_CHECK(spi_bus_initialize(SPI3_HOST, &bus, SPI_DMA_CH_AUTO));

    sent = xSemaphoreCreateBinary();
    esp_lcd_panel_io_spi_config_t io_cfg = {
        .cs_gpio_num = PIN_LCD_CS,
        .dc_gpio_num = PIN_LCD_DC,
        .spi_mode = 0,
        .pclk_hz = SPI_HZ,
        .trans_queue_depth = 4,
        .on_color_trans_done = on_sent,
        .lcd_cmd_bits = 8,
        .lcd_param_bits = 8,
    };
    ESP_ERROR_CHECK(esp_lcd_new_panel_io_spi((esp_lcd_spi_bus_handle_t)SPI3_HOST, &io_cfg, &io));

    // GC9107 power-on sequence
    CMD0(0xFE); vTaskDelay(pdMS_TO_TICKS(5));  // inter register enable 1
    CMD0(0xEF); vTaskDelay(pdMS_TO_TICKS(5));  // inter register enable 2
    CMD(0xB0, 0xC0); CMD(0xB2, 0x2F); CMD(0xB3, 0x03); CMD(0xB6, 0x19); CMD(0xB7, 0x01);
    CMD(0xAC, 0xCB); CMD(0xAB, 0x0E); CMD(0xB4, 0x04); CMD(0xA8, 0x19); CMD(0xB8, 0x08);
    CMD(0xE8, 0x24); CMD(0xE9, 0x48); CMD(0xEA, 0x22); CMD(0xC6, 0x30); CMD(0xC7, 0x18);
    CMD(0xF0, 0x01, 0x2b, 0x23, 0x3c, 0xb7, 0x12, 0x17, 0x60, 0x00, 0x06, 0x0c, 0x17, 0x12, 0x1f);  // gamma
    CMD(0xF1, 0x05, 0x2e, 0x2d, 0x44, 0xd6, 0x15, 0x17, 0xa0, 0x02, 0x0d, 0x0d, 0x1a, 0x18, 0x1f);
    CMD(0x3A, 0x05);                           // COLMOD: 16 bits a pixel
    CMD(0x36, 0x08);                           // MADCTL: upright with USB-C down, BGR panel
    CMD(0x2A, 0, 0, 0, W - 1);                 // the visible window
    CMD(0x2B, 0, Y_GAP, 0, Y_GAP + H - 1);
    CMD0(0x11); vTaskDelay(pdMS_TO_TICKS(120)); // sleep out
    CMD0(0x29);                                // display on
}

static void show(void)
{
    ESP_ERROR_CHECK(esp_lcd_panel_io_tx_color(io, 0x2C, fb, W * H * sizeof(uint16_t)));
    xSemaphoreTake(sent, portMAX_DELAY);    // wait for the DMA before the buffer is drawn into again
}

void app_main(void)
{
    fb = heap_caps_malloc(W * H * sizeof(uint16_t), MALLOC_CAP_DMA | MALLOC_CAP_INTERNAL);
    assert(fb);
    display_init();
    // four squares: red top-left, green top-right, blue bottom-left, white bottom-right
    for (int y = 0; y < H; y++)
        for (int x = 0; x < W; x++)
            fb[y * W + x] = y < H / 2 ? (x < W / 2 ? RED : GREEN) : (x < W / 2 ? BLUE : WHITE);
    show();
    backlight_on(0xC0);
    printf("lcd on\n");
}
