# Jeton de session dans les skills

## But

Les skills `pr`, `notify`, `release`, `todo`, `pr-risk` et `profile` et le `CLAUDE.md` du dépôt passent encore le
compte gh par un jeton ponctuel :

```bash
t=$(gh auth token -u <compte>); [ -n "$t" ] && GH_TOKEN=$t gh …
```

Depuis le plugin `profile`, le jeton de session du compte du profil est exporté pour toute la session et recalculé
après un `cd`. Le préfixe ne fait plus que rallonger chaque appel. Le classifieur refuse aussi les appels
`VAR=$(…) gh`, et une session `EnterWorktree` refuse `VAR=… gh`. Cette spec retire le préfixe et garde un
garde-fou : dans un projet à profil, un skill n'agit jamais sur GitHub avec le compte actif.

## 1. Demande initiale

`/feature issue 140`, après `/bugfix issue 140` arrêté (« règle à changer, plus de ~5 fichiers ») :

> **Constat** : les skills `pr`, `notify`, `release`, `todo`, `pr-risk` et `CLAUDE.md` passent encore le compte gh en
> jeton ponctuel (`t=$(gh auth token -u <compte>); [ -n "$t" ] && GH_TOKEN=$t gh …`). Depuis le plugin `profile`,
> `GH_TOKEN` du compte du profil est exporté pour toute la session (`SessionStart`) et suivi après un `cd`
> (`CwdChanged`).
>
> **Impact** : chaque appel `gh` reste plus long et plus fragile que nécessaire (refus du classifieur sur
> `VAR=$(…) gh`, appels séparés).
>
> **Piste** : une fois le hook éprouvé sur quelques semaines (jeton présent après `/clear`, après un `cd`,
> sous-agents compris), retirer le préfixe des skills et de `CLAUDE.md`, en gardant le test `[ -n "$GH_TOKEN" ]`
> avant les écritures.
>
> **Origine** : hors périmètre de la spec `docs/superpowers/specs/2026-11-17-profile-plugin-design.md` (décision de
> garder le préfixe dans ce lot), PR plugin `profile`.

Le plugin a été mergé le 2026-11-18 : les « quelques semaines » ne sont pas passées. L'utilisateur a lancé
`/feature` en connaissant ce point. Les trois cas de l'issue se vérifient donc dans la recette (R6).

## Constaté le 2026-11-18

- Dans cette session et dans un sous-agent (`ddd`), `GH_TOKEN` est posé et `gh api user` répond `Dahiorus`.
- `git push`, `git fetch` et `git pull` sur un remote HTTPS passent par `gh auth git-credential`, qui lit
  `GH_TOKEN` : ils profitent du jeton de session sans préfixe. Un remote SSH ne le lit pas, comme aujourd'hui.
- Le jeton de session suit un `cd` à l'appel Bash suivant, pas dans la suite de l'appel qui fait le `cd`
  (`cd ../autre && gh …` garde le jeton du dossier de départ).

## Règles

**R1 — Les commandes `gh`, `git push`, `git fetch` et `git pull` des skills partent sans préfixe.** Elles
utilisent le jeton de session. La même phrase remplace la règle du jeton ponctuel dans `pr`, `notify`, `release`,
`todo` et `pr-risk` (en anglais pour `pr-risk`) :

> Le compte gh vient du profil du projet par le jeton de session que le plugin `profile` exporte : les commandes
> `gh`, `git push`, `git fetch` et `git pull` partent sans préfixe. Avant la première d'entre elles, et après tout
> `cd` vers un autre dépôt, lancer `bash ~/.claude/profile.sh require-token` : s'il échoue, rapporter sa sortie et
> s'arrêter. Un `cd` ne change le jeton qu'à l'appel Bash suivant. Projet sans profil : compte actif. Jamais
> `gh auth switch`.

Décision : le test se fait une fois, avant la première commande `gh` ou git distante du skill, et non avant chaque
écriture comme le disait l'issue : il couvre aussi les lectures qui décident d'une écriture (`@me`, `gh api user`
de `pr-risk`, `git fetch` d'un dépôt privé). Il passe par `require-token` (R8) et non par un test écrit dans chaque
skill (review finale, P1 : la forme du test était à deviner, recette cas 6).

**R2 — `pr-risk` sur un dépôt d'un autre propriétaire.** `pr-risk` accepte l'URL d'une PR. Le jeton de session est
celui du dossier courant, pas du dépôt de l'URL.

Décision : rien ne change pour ce cas. Le compte venait déjà du dossier courant ; le défaut existe déjà.

**R3 — Le bloc de publication de `pr-risk` perd sa première ligne.** Le bloc commence aujourd'hui par
`t=$(gh auth token -u <account>); [ -n "$t" ] || exit 1; export GH_TOKEN=$t`. Il devient
`bash ~/.claude/profile.sh require-token || exit 1`, avec ou sans compte (R8 ne vérifie rien hors profil) : la
consigne « Without a profile account, drop the first line » tombe. `ME=$(gh api user …)` reste dans le même bloc.

**R4 — Session `EnterWorktree`.** `pr` (ligne 19) et `pr-risk` (ligne 25) disent que Claude Code refuse le
préfixe `GH_TOKEN=` dans une session `EnterWorktree`. Sans préfixe, ce refus ne vise plus `gh` ni `git push`.
`CLAUDE.md` ligne 9 reste inchangée : elle refuse `VAR=$(…) git/gh` en général, ce qui reste vrai ; son renvoi
depuis la ligne 8 (« hors session `EnterWorktree` (voir ligne suivante) ») tombe avec la réécriture de R5.

Décision : le passage sur le préfixe de jeton est retiré de `pr` et `pr-risk`, le reste des règles `EnterWorktree`
(`git -c`, heredocs, longs `gh api -f body=…`) est gardé. La recette (R6, cas 5) essaie un `git push` en session
`EnterWorktree` avant le push de la branche.

Décision (review finale, M1) : le cas 5 est passé. Dans `pr`, la consigne « `ExitWorktree` avec `action: "keep"`,
puis lancer fetch, pull et push depuis le dépôt principal » tombe : aucune commande de `pr` n'écrit `git -c` ni
`VAR=… git/gh`. La phrase garde le refus de ces deux formes.

**R5 — `CLAUDE.md` et le skill `profile` suivent.**
- `CLAUDE.md` ligne 8 : « Compte gh : `bash ~/.claude/profile.sh account`, porté par le jeton de session du plugin
  `profile` ; `GH_TOKEN` absent dans un projet à profil → `/profile`. » La fin sur `GH_CONFIG_DIR` reste.
- `CLAUDE.md` ligne 7 : « Un compte gh ou un jeton ne s'ajoute pas par hook : les skills le passent dans la
  commande. » devient « Un compte gh ou un jeton ne s'ajoute pas par réécriture de commande. » La phrase suivante
  (seul le plugin `profile` exporte `GH_TOKEN`) reste.
- `CLAUDE.md` ligne 4 : la phrase « Même réponse pour un appel `gh` à jeton ponctuel… lancé avec un autre Bash »
  tombe, plus aucun skill n'écrivant ce jeton.
- `CLAUDE.md` ligne 26 (« Un `GH_TOKEN` vide fait choisir à gh le compte actif ») reste : c'est la raison du test.
- Skill `profile`, « À savoir », premier point : la règle du jeton ponctuel est remplacée par R1. Le diagnostic
  « compte attendu mais `GH_TOKEN` absent » (lignes 39 à 42) reste : c'est là que les skills renvoient.
- `version` de `mods/profile/.claude-plugin/plugin.json` passe de `0.1.1` à `0.1.2`.

**R6 — Recette des trois cas de l'issue**, par un agent neuf et par l'utilisateur pour ce qu'un agent ne peut pas
faire :
1. Sous-agent : `gh api user` répond le compte du profil (fait le 2026-11-18, à rejouer sur le texte final).
2. `cd` vers un dépôt d'un autre profil, puis `gh api user` à l'appel suivant : l'autre compte.
3. `/clear` puis `gh api user` : le compte du profil (utilisateur).
4. `/pr list` et `pr-risk` sans argument sur une PR de ce dépôt, en suivant le skill modifié : aucun préfixe, bon
   compte.
5. Si R4 retire le passage : un `git push` d'une branche jetable en session `EnterWorktree`.
6. `/pr list` après `unset GH_TOKEN` dans le même appel : le skill s'arrête et renvoie à `/profile`, sans `gh`.
7. `/pr list` quand `profile.sh account` échoue (`profiles.json` mal formé, dossier de config jetable) : le skill
   rapporte la sortie et s'arrête.
8. `cd` vers un dépôt d'un autre profil hors des répertoires de travail (annulé par Claude Code), puis `/pr list` :
   `require-token` signale le jeton de l'autre compte, le skill s'arrête sans `gh` (contrôleur, R8).

Le cas 4 joue aussi `todo sync`.

**R7 — Compte non connecté et `GH_TOKEN` du shell.** Quand le compte du profil n'est pas connecté, `session-start`
n'exporte rien. Un `GH_TOKEN` posé par l'utilisateur dans son shell survit alors, et le test de R1 passe.

Décision (révisée en review finale) : R8 compare le compte du jeton au compte du profil, ce qui ferme la limite. Le
point 11 du reste à faire, ajouté pour elle, est rayé.

**R8 — `profile.sh require-token [dossier]`, garde des skills.** Origine : review finale, I1, *régression* de cette
branche, vue par la recette (cas 2) : un `cd` hors des répertoires de travail est annulé par Claude Code après que
le hook `CwdChanged` a posé le jeton du dossier cible. La session garde alors le jeton d'un autre profil, et
`[ -n "$GH_TOKEN" ]` passe. Avec l'ancien préfixe, le jeton était recalculé à chaque commande.

| Situation | Sortie (stderr) | Code |
|---|---|---|
| `account` en échec | sa sortie | 1 |
| Compte vide (projet sans profil) | rien | 0 |
| Compte non vide, `GH_TOKEN` vide | `GH_TOKEN absent pour le compte <compte> : lancer /profile` | 1 |
| `gh api user --jq .login` en échec | `gh api user a échoué : <première ligne>` | 1 |
| Login ≠ compte (casse ignorée) | `jeton de session de <login>, compte attendu <compte> : lancer /profile` | 1 |
| Login = compte | rien | 0 |

Une commande d'API par lancement de skill : coût accepté. `[ -n "$GH_TOKEN" ]` seul ne suffit pas (cas ci-dessus
et R7). Le correctif de `cwd_changed` est écarté : le hook ne voit pas l'annulation du `cd`.

## 2. Portée

| Endroit | Ce qu'il devient |
|---|---|
| `global/skills/pr/SKILL.md` l. 18 | Règle du jeton ponctuel → R1. « Les étapes écrivent `git fetch`… sans ce préfixe : il s'ajoute à chacune » tombe |
| `global/skills/pr/SKILL.md` l. 19 | Selon R4 : « (commandes `gh` à jeton comprises) » retiré ; consigne `ExitWorktree` pour fetch, pull et push retirée (M1) |
| `global/skills/pr/SKILL.md` l. 88 | « sous jeton ponctuel, `@me` = soi » → « sous jeton de session » |
| `global/skills/pr/*.md` (actions) | Inchangés : aucun ne cite le préfixe (grep), ils renvoient à la règle de `SKILL.md` |
| `global/skills/notify/SKILL.md` l. 28 | R1 (sa variante « Pour lire une PR » garde ce début) |
| `global/skills/release/SKILL.md` l. 39 | R1 ; « Projet sans profil et accès refusé → demander quel compte » reste |
| `global/skills/todo/SKILL.md` l. 37 | R1 |
| `global/skills/pr-risk/SKILL.md` l. 20-26 | R1 en anglais ; phrase `EnterWorktree` selon R4 ; R2 |
| `global/skills/pr-risk/SKILL.md` l. 230 | R3 |
| `global/skills/bugfix/SKILL.md` l. 30 et 57 | « avec le jeton du compte du profil » → « avec le compte du profil » (le fetch passe sans préfixe) |
| `global/skills/bugfix/SKILL.md` l. 58 | « L'agent, sans jeton, » faux (les sous-agents voient le jeton de session) : « L'agent » ; la création par `git switch -c` reste (pas de fetch dans un worktree) |
| `global/skills/feature/SKILL.md` | Inchangé : « compte du profil du projet » sans préfixe (grep) |
| `mods/profile/skills/profile/SKILL.md` l. 81-85 | R5 |
| `mods/profile/skills/profile/SKILL.md` l. 39-42 | Diagnostic gardé ; il cite `require-token` (R8) pour le jeton d'un autre compte |
| `mods/profile/.claude-plugin/plugin.json` | `0.1.2` |
| `mods/profile/scripts/profile.sh` | Sous-commande `require-token` (R8), ligne d'usage ; commentaire l. 19 → « les skills comparent le compte au jeton (require-token) » |
| `tests/test_profile.sh`, `tests/helpers.sh` | Un test par ligne du tableau de R8 ; le faux gh répond `api user` d'après `GH_TOKEN` |
| `CLAUDE.md` l. 4, 7, 8 | R5 |
| `CLAUDE.md` l. 9, 26 | Inchangées (R4, R5) |
| `docs/reste-a-faire.md` point 8 | Rayé (#142) |
| `docs/reste-a-faire.md` point 11 | Ajouté pour R7, rayé par R8 |
| Mémoire `gh-account-push.md` (hors dépôt) | Au merge : jeton de session, `git push` sans préfixe ; « Aucun hook ne l'ajoute » retiré |
| `docs/domaine.md` | Fait par `ddd` : jeton de session précisé, « Jeton de session absent », invariant Profils, « Soi » et « Demande de relecture » sous jeton de session. « Jeton ponctuel » reste (statusline). R8 : « Jeton de session absent » devient « Jeton de session refusé » (absent ou d'un autre compte, `require-token`), invariant suivi |
| `docs/reste-a-faire.md` point 6 | Rayé (#140) |
| `global/statusline-gh.sh` | Inchangé : processus à part, sonde plusieurs comptes, garde son jeton ponctuel |
| `tests/test_main_guard_ast.sh` l. 87 | Inchangé : le préfixe y est une entrée du hook, pas une règle |
| `tests/test_skills.sh` | Nouveau test : aucun `t=$(gh auth token` ni `GH_TOKEN=$(gh auth token` dans `global/skills/` ni `mods/profile/skills/` (le diagnostic `[ -n "$(gh auth token -u …)" ]` du skill `profile` reste) ; chacun des cinq skills de R1 cite `profile.sh require-token` |
| `CLAUDE.md` l. 8 | Cite `require-token` (R8) |

## 3. Données existantes

Aucune donnée. Une session ouverte avant l'installation du plugin n'a pas de jeton de session : les skills s'y
arrêtent (R1) et `/profile` dit de relancer la session.

## 4. Critères d'acceptation

Une seule story : la règle change dans tous les skills à la fois.

**P1 — Les skills agissent sur GitHub sans préfixe, jamais avec le compte actif dans un projet à profil.**
- Nominal : projet perso, jeton de session posé → `/pr list`, `pr-risk`, `todo sync` lancent `gh` sans préfixe et
  voient le compte `Dahiorus`.
- Refus : projet à profil, `GH_TOKEN` vide → le skill s'arrête avant toute commande gh ou git distante et renvoie à
  `/profile`.
- Projet sans profil : pas de test, compte actif.
- Combiné : `cd` vers un dépôt vidal et `gh` dans le même appel → la règle dit que le jeton change à l'appel suivant.
- Combiné : projet à profil, jeton d'un autre compte (`GH_TOKEN` hérité du shell, `cd` annulé) → `require-token`
  nomme les deux comptes, le skill s'arrête (R7, R8).
- Refus : `profile.sh account` en échec → sa sortie est rapportée, le skill s'arrête.
- Refus : `gh api user` en échec → `require-token` échoue, le skill s'arrête.
- Aucun préfixe de jeton ponctuel ne reste dans les skills, et les cinq skills de R1 citent `require-token` (test de
  `tests/test_skills.sh`). Chaque ligne du tableau de R8 a son test dans `tests/test_profile.sh`.

## 5. Filet sur l'existant

Les fichiers modifiés sont des textes de skills : aucun test n'en fige le comportement. Le test ajouté à
`tests/test_skills.sh` est écrit d'abord et vu rouge sur l'état actuel (cinq skills et le skill `profile` le
font échouer). La recette (R6) rejoue le comportement réel.

## 6. Origine

- Traité : *hors périmètre* de la spec `2026-11-17-profile-plugin-design.md` (issue #140, point 6 du reste à faire).
- Corrigé en route : `bugfix/SKILL.md` l. 58, *défaut ancien* rendu faux par le plugin `profile` (PR #143).
- Traité aussi : #142 (code non nul de `profile.sh account`, mêmes phrases), *hors périmètre* de la review finale
  de `feat/profile-plugin` (M7).
- Corrigé en review : limite R7 et `cd` annulé (R8, *régression* de cette branche, review finale I1).

Décision : #142 est traité dans cette branche. R1 ajoute « `profile.sh account` en échec → rapporter sa sortie et
s'arrêter », et le point 8 du reste à faire est rayé.

## 7. Dette du code touché

Textes de skills, pas de méthode. Les lignes 18 et 19 de `pr/SKILL.md` dépassent 120 colonnes (règle de `CLAUDE.md`) : la
phrase réécrite se coupe à 120 colonnes, *corrigé dans cette PR*. Les lignes 28, 39 et 37 de `notify`, `release`
et `todo` aussi.
