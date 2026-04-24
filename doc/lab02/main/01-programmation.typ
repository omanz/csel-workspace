#import "../metadata.typ": *
#pagebreak()

= Programmation système Linux

== Résumé du laboratoire
La carte NanoPi NEO Plus2 est équipée de plusieurs LEDs dont une verte qui donne des indications d’état (status).
Le but de ce laboratoire est d'optimiser une application qui contrôle la fréquence de clignotement de cette LED.
Cette application permet de gérer la fréquence de clignotement de la LED à l’aide des trois boutons-poussoirs.

== Travail réalisé
En utilisant le module que nous avion développé on peut retrouvé les GPIO des bouttons K1, K2 et K3 ainsi que la LED verte. Nous avons ensuite développé une application qui utilise ces GPIO pour contrôler la fréquence de clignotement de la LED en fonction des boutons pressés.
``` bash
# mount -t debugfs none /sys/kernel/debug
# cat /sys/kernel/debug/gpio
```
``` bash
cat /sys/kernel/debug/gpio
gpiochip1: GPIOs 0-223, parent: platform/1c20800.pinctrl, 1c20800.pinctrl:
 gpio-0   (                    |k1                  ) in  lo IRQ 
 gpio-2   (                    |k2                  ) in  lo IRQ 
 gpio-3   (                    |k3                  ) in  lo IRQ 
 gpio-10  (                    |sysfs               ) out lo 
 gpio-102 (                    |gmac-3v3            ) out hi 
 gpio-166 (                    |cd                  ) in  lo IRQ ACTIVE LOW

gpiochip0: GPIOs 352-383, parent: platform/1f02c00.pinctrl, 1f02c00.pinctrl:
 gpio-358 (                    |vdd-cpux            ) out hi 
 gpio-359 (                    |reset               ) out hi ACTIVE LOW
```

== Réponse aux questions

== Synthèse sur ce qui a été appris/exercé

== Remarques et choses à retenir

