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
== Résumé du laboratoire

== Réponse aux questions

== Synthèse sur ce qui a été appris/exercé

== Remarques et choses à retenir

