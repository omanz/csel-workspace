#import "../metadata.typ": *
#pagebreak()

= Résumé du laboratoire 
Ce projet est une application permettant de simuler la gestion de la vitesse de rotation d’un ventilateur en fonction de la température du processeur.

= Description de l'application

L'application est composée de trois parties principales : un module noyau, un daemon userspace et une application qui fourni une interface utilisateur en ligne de commande.

== Module noyau (`fanctl.ko`)
Le module noyau gère la LED status (gpio10) et expose deux attributs via sysfs :
- `/sys/class/fanctl/fanctl/frequency` : fréquence de clignotement de la LED, de 1 à 20 Hz
- `/sys/class/fanctl/fanctl/mode` : mode de fonctionnement (`auto` ou `manual`)

En mode *auto*, la fréquence est déterminée par la température du CPU :
- < 35°C → 2 Hz
- < 40°C → 5 Hz
- < 45°C → 10 Hz
- ≥ 45°C → 20 Hz

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
== Installation du device tree
Nous compilons le projet `oled` founi et remplacons le dts sur la cible:
```
mount /dev/mmcblk2p1 /mnt/boot
ls /mnt/boot/
cp /mnt/boot/nanopi-neo-plus2.dtb /mnt/boot/nanopi-neo-plus2.dtb.bak
cp /workspace/src/07_miniproj/oled/mydt.dtb /mnt/boot/nanopi-neo-plus2.dtb
umount /mnt/boot
reboot
```
Une fois redemaré, nous testons la présence du endpoint:
```
# ls /dev/i2c-*
/dev/i2c-0
```
Nous testons avec succès le programme de demo `/workspace/src/07_miniproj/oled/oled`. Le texte attendu s'affiche à l'ecran.

== Module noyau
Nous allons commencer par créer un module noyau qui fait clignoter la LED Status (gpio10) à une fréquence fixe.
Nous installons manuellement le module pour vérifier son bon fonctionnement avec la commande `insmod`.

La seconde étape est d'exposer la fréquence et le mode via sysfs.
La frequence est atteignable via `/sys/class/fanctl/fanctl/frequency` et peut aller de 1 à 20.
Le mode est atteignable via `/sys/class/fanctl/fanctl/mode` et prend les valeurs `auto` et `manual`.

La lecture de la température peut être testée via `cat /sys/class/thermal/thermal_zone0/temp`.

Le module gère la led status (gpiol.10 --> gpio10 selon `silly_led_control.c`))

=== Deamon en espace utilisateur
Le daemon userspace doit :
- Lire les boutons S1/S2/S3 via interruptions
- Écrire dans le sysfs pour changer mode/fréquence
- Afficher sur l'écran OLED : mode, température, fréquence

Le deamon gère la led Power (gpiol.10 --> gpio362 selon `silly_led_control.c`))
Je me base sur le fichier `/workspace/src/04_system/silly/silly_led_control.c` qui gère deja une led et des boutons.
Je veux voir mes logs avec `tail -f /var/log/messages`
Prochaine étape:
blink de la led lors de l'appui sur un bouton


Prochaine étape, aller communiquer avec le module noyau via sysfs pour lire la température par exemple
La lecture de la temperature a déjà été faite dans `01_environement/system_calls/syscall.c`
On s'en inspire pour lire la température. Celle-ci devra être lue périodiquement à l'aide d'un timer pour l'affichage sur l'écran

Dans la lancée, on continue avec la lecture des sysfs exportés par notre module.
(frequence et mode)
On se rend compte qu'il est plus aisé de retourner des int plutot que des char pour les comparaisons.
Or on lis du sysfs une string, que on converti en int. On fesait l'inverse dans le module ce qui double le travail. Mais on maintient cette manière de faire car il nous semble plus "user friendly" de retourner une string comprehensible en interrogeant le sysfs que un numero qu'il faut interpréter.

