#import "../metadata.typ": *
#pagebreak()

= Programmation système Linux 
== Résumé du laboratoire 
La carte NanoPi NEO Plus2 est équipée de deux LEDs dont une verte qui donne des indications d’état (status).
Le but de la première partie du laboratoire (Système de fichiers) est d'optimiser une application qui contrôle la fréquence de clignotement de cette LED à l’aide des trois boutons-poussoirs.

Le bouton K1 permet de diminuer la fréquence de clignotement, le bouton K2 permet de réinitialiser la fréquence à la valeur par défaut, et le bouton K3 permet d'augmenter la fréquence de clignotement. 
Une fonctionnalité optionnelle permet l’auto-incrémentation et l’auto-décrémentation de la fréquence de clignotement lors d’un appui prolongé sur les boutons K1 et K3.

Tous changements de fréquence doivent être indiqués dans les logs du système à l'aide de syslog. 

Une contrainte supplémentaire impose l’utilisation du multiplexage des entrées et sorties pour la gestion des interactions avec les boutons et la LED. Cette exigence s’inscrit dans l’objectif d’optimisation de l’application afin d’éviter une utilisation de 100 % d’un cœur processeur, observée dans la version initiale.

Dans la deuxième partie du laboratoire (Multiprocessing et Ordonnanceur) permet d'exercer la communication interprocessus, la gestion des signaux et le contrôle des ressources à l’aide des CGroups à l'aide de plusieurs exercices.

== Travail réalisé
=== Système de fichiers
Nous commencons par ajouter la possibilité de modifier la fréquence de clignotement à l'aide des boutons. Afin d’identifier les GPIO associés aux boutons K1, K2 et K3 ainsi qu’à la LED verte, il est nécessaire de monter le système de fichiers debugfs afin d’accéder aux informations correspondantes, comme illustré ci-dessous.

Nous développons une application qui utilise ces GPIO pour contrôler la fréquence de clignotement de la LED en fonction des boutons pressés.
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
Ces informations permettent d’identifier les GPIO des boutons et de la LED. Il est ensuite possible de les contrôler en écrivant dans les fichiers correspondants dans le système de fichiers virtuel _sysfs_.

Dans un premier temps, nous prenons exemple sur le code de la version initiale qui utilise le polling. Comme on peut le voir sur l'extrait du 'top' ci-dessous, cette version utilise 100% du cœur 0 de notre processeur.
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
Nous ajoutons gestion des boutons à l'aide du multiplexage des entrées et sorties avec la fonction `epoll()`.
Cela nous permet de travailler de manière événementielle, en réagissant uniquement lorsque les boutons sont pressés ou lorsque le timer pour le clignotement de la LED expire, plutôt que de faire du polling constant qui consomme beaucoup de ressources CPU. Dans cette version optimisée, nous avons réussi à réduire l'utilisation du CPU à environ 1% lors de l'exécution de l'application, ce qui est une amélioration significative par rapport à la version initiale.
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
Nous ajoutons également la fonctionnalité d'auto incrémentation et auto décrémentation de la fréquence de clignotement lorsque les boutons K1 ou K3 sont maintenus enfoncés. Nous créons un timer supplémentaire pour détecter la durée pendant laquelle un bouton est maintenu enfoncé, et nous ajustons la fréquence de clignotement en conséquence. La période de ce timer est hardcodée, la valeur est choisie de manière empirique. Cette methode n'est pas optimale mais elle permet d'avoir une bonne réactivité sans être trop rapide.

=== Multiprocessing et Ordonnanceur
==== Exercice 1 - Processus, signaux et communication
L’exécution de l’application met en évidence la création de deux processus distincts. En effet, l’appel système `fork()` duplique le processus courant afin de créer un processus enfant possédant son propre contexte d’exécution. Nous observons cette duplication à l’aide de la commande `ps`, qui affiche simultanément le processus parent et le processus enfant :
```
ps -aux
...
root       307  0.0  0.0   1868   196 pts/1    S+   00:57   0:00 ./app
root       308  0.0  0.0   1868    80 pts/1    S+   00:57   0:00 ./app
```
L’application implémente un mécanisme de communication inter-processus basé sur socketpair(). Le processus enfant lit les données saisies au clavier puis transmet les messages textuels au processus parent, lequel les affiche sur la sortie standard.

