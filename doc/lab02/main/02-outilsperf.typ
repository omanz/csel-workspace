#import "../metadata.typ": *
#pagebreak()
= #box[
  #text(size: 19pt)[Outils d'analyse de performance pour Linux]
]
== Exercice 01
#thinkbox()[Sans options spécifiques, la commande mesure par défaut un certain nombre de compteurs. Relevez par exemple les compteurs du nombre de context-switches et d’instructions ainsi que le temps d’exécution.]
```
# perf stat ./ex1 

 Performance counter stats for './ex1':

          41986.51 msec task-clock                #    1.000 CPUs utilized          
                20      context-switches          #    0.476 /sec                   
                 0      cpu-migrations            #    0.000 /sec                   
             48868      page-faults               #    1.164 K/sec                  
       34260711638      cycles                    #    0.816 GHz                    
        1672170819      instructions              #    0.05  insn per cycle         
         269720534      branches                  #    6.424 M/sec                  
           1011106      branch-misses             #    0.37% of all branches        

      42.005333145 seconds time elapsed

      41.311481000 seconds user
       0.280660000 seconds sys
```
L'execution du programme prend environ 42 secondes dont la majeur partie en espace utilisateur. Nous en déduisons qu'il travaille probablement peu avec les I/O et fait majoritairement du calcul pur et des accès mémoire.
Le compteur d'instruction indique que le CPU passe le principal de son temps à attendre (0.05 insn per cycle). Le branch-misses est raisonnable (0.37%). Le programme a subi 20 changements de contexte durant son exécutionle ce qui est également raisonnable.

#thinkbox()[Ce programme contient une erreur triviale qui empêche une utilisation optimale du cache. De quelle erreur s’agit-il ?]
Le programme parcours le tableau par colonnes au lieu de lignes. Il fait donc des sauts entre les adresses memoire au lieu de modifier des emplacement mémoire contigu. En effet, le cache depend de la localité spatiale et temporelle: il faut que 2 opérations qui utilisent une même zone mémoire soient faites proche dans le temps.
Notre analyse est confirmée par la commande `perf stat -e cache-misses ./ex1`. Elle nous permet de voir que le cache misses est très élevé, le cache mémoire est donc mal utilisé.
```
# perf stat -e cache-misses ./ex1
 Performance counter stats for './ex1':
         406897743      cache-misses
      38.942507102 seconds time elapsed
      38.265720000 seconds user
       0.276567000 seconds sys
```


#thinkbox()[Corrigez l’erreur, recompilez et mesurez à nouveau le temps d’exécution (soit avec perf stat, soit avec la commande time). Quelle amélioration constatez-vous ?]
```
# perf stat ./ex1 

 Performance counter stats for './ex1':

           2409.50 msec task-clock                #    0.992 CPUs utilized          
                17      context-switches          #    7.055 /sec                   
                 0      cpu-migrations            #    0.000 /sec                   
             48867      page-faults               #   20.281 K/sec                  
        1966007847      cycles                    #    0.816 GHz                    
        1380444909      instructions              #    0.70  insn per cycle         
         264953592      branches                  #  109.962 M/sec                  
            653992      branch-misses             #    0.25% of all branches        

       2.429980293 seconds time elapsed

       2.165846000 seconds user
       0.222076000 seconds sys


# perf stat -e cache-misses ./ex1
 Performance counter stats for './ex1':
           1244933      cache-misses
       2.440078626 seconds time elapsed
       2.123245000 seconds user
       0.275689000 seconds sys
```
#table(
  columns: (2fr, 1fr, 1fr, 2fr),
  stroke: 0.5pt,
  inset: 4pt,

  table.header(
    [*Compteur*],
    [*Avant*],
    [*Après*],
    [*Amélioration*],
  ),

  [Temps d'exécution], [42.0 s], [2.4 s], [~17× plus rapide],
  [insn per cycle], [0.05], [0.70], [14× meilleur],
  [task-clock], [41 986 ms], [2 409 ms], [~17× moins de CPU],
  [Instructions], [1.67 Mrd], [1.38 Mrd], [similaire],
  [Fréquence effective], [0.816 GHz], [0.816 GHz], [inchangée],
)
Le nombre d'instructions est quasi identique, donc le programme fait le même travail, mais 17x plus vite.
Le nombre de cache-misses est maintenant bien plus faible.

