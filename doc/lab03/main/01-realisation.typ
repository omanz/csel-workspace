#import "../metadata.typ": *
#pagebreak()

= Résumé du laboratoire 
Ce projet est une application permettant de simuler la gestion de la vitesse de rotation d’un ventilateur en fonction de la température du processeur.

= Description de l'application

L'application est composée de trois parties principales : un module noyau, un daemon userspace et une application qui fournit une interface utilisateur en ligne de commande.

== Module noyau (`fanctl.ko`)
Le module noyau gère la LED status (gpio10) et expose deux attributs via sysfs :
- `/sys/class/fanctl/fanctl/frequency` : fréquence de clignotement de la LED, de 1 à 20 Hz
- `/sys/class/fanctl/fanctl/mode` : mode de fonctionnement (`auto` ou `manual`)

En mode *auto*, la fréquence est déterminée par la température du CPU :
- < 35°C → 2 Hz
- < 40°C → 5 Hz
- < 45°C → 10 Hz
- ≥ 45°C → 20 Hz
La température est lue toutes les secondes.

En mode *manual*, la fréquence est fixée par l'utilisateur via les boutons ou l'interface IPC.

== Daemon userspace (`fanctl_daemon`)
Le daemon gère :
- La LED power (gpio362): clignote lors de chaque appui bouton
- Les boutons S1, S2, S3 via interruptions GPIO
- L'affichage sur l'écran OLED
- La communication avec le module via sysfs
- L'interface IPC via un socket Unix

L'écran OLED affiche en temps réel :
- La température du CPU (rafraîchie toutes les secondes)
- La fréquence de clignotement de la LED status
- Le mode actuel (auto / manual)

== Boutons
#table(
  columns: (auto, 1fr),
  [*Bouton*], [*Action*],
  [S1], [Augmente la fréquence de 1 Hz (mode manuel uniquement)],
  [S2], [Diminue la fréquence de 1 Hz (mode manuel uniquement)],
  [S3], [Bascule entre le mode auto et manuel],
)

En mode auto, les boutons S1 et S2 sont ignorés.

== Application CLI (`fanctl_cli`)
L'application CLI permet de piloter le daemon via un socket Unix (`/tmp/fanctl.sock`).

#table(
  columns: (auto, 1fr),
  [*Commande*], [*Action*],
  [`fanctl_cli status`], [Affiche la température, le mode et la fréquence],
  [`fanctl_cli mode toggle`], [Bascule entre le mode auto et manuel],
  [`fanctl_cli freq <1-20>`], [Définit la fréquence en Hz (mode manuel uniquement)],
)

Le daemon traite chaque connexion de manière indépendante : il lit la commande, l'exécute et retourne immédiatement une réponse avant de fermer la connexion.

= Installation et lancement

== Prérequis
- Le device tree OLED doit être installé sur la cible et la carte redémarrée
- Le rootfs de la cible doit être synchronisé via CIFS sur le host sous `/rootfs/`

== Compilation et installation
Depuis le host, à la racine du projet :
`make install`

Cette commande compile tous les composants et les installe sur la cible :
- Module noyau: `/usr/lib/fanctl.ko`
- Daemon: `/usr/bin/fanctl_daemon`
- Application CLI: `/usr/bin/fanctl_cli`
- Script de lancement: `/etc/init.d/S60fanctl`

== Lancement automatique
Le script `S60fanctl` est installé dans `/etc/init.d/` et est exécuté automatiquement au démarrage de la carte. Le module est chargé puis le daemon est lancé en arrière-plan.

== Logs
Les logs du module sont disponibles avec la commande `dmesg`.
Les logs du daemon sont disponibles avec la commande `tail -f /var/log/messages`

= Travail réalisé
== Intégration de l'écran OLED
L'intégration de l'écran OLED nécessite l'installation d'un Device Tree spécifique sur la cible.
Nous utilisons pour cela le projet `oled` fourni. Après compilation, nous transférons le dts comme suit:
```
mount /dev/mmcblk2p1 /mnt/boot
ls /mnt/boot/
cp /mnt/boot/nanopi-neo-plus2.dtb /mnt/boot/nanopi-neo-plus2.dtb.bak
cp /workspace/src/07_miniproj/oled/mydt.dtb /mnt/boot/nanopi-neo-plus2.dtb
umount /mnt/boot
reboot
```
Une fois redémarré, nous testons la présence du endpoint:
```
# ls /dev/i2c-*
/dev/i2c-0
```
Nous testons avec succès le programme de demo `/workspace/src/07_miniproj/oled/oled`. Le texte attendu s'affiche à l'écran.

