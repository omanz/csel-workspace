//#import "../metadata.typ": *
//#pagebreak()

= Programmation système Linux - Système de fichiers

== Résumé du laboratoire 
La carte NanoPi NEO Plus2 est équipée de deux LEDs dont une verte qui donne des indications d’état (status).
Le but de ce laboratoire est d'optimiser une application qui contrôle la fréquence de clignotement de cette LED.
Cette application permet de gérer la fréquence de clignotement de la LED à l’aide des trois boutons-poussoirs.

Le bouton K1 permet de diminuer la fréquence de clignotement, le bouton K2 permet de réinitialiser la fréquence à la valeur par défaut, et le bouton K3 permet d'augmenter la fréquence de clignotement. Une fonctionnalité optionnelle est que lors d'un maintien du bouton K1 ou K3, la fréquence de clignotement provoquera une auto incrémentation ou une auto décrémentation de la fréquence.

Un autre aspect important de ce laboratoire est que tous changements de fréquence doivent être indiqués dans les logs du système à l'aide de syslog. 

Une contrainte nous à été imposée : l'utilisation du multiplexage des entrées et sorties (I/O multiplexing) pour gérer les interactions avec les boutons et la LED.

Tout cela dans l'objectif d'optimiser l'application pour qu'elle n'utilise pas 100% d'un cœur du processeur, ce qui était le cas dans la version initiale de l'application.

== Travail réalisé
En utilisant le module que nous avions développé on peut retrouvé les GPIO des bouttons K1, K2 et K3 ainsi que la LED verte. Nous avons ensuite développé une application qui utilise ces GPIO pour contrôler la fréquence de clignotement de la LED en fonction des boutons pressés.
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

