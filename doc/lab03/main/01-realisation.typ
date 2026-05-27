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

=== Deamon en espace utilisateur
Le daemon userspace doit :
- Lire les boutons S1/S2/S3 via interruptions
- Écrire dans le sysfs pour changer mode/fréquence
- Afficher sur l'écran OLED : mode, température, fréquence