L’arrêt normal de l’application est réalisé par l’envoi du message "exit" depuis l’entrée standard. Le parent détecte alors cette commande et termine proprement son exécution.

Afin de valider la gestion des signaux, le PID du processus parent est récupéré puis plusieurs signaux sont envoyés manuellement à l’aide de la commande kill. Les signaux SIGHUP, SIGINT, SIGQUIT, SIGABRT et SIGTERM sont correctement interceptés et ignorés conformément aux spécifications de l’exercice. Un simple message informatif est alors affiché à l’écran sans interruption du programme.

À l’inverse, l’envoi du signal SIGILL (4), qui n’est pas explicitement géré par l’application, provoque l’arrêt immédiat du programme avec une erreur d’instruction illégale.

#table(
columns: 2,
align: left + top,
inset: 8pt,

[Sortie du programme],[Commandes envoyées],

[
```
hihihi
[PARENT] reçu: hihihi
[SIGNAL IGNORED] reçu SIGINT (2)
[SIGNAL IGNORED] reçu SIGHUP (1)
[SIGNAL IGNORED] reçu SIGINT (2)
[SIGNAL IGNORED] reçu SIGQUIT (3)
[SIGNAL IGNORED] reçu SIGABRT (6)
[SIGNAL IGNORED] reçu SIGTERM (15)
Illegal instruction
```
],
[
```
# kill -1 307
# kill -2 307
# kill -3 307
# kill -6 307
# kill -15 307
# kill -4 307
```
]
)

==== Exercice 2 - CGroups
La configuration du noyau Linux est déjà adaptée à l'utilisation des cgroups.
Nous créons le script `run.sh` qui monte les cgroups, il est disponible et commenté dans les sources.
#thinkbox()[1. Quel effet a la commande echo $$ > ... sur les cgroups ?]

La commande `echo $$` retourne le PID du shell courant, dans notre cas celui exécutant le script `run.sh`.
Ce PID est ensuite écrit dans le fichier `tasks` du cgroup. Cela ajoute le processus shell au groupe de contrôle `mem`.

Ainsi, tous les processus enfants lancés depuis ce shell héritent de ce cgroup. Lorsque le script lance l’application `memtest`, celle-ci est donc exécutée dans le cgroup configuré et respecte la limite mémoire définie avec `memory.limit_in_bytes`.

---

#thinkbox()[2. Quel est le comportement du sous-système memory lorsque le quota de mémoire est épuisé ? Pourrait-on le modifier ? Si oui, comment ?]
Dans notre cas, le noyau déclenche l’OOM killer du cgroup, qui termine notre programme. Nous observons alors un message `Killed` dans les logs.

La limite mémoire peut être modifiée via une écriture d’une valeur valide dans `memory.limit_in_bytes`.
La valeur de limite peut être modifiée dynamiquement (dans un autre terminal), tant qu'elle est valide et supérieure à la consommation actuelle du cgroup.
Si nous essayons d'écrire une valeur invalide, le message `sh: write error: Invalid argument`s'affiche.
Si la nouvelle limite est inférieure à la consommation actuelle, la commande peut échouer avec une erreur de type `Device or resource busy`.
Les fichiers du système cgroup ne sont pas des fichiers physiques mais des interfaces exposées par le noyau Linux ; ils ne peuvent donc pas être supprimés avec `rm`.
Pour supprimer la limitation mémoire, il est possible d’utiliser la valeur `-1`.


Le comportement peut être également modifié via la configuration de l'OOM.
Pour désactiver l'OOM-killer, nous pouvons ecrire `1` sur le fichier `memory.oom_control`

Le comportement OOM est visible avec la commande suivante:
```
# cat /sys/fs/cgroup/memory/mem/memory.oom_control
oom_kill_disable 0
under_oom 0
oom_kill 7
```
- "oom_kill_disable" : indique si l’OOM killer est désactivé,
- "under_oom" : indique si le cgroup est en état de manque de mémoire,
- "oom_kill" : compteur du nombre de processus tués par OOM.

