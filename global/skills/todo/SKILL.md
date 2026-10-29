---
name: todo
description: Use when the user invokes /todo, or asks to show, list, update, clean up or add to the project's « reste à faire » (reste-à-faire, TODO, reliquats, features restantes), or to check which leftovers recent commits or merged PRs have fixed.
model: sonnet
argument-hint: "[show|sync [depuis <date|sha>]|add <texte>|done <n°…>]"
---

# Todo

Le reste à faire d'un projet vit dans un fichier versionné, qui fait foi. La mémoire de Claude n'est pas une source.
`show` par défaut.

## Trouver le fichier

`git ls-files | grep -iE '(^|/)(reste-a-faire|todo)\.md$'` (la casse varie : `docs/reste-a-faire.md`,
`docs/RESTE-A-FAIRE.md`). Plusieurs → celui de `docs/`, sinon demander. Aucun :

- `show`, `sync`, `done` → le dire et proposer de créer `docs/reste-a-faire.md` ;
- `add` → le créer (`# Reste à faire`, sections `## Features` et `## Corrections`) et le dire.

Suivre les conventions écrites en tête du fichier et celles des lignes voisines : rayer (`~~…~~`) ou retirer une
ligne faite, numérotation, sections, date « Mis à jour le ». Sans convention : rayer et ajouter `(PR #n)`.

## Actions

- **`show`** — les points ouverts (ni rayés, ni cochés `[x]`), groupés par section, numéros d'origine conservés s'il y en a, une
  ligne chacun : titre et résumé. Puis le total. Pas de vérification du code.
- **`sync [depuis <date|sha>]`** — vérifier chaque point ouvert contre le code, puis mettre le fichier à jour.
  1. Mettre à jour `origin/main` : `git fetch origin main` (pas de refspec explicite : avec `fetch.prune`, il supprime
     `origin/main` une fois sur deux). `origin/main` différent de `FETCH_HEAD` (refspec restreint) → travailler sur
     `FETCH_HEAD` à sa place. Point de départ : l'argument (date ou SHA), sinon le SHA du dernier
     commit de `origin/main` qui touche le fichier (`git log -1 --format=%H origin/main -- <fichier>`). Puis les
     commits (`git log <sha>..origin/main`, ou `--since=<date>` pour une date) et les PR mergées après ce commit
     (`gh pr list -R <owner/repo> --state merged --search "merged:>=<date du commit>"`, `<owner/repo>` tiré de
     `git remote get-url origin`).

     Compte : celui de la mémoire du projet, jamais `gh auth switch`. Pour `gh`, `GH_TOKEN=$(gh auth token -u <compte>)` ;
     pour `git`, qui ignore `GH_TOKEN`,
     `git -c credential.helper= -c "credential.helper=!f(){ echo username=<compte>; echo password=$(gh auth token -u <compte>); }; f" fetch …`.
     Toujours en échec → travailler sur le `main` local et le dire dans le rapport. Fichier déjà modifié sans commit
     (`git status --short <fichier>`) → le signaler, et partir de cette version.
  2. Un point est ouvert tant qu'une partie n'est pas rayée ; le verdict porte sur cette partie. Une ligne qui ne fait
     que renvoyer à un autre point (« voir le point 2 des Features ») n'est pas un point. Pour chacun, lire le code
     actuel qu'il cite (`fichier:ligne`, symbole, route), ou chercher ses symboles et son concept (grep) s'il ne cite
     rien ou si la ligne a bougé : un message de commit ne suffit pas. Verdict : **fait** (preuve : SHA ou PR, et le
     code ; corrigé dans l'arbre sans commit → « fait, non commité » avec `fichier:ligne`), **faux positif** (le code
     ou le contexte de l'application montre que ce n'est pas un défaut, dire pourquoi), **ouvert**, **non vérifiable
     ici** (prod, base, appareil), **à trancher**.
  3. Specs et PR mergées depuis le point de départ : leurs « hors périmètre » et reliquats absents du fichier sont des
     ajouts à proposer. Ils sont souvent dans le corps des règles plutôt que dans une section :
     `grep -in "hors périmètre\|reliquat"` sur les specs ajoutées ou modifiées par ces commits. Idem pour les
     `TODO`, `FIXME` et `shortcut:` ajoutés par ces commits (`git diff <sha>..origin/main | grep -E '^\+.*(TODO|FIXME|shortcut:)'`,
     avec une date : `<sha>` = `git rev-list -1 --before=<date> origin/main`), sans doublon avec un point existant.
  4. Appliquer : rayer ou retirer les points **faits** (avec la PR), mettre la date à jour. Ne pas toucher aux autres
     verdicts ni aux ajouts proposés : ils attendent la décision de l'utilisateur.
  5. Rapport : un tableau point → verdict → preuve, puis les décisions attendues.
- **`add <texte>`** — chercher d'abord un doublon. Puis la section qui convient (feature ou correction), au format des
  lignes voisines, avec le numéro suivant.
- **`done <n°…>`** — rayer ou retirer ces points, avec la PR si elle est connue.

## Après une modification

Le fichier reste modifié, sans commit. Sur une branche de feature, il part avec la PR (`/pr push`). Sur `main`, le
dire : ne rien commiter ni pousser sur `main` sans demande.

## Signaux d'alarme

- Déclarer un point fait sur la foi d'un message de commit, sans avoir lu le code.
- Renuméroter : d'autres documents et l'utilisateur citent les numéros (« point 3 », R1 à R15).
- Compléter le fichier de mémoire, ou répondre de mémoire sans relire le fichier.
