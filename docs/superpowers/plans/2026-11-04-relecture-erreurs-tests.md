# Relecture : erreurs avalées et tests absents — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `/pr review`, la review finale de `/feature` et la review Opus de `/bugfix` cherchent les erreurs avalées
et les tests absents, sans brancher `pr-review-toolkit`.

**Architecture:** seul du texte de skill change : deux règles et leurs gravités dans la consigne fixe de l'étape 2
de `/pr review`, puis une phrase de renvoi dans l'étape 7 de `feature` et l'étape 8 de `bugfix`.

**Tech Stack:** Markdown (skills Claude Code), `bash tests/run.sh`.

**Spec:** `docs/superpowers/specs/2026-11-04-relecture-erreurs-tests-design.md`

## Découpage en PR

3 fichiers touchés hors spec et plan (`global/skills/pr/SKILL.md`, `global/skills/feature/SKILL.md`,
`global/skills/bugfix/SKILL.md`) : **une seule PR**, story unique P1.

## Table de traçabilité

| Exigence (spec) | Tâche | Preuve |
|---|---|---|
| §2 décision : plugin non branché, `settings/base.json` et `global/profiles.json` inchangés | — | `git diff main --stat` ne cite aucun des deux |
| §2 règle « erreur avalée » + sa gravité | 1 | `grep` tâche 1 ; recette cas 1, 5 |
| §2 règle « test absent » + ses gravités | 1 | `grep` tâche 1 ; recette cas 2, 3, 7, 9 |
| §2 termes « correctif de bug », « projet sans suite de tests » | 1 | `grep` tâche 1 ; recette cas 3, 7, 9 |
| §2 même ligne erreur avalée + sans test | 1 | recette cas 8 |
| §2 règles hors grille, valables avec une grille du projet | 1 | recette cas 6 |
| §2 règle « reviews finales » : phrase dans l'étape 7 de `feature` | 2 | `grep` tâche 2 ; recette cas 10 |
| §2 règle « reviews finales » : même phrase dans l'étape 8 de `bugfix` | 2 | `grep` tâche 2 ; recette cas 10 |
| §2 grille qualité de `feature` inchangée | 2 | `git diff main -- global/skills/feature/SKILL.md` ne touche que la ligne de l'étape 7 |
| §4 cas 1 à 10 | 3 | `recette.md` |
| §5 filet : rien à caractériser | — | — |

Usages vérifiés à l'étape 1b :

| Fichier | Usages trouvés | Ce qu'ils deviennent |
|---|---|---|
| `global/skills/pr/SKILL.md:287-292` | seule occurrence de « Bugs et sécurité d'abord » ; étapes 1, 3-5 de `review` lisent le JSON de l'étape 2 | format JSON inchangé, étapes 1, 3-5 inchangées |
| `global/skills/feature/SKILL.md:28` | étape 7 ; `sdd-final-reviewer` n'est défini dans aucun projet de ce dépôt | reçoit la phrase |
| `global/skills/bugfix/SKILL.md:36` | étape 8, renvoie à la grille de `feature` seulement | reçoit la phrase |
| `docs/domaine.md` | « Erreur avalée », « Test absent », « Agent spécialisé » à jour ; « Correctif de bug » et « Projet sans suite de tests » manquent | les deux termes ajoutés par la tâche 1 |

## Global Constraints

- Texte en français, termes du glossaire « Relecture de PR » (`docs/domaine.md`) : « agent de relecture », « review
  publiée », « erreur avalée », « test absent ». Pas de « reviewer Opus » pour `/pr review`.
- Gravités écrites comme dans l'étape 2 actuelle : bloquant, non-bloquant, question.
- Ne pas toucher à la section « Grille qualité » de `feature`, ni à `settings/base.json`, ni à `global/profiles.json`.

## Review Focus

- Un `2>/dev/null` sur une sonde dont l'échec est attendu et traité ne doit pas devenir une remarque (cas 5) : la
  formulation « dont l'échec compte » doit rester dans la règle.
- Un projet avec sa propre grille garde les deux règles : elles sont hors de la phrase « Grille, à recopier… », pas
  dedans (cas 6).
- Correctif de bug dans un projet sans tests : **question** l'emporte sur bloquant ; la règle doit le dire en toutes
  lettres (cas 9).

---

### Lot parallélisable : tâches 1 et 2

