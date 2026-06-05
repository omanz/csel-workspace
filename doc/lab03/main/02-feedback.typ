#import "../metadata.typ": *
#pagebreak()

= Synthèse sur ce qui a été appris/exercé
Ce laboratoire nous a permis d'intégrer dans un projet cohérent les différentes briques vues au cours du semestre : développement d'un module noyau avec timers et sysfs, communication entre le noyau et l'espace utilisateur, gestion de périphériques via _GPIO_, et _IPC_ entre processus.
L'intégration de l'écran OLED a nécessité la modification du _Device Tree_ pour exposer le bus _I2C_ correspondant, illustrant concrètement le lien entre la description matérielle et les interfaces disponibles en espace utilisateur.

= Remarques et choses à retenir
Nous retienderons que la mise en place d'un projet de cette envergure nécessite une bonne organisation. Il est important de bien comprendre les différentes composants du système et de savoir comment ils interagissent entre eux. Nous avons également vu que les choix de conception faits tôt ont des répercussions sur l'ensemble du développement. Par exemple, exposer le mode en chaîne de caractères (`auto`/`manual`) plutôt qu'en entier rend l'interface sysfs plus lisible, mais implique un traitement supplémentaire côté daemon lors de la comparaison des valeurs.

Nous avons également vu que la réutilisation de code et de concepts déjà abordés peut grandement faciliter le développement, tout en renforçant notre compréhension globale du système.

#pagebreak()

= Feedback personnel sur le laboratoire
La principale difficulté rencontrée lors de ce laboratoire a été de savoir par où commencer, bien que l'énoncé permettait déjà d'avoir une idée claire du découpage et des interfaces.

Nous avons commencé par tester l'affichage sur l'écran, car un pilote basique était fourni et il est toujours motivant d'obtenir rapidement un résultat visuel.

Les différents laboratoires réalisés au cours du semestre nous ont fourni des briques pour aborder les différentes composantes du système. Nous avons notamment pu réutiliser plusieurs éléments développés précédemment.

Nous avons particulièrement apprécié le fait que ce laboratoire prenne la forme d'un projet. Il permet de mettre en pratique, dans un contexte concret, des notions abordées séparément durant le semestre. Cet aspect synthétique en fait également un excellent exercice de révision.

La principale limite de ce projet réside dans son positionnement en fin d'année académique. La période est chargée en rendus et en préparations d'examens, ce qui réduit le temps disponible pour approfondir certains aspects techniques. Cela est d'autant plus frustrant que le projet se prête naturellement à de nombreuses améliorations qui n'ont pas pu être explorées dans le temps imparti.

Enfin, la réalisation d'un système complet et fonctionnel constitue un aspect particulièrement satisfaisant de ce laboratoire. Le fait de travailler sur une plateforme matérielle utilisée tout au long du semestre renforce le sentiment d'aboutissement, tandis que l'intégration de l'écran OLED apporte une dimension concrète et visuelle appréciable au résultat final.

En conclusion, ce mini-projet nous a semblé bien dimensionné, englobant plusieurs thèmes abordés en cours et intéressant d'un point de vue technique. Malgré un calendrier exigeant, il constitue une excellente synthèse des compétences développées durant le semestre.