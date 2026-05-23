#include <linux/module.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/timer.h>
#include <linux/gpio.h>
#include <linux/device.h>

#define LED_GPIO 10
#define FREQ_MIN    1
#define FREQ_MAX    20

static struct timer_list blink_timer;
static int led_state = 0;
static int frequency  = 2;    // Hz

static struct class* sysfs_class;
static struct device* sysfs_device;

static ssize_t frequency_show(struct device *dev,
                               struct device_attribute *attr, char *buf)
{
    return sysfs_emit(buf, "%d\n", frequency);
}

static ssize_t frequency_store(struct device *dev,
                                struct device_attribute *attr,
                                const char *buf, size_t count)
{
    int val;
    if (kstrtoint(buf, 10, &val)) return -EINVAL;
    if (val < FREQ_MIN || val > FREQ_MAX) return -EINVAL;
    frequency = val;
    mod_timer(&blink_timer, jiffies + HZ / frequency);
    return count;
}
static DEVICE_ATTR_RW(frequency);  // create dev_attr_frequency

static void blink_callback(struct timer_list *t)
{
    led_state = !led_state;
    gpio_set_value(LED_GPIO, led_state);
    mod_timer(&blink_timer, jiffies + HZ / frequency);
}

static int __init fanctl_init(void)
{
    int status = 0;

    /* GPIO */
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

    /* sysfs class + device*/
    sysfs_class = class_create(THIS_MODULE, "fanctl");
    sysfs_device = device_create(sysfs_class, NULL, 0, NULL, "fanctl");
    status = device_create_file(sysfs_device, &dev_attr_frequency);

     /* timer */
    timer_setup(&blink_timer, blink_callback, 0);
    mod_timer(&blink_timer, jiffies + HZ / frequency);

    pr_info("fanctl: module loaded, LED blinking at %dHz\n", frequency);
    return 0;
}

static void __exit fanctl_exit(void)
{
    del_timer_sync(&blink_timer);
    device_remove_file(sysfs_device, &dev_attr_frequency);
    device_destroy(sysfs_class, 0);
    class_destroy(sysfs_class);
    gpio_set_value(LED_GPIO, 0);
    gpio_free(LED_GPIO);
    pr_info("fanctl: module unloaded\n");
}

module_init(fanctl_init);
module_exit(fanctl_exit);

MODULE_AUTHOR("Olivia Manz & Yoann Archier");
MODULE_DESCRIPTION("Fan controller - LED blink");
MODULE_LICENSE("GPL");