#import "../metadata.typ": *
#pagebreak()

= Outils d'analyse de performance pour Linux
== Validation de l’installation
Contrairement à ce qui est indiqué dans le codelab, la commande `perf list` nous permets de voir que `perf` inclus déja les binutils nécessaires.

== Exercice 01
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