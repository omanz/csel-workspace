#import "../metadata.typ": *
#pagebreak()

= Optimisation système Linux
TODO: expliquer a quel signal il ne va plus repondre
SIGHUP, SIGINT, SIGQUIT, SIGABRT et SIGTERM
avec exemple pkill etc
== Processus, signaux et communication
=== Exercice 1
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

== CGroups
=== Exercice 2
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


=== Exercice 3
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



== Résumé du laboratoire

== Réponse aux questions

== Synthèse sur ce qui a été appris/exercé

== Remarques et choses à retenir

