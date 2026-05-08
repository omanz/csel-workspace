# Documentation — Rapports de laboratoire

Ce dossier contient les rapports des laboratoires rédigés avec [Typst](https://typst.app/), en utilisant le template [`hei-synd-report`](https://github.com/omanz/hei-synd-report).

## Structure

```
doc/
├── lib/
│   └── hei-synd-report/     # Template (submodule Git)
├── lab02/
│   ├── report.typ
│   ├── metadata.typ
│   └── tail/
├── labXX/
│   ├── report.typ
│   ├── metadata.typ
│   └── tail/
...
```

## Prérequis

- [Typst](https://typst.app/) installé
- Git

## Initialisation (premier clone)

Le template est inclus comme submodule Git. Après avoir cloné ce repo, initialise le submodule :

```bash
git clone <url-du-repo>
cd <repo>
git submodule update --init --recursive
```

## Générer un rapport

Depuis le dossier du lab concerné :

```bash
cd lab02
typst compile report.typ --root ..
```

Le `--root ..` est nécessaire pour que Typst resolve correctement les chemins absolus vers `/lib/hei-synd-report/`.

Le PDF généré sera `report.pdf` dans le même dossier.

Pour générer le rapport final:

```bash
typst compile report.typ --input type="final" --input lang="fr"
```

## Problèmes de droits
Attention lors de l'import d'image à avoir le bon owner de l'image. si l'image est possedée par root, le rapport ne pourra pas être généré. Dans ce cas, changer le ownser de l'image
sudo chown -R toi:toi ~/Documents/tonpathprefere/labo/csel-workspace/

## Modifier le template

Le template se trouve dans `lib/hei-synd-report/` et est un submodule pointant vers le fork [omanz/hei-synd-report](https://github.com/omanz/hei-synd-report).

Pour le modifier :

```bash
cd lib/hei-synd-report
# ... faire les modifications ...
git add .
git commit -m "description des modifications"
git push
cd ../..
git add lib/hei-synd-report
git commit -m "update submodule template"
git push
```

## Mettre à jour le template

Si des modifications ont été poussées sur le fork du template :

```bash
cd lib/hei-synd-report
git pull
cd ../..
git add lib/hei-synd-report
git commit -m "update template submodule"
git push
```
