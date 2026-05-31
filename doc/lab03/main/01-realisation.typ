#import "../metadata.typ": *
#pagebreak()

= Mini Projet - Programmation noyau et système

== Résumé du laboratoire 
Ce projet est une application permettant de simuler la gestion de la vitesse de rotation d’un ventilateur en fonction de la température du processeur.

== Description de l'application

L'application est composée de trois parties principales : un module noyau, un daemon userspace et une application qui fourni une interface utilisateur en ligne de commande.

=== Module noyau (`fanctl.ko`)
Le module noyau gère la LED status (gpio10) et expose deux attributs via sysfs :
- `/sys/class/fanctl/fanctl/frequency` : fréquence de clignotement de la LED, de 1 à 20 Hz
- `/sys/class/fanctl/fanctl/mode` : mode de fonctionnement (`auto` ou `manual`)

En mode *auto*, la fréquence est déterminée par la température du CPU :
- < 35°C → 2 Hz
- < 40°C → 5 Hz
- < 45°C → 10 Hz
- ≥ 45°C → 20 Hz

En mode *manual*, la fréquence est fixée par l'utilisateur via les boutons ou l'interface IPC.

=== Daemon userspace (`fanctl_daemon`)
Le daemon gère :
- La LED power (gpio362): clignote lors de chaque appui bouton
- Les boutons S1, S2, S3 via interruptions GPIO
- L'affichage sur l'écran OLED
- La communication avec le module via sysfs

L'écran OLED affiche en temps réel :
- La température du CPU (rafraîchie toutes les secondes)
- La fréquence de clignotement de la LED status
- Le mode actuel (auto / manual)

=== Boutons
#table(
  columns: (auto, 1fr),
  [*Bouton*], [*Action*],
  [S1], [Augmente la fréquence de 1 Hz (mode manuel uniquement)],
  [S2], [Diminue la fréquence de 1 Hz (mode manuel uniquement)],
  [S3], [Bascule entre le mode auto et manuel],
)

En mode auto, les boutons S1 et S2 sont ignorés.

== Installation

=== Prérequis
- Le device tree OLED doit être installé sur la cible
- le workspace doit être disponible

=== Compilation
TODO: faire un makefile global
TODO: installer sur la cible avec un make install plutot que d'utiliser le workspace?

=== Lancement manuel
`/workspace/src/07_miniproj/daemon/S60fanctl start`

== Travail réalisé
=== Ecran
Nous commencons par tester l'écran. Pour ce faire, nous compilons le projet founi a disposition et remplacons le dts sur la cible:
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
Puis nous tetons avec succès le programme de test `/workspace/src/07_miniproj/oled/oled`. Le texte attendu s'affiche à l'ecran.

=== Module noyau
Nous allons commencer par créer un module noyau qui fait clignoter la LED Status (gpio10) à une fréquence fixe.
Nous installons manuellement le module pour vérifier son bon fonctionnement avec la commande `insmod`.

La seconde étape est d'exposer la fréquence et le mode via sysfs.
La frequence est atteignable via `/sys/class/fanctl/fanctl/frequency` et peut aller de 1 à 20.
Le mode est atteignable via `/sys/class/fanctl/fanctl/mode` et prend les valeurs `auto` et `manual`.

La lecture de la température peut être testée via `cat /sys/class/thermal/thermal_zone0/temp`.

Le module gère la led status (gpiol.10 --> gpio10 selon silly_led_control.c))

=== Deamon en espace utilisateur
Le daemon userspace doit :
- Lire les boutons S1/S2/S3 via interruptions
- Écrire dans le sysfs pour changer mode/fréquence
- Afficher sur l'écran OLED : mode, température, fréquence

Le deamon gère la led Power (gpiol.10 --> gpio362 selon silly_led_control.c))
Je me base sur le fichier /workspace/src/04_system/silly/silly_led_control.c qui gère deja une led et des boutons.
Je veux voir mes logs avec `tail -f /var/log/messages`
Prochaine étape:
blink de la led lors de l'appui sur un bouton


Prochaine étape, aller communiquer avec le module noyau via sysfs pour lire la température par exemple
La lecture de la temperature a déjà été faite dans 01_environement/system_calls/syscall.c
On s'en inspire pour lire la température. Celle-ci devra être lue périodiquement à l'aide d'un timer pour l'affichage sur l'écran

