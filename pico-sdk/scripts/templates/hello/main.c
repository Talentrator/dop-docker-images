// hello: blinks the Pico 2's LED (GPIO 25) for 10 seconds and says what it does on the
// USB serial console:
//   hello world
//   LED on
//   LED off
//   ... (10 on/off cycles, 0.5 s each half)
//   done
#include <stdio.h>
#include "pico/stdlib.h"

#define HALF_PERIOD_MS 500
#define BLINK_MS 10000

int main(void) {
    stdio_init_all();
    gpio_init(PICO_DEFAULT_LED_PIN);
    gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);

    // the console is USB: what is printed before the host opens the port is lost, and so is
    // what is printed in the first moments after it does
    while (!stdio_usb_connected())
        sleep_ms(10);
    sleep_ms(200);

    printf("hello world\n");
    for (int t = 0; t < BLINK_MS; t += HALF_PERIOD_MS) {
        bool on = (t / HALF_PERIOD_MS) % 2 == 0;
        gpio_put(PICO_DEFAULT_LED_PIN, on);
        printf("LED %s\n", on ? "on" : "off");
        sleep_ms(HALF_PERIOD_MS);
    }
    gpio_put(PICO_DEFAULT_LED_PIN, 0);
    printf("done\n");

    // stay up, so the USB port (and picotool's reset interface) stay there
    while (true)
        sleep_ms(1000);
}