#thinkbox()[Relevez les valeurs du compteur L1-dcache-load-misses pour les deux versions de l’application. Quel facteur constatez-vous entre les deux valeurs ?
`# perf stat -e L1-dcache-load-misses ./ex1`]
#table(
  columns: (1fr, 1fr),
  stroke: 0.5pt,
  inset: 4pt,

  [*Version initiale*], [*Version corrigée*],

  [
```
# perf stat -e L1-dcache-load-misses ./ex1
 Performance counter stats for './ex1':
         406972967      L1-dcache-load-misses                                       
      40.687446478 seconds time elapsed
      39.986415000 seconds user
       0.288499000 seconds sys
```
],

[
```
# perf stat -e L1-dcache-load-misses ./ex1
 Performance counter stats for './ex1':
           1297820      L1-dcache-load-misses
       2.431259751 seconds time elapsed
       2.186329000 seconds user
       0.209635000 seconds sys
```
],
)
La version corrigée génère environ 300 fois moins de miss L1 que la version initiale. C'est la preuve que l'erreur était un problème de localité mémoire: le CPU devait aller chercher les données hors du cache L1 à presque chaque accès dans la version originale.

#thinkbox()[Décrivez brièvement ce que sont les évènements suivants :]
 *instructions* : nombre total d'instructions exécutées par le processeur. Cet indicateur donne une idée de la quantité de travail réellement effectuée par le programme. Il est souvent comparé au nombre de cycles pour calculer l'IPC (Instructions Per Cycle).

- *cache-misses* : nombre d'accès mémoire qui n'ont pas trouvé les données dans le cache du processeur. Le CPU doit alors récupérer les données depuis un niveau de cache inférieur (L2, L3) ou directement depuis la RAM, ce qui augmente fortement le temps d'exécution.

- *branch-misses* : nombre d'erreurs de prédiction des branchements conditionnels (`if`, boucles, etc.). Les instructions dans le pipeline sont remplies en avance pour améliorer les performances. Lorsque le processeur prédit mal le chemin à suivre, il doit vider une partie du pipeline puis recommencer l'exécution, ce qui réduit les performances.

- *L1-dcache-load-misses* : nombre d'échecs lors des lectures dans le cache de données L1. Le cache L1 est le cache le plus rapide.

- *cpu-migrations* : nombre de fois où le système d'exploitation déplace un processus ou un thread d'un oeur CPU à un autre. Trop de migrations peuvent diminuer les performances car les caches doivent être reconstruits sur le nouveau cœur.

- *context-switches* : nombre de changements de contexte entre processus ou threads. Lorsqu'un changement a lieu, le système sauvegarde l'état courant puis charge celui d'une autre tâche. Un nombre élevé indique souvent beaucoup de multitâche ou d'attente sur des ressources par exemple.


#thinkbox()[Lors de la présentation de l’outil perf, on a vu que celui-ci permettait de profiler une application avec très peu d’impacts sur les performances. En utilisant la commande time, mesurez le temps d’exécution de notre application ex1 avec et sans la commande perf stat.]
#table(
  columns: (1fr, 1fr),
  stroke: 0.5pt,
  inset: 4pt,
  [
```
# time perf stat ./ex1
...
real	0m 3.09s
user	0m 2.18s
sys	0m 0.28s

```
],

[
```
# time ./ex1
real	0m 2.41s
user	0m 2.17s
sys	0m 0.20s
```
],
)
On observe une augmentation du temps d’exécution réel lors de l’utilisation de `perf stat` (2.41 s contre 3.09 s). Le temps utilisateur reste pratiquement identique (2.17 s contre 2.18 s), ce qui indique que le comportement du code applicatif est peu modifié. 
En revanche, le temps système augmente légèrement (0.20 s contre 0.28 s), ce qui met en évidence le surcoût introduit par le profilage et la collecte des compteurs de performance.

== Exercice 02
=== Analyse du code source
Le programme génère un tableau de valeurs aléatoires entre 0 et 511 puis additionne 10'000 fois toutes les valeurs supérieures ou égales à 256.

=== Mesure du temps d’exécution
Nous mesurons plusieurs fois mais les mesures sont stables à 0.01 secondes près.
```
# time ./ex2 
sum=125454290000
real	0m 26.19s
user	0m 26.11s
sys	0m 0.00s
```
=== Optimisation
Après optimisation, les mesures de temps sont également stables. Nous observons une diminution du temps d'execution d'environ 3 secondes.
```
# time ./ex2 
sum=125454290000
real	0m 23.44s
user	0m 23.38s
sys	0m 0.00s
```
=== Mesures
#thinkbox()[À l’aide de l’outil perf et de sa sous-commande stat, en utilisant différents compteurs déterminez pourquoi le programme modifié s’exécute plus rapidement.]