À noter que ce mécanisme appartient aux cgroups v1 et est marqué comme déprécié, mais il est encore utilisé dans le cadre de ce laboratoire.

#thinkbox()[3. Est-il possible de surveiller/vérifier l’état actuel de la mémoire ? Si oui, comment ?]
Pour connaitre l'utilisation de la mémoire de notre sous groupe nous utilisons la commande `# cat /sys/fs/cgroup/memory/mem/memory.usage_in_bytes`
La lecture du fichier `memory.stat` fournit des informations plus détaillées sur la répartition de la mémoire (RSS, cache, pages mappées, etc.).

Source: https://docs.kernel.org/admin-guide/cgroup-v1/memory.html


==== Exercice 3
Nous créons un programme pour consommer du CPU et nous ajoutons des limitations concernant le CPU dans les cgroups.
```
$ mkdir /sys/fs/cgroup/cpuset
$ mount -t cgroup -o cpu,cpuset cpuset /sys/fs/cgroup/cpuset
# création de 2 groupes high et low
$ mkdir /sys/fs/cgroup/cpuset/high
$ mkdir /sys/fs/cgroup/cpuset/low
$ echo 3 > /sys/fs/cgroup/cpuset/high/cpuset.cpus
$ echo 0 > /sys/fs/cgroup/cpuset/high/cpuset.mems
$ echo 2 > /sys/fs/cgroup/cpuset/low/cpuset.cpus
$ echo 0 > /sys/fs/cgroup/cpuset/low/cpuset.mems
```
#thinkbox()[1. Les 4 dernières lignes sont obligatoires pour que les prochaines commandes fonctionnent correctement. Pouvez-vous en donner la raison ?]
`echo 3 > /sys/fs/cgroup/cpuset/high/cpuset.cpus` et `echo 2 > /sys/fs/cgroup/cpuset/low/cpuset.cpus`
Ces commandes définissent les CPU autorisés pour chaque cgroup. Le groupe high est limité au CPU 3 et le groupe low au CPU 2.

`$ echo 0 > /sys/fs/cgroup/cpuset/high/cpuset.mems`
Le paramètre `cpuset.mems` correspond à liste des noeuds mémoire autorisés pour un cgroup. Un noeud mémoire représente une zone physique de RAM.
Certains systèmes linux peuvent avoir leur mémoire divisée en “noeuds” mais dans notre cas, nous avons une seule mémoire non divisée.
Si nous ne renseignons pas ce paramètre, le noyau refuse d’associer un processus au cgroup, ce qui entraîne l’erreur suivante :
```bash
# echo $$ > /sys/fs/cgroup/cpuset/low/tasks
sh: write error: No space left on device
```

#thinkbox()[2. Ouvrez deux shells distincts et placez une dans le cgroup high et l’autre dans le cgroup low. Lancez ensuite votre application dans chacun des shells. Quel devrait être le bon comportement ? Pouvez-vous le vérifier ?]
Chaque shell est assigné à un cgroup différent et donc restreint à un CPU distinct.
Chaque processus peut ainsi utiliser pleinement le CPU qui lui est assigné, ce qui permet d’observer une utilisation proche de 100% sur chaque coeur.
Nous vérifions cela avec la commande `htop`:
#figure(image("/lab02/resources/img/ex3_htop.png", width: 100%), caption: "Commande Htop avec répartition sur 2 CPUs")

À l’inverse, si les deux processus sont placés dans le même cgroup ou sur le même CPU, ils se partagent le temps processeur, ce qui entraîne une répartition approximative de 50% / 50%.
#figure(image("/lab02/resources/img/ex3_htp_samecpu.png", width: 100%), caption: "Commande Htop sans répartition")

Source: https://docs.kernel.org/admin-guide/cgroup-v1/cpusets.html


