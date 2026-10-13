---
name: livrer
description: Livre la branche feat/… courante — squash en un commit, push, PR créée ou mise à jour ; avec l'argument « merge », merge en rebase, suivi du déploiement, nettoyage et mémoire. Invoqué par /livrer [merge].
disable-model-invocation: true
argument-hint: "[merge]"
---

# Livrer

Raccourci des étapes 8 à 13 du skill `developper-une-feature`, qui reste la référence (règles, signaux d'alarme).
L'invocation de `/livrer` vaut demande explicite de pousser et d'ouvrir la PR ; `/livrer merge` vaut aussi demande
de merger.

## Préconditions (s'arrêter et le dire si l'une manque)

- Branche courante `feat/…` (ou `fix/…`, `docs/…`), jamais `main`.
- Arbre de travail propre, ou modifications en cours à intégrer : les lister et demander avant de les commiter.
- Vérification au vert dans cette session (tests + analyse statique, commande du CLAUDE.md du projet) ; sinon la
  lancer et lire la sortie. Rouge → on ne livre pas.

## Étapes

1. **Squash** — `git fetch origin main`, puis un seul commit au-dessus de `origin/main` :
   `git reset --soft $(git merge-base HEAD origin/main)` et commit au format de `CONTRIBUTING.md` (message qui résume
   la feature, en français, attribution du system-reminder). Rebaser sur `origin/main` si la branche est en retard.
2. **Push** — avec le compte gh indiqué par la mémoire du projet (jeton ponctuel, sans changer le compte actif).
   Branche déjà poussée : `push --force-with-lease=<branche>:<sha distant attendu>`, jamais `--force` seul.
3. **PR** — aucune PR ouverte pour la branche : `gh pr create` (titre = sujet du commit, description fonctionnelle
   en français). PR existante : mettre à jour la description si le périmètre a changé. Donner le lien.

Sans l'argument `merge`, s'arrêter ici et rapporter : commit, lien de la PR, ce qui reste (recette, review).

4. **Merge** (`/livrer merge` seulement) — CI de la PR au vert s'il y en a une (`gh pr checks --watch`), puis `gh pr merge --rebase`,
   jamais `--merge`. Si un push sur main déploie : suivre le run (`gh run watch`) jusqu'au succès ou à l'échec, et
   le rapporter.
5. **Nettoyage** — `git switch main && git pull --ff-only` ; supprimer la branche locale (et son worktree) après
   avoir vérifié que main contient son contenu ; supprimer la branche distante si le dépôt ne le fait pas au merge.
6. **Mémoire** — mettre à jour la mémoire du projet : PR, SHA de merge, déploiement, ce qui reste à faire.

## Rapport final

Une ligne par étape faite (SHA, lien de PR, état du déploiement) et ce qui n'a pas été fait, avec la raison.
