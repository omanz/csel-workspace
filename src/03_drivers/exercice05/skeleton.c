/*
 * skeleton.c 
 *
 * module pour exposer des interfaces dans le noyau Linux vers l'espace utilisateur
 * 
 * 3. CLASS : création d'un device sysfs dans une classe (/sys/class/my_sysfs_class/my_sysfs_device)
 * 2. MISC : création d'un device simple (/dev/mymodule et /sys/class/misc/mymodule)
 * 3. PLATFORM : création d'un device platform simulant
 *    un périphérique matériel
 * Le module possède 2 attributs accessibles en lecture/ecriture:
 *  - val : int
 *  - cfg : struct
 */
 
#include <linux/init.h>   /* needed for macros */
#include <linux/kernel.h> /* needed for debugging */
#include <linux/module.h> /* needed by all modules */

#include <linux/cdev.h>    /* needed for char device driver */
#include <linux/fs.h>      /* needed for device drivers */
#include <linux/uaccess.h> /* needed to copy data to/from user */

#include <linux/device.h> /* needed for sysfs handling */
#include <linux/miscdevice.h>
#include <linux/platform_device.h> /* needed for sysfs handling */

//#define MISC
#define PLATFORM
//#define CLASS

struct skeleton_config {
    int id;
    long ref;
    char name[30];
    char descr[30];
};

// valeurs accessibles dans /sys
static struct skeleton_config config;
static int val;

// methodes pour la variable val
ssize_t sysfs_show_val(struct device* dev,
                       struct device_attribute* attr,
                       char* buf)
{
    sprintf(buf, "%d\n", val);
    return strlen(buf);
}
ssize_t sysfs_store_val(struct device* dev,
                        struct device_attribute* attr,
                        const char* buf,
                        size_t count)
{
    val = simple_strtol(buf, 0, 10);
    return count;
}
// enregistrement de la variable
DEVICE_ATTR(val, 0664, sysfs_show_val, sysfs_store_val);

// methodes pour la variable config
ssize_t sysfs_show_cfg(struct device* dev,
                       struct device_attribute* attr,
                       char* buf)
{
    sprintf(buf,
            "%d %ld %s %s\n",
            config.id,
            config.ref,
            config.name,
            config.descr);
    return strlen(buf);
}
ssize_t sysfs_store_cfg(struct device* dev,
                        struct device_attribute* attr,
                        const char* buf,
                        size_t count)
{
    sscanf(buf,
           "%d %ld %s %s",
           &config.id,
           &config.ref,
           config.name,
           config.descr);
    return count;
}
// enregistrement de la variable
DEVICE_ATTR(cfg, 0664, sysfs_show_cfg, sysfs_store_cfg);


#ifdef MISC
static struct miscdevice misc_device = {
    .minor = MISC_DYNAMIC_MINOR,
    .name = "mymodule",
    .mode = 0,
};
#endif

#ifdef PLATFORM
static void sysfs_dev_release (struct device *dev)
{
    pr_info ("skeleton - sysfs dev release\n");
}

static struct platform_device platform_device = {
    .name = "mymodule",
    .id = -1,
    .dev.release = sysfs_dev_release
};
#endif

#ifdef CLASS
static struct class* sysfs_class;
static struct device* sysfs_device;
#endif

static int __init skeleton_init(void)
{
    int status = 0;

#ifdef MISC
    // crée le device de type caractère /dev/mymodule qui reagit au read/write si on les as définis
    // crée une entrée dans /sys/class/misc/
    if (status == 0) status = misc_register(&misc_device);
    if (status == 0) status = device_create_file(misc_device.this_device, &dev_attr_val);
    if (status == 0) status = device_create_file(misc_device.this_device, &dev_attr_cfg);
#endif

#ifdef PLATFORM
    // crée une entrée sous /sys/devices/platform/mymodule/
	if (status == 0) status = platform_device_register (&platform_device);
    if (status == 0) status = device_create_file (&platform_device.dev, &dev_attr_val);
 	if (status == 0) status = device_create_file (&platform_device.dev, &dev_attr_cfg);
#endif

#ifdef CLASS
    // cree une entrée dans /sys/class/my_sysfs_class/
    sysfs_class = class_create(THIS_MODULE, "my_sysfs_class");
    // cree une entree /sys/class/my_sysfs_class/my_sysfs_device/ -> ../../devices/virtual/my_sysfs_class/my_sysfs_device
    sysfs_device = device_create(sysfs_class, NULL, 0, NULL, "my_sysfs_device");
    // crée les fichiers pour les parametres sous /sys/class/my_sysfs_class/my_sysfs_device/nomparam. Le nomparam depend du premier paramètre de DEVICE_ATTR 
    if (status == 0) status = device_create_file(sysfs_device, &dev_attr_val);
 	if (status == 0) status = device_create_file(sysfs_device, &dev_attr_cfg);
#endif

    pr_info("Linux module skeleton loaded\n");
    return 0;
}

static void __exit skeleton_exit(void)
{
#ifdef MISC
    misc_deregister(&misc_device);
#endif

#ifdef PLATFORM
	device_remove_file (&platform_device.dev, &dev_attr_cfg);
	device_remove_file (&platform_device.dev, &dev_attr_val);
	platform_device_unregister (&platform_device);
#endif

#ifdef CLASS
    device_remove_file(sysfs_device, &dev_attr_val);
    device_remove_file(sysfs_device, &dev_attr_cfg);
    device_destroy(sysfs_class, 0);
    class_destroy(sysfs_class);
#endif

    pr_info("Linux module skeleton unloaded\n");
}

// crée l'entrée dans /sys/module
module_init(skeleton_init);
module_exit(skeleton_exit);

MODULE_AUTHOR("Daniel Gachet <daniel.gachet@hefr.ch>");
MODULE_DESCRIPTION("Module skeleton");
MODULE_LICENSE("GPL");
