// tft: turns on the Feather ESP32-S3 Reverse TFT's 240x135 ST7789 with esp_lcd, landscape,
// and fills it red, green, blue and black in turn, once a second, saying so on the console.
#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "driver/spi_master.h"
#include "esp_err.h"
#include "esp_heap_caps.h"
#include "esp_lcd_panel_io.h"
#include "esp_lcd_panel_ops.h"
#include "esp_lcd_panel_vendor.h"

#define PIN_TFT_POWER 7      // TFT_I2C_POWER: drive high to power the display
#define PIN_TFT_BL    45     // backlight, high = on
#define PIN_TFT_CS    42
#define PIN_TFT_DC    40
#define PIN_TFT_RST   41
#define PIN_MOSI      35
#define PIN_SCK       36
#define W 240
#define H 135
#define LINES 15             // rows sent per transfer

void app_main(void)
{
    gpio_config_t out = {.pin_bit_mask = 1ULL << PIN_TFT_POWER | 1ULL << PIN_TFT_BL, .mode = GPIO_MODE_OUTPUT};
    ESP_ERROR_CHECK(gpio_config(&out));
    gpio_set_level(PIN_TFT_POWER, 1);
    vTaskDelay(pdMS_TO_TICKS(10));

    spi_bus_config_t bus = {.mosi_io_num = PIN_MOSI, .miso_io_num = -1, .sclk_io_num = PIN_SCK,
                            .quadwp_io_num = -1, .quadhd_io_num = -1, .max_transfer_sz = W * LINES * 2};
    ESP_ERROR_CHECK(spi_bus_initialize(SPI2_HOST, &bus, SPI_DMA_CH_AUTO));
    esp_lcd_panel_io_handle_t io;
    esp_lcd_panel_io_spi_config_t io_cfg = {.cs_gpio_num = PIN_TFT_CS, .dc_gpio_num = PIN_TFT_DC, .spi_mode = 0,
                                            .pclk_hz = 40 * 1000 * 1000, .trans_queue_depth = 1,
                                            .lcd_cmd_bits = 8, .lcd_param_bits = 8};
    ESP_ERROR_CHECK(esp_lcd_new_panel_io_spi((esp_lcd_spi_bus_handle_t)SPI2_HOST, &io_cfg, &io));
    esp_lcd_panel_handle_t panel;
    esp_lcd_panel_dev_config_t dev = {.reset_gpio_num = PIN_TFT_RST, .rgb_ele_order = LCD_RGB_ELEMENT_ORDER_RGB,
                                      .bits_per_pixel = 16};
    ESP_ERROR_CHECK(esp_lcd_new_panel_st7789(io, &dev, &panel));
    ESP_ERROR_CHECK(esp_lcd_panel_reset(panel));
    ESP_ERROR_CHECK(esp_lcd_panel_init(panel));
    ESP_ERROR_CHECK(esp_lcd_panel_invert_color(panel, true));    // IPS panel
    ESP_ERROR_CHECK(esp_lcd_panel_swap_xy(panel, true));         // landscape, as Adafruit's setRotation(3)
    ESP_ERROR_CHECK(esp_lcd_panel_mirror(panel, false, true));
    ESP_ERROR_CHECK(esp_lcd_panel_set_gap(panel, 40, 53));
    ESP_ERROR_CHECK(esp_lcd_panel_disp_on_off(panel, true));
    gpio_set_level(PIN_TFT_BL, 1);

    // RGB565, high byte first
    static const struct { const char *name; uint16_t rgb565; } colors[] = {
        {"red", 0xF800}, {"green", 0x07E0}, {"blue", 0x001F}, {"black", 0x0000}};
    uint16_t *buf = heap_caps_malloc(W * LINES * 2, MALLOC_CAP_DMA);
    assert(buf);
    for (int i = 0;; i = (i + 1) % 4) {
        uint16_t c = colors[i].rgb565 >> 8 | colors[i].rgb565 << 8;
        for (int p = 0; p < W * LINES; p++) buf[p] = c;
        // trans_queue_depth 1: each draw waits for the one before, so the buffer is not reused mid-transfer
        for (int y = 0; y < H; y += LINES) ESP_ERROR_CHECK(esp_lcd_panel_draw_bitmap(panel, 0, y, W, y + LINES, buf));
        printf("tft %s\n", colors[i].name);
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