#thinkbox()[3. Sachant que l’attribut cpu.shares permet de répartir le temps CPU entre différents cgroups, comment devrait-on procéder pour lancer deux tâches distinctes sur le cœur 4 de notre processeur et attribuer 75% du temps CPU à la première tâche et 25% à la deuxième ?]
`cpu.shares` contient un ratio. Voici les commandes que nous lançons:
```bash
# forcer les cgroups sur le même coeur (4)
echo 4 > /sys/fs/cgroup/cpuset/high/cpuset.cpus
echo 4 > /sys/fs/cgroup/cpuset/low/cpuset.cpus
# fixer la mémoire node (déjà fait normalement)
echo 0 > /sys/fs/cgroup/cpuset/high/cpuset.mems
echo 0 > /sys/fs/cgroup/cpuset/low/cpuset.mems
# fixer le ratio (le minimum est 2)
echo 6 > /sys/fs/cgroup/cpuset/high/cpu.shares
echo 2 > /sys/fs/cgroup/cpuset/low/cpu.shares
```

Nous avons constaté que en écrivant la valeur "1" dans "cpu.shares", celle-ci est forcée à "2". Nous adaptons les valeurs en conséquence tout en consérvant le même ratio.
Le CPU 4 n’étant pas disponible sur notre système, nous utilisons le CPU 3.

#figure(image("/lab02/resources/img/ex3_htop_75_25.png", width: 100%), caption: "Commande Htop avec répartition 75-25")

#pagebreak()
== Synthèse sur ce qui a été appris/exercé
Lors de la première partir de ce laboratoire, nous avons appris et exercé l'utilisation des GPIOs pour contrôler des composants matériels, en l'occurrence des boutons et une LED, ainsi que l'utilisation de `epoll()` pour faire de la programmation événementielle, ce qui est essentiel pour optimiser les applications système et éviter une utilisation excessive du CPU. Nous avons également pu ré-exercer l'utilisation de syslog pour enregistrer des événements dans les logs du système, ce qui est une pratique courante pour le débogage et la surveillance des applications système.

L'utilisation des timers pour gérer les fréquences de clignotement et les auto incrémentations/décrémentations a également été une partie importante de ce laboratoire, nous permettant de mieux comprendre comment gérer le temps dans les applications système.

La seconde partie nous a permis d’exercer la programmation multiprocessus avec la création de processus via `fork()`, la communication interprocessus au moyen de `socketpair()`, ainsi que la gestion et l’interception des signaux Linux. Nous étudions également la capacité, via les groupes de contrôle, à limiter l'utilisation de la mémoire et l'utilisation des CPU.

== Remarques et choses à retenir
La programmation sur système Linux nécessite une bonne compréhension du système de fichiers virtuel, notamment _sysfs_ et _debugfs_, pour interagir avec le matériel. L'utilisation de `epoll()` est essentielle pour créer des applications efficaces qui réagissent aux événements sans consommer inutilement des ressources CPU. Enfin, l'enregistrement d'événements dans les logs du système à l'aide de syslog est une pratique importante pour le débogage et la surveillance des applications système.

La gestion multiprocessus nécessite une bonne compréhension du cycle de vie des processus, de la communication interprocessus et du traitement des signaux.
Les CGroups constituent un mécanisme important permettant de limiter les ressources utilisées par des processus. Ils jouent un rôle central dans la gestion des performances.

== Feedback personnel sur le laboratoire
Ce laboratoire a été très instructif et didactique pour comprendre comment fonctionne la programmation système Linux, en particulier en ce qui concerne l'interaction avec le matériel à travers les GPIOs et l'optimisation des applications pour une utilisation efficace des ressources. 
Le fait de nous avoir donné une base de programme fonctionnelle, puis de nous demander d'ajouter des fonctionnalités tout en l'optimisant, à été une très bonne approche pour comprendre le fonctionnement global du système. Selon nous, une structure similaire pour les laboratoires précédents aurait représenté un avantage pédagogique, malgré la charge de travail supplémentaire qu’elle implique.

Concernant la seconde partie du laboratoire, les exercices proposés sont bien structurés et suffisamment courts pour permettre une bonne compréhension des différents concepts abordés. Un complément pourrait toutefois être apporté concernant les signaux Linux, notamment en établissant une correspondance entre certains événements ou actions utilisateur et les signaux générés (par exemple _Ctrl+C_ pour `SIGINT` ou la fermeture d’un terminal pour `SIGHUP`).