== Développement du module noyau
Nous commençons la réalisation par le module module noyau en nous inspirons des codelabs précédents dont `/workspace/src/03_drivers/exercice05`.
Nous le réalisons par étape: faire clignoter la LED Status (gpio10) à une fréquence fixe, nous exposons ensuite la fréquence sur le sysfs puis le mode.
La lecture de la température est testée via `cat /sys/class/thermal/thermal_zone0/temp`.

== Développement du daemon utilisateur
Le daemon userspace doit :
- Lire les boutons S1/S2/S3 via interruptions
- Écrire dans le sysfs pour changer mode/fréquence
- Afficher sur l'écran OLED : mode, température, fréquence

Nous nous basons sur les codelabs différents dont `/workspace/src/04_system/silly/silly_led_control.c` qui gère déjà une led et des boutons.

La lecture de la température (via le sysfs) a déjà été faite dans `/workspace/src/01_environement/system_calls/syscall.c`
On s'en inspire pour non seulement lire la température mais également la fréquence et le mode que nous venons d'exporter. 

Nous passons un certain temps à soigner les réponses en cas de mauvaise commande (par exemple essayer de modifier la fréquence alors que le mode n'est pas en manual, renvoyer le mode en cas de mode toggle, etc)

== Un Makefile pour les gouverner tous
Nous créons un makefile qui compilera tous nos binaires en une seule commande et qui les installera sur la carte.
Pour ceci, il faut que le rootfs soit bien synchronisé en cifs comme ça a été fait dans les laboratoires précédents.
Attention, le rootfs sur le host est situé sous `/rootfs/`.
Le module sera installé sous `/usr/lib`, le daemon et l'application sous `/usr/bin` et le script pour lancer le daemon sous `/etc/init.d`

= Choix de conception
== Gestion des fréquences
Dans le mode "auto", la fréquence peut prendre les valeurs de 2Hz, 5Hz, 10Hz ou 20Hz
Or, rien n'est indiqué pour le mode manuel.
Nous décidons de proposer des pas de 1 pour chaque fréquence avec comme fréquence minimale 1Hz et comme fréquence maximale 20Hz.

Nous n'avons pas implémenté de "mémoire" pour les fréquences manuelles: en passant du mode auto a manuel, la dernière fréquence utilisée en auto sera celle qui sera effective en mode manuel.
Ce choix semble cohérent avec l'hypothèse que si il s'agissait de contrôler un moteur,un saut sur les fréquences pourrait être dommageable. En outre, cela simplifie l'implémentation.

== Représentation du mode dans SysFS
Deux approches étaient possibles : exposer une valeur numérique ou exposer une chaîne de caractères.

Bien qu'une représentation numérique simplifie les comparaisons côté logiciel, le choix a été fait d'utiliser les chaînes "auto" et "manual" afin de rendre l'interface SysFS plus lisible et plus intuitive pour  l'utilisateur.

== Stratégie de rafraîchissement de l'écran
L'écran fonctionne de telle sorte que on peut mettre à jour uniquement les lignes qui changent.

Le taux de rafraîchissement des données susceptibles de changer (température, fréquence, mode) reste a déterminer.
Nous avons pris le parti de mettre à jour ces informations toute les secondes.

Nous savons cependant que certaines données vont changer suite à l'appui sur un bouton:
- la fréquence lors de l'appui sur les boutons pour l'incrémenter et la décrémenter
- le mode et la fréquence lors de l'appui sur le bouton toggle. En effet, en changeant le mode de manuel à automatique, la fréquence sera suceptible de changer.
- la réception d'une commande via l'IPS.

Pour une meilleure réactivité, les éléments susceptibles de changer sont également mis à jour lors de l'appui sur le bouton correspondant. Nous n'avons pas implémenté la mise à jour suite à la réception d'un message via l'IPS, pour éviter les effets de bord en cas de réception de messages répétés.

== Gestion de la LED Power
La led power sert à indiquer à l'utilisateur que l'appui sur le bouton a bien été réalisé.
Nous avons choisi de faire clignoter cette led même si l'action retourne une erreur (par exemple modifier la fréquence alors que le mode est en auto). Cela permet à l'utilisateur de voir que le bouton fonctionne, même si l'action désirée n'a pas pu être réalisée.

Le clignotement est actuellement réalisé à l'aide d'un usleep(). Cette solution bloque momentanément le traitement principal mais reste acceptable compte tenu des contraintes temporelles limitées du projet.

Une implémentation basée sur un timer supplémentaire ou sur un thread dédié aurait permis une meilleure séparation des responsabilités au prix d'une complexité accrue.

= Perspectives d'amélioration
- Ajouter une vérification en mode automatique afin d'éviter les changements fréquents de fréquence lorsque la température oscille autour d'un seuil.
- Remplacer l'utilisation de usleep() dans le daemon par un mécanisme non bloquant.
- Mettre en place des tests automatisés.
- Gérer les erreurs des appels système (`open`, `write`, `epoll`, etc). Cela n'a pas été réalisé dans les précédents codelab et amène de la complexité et de la lourdeur sur la lisibilité du code mais est indispensable pour un projet en production.
- Dans le daemon nous ouvrons/fermons des fichiers sysfs à chaque appel ce qui génère des syscalls et des accès mémoire dispersés. nous pourrions garder les fd ouverts en permanence, ce qui réduirait les accès mémoire.

== Optimisation
L'application CLI est très simple et son temps d'execution dépend principalement de l'utilisation du socket. Nous n'avons pas trouvé de piste d'optimisation.

Concernant le module noyau, nous avons identifié une optimisation pertinente : puisque le timer était partagé entre le clignottement de la led et la lecture de la température, celle-ci était effectuée à chaque tick du timer de clignotement, soit jusqu'à 20 fois par seconde en mode auto. La température du CPU ne variant pas si rapidement, nous avons séparé la logique en deux timers distincts : un timer dédié au clignotement de la LED, et un second timer lisant la température toutes les 5 secondes pour ajuster la fréquence en mode auto.

Nous réalisons une courte analyse de la consommation à l'aide de `htop`. Puisque notre plateforme est dédiée à cette application, la consommation mémoire et CPU reste largement dans les limites acceptables.
#figure(image("/lab03/resources/img/htop.png", width: 100%), caption: "Commande Htop")

= Difficulté
== mauvais export
Lors de la création du deamon, nous avons par erreur exporté la led gpui10 plutôt que la led de power.
Nous avons corrigé notre erreur, relancé le deamon, mais la led reste exportée.
Lorsque nous avons rechargé le module, nous obtenions l'erreur
```
# insmod fanctl.ko 
insmod: can't insert 'fanctl.ko': Device or resource busy
```
Nous avons pris un moment pour comprendre que l'erreur venait de la led qui était déjà exporté dans le sysfs. Il suffisait alors de la désexporter: `echo 10 > /sys/class/gpio/unexport` mais l'analyse nous a pris du temps.
Il nous aurai suffit pourtant de regarder le `dmesg` où l'erreur était explicite
```
[ 4649.442718] fanctl: failed to request gpio 10
```

== strncmp et le sysfs
sysfs ajoute un retour a la ligne en retournant le mode. Lors de la lecture et la comparaison du mode dans le daemon, attention a tronquer la fin de la chaîne de caractère. Cela nous a amené quelques déconvenues lors de la comparaison de chaine de caractère.

== IPC avec FIFO
Nous avons plusieurs choix pour réaliser l'IPC:
- FIFO: simple à implémenter mais unidirectionnel. Le deamon ne pourra pas répondre à la CLI pour confirmer le message, ou alors il faudra 2 FIFO.
- Pipe: nécessite un fork et nous aimerions que nos 2 processus soient indépendant.
- Message Queue: plus complexe qu'un fifo, mais bidirectionnel. La taille ainsi que le nombre de message doit être détérminé à la création.
- Socket: bidirectionnel mais plus complexe. 

Dans le cadre des anciens laboratoires, nous avons réalisé un socket-pair. Nous voulions tester ici une implémentation avec FIFO. Afin de pouvoir envoyer mais aussi recevoir des information, nous créons 2 FIFO: `/tmp/fanctl_cmd.fifo` et `/tmp/fanctl_resp.fifo`.
Les droits sur ces fichiers sont en read et write pour tous.

Le problème que nous rencontrons avec les FIFO est le flush des buffers.
Puisque nous sommes parti sur la volonté d'avoir une communication bidirectionnelle, il nous est difficile de gérer et nettoyer 2 fichiers entre les communications.
Nous nous retrouvons avec des messages dupliqués, des boucles pour nettoyer, etc. Ce n'est pas idéal.
Nous repartons donc sur les sockets heureusement, une bonne partie du code peut être réutilisé.
