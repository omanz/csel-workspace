#import "../metadata.typ": *
#pagebreak()

= Mini Projet - Programmation noyau et système

== Résumé du laboratoire 
Ce projet est une application permettant de simuler la gestion de la vitesse de rotation d’un ventilateur en fonction de la température du processeur.

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

question: taux de rafraichissement de l'écran?

== Difficulté
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