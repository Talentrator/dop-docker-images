// Atomic Echo Base on the AtomS3R: plays a 1 kHz tone on the speaker while recording the
// microphone, and prints the mic level in silence and during the tone.
//
// Echo Base wiring (on the AtomS3R's bottom header):
//   I2C  SDA GPIO38, SCL GPIO39: ES8311 codec at 0x18, PI4IOE5V6408 IO expander at 0x43
//   I2S  BCLK GPIO8, LRCK GPIO6, DOUT GPIO5 (to the codec's DAC), DIN GPIO7 (from its ADC), no MCLK
// The IO expander's outputs enable the speaker amplifier (NS4150B); the codec runs its
// clocks from BCLK (16-bit stereo frames: BCLK = 32 x the sample rate).

#include <math.h>
#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/i2c_master.h"
#include "driver/i2s_std.h"
#include "esp_check.h"
#include "esp_codec_dev.h"
#include "esp_codec_dev_defaults.h"

#define PIN_SDA   38
#define PIN_SCL   39
#define PIN_BCLK  8
#define PIN_LRCK  6
#define PIN_DOUT  5
#define PIN_DIN   7
#define PI4IOE_ADDR 0x43
#define RATE      16000

static i2c_master_bus_handle_t bus;

static void amp_enable(void)
{
    i2c_master_dev_handle_t io;
    i2c_device_config_t dc = { .dev_addr_length = I2C_ADDR_BIT_LEN_7, .device_address = PI4IOE_ADDR,
                               .scl_speed_hz = 100000 };
    ESP_ERROR_CHECK(i2c_master_bus_add_device(bus, &dc, &io));
    const uint8_t seq[][2] = {
        {0x07, 0x00},   // output high-impedance: off
        {0x0D, 0xFF},   // pull-up/down select: up
        {0x03, 0x6F},   // IO direction: outputs
        {0x05, 0xFF},   // output state: high (amplifier on)
    };
    for (int i = 0; i < 4; i++) ESP_ERROR_CHECK(i2c_master_transmit(io, seq[i], 2, 100));
}

static int16_t buf[RATE / 10 * 2];  // 100 ms of 16-bit stereo

// RMS of the left (microphone) channel over `ms` of recording
static float record_rms(esp_codec_dev_handle_t dev, int ms)
{
    double sum = 0; long n = 0;
    for (int t = 0; t < ms; t += 100) {
        ESP_ERROR_CHECK(esp_codec_dev_read(dev, buf, sizeof buf));
        for (int i = 0; i < RATE / 10; i++) { double s = buf[2 * i]; sum += s * s; n++; }
    }
    return sqrtf(sum / n);
}

static void tone_task(void *arg)
{
    esp_codec_dev_handle_t dev = arg;
    static int16_t out[RATE / 10 * 2];
    for (int i = 0; i < RATE / 10; i++)
        out[2 * i] = out[2 * i + 1] = (int16_t)(8000 * sinf(2 * M_PI * 1000 * i / RATE));
    for (int k = 0; k < 15; k++) esp_codec_dev_write(dev, out, sizeof out);   // 1.5 s
    vTaskDelete(NULL);
}

void app_main(void)
{
    i2c_master_bus_config_t bc = { .i2c_port = I2C_NUM_1, .sda_io_num = PIN_SDA, .scl_io_num = PIN_SCL,
        .clk_source = I2C_CLK_SRC_DEFAULT, .glitch_ignore_cnt = 7, .flags.enable_internal_pullup = true };
    ESP_ERROR_CHECK(i2c_new_master_bus(&bc, &bus));
    amp_enable();

    i2s_chan_handle_t tx, rx;
    i2s_chan_config_t cc = I2S_CHANNEL_DEFAULT_CONFIG(I2S_NUM_0, I2S_ROLE_MASTER);
    cc.auto_clear = true;
    ESP_ERROR_CHECK(i2s_new_channel(&cc, &tx, &rx));
    i2s_std_config_t sc = {
        .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(RATE),
        .slot_cfg = I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_STEREO),
        .gpio_cfg = { .mclk = I2S_GPIO_UNUSED, .bclk = PIN_BCLK, .ws = PIN_LRCK, .dout = PIN_DOUT, .din = PIN_DIN },
    };
    ESP_ERROR_CHECK(i2s_channel_init_std_mode(tx, &sc));
    ESP_ERROR_CHECK(i2s_channel_init_std_mode(rx, &sc));
    ESP_ERROR_CHECK(i2s_channel_enable(tx));
    ESP_ERROR_CHECK(i2s_channel_enable(rx));

    audio_codec_i2c_cfg_t ic = { .port = I2C_NUM_1, .addr = ES8311_CODEC_DEFAULT_ADDR, .bus_handle = bus };
    audio_codec_i2s_cfg_t is = { .port = I2S_NUM_0, .rx_handle = rx, .tx_handle = tx };
    const audio_codec_ctrl_if_t *ctrl = audio_codec_new_i2c_ctrl(&ic);
    const audio_codec_data_if_t *data = audio_codec_new_i2s_data(&is);
    es8311_codec_cfg_t ec = {
        .ctrl_if = ctrl,
        .gpio_if = audio_codec_new_gpio(),
        .codec_mode = ESP_CODEC_DEV_WORK_MODE_BOTH,
        .pa_pin = -1,            // the amplifier is enabled through the IO expander above
        .use_mclk = false,       // clocks from BCLK
    };
    const audio_codec_if_t *codec = es8311_codec_new(&ec);
    esp_codec_dev_cfg_t dcfg = { .dev_type = ESP_CODEC_DEV_TYPE_IN_OUT, .codec_if = codec, .data_if = data };
    esp_codec_dev_handle_t dev = esp_codec_dev_new(&dcfg);
    esp_codec_dev_sample_info_t fs = { .sample_rate = RATE, .channel = 2, .bits_per_sample = 16 };
    ESP_ERROR_CHECK(esp_codec_dev_open(dev, &fs) == ESP_CODEC_DEV_OK ? ESP_OK : ESP_FAIL);
    esp_codec_dev_set_out_vol(dev, 60);
    esp_codec_dev_set_in_gain(dev, 30.0);

    printf("echo base ready\n");
    record_rms(dev, 300);                         // let the ADC settle
    float quiet = record_rms(dev, 500);
    xTaskCreate(tone_task, "tone", 4096, dev, 5, NULL);
    vTaskDelay(pdMS_TO_TICKS(300));
    float tone = record_rms(dev, 800);
    printf("mic rms: silence %.0f, 1 kHz tone %.0f\n", quiet, tone);
    printf(tone > 4 * quiet + 100 ? "echo loopback OK\n" : "echo loopback FAIL\n");
}