*Version non optimisée*
```
# perf stat ./ex2
sum=125454290000

 Performance counter stats for './ex2':

          26381.05 msec task-clock                #    1.000 CPUs utilized          
                17      context-switches          #    0.644 /sec                   
                 0      cpu-migrations            #    0.000 /sec                   
                76      page-faults               #    2.881 /sec                   
       21526819053      cycles                    #    0.816 GHz                    
       14768926903      instructions              #    0.69  insn per cycle         
         988575602      branches                  #   37.473 M/sec                  
         327856920      branch-misses             #   33.16% of all branches        

      26.392412804 seconds time elapsed

      26.325403000 seconds user
       0.003968000 seconds sys
```
*Version optimisée*
```
# perf stat ./ex2
sum=125454290000

 Performance counter stats for './ex2':

          23436.26 msec task-clock                #    0.999 CPUs utilized          
               133      context-switches          #    5.675 /sec                   
                 0      cpu-migrations            #    0.000 /sec                   
               107      page-faults               #    4.566 /sec                   
       19123431577      cycles                    #    0.816 GHz                    
       14819330753      instructions              #    0.77  insn per cycle         
         997994235      branches                  #   42.583 M/sec                  
            873488      branch-misses             #    0.09% of all branches        

      23.457655803 seconds time elapsed

      23.389797000 seconds user
       0.000000000 seconds sys
```

L'outil `perf` montre que le nombre de branch-misses a fortement diminué. Avant le tri, le test `if (data[i] >= 256)` est appliqué sur des valeurs aléatoires, le résultat alterne donc fréquemment entre vrai et faux. Le prédicteur de branchement du processeur ne peut alors pas anticiper correctement l'exécution et doit régulièrement vider une partie du pipeline.

Après le tri du tableau, le branchement devient plus prévisible : il reste faux pendant une longue période puis devient vrai. Le prédicteur apprend rapidement ce comportement et les erreurs deviennent rares.

Malgré le coût du qsort(), le tri n'est effectué qu'une seule fois alors que la boucle est répétée 10'000 fois, ce qui explique la diminution du temps d'exécution.

== Parsing de logs apache
#thinkbox()[
Avec les instructions précédentes, déterminez quelle fonction de notre application fait (indirectement) appel à `std::operator==<char>`.]

L'option `--no-children` de la commande `perf report --no-children --demangle` masque une partie des informations hiérarchiques. En utilisant la commande `perf report -g graph --demangle` , nous pouvons développer la hierarchie avec `+`
En remontant la callchain dans `perf report`, on observe que `std::operator==<char>` est appelée indirectement depuis `HostCounter::isNewHost()`. Cette fonction utilise `std::find()` pour vérifier si un hôte est déjà présent, ce qui entraîne de nombreuses comparaisons de chaînes. 

=== Optimisation algorithmique
La solution proposée dans le codelab remplace le `std::vector` par un `std::set`. La recherche passe de O(n) à O(log(n)) mais l'insertion est un peu plus lente en passant de O(1) à O(log n) car `set` permet une recherche dans un arbre structuré.

L'amélioration est drastique, on passe de plus de 2 minutes d'execution à un peu plus de 2 secondes.
```
# time ./read-apache-logs access_log_NASA_Jul95_samples
Processing log file access_log_NASA_Jul95_samples
Found 14867 unique Hosts/IPs
real	2m 15.70s
user	2m 14.59s
sys	0m 0.10s
# time ./read-apache-logs-opt  access_log_NASA_Jul95_samples
Processing log file access_log_NASA_Jul95_samples
Found 14867 unique Hosts/IPs
real	0m 2.27s
user	0m 1.39s
sys	0m 0.10s
```
Plutôt que d'utiliser un `set`, nous améliorons encore les performances avec un `unordered_set`: il permet des recherches et insertions en O(1) moyen grâce à une table de hachage, contrairement à O(log n) pour un arbre équilibré.
Puisque le gain est moins remarquable, nous utilisons un script (`tempsmoyen.sh`) pour mesurer la moyenne de temps d'execution (hyperfine n'étant pas disponible sur notre cible). Cette dernière modification nous permet de passer de 2.273 secondes en moyenne à 2.225 secondes sur le fichier `access_log_NASA_Jul95_samples` et sur le fichier `access_log_NASA_Jul95` de 18.194 secondes à 18 secondes.

