# Relecture de PR : erreurs avalées et tests absents

## But

`/pr review` confie la relecture à un seul agent de relecture (Opus), avec la grille du projet. Cette grille porte surtout sur la
structure (SOLID, object calisthenics) : rien ne pousse l'agent à chercher les erreurs avalées ni le code modifié
sans test, deux angles que des agents spécialisés du plugin `pr-review-toolkit` couvrent. La spec décide comment
la relecture les prend en compte, en pesant le coût en jetons.

## 1. Demande initiale

`/feature issue 71`. L'issue 71, « /pr review : brancher pr-review-toolkit ? » :

> **Constat** — `/pr review` (`global/skills/pr/SKILL.md`, section `review`) relit la PR avec un seul agent Opus et
> la grille du projet. Les agents spécialisés du plugin `pr-review-toolkit` ne sont pas utilisés : tests, gestion
> d'erreurs, types, commentaires.
>
> **Impact** — La relecture peut manquer ce que ces agents ciblés trouvent mieux, comme des erreurs avalées ou des
> tests absents.
>
> **Piste** — Décider s'il faut lancer certains agents de `pr-review-toolkit` en parallèle de l'agent Opus et
> fusionner leurs remarques dans la review unique, ou laisser les choses comme elles sont. Il faudra peser le coût
> en jetons.

## 2. Portée

### Ce que les agents du plugin apporteraient

| Agent spécialisé | Déjà couvert par | Apport |
|---|---|---|
| `code-reviewer` | l'agent de relecture | aucun |
| `code-simplifier` | `ponytail:ponytail-review`, `/simplify` | aucun |
| `type-design-analyzer` | grille, points 3, 4 et 9 | faible |
| `comment-analyzer` | nature `doc` | faible |
| `silent-failure-hunter` | rien | réel : erreurs avalées, repli injustifié |
| `pr-test-analyzer` | la nature `test` existe, aucune règle ne la nourrit | réel : code modifié sans test |

Brancher le plugin aurait trois coûts :
- ses agents ne s'appellent par leur type que si le plugin est activé : ses 6 descriptions (« à lancer de façon
  proactive ») et sa commande `/review-pr` entreraient alors dans toutes les sessions, en doublon de la review
  finale de `feature` et de `ponytail-review`. Lire ses `.md` dans le cache casserait à chaque mise à jour (le chemin
  contient la version) ;
- leur sortie est en anglais, en Markdown libre, avec leurs propres sévérités (CRITICAL/HIGH/MEDIUM, notes sur 10) :
  il faudrait la traduire vers `{nature, gravite}` avant la review publiée ;
- chacun relit tout le diff : deux agents de plus multiplient le coût de la relecture par 2 à 3 environ.

Décision : le plugin n'est pas branché. Les deux angles qu'il apportait deviennent deux règles de la consigne de
l'agent de relecture ; `pr-review-toolkit` reste désactivé.

### Règle : la relecture cherche les erreurs avalées et les tests absents

Deux règles s'ajoutent à la consigne fixe de l'étape 2 de `review`, à côté de « Bugs et sécurité d'abord ». Elles
vont dans la consigne fixe, pas dans la grille seule : un projet qui a sa propre grille (`AGENTS.md`…) ne recopie pas
celle de `feature` et les perdrait.

- **Erreur avalée** (nature `bug`) : `catch` vide ou trop large, erreur journalisée puis ignorée, repli silencieux
  qui masque un échec (valeur par défaut, `|| true`, `2>/dev/null` sur une commande dont l'échec compte).
- **Test absent** (nature `test`) : code de production modifié qui porte une règle (branche, boucle, calcul,
  parseur) sans test qui l'exerce dans la PR ni dans les tests existants.

Termes que l'agent doit reconnaître :
- **Correctif de bug** : branche `fix/…`, commit `fix` ou 🐛, ou issue de bug liée à la PR.
- **Projet sans suite de tests** : ni fichier de test (dossier de tests, `*.test.*`, `*.spec.*`) ni commande de test
  dans le CLAUDE.md, l'AGENTS.md, le README, le `package.json` ou le Makefile.

Gravité d'une erreur avalée (règle nouvelle, l'étape 2 n'en définit aucune aujourd'hui) : `**[bloquant]**` si elle
masque un échec qui perd ou corrompt des données, `**[non-bloquant]**` sinon.

Même ligne à la fois erreur avalée et sans test : une seule remarque `bug`, qui cite le test manquant, avec la plus
forte des deux gravités (bloquant > non-bloquant > question).

Gravité d'un test absent : `**[non-bloquant]**` ; `**[bloquant]**` pour le test de non-régression absent d'un
correctif de bug (les autres tests absents du correctif restent `**[non-bloquant]**`) ; `**[question]**` dans un
projet sans suite de tests. Un correctif de bug sans test dans un projet sans suite de tests est une `**[question]**` :
on ne peut pas exiger un test sans suite où le mettre. Même chose pour un correctif dont la PR ou le rapport décrit la
vérification manuelle d'un bug impossible à tester automatiquement (étape 4 de `/bugfix`).

### Règle : les reviews finales de `/feature` et `/bugfix` cherchent aussi ces deux angles

Une phrase dans l'étape 7 de `feature` et la même dans l'étape 8 de `bugfix` : la review Opus cherche aussi les
erreurs avalées et les tests absents, avec les règles de `/pr review` ; dans `final-review.md`, ses gravités
deviennent I pour bloquant (C si l'échec perd ou corrompt des données), M pour non-bloquant, M rédigé en question
pour question. Elle va dans l'étape, hors de la grille
qualité : une ligne de grille se perdrait dans les projets qui ont leur propre grille, et arriverait dans le brief de
l'implémenteur (la grille sert aussi au plan et à l'implémentation). `/bugfix` ne renvoie qu'à la grille de
`feature`, pas à son étape 7 : il lui faut sa propre phrase.

### Lecteurs et écrivains touchés

| Endroit | Devient |
|---|---|
| `global/skills/pr/SKILL.md`, § `review`, étape 2 | reçoit les deux règles, les deux termes et les gravités |
| `global/skills/pr/SKILL.md`, § `review`, étapes 1, 3 à 5 | inchangées : même agent, même format JSON, même review publiée |
| `global/skills/feature/SKILL.md`, étape 7 | reçoit la phrase sur les deux angles |
| `global/skills/feature/SKILL.md`, « Grille qualité » | inchangée |
| `global/skills/bugfix/SKILL.md`, étape 8 | reçoit la même phrase, pour sa review Opus (au-delà de ~50 lignes ou code sensible) |
| `global/skills/pr/SKILL.md`, § `comments` | inchangé : il trie des commentaires reçus, il ne relit pas |
| `global/skills/pr-risk` | inchangé : la criticité n'est pas une relecture de code |
| `settings/base.json` (`pr-review-toolkit` à `false`) | inchangé |
| `global/profiles.json` | inchangé : aucun profil n'active le plugin |
| `docs/domaine.md` | contexte « Relecture de PR » ajouté par `ddd`, avec les termes « Erreur avalée » et « Test absent » ; « Agent spécialisé » marqué non utilisé |

## 3. Données existantes

Aucune donnée : les reviews déjà publiées ne changent pas. Une PR relue avant la livraison n'est pas relue à nouveau.

## 4. Critères d'acceptation

### P1 : la relecture signale les erreurs avalées et les tests absents

Story unique : la demande ne se découpe pas.

Cas nominaux :
1. PR dont un script ajoute `cmd 2>/dev/null || true` sur une commande dont l'échec compte → une remarque 🐛 sur
   cette ligne, qui dit l'échec masqué : `**[bloquant]**` si l'échec perd ou corrompt des données,
   `**[non-bloquant]**` sinon.
2. PR qui ajoute une branche de calcul sans test → une remarque ✅ `**[non-bloquant]**` sur cette ligne.
3. PR de correctif de bug sans test de non-régression ni vérification manuelle décrite → remarque ✅
   `**[bloquant]**` ; vérification manuelle décrite dans la PR ou le rapport → `**[question]**`.

Refus (rien à signaler) :
4. PR seulement documentaire ou de configuration → aucune remarque sur ces deux angles.
5. `2>/dev/null` sur une sonde dont l'échec est attendu et traité (`command -v x 2>/dev/null || repli`) → aucune
   remarque.

Cas combinés :
6. Projet avec sa propre grille (`AGENTS.md`) → les deux règles s'appliquent quand même.
7. Projet sans suite de tests + code modifié sans test → remarque ✅ `**[question]**`, pas un bloquant.
8. Même ligne à la fois erreur avalée et sans test → une seule remarque 🐛, qui cite aussi le test manquant, avec
   la plus forte des deux gravités (bloquant > non-bloquant > question).
9. Correctif de bug sans test dans un projet sans suite de tests → remarque ✅ `**[question]**`.
10. Review finale de `/feature` (et review Opus de `/bugfix`) sur une branche qui avale une erreur → le point
    figure dans `final-review.md`, même dans un projet qui a sa propre grille.

Vérification : l'agent de relecture est lancé avec le brief des étapes 1 et 2 sur une branche de bac à sable, sans
PR ni publication ; on relit le JSON qu'il rend. Trois bacs à sable :
- **A** (dossier `tests/`, pas d'`AGENTS.md`) : cas 1 à 5 et 8 ;
- **B** (un `AGENTS.md` avec sa grille) : cas 6 ;
- **C** (aucun test ni commande de test) : cas 7 et 9.

## 5. Filet sur l'existant

Aucun test ne couvre le texte des skills ; la modification n'est que de la consigne, pas de code. Rien à
caractériser.

## 6. Origine

- Hors périmètre de la spec des profils (`docs/superpowers/specs/2026-11-04-profils-projet-design.md`, §6,
  « à trancher plus tard »), PR #68 ; issue #71.

## 7. Dette du code touché

Aucune : seul du texte de skill change.