Nous passons un certain temps à soigner les réponses en cas de mauvaise commande (par exemple essayer de modifier la fréquence alors que le mode n'est pas en manual, renvoyer le mode en cas de mode toggle, etc)

=== Integration de l'écran
Plusieurs questions se posent: taux de rafraichissement, comment gérer le timer...
`silly_led_control` contenait deja un timer, on va le réutiliser.
L'ecran fonctionne de telle sorte que on peut mettre a jour uniquement les lignes qui changent.

On choisi donc de mettre a jour la température toute les secondes, et on en profite pour mettre à jour la fréquence et le mode au cas où ils auraient changés (un restart du module?).
la fréquence est mise à jour également si elle est modifiée lors de l'appui sur un bouton.
le mode est mis à jour lors de l'appui sur le bouton toggle.

Pour éviter d'avoir un délai de 1 seconde sur l'affichage de la nouvelle fréquence lorsqu'on passe de manual à auto, on relis la fréquence une fois que on a changé de mode.

=== Choix d'implémentation
== Frequence
Dans le mode "auto", la fréquence peut prendre les valeurs de 2Hz, 5Hz, 10Hz ou 20Hz
Or, rien n'est indiqué pour le mode manuel.
Nous décidons de donner plus de liberté en fesant des pas de 1 pour chaque fréquence avec comme frequence minimale 1Hz et comme frequence maximale 20Hz (c'est ce qui est deja défini dans notre module)

Lorsque on change de mode pour passer de auto à manual, la dernière fréquence utilisée en manuelle reste active. Cela semble cohérent si il s'agissait de controler un moteur, et cela évite de gérer une mémoire quand à la dernière fréquence utilisée en mode manuel.

=== Integration de l'écran
Plusieurs questions se posent: taux de rafraichissement, comment gérer le timer...
`silly_led_control` contenait deja un timer, on va le réutiliser.
L'ecran fonctionne de telle sorte que on peut mettre à jour uniquement les lignes qui changent.

On choisi donc de mettre a jour la température toute les secondes, et on en profite pour mettre à jour la fréquence et le mode au cas où ils auraient changés (un restart du module?).
la fréquence est mise à jour également si elle est modifiée lors de l'appui sur un bouton.
le mode est mis à jour lors de l'appui sur le bouton toggle.

Pour éviter d'avoir un délai de 1 seconde sur l'affichage de la nouvelle fréquence lorsqu'on passe de manual à auto, on relis la fréquence une fois que on a changé de mode.

== Questionnement
- Est ce que on ajoute un délai en auto si on est entre 2 température pour éviter que la fréquence change trop souvent? Ce serai à faire dans le module.

=== Un Makefile pour les gouverner tous
Nous créons un makefile qui compilera touts nos binaires en une seule commande et qui les installeras sur la carte.
Pour ceci, il faut que le rootfs soit bien syncronisé en cifs comme ça a été fait dans les laboratoires précédents.
Attention, le rootfs sur le host est situé sous `/rootfs/`.
Le module sera installé sous `/usr/lib`, le daemon et l'application sous `/usr/bin` et le script pour lancer le daemon sous `/etc/init.d`

== Amélioration du daemon
Pour faire allumer et éteindre la led power, nous utilisons un usleep qui a le désaventage de bloquer tout le système. Dans ce projet, le temps n'est pas critique, mais l'utilisation d'un second timer serait plus propre, bien que très verbeuse. Nous avons privilegié la simplicité en maintenant notre usleep.

Une autre possibilité aurait été d'utiliser un thread et de maintenir le `usleep` dans le thread, pour ne pas bloquer le thread principal mais cela amène d'autres difficultés (concurence lors de l'appui répété sur le bouton, gestion de ressource partagées, etc)

== Clignotement de la led power
La led power sert à indiquer à l'utilisateur que l'appui sur le bouton a bien été réalisé.
Nous avons choisi de faire clignotter cette led même si l'action retounre une erreur (par exemple modifier la fréquence alors que le mode est en auto). car un retour visuel nous semble important pour signifier a l'utilisateur que son action a bien été prise en compte, même si elle ne peux pas être réalisée. Cela permet à l'utilisateur de voir que le bouton fonctionne, même si l'action désirée n'a pas pu être réalisée.
== Difficulté
=== mauvais export
Lors de la création du deamon, nous avons par erreur exporté la led gpui10 plustot que la led de power.
Nous avons corrigé notre erreur, relancé le deamon, mais la led reste exportée.
Lorsque nous avons rechargé le module, nous obtenions l'erreur
```
# insmod fanctl.ko 
insmod: can't insert 'fanctl.ko': Device or resource busy
```
Nous avons pris un moment pour comprendre que l'erreur venait de la led qui était deja exporté dans le sysfs. Il suffisait alors de la désexporter: `echo 10 > /sys/class/gpio/unexport` mais l'analyse nous a pris du temps.
Il nous aurai suffit pourtant de regarder le `dmesg` où l'erreur était explicite
```
[ 4649.442718] fanctl: failed to request gpio 10
```

=== strncmp et le sysfs
sysfs ajoute un retour a la ligne en retournant le mode. Lors de la lecture et la comparaison du mode dans le daemon, attention a tronquer la fin de la châine de caractère. Cela nous a amené quelques déconvenues lors de la comparaison de chaine de caractère.

=== IPC avec FIFO
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