Fichiers disjoints, aucune dépendance. Tâche 1 : `global/skills/pr/SKILL.md`, `docs/domaine.md`. Tâche 2 :
`global/skills/feature/SKILL.md`, `global/skills/bugfix/SKILL.md`.

### Tâche 1 : règles dans la consigne de `/pr review` (spec §2 « Règle : la relecture cherche… »)

**Files:**
- Modify: `global/skills/pr/SKILL.md:287-292` (étape 2 de `### \`review\``)
- Modify: `docs/domaine.md` (contexte « Relecture de PR »)

- [ ] **Step 1 : constater le rouge**

```bash
grep -c "Erreur avalée" global/skills/pr/SKILL.md
grep -c "Projet sans suite de tests" global/skills/pr/SKILL.md
```

Attendu : `0` deux fois.

- [ ] **Step 2 : insérer les règles**

Dans `global/skills/pr/SKILL.md`, juste après la phrase « Pas de remarque de goût sans règle du projet derrière. »
et avant « L'agent rend une liste JSON », couper la ligne et insérer, indenté de trois espaces comme l'étape :

```markdown
   Quelle que soit la grille, deux règles s'appliquent toujours :
   - **Erreur avalée** (nature `bug`) : `catch` vide ou trop large, erreur journalisée puis ignorée, repli silencieux
     qui masque un échec (valeur par défaut, `|| true`, `2>/dev/null` sur une commande dont l'échec compte).
     Bloquant si l'échec perd ou corrompt des données, non-bloquant sinon.
   - **Test absent** (nature `test`) : code de production modifié qui porte une règle (branche, boucle, calcul,
     parseur) sans test qui l'exerce, ni dans la PR ni dans les tests existants. Non-bloquant ; bloquant pour le test
     de non-régression du défaut corrigé, absent d'un correctif de bug (branche `fix/…`, commit `fix` ou 🐛, issue de
     bug liée) sans vérification manuelle décrite dans la PR ou le rapport (décrite : question), les autres tests
     absents du correctif restant non-bloquants ; question dans un projet sans suite de
     tests (ni fichier de test : dossier de tests, `*.test.*`, `*.spec.*` ; ni commande de test dans le CLAUDE.md,
     l'AGENTS.md, le README, le `package.json` ou le Makefile), correctif de bug compris.

   Une ligne qui relève des deux règles donne une seule remarque `bug`, qui cite le test manquant, avec la plus
   forte des deux gravités (bloquant > non-bloquant > question).

   L'agent rend une liste JSON, sans rien publier :
```

La suite de l'étape (format JSON, natures, gravités) reste telle quelle.

Dans `docs/domaine.md`, tableau du contexte « Relecture de PR », ajouter après la ligne « Test absent » :

```markdown
| Correctif de bug | PR qui corrige un défaut : branche `fix/…`, commit `fix` ou 🐛, ou issue de bug liée | `fix/…`, 🐛 | hotfix |
| Projet sans suite de tests | Projet sans dossier de tests ni commande de test dans CLAUDE.md, AGENTS.md ou README | — | projet non testé |
```

- [ ] **Step 3 : constater le vert**

```bash
grep -c "Erreur avalée" global/skills/pr/SKILL.md
grep -c "Projet sans suite de tests\|projet sans suite de tests" global/skills/pr/SKILL.md
bash tests/run.sh
```

Attendu : `1` deux fois ; `tests/run.sh` au vert.

- [ ] **Step 4 : commit**

```bash
git add global/skills/pr/SKILL.md docs/domaine.md
git commit -m "✨ pr: Look for swallowed errors and missing tests in review"
```

### Tâche 2 : renvoi dans les reviews finales de `feature` et `bugfix` (spec §2 « Règle : les reviews finales… »)

**Files:**
- Modify: `global/skills/feature/SKILL.md:28` (ligne `| 7 | Reviews |`)
- Modify: `global/skills/bugfix/SKILL.md:36` (ligne `| 8 | Review |`)

- [ ] **Step 1 : constater le rouge**

```bash
grep -c "erreurs avalées" global/skills/feature/SKILL.md global/skills/bugfix/SKILL.md
```

Attendu : `0` pour chacun.

Décision (Plannotator) : dans `final-review.md`, bloquant devient I (C si l'échec perd ou corrompt des données),
non-bloquant devient M, question devient un M rédigé en question. La spec §2 est amendée en ce sens.

- [ ] **Step 2 : `feature`, étape 7**

Dans la ligne `| 7 | Reviews |`, juste après « puis applique la grille qualité. », insérer :

```markdown
 Grille du projet ou non, elle cherche aussi les erreurs avalées et les tests absents, avec les règles de `/pr review` (skill `pr`, § `review`, étape 2) ; ses gravités deviennent I pour bloquant (C si l'échec perd ou corrompt des données), M pour non-bloquant, M rédigé en question pour question.
```

La section « Grille qualité » ne change pas.

- [ ] **Step 3 : `bugfix`, étape 8**

Dans la ligne `| 8 | Review |`, juste après « en parallèle. », insérer :

```markdown
 Grille du projet ou non, la review Opus cherche aussi les erreurs avalées et les tests absents, avec les règles de `/pr review` (skill `pr`, § `review`, étape 2) ; ses gravités deviennent I pour bloquant (C si l'échec perd ou corrompt des données), M pour non-bloquant, M rédigé en question pour question.
```

- [ ] **Step 4 : constater le vert**

```bash
grep -c "erreurs avalées" global/skills/feature/SKILL.md global/skills/bugfix/SKILL.md
git diff main -- global/skills/feature/SKILL.md | grep -c '^[-+][^-+]'
bash tests/run.sh
```

Attendu : `1` pour chacun ; `2` lignes changées dans `feature` (l'ancienne et la nouvelle ligne 28) ;
`tests/run.sh` au vert.

- [ ] **Step 5 : commit**

```bash
git add global/skills/feature/SKILL.md global/skills/bugfix/SKILL.md
git commit -m "✨ skills: Make final reviews look for swallowed errors and missing tests"
```

### Tâche 3 : recette sur bacs à sable (spec §4, « Vérification »)

Faite par la session (étape 6 du cycle), pas par un implémenteur : elle juge le comportement de l'agent de relecture.
Après les tâches 1 et 2.

**Files:**
- Create: `.superpowers/sdd/pr-review-erreurs-tests/recette.md`
- Bacs à sable dans le scratchpad de la session, hors du dépôt.

- [ ] **Step 1 : préparer les trois bacs à sable**

Chacun : `git init`, un commit sur `main`, puis une branche avec le diff du cas.

| Bac | Contenu de `main` | Branches |
|---|---|---|
| A | `lib/sync.sh`, `tests/test_sync.sh`, `CLAUDE.md` qui cite `bash tests/run.sh` | `feat/cas1` : `cp "$src" "$dst" 2>/dev/null \|\| true` dans une copie de sauvegarde ; `feat/cas2` : nouvelle branche de calcul sans test ; `fix/cas3` : correctif sans test ; `feat/cas4` : README seul ; `feat/cas5` : `command -v jq 2>/dev/null \|\| repli` ; `feat/cas8` : même ligne que cas 1, dans une fonction nouvelle sans test |
| B | comme A, plus `AGENTS.md` avec une grille propre (deux règles de style) | `feat/cas6` : même diff que `feat/cas1` |
| C | `lib/sync.sh` seul, aucun test, aucune commande de test | `feat/cas7` : branche de calcul sans test ; `fix/cas9` : correctif sans test |

- [ ] **Step 2 : lancer l'agent de relecture par cas**

Un agent `general-purpose`, modèle `opus` passé explicitement, par branche, avec le brief des étapes 1 et 2 de
`global/skills/pr/SKILL.md` (sans n° de PR : diff `git diff main...HEAD` dans le bac à sable), sans rien publier.
Les cas d'un même bac partent dans un même message.

- [ ] **Step 3 : cas 10**

Lancer un agent `general-purpose`, modèle `opus`, avec la consigne de l'étape 7 de `feature` (review finale) sur
`feat/cas6` du bac B ; attendu : le point d'erreur avalée figure dans sa sortie, classé selon la correspondance de
la tâche 2. Lancer aussi un agent `general-purpose`, modèle `opus`, avec la consigne de l'étape 8 de `bugfix` sur
`fix/cas3` du bac A ; attendu : le test absent figure dans sa sortie, classé de même.

- [ ] **Step 4 : écrire `recette.md`**

Tableau *cas | attendu (spec §4) | obtenu | ✅/❌*. Un ❌ → amender la formulation de la tâche concernée (retour
étape 4 du cycle pour elle), puis rejouer le cas.

Pas de commit : `.superpowers/` est exclu de git (`.git/info/exclude`), `recette.md` reste local.