Dans la lancée, on continue avec la lecture des sysfs exportés par notre module.
(frequence et mode)
On se rend compte qu'il est plus aisé de retourner des int plutot que des char pour les comparaisons.
Or on lis du sysfs une string, que on converti en int. On fesait l'inverse dans le module ce qui double le travail. Mais on maintient cette manière de faire car il nous semble plus "user friendly" de retourner une string comprehensible en interrogeant le sysfs que un numero qu'il faut interpréter.

== Frequence
Dans le mode "auto", la fréquence peut prendre les valeurs de 2Hz, 5Hz, 10Hz ou 20Hz
Or, rien n'est indiqué pour le mode manuel.
Nous décidons de donner plus de liberté en fesant des pas de 1 pour chaque fréquence avec comme frequence minimale 1Hz et comme frequence maximale 20Hz (c'est ce qui est deja défini dans notre module)


question: taux de rafraichissement de l'écran?

== Script
Nous créons un script en nous inspirant de /workspace/src/01_environment/daemon/S60_appl, que nous nommons `S60fanctl` qui permets de relancer le deamon lors de nos nombreux tests.
Il charge le module et lance le daemon.

TODO: Il sera installé dans /etc/init.d. Faire Makefile?

=== Integration de l'écran
Plusieurs questions se posent: taux de rafraichissement, comment gérer le timer...
silly_led_control contenait deja un timer, on va le réutiliser.
L'ecran fonctionne de telle sorte que on peut mettre a jour uniquement les lignes qui changent.

On choisi donc de mettre a jour la température toute les secondes, et on en profite pour mettre à jour la fréquence et le mode au cas où ils auraient changés (un restart du module?).
la fréquence est mise à jour également si elle est modifiée lors de l'appui sur un bouton.
le mode est mis à jour lors de l'appui sur le bouton toggle.

Pour éviter d'avoir un délai de 1 seconde sur l'affichage de la nouvelle fréquence lorsqu'on passe de manual à auto, on relis la fréquence une fois que on a changé de mode.

== Frequence
Lorsque on change de mode pour passer de auto à manual, la dernière fréquence utilisée en manuelle reste active. Cela semble cohérent si il s'agissait de controler un moteur, et cela évite de gérer une mémoire quand à la dernière fréquence utilisée en mode manuel.

=== Application pour l'interface utilisateur
L'application fournis une interface utilisateur, une ligne de commande, pour piloter le système via l’interface IPC choisie.

==== Interface IPC - Inter-Process Communication
Nous avons plusieurs choix pour réaliser l'IPC:
- FIFO: simple à implémenter mais unidirectionnel. Le deamon ne pourra pas répondre à la CLI pour confirmer le message, ou alors il faudra 2 FIFO.
- Pipe: nécessite un fork et nous aimerions que nos 2 processus soient indépendant.
- Message Queue: plus complexe qu'un fifo, mais bidirectionnel. La taille ainsi que le nombre de message doit être détérminé à la création.
- Socket: bidirectionnel mais plus complexe. 

Dans le cadre des anciens laboratoires, nous avons réalisé un socket-pair. Nous allons tester ici une implémentation avec FIFO. Afin de pouvoir envoyer mais aussi recevoir des information, nous créons 2 FIFO: `/tmp/fanctl_cmd.fifo` et `/tmp/fanctl_resp.fifo`.
Les droits sur ces fichiers sont en read et write pour tous.

==== Changement IPC
Le problème que nous rencontrons avec les FIFO est le flush des buffers.
Puisque nous sommes parti sur la volonté d'avoir une communication bidirectionnelle, il nous est difficile de gérer et nettoyer 2 fichiers entre les communications.
Nous nous retrouvons avec des messages dupliqués, des boucles pour nettoyer, etc. Ce n'est pas idéal.
Nous repartons donc sur les sockets heureusement, une bonne partie du code peut être réutilisé.



== Questionnement
- Est ce que on ajoute un délai en auto si on est entre 2 température pour éviter que la fréquence change trop souvent? Ce serai à faire dans le module.



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