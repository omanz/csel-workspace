#import "../metadata.typ": *
#pagebreak()

= Programmation système Linux 

== Résumé du laboratoire 
La carte NanoPi NEO Plus2 est équipée de deux LEDs dont une verte qui donne des indications d’état (status).
Le but de ce laboratoire est d'optimiser une application qui contrôle la fréquence de clignotement de cette LED.
Cette application permet de gérer la fréquence de clignotement de la LED à l’aide des trois boutons-poussoirs.

Le bouton K1 permet de diminuer la fréquence de clignotement, le bouton K2 permet de réinitialiser la fréquence à la valeur par défaut, et le bouton K3 permet d'augmenter la fréquence de clignotement. 
Une fonctionnalité optionnelle est que lors d'un maintien du bouton K1 ou K3, la fréquence de clignotement provoquera une auto incrémentation ou une auto décrémentation de la fréquence.

Un autre aspect important de ce laboratoire est que tous changements de fréquence doivent être indiqués dans les logs du système à l'aide de syslog. 

Une contrainte nous à été imposée : l'utilisation du multiplexage des entrées et sorties pour gérer les interactions avec les boutons et la LED.

Tout cela dans l'objectif d'optimiser l'application pour qu'elle n'utilise pas 100% d'un cœur du processeur, ce qui était le cas dans la version initiale de l'application.

== Travail réalisé
Nous commencons par ajouter la possibilité de modifier la fréquence de clignotement à l'aide des boutons. Pour trouver les identifiants des GPIOs des bouttons K1, K2 et K3 ainsi que la LED verte il est nécessaire de monter le _debugfs_ pour pouvoir le lire. comme montré ci-dessous.

Nous avons ensuite développé une application qui utilise ces GPIO pour contrôler la fréquence de clignotement de la LED en fonction des boutons pressés.
``` bash
# mount -t debugfs none /sys/kernel/debug
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
Ceci nous permet de trouver les GPIOs des boutons et de la led. Il est ensuite possible de les contrôler en écrivant dans les fichiers correspondants dans le système de fichiers virtuel _sysfs_.

Nous avons pris exemple sur le code de la version initiale qui ne s'occupait pas de la gestion des boutons pour l'implémenter dans notre version. D'abord, nous avons garder la même structure de code que la version initiale, c'est à dire une version polling qui gère le clignotement de la LED et des boutons. comme on peut le voir sur l'extrait du 'top' ci-dessous, cette version utilise 100% du cœur 0 de notre processeur.
```bash
top - 00:36:16 up 35 min,  3 users,  load average: 1.00, 0.88, 0.49
Tasks: 103 total,   2 running, 101 sleeping,   0 stopped,   0 zombie
%Cpu0  :  18.2/81.8  100[|||||||||||||||||||||||||||] %Cpu1  :   0.7/0.0     1[   ]
%Cpu2  :   0.0/0.0     0[                           ] %Cpu3  :   0.0/0.0     0[   ]
GiB Mem :  9.1/0.5      [                           ] 
GiB Swap:  0.0/0.0      [                           ]
PID USER   PR  NI    VIRT    RES  %CPU  %MEM     TIME+ S COMMAND
1   root   20   0    2.6m   0.3m   0.0   0.1   0:01.78 S init
...
280 root   20   0    1.7m   0.2m  99.4   0.0   0:50.28 R `- ./build/silly_led_control
...
```
Ensuite, nous avons ajouté la gestion des boutons à l'aide du multiplexage des entrées et sorties avec la fonction `epoll()`.
Il nous permet de travailler de manière événementielle, en réagissant uniquement lorsque les boutons sont pressés ou lorsque le timer pour le clignotement de la LED expire, plutôt que de faire du polling constant qui consomme beaucoup de ressources CPU. Dans cette version optimisée, nous avons réussi à réduire l'utilisation du CPU à environ 1% lors de l'exécution de l'application, ce qui est une amélioration significative par rapport à la version initiale.
```bash
top - 01:59:55 up  1:59,  3 users,  load average: 0.09, 0.06, 0.30
Tasks: 103 total,   1 running, 102 sleeping,   0 stopped,   0 zombie
%Cpu0  :   0.0/0.0     0[                           ]  %Cpu1  :   0.0/0.0     0[   ]
%Cpu2  :   0.0/0.7     1[                           ]  %Cpu3  :   0.0/0.7     1[   ]
GiB Mem :  9.3/0.5      [                           ]
GiB Swap:  0.0/0.0      [                           ]

PID USER   PR  NI    VIRT    RES  %CPU  %MEM     TIME+ S COMMAND
1   root   20   0    2.6m   0.3m   0.0   0.1   0:01.78 S init
...
293 root   20   0    1.8m   0.2m   1.3   0.0   0:03.18 S `- ./build/silly_led_control
...
```
Nous avons également ajouté la fonctionnalité optionnelle d'auto incrémentation et auto décrémentation de la fréquence de clignotement lorsque les boutons K1 ou K3 sont maintenus enfoncés. Cela a été réalisé en utilisant un timer supplémentaire pour détecter la durée pendant laquelle un bouton est maintenu enfoncé, et en ajustant la fréquence de clignotement en conséquence. La période de ce timer à été hardcodée après plusieurs essais et n'est surment pas la plus optimale, mais elle permet d'avoir une bonne réactivité sans être trop rapide.

#pagebreak()
== Synthèse sur ce qui a été appris/exercé
Pour ce laboratoire nous avons appris et exercé l'utilisation des GPIOs pour contrôler des composants matériels, en l'occurrence des boutons et une LED. ainsi que l'utilisation de `epoll()` pour faire de la programmation événementielle, ce qui est essentiel pour optimiser les applications système et éviter une utilisation excessive du CPU. Nous avons également pu ré-exercer l'utilisation de syslog pour enregistrer des événements dans les logs du système, ce qui est une pratique courante pour le débogage et la surveillance des applications système.

Il y a également l'utilisation des timers pour gérer les fréquences de clignotement et les auto incrémentations/décrémentations a également été une partie importante de ce laboratoire, nous permettant de mieux comprendre comment gérer le temps dans les applications système.

== Remarques et choses à retenir
La programmation sur système Linux nécessite une bonne compréhension du système de fichiers virtuel, notamment _sysfs_ et _debugfs_, pour interagir avec le matériel. L'utilisation de `epoll()` est essentielle pour créer des applications efficaces qui réagissent aux événements sans consommer inutilement des ressources CPU. Enfin, l'enregistrement d'événements dans les logs du système à l'aide de syslog est une pratique importante pour le débogage et la surveillance des applications système.

== Feedback personnel sur le laboratoire
Ce laboratoire a été très instructif et didactique pour comprendre comment fonctionne la programmation système Linux, en particulier en ce qui concerne l'interaction avec le matériel à travers les GPIOs et l'optimisation des applications pour une utilisation efficace des ressources. 

Le fait de nous avoir donné un début de programme qui fonctionne et de nous demander d'ajouter des fonctionnalités ainsi que de l'optimiser à été une très bonne approche pour apprendre comment tout fonctionne. Pour nous si les laboratoires précédents été structurés de la même manière, cela aurait été encore mieux pour l'apprentissage. Même si il demande plus de travail de notre part.