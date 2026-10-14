---
name: livrer
description: Livre la branche feat/… courante — push des commits tels quels, PR créée ou mise à jour ; avec l'argument « squash », squash en un commit (ou un par pan fonctionnel métier si la PR est volumineuse) avant le push ; avec « merge », squash puis merge en rebase, suivi du déploiement, nettoyage et mémoire. Invoqué par /livrer [squash] [merge].
disable-model-invocation: true
argument-hint: "[squash] [merge]"
---

# Livrer

Raccourci des étapes 8 à 13 du skill `developper-une-feature`, qui reste la référence (règles, signaux d'alarme).
L'invocation de `/livrer` vaut demande explicite de pousser et d'ouvrir la PR. Arguments combinables, dans n'importe
quel ordre : `squash` vaut demande de réécrire l'historique (étape 1), `merge` vaut demande de merger (étapes 4 à 6)
et implique `squash`, car c'est le merge qui impose l'historique final. Sans `squash` ni `merge`, ne jamais squasher ni
réécrire les commits : une PR peut porter plusieurs commits ; un historique désordonné se signale au plus dans le rapport.

## Préconditions (s'arrêter et le dire si l'une manque)

- Branche courante `feat/…` (ou `fix/…`, `docs/…`), jamais `main`.
- Arbre de travail propre, ou modifications en cours à intégrer : les lister et demander avant de les commiter.
- Vérification au vert dans cette session (tests + analyse statique, commande du CLAUDE.md du projet) ; sinon la
  lancer et lire la sortie. Rouge → on ne livre pas.

## Étapes

1. **Squash** (`squash` ou `merge` ; sinon passer au push) — `git fetch origin main`, noter le SHA de départ (retour
   possible par `git reset --hard <sha>`), puis repartir de `origin/main` :
   `git reset --soft $(git merge-base HEAD origin/main)`. Rebaser sur `origin/main` si la branche est en retard. Messages dans la langue et au format de `CONTRIBUTING.md` (attribution du system-reminder).
   - **PR de taille normale** : un seul commit qui résume la feature.
   - **PR volumineuse** (plus de ~30-40 fichiers modifiés hors fichiers générés) : un commit par pan fonctionnel
     métier, chacun avec son code, ses tests et sa doc. Ordre de dépendance, pas de commit « correctifs de review ».
     Chaque commit doit compiler : lancer la vérification au moins sur le dernier, compiler les intermédiaires (`git rebase --exec '<build>' origin/main`).
     Vérifier que l'arbre final est identique à celui du SHA de départ (`git diff <sha>` vide). Lister le découpage
     dans le rapport.
2. **Push** — avec le compte gh indiqué par la mémoire du projet (jeton ponctuel, sans changer le compte actif).
   Sans squash : `push` simple. Après un squash d'une branche déjà poussée :
   `push --force-with-lease=<branche>:<sha distant attendu>`, jamais `--force` seul.
3. **PR** — aucune PR ouverte pour la branche : `gh pr create` (titre = sujet du commit ou de la feature, description fonctionnelle
   en français). PR existante : mettre à jour la description si le périmètre a changé. Donner le lien.

Sans l'argument `merge`, s'arrêter ici et rapporter : commit(s), lien de la PR, ce qui reste (recette, review). Terminer par
ce rappel, mot pour mot : « Recette : `/clear`, puis « recette de la PR #N » avec tous les retours en un message — liste
numérotée écran + élément + observé + attendu + périmètre, règle générale plutôt que cas. »

4. **Merge** (`merge` seulement) — CI de la PR au vert s'il y en a une (`gh pr checks --watch`), puis `gh pr merge --rebase`,
   jamais `--merge`. Dépôt avec un `Jenkinsfile` à la racine : le statut `continuous-integration/jenkins/pr-head` n'apparaît
   qu'une fois le build lancé, et rien côté GitHub n'empêche de merger sans lui. Ne merger que lorsqu'il est `SUCCESS` sur le
   SHA poussé (`gh pr view --json headRefOid,statusCheckRollup`). Absent ou `PENDING` : attendre et revérifier toutes
   les quelques minutes, sans timeout plus court que celui du `Jenkinsfile`. `FAILURE`/`ERROR`, ou toujours absent après
   ~15 min : ne pas merger, rapporter avec le lien Jenkins (`targetUrl`). Si un push sur main déploie : suivre le run (`gh run watch`) jusqu'au succès ou à l'échec, et
   le rapporter.
5. **Nettoyage** — `git switch main && git pull --ff-only` ; supprimer la branche locale (et son worktree) après
   avoir vérifié que main contient son contenu ; supprimer la branche distante si le dépôt ne le fait pas au merge.
6. **Mémoire** — mettre à jour la mémoire du projet : PR, SHA de merge, déploiement, ce qui reste à faire.

## Rapport final

Une ligne par étape faite (SHA, lien de PR, état du déploiement) et ce qui n'a pas été fait, avec la raison.