Finalement, en ajoutant encore 2 optimisations (éviter la copie de `std::string hostname` et profiter de la propriété de `insert` qui n'insère un élement que si il n'est pas présent), nous descendons à une moyenne de 17.996 secondes pour le fichier `access_log_NASA_Jul95`.

== Mesure de la latence et de la gigue (jitter)
#thinkbox()[Décrivez comment devrait-on procéder pour mesurer la latence et la gigue d’interruption, ceci aussi bien au niveau du noyau (kernel space) que de l’application (user space).]

Pour mesurer la latence et la gigue d'une interruption au niveau du noyau, on peut utiliser un GPIO qui changera d'état au moment de la requète d'interruption. Il faut activer une interruption sur un GPIO et activer un autre GPIO pour mesurer le temps entre les deux signaux grâce à un oscilloscope ou un analyseur logique. La latence correspond au temps entre le signal de requête et le signal d'éxecution de l'interruption, tandis que la gigue correspond à la variation de cette latence sur plusieurs interruptions.

Pour les mesurer au niveau de l'application, nous ne pouvons pas utiliser la technique d'écrire dans `/sys/class/gpio/...` pour faire du toggling de GPIO, car cela introduit une latence supplémentaire due à l'accès au système de fichiers. En revanche il est possible d'utiliser la méthode `mmap()` pour accéder directement aux registres du GPIO, ce qui permet de réduire la latence et d'obtenir des mesures plus précises. En utilisant `mmap()`, l'application peut directement contrôler les GPIOs sans passer par le système de fichiers, ce qui minimise les délais et permet de mesurer la latence et la gigue de manière plus précise.


== Synthèse sur ce qui a été appris/exercé
Lors de ce laboratoire, nous utilisons différents outils d’analyse de performances sous Linux, principalement `perf`, afin de mesurer et d’identifier les causes de ralentissement dans plusieurs applications.

Dans le premier exercice, nous mettons en évidence l’impact de la localité mémoire et de l’utilisation du cache processeur. L’analyse des compteurs de performance permet d’identifier un parcours mémoire inefficace provoquant un nombre élevé de *cache-misses*. 

Le second exercice permet d’étudier l’impact de la prédiction de branchement du processeur. Nous observons qu’une simple réorganisation des données réduit fortement le nombre de *branch-misses* et améliore le temps d’exécution.

La partie consacrée au parsing des logs Apache met en évidence l’importance des choix algorithmiques et des structures de données. Le remplacement d’une recherche linéaire par des structures adaptées (`set`, puis `unordered_set`) permet une réduction importante du temps d’exécution.

== Remarques et choses à retenir
Les compteurs matériels accessibles via `perf` permettent d’identifier plus précisément les causes d’un ralentissement, notamment les défauts de cache, les erreurs de prédiction de branchement ou les changements de contexte.

La manière de programmer, que ce soit pour le choix des structures de donnée, ou l'ordre d'accès aux données, a une enorme importance sur les performances.
L’utilisation de `perf` introduit une légère surcharge d’exécution, mais peut sans autre être utilisée pour identifier les causes de lenteur dans l'execution d'une application.

== Feedback personnel sur le laboratoire
Comme précédemment, le fait d’optimiser un code existant est particulièrement intéressant et gratifiant, car cela permet de mieux visualiser l’impact que peuvent avoir des choix inadaptés de structures de données, d’algorithmes ou d’accès mémoire sur les performances globales d’une application.

Au début du laboratoire, il est indiqué qu’il est nécessaire d’ajouter plusieurs paquets dans Buildroot. Toutefois, une partie des options requises est déjà activée par défaut et la commande `perf list` ne nous a pas permis d’identifier l’absence de l’option `BR2_PACKAGE_BINUTILS_TARGET`. Ce point n’a été constaté qu’au moment de l’utilisation de `perf report`, qui nécessite la présence de l’outil `addr2line`.
Afin de faciliter la procédure et d’éviter cette ambiguïté, il pourrait être interessant d’ajouter dans le codelab une étape de vérification de la disponibilité de `addr2line` avant l’utilisation des outils perf.

