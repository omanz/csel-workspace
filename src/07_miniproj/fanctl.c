#include <linux/module.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/timer.h>
#include <linux/gpio.h>

#define LED_GPIO 10
#define FREQUENCY 2  // Hz

static struct timer_list blink_timer;
static int led_state = 0;

static void blink_callback(struct timer_list *t)
{
    led_state = !led_state;
    gpio_set_value(LED_GPIO, led_state);
    mod_timer(&blink_timer, jiffies + HZ / FREQUENCY);
}

static int __init fanctl_init(void)
{
    int status = 0;
    status = gpio_request(LED_GPIO, "status_led");
    if (status != 0) {
        pr_err("fanctl: failed to request gpio %d\n", LED_GPIO);
        return status;
    }

    status = gpio_direction_output(LED_GPIO, 0);
    if (status != 0) {
        pr_err("fanctl: failed to set gpio direction\n");
        gpio_free(LED_GPIO);
        return status;
    }

    timer_setup(&blink_timer, blink_callback, 0);
    mod_timer(&blink_timer, jiffies + HZ / FREQUENCY);

    pr_info("fanctl: module loaded, LED blinking at %dHz\n", FREQUENCY);
    return 0;
}

static void __exit fanctl_exit(void)
{
    del_timer_sync(&blink_timer);
    gpio_set_value(LED_GPIO, 0);
    gpio_free(LED_GPIO);
    pr_info("fanctl: module unloaded\n");
}

module_init(fanctl_init);
module_exit(fanctl_exit);

MODULE_AUTHOR("Olivia Manz & Yoann Archier");
MODULE_DESCRIPTION("Fan controller - LED blink");
MODULE_LICENSE("GPL");