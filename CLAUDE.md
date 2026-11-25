# claude-config

Une règle vérifiable par un programme va dans `tests/` ou un hook, pas ici.

## Tests et push

- `bash tests/run.sh` (tests + shellcheck) et `git push` (le pre-push les relance) : plus de 120 s, `timeout: 580000`.
  Lire leur sortie par `grep -v '^PASS'`, jamais `tail`. Un test qui échoue au push et passe seul : relancer une fois.
- Avant de commiter un script shell, `shellcheck` sur les fichiers modifiés : le pre-push le refuserait après 2 min.
  Script shell sans `.sh` hors de `bin/` et `githooks/` : l'ajouter au motif de `tests/run.sh`
  (`test_shell_scripts_in_shellcheck_scope`).
- `git commit`, `git push` et `bash tests/run.sh` partent seuls dans leur message, sans autre appel Bash : sinon le
  classifieur répond « no verdict ». Le mode auto refuse aussi une écriture qu'un hook a réécrite :
  `bash-rewrite-hook.sh` ne réécrit que pour build-brief et rtk (jamais en mode auto, ni pour un compte ou un jeton).
- Session `EnterWorktree` : Claude Code refuse `git -c`, `VAR=$(…) git/gh`, les heredocs qui citent git et les longs
  `gh api -f body=…`. Passer par un fichier (`--input`, `--body-file`) ou sortir du worktree (`ExitWorktree` `keep`).
- `gh` et `git` se lancent depuis l'arbre du dépôt, jamais après un `cd` vers le scratchpad : fichier par chemin absolu.
- `git push` depuis l'arbre où la branche est extraite, propre. Modifications d'une autre session dans le dépôt
  principal : ni remiser ni commiter, pousser depuis `git worktree add ../claude-config.worktrees/<nom> <branche>`.
- Une autre session peut commiter sur la branche extraite ou modifier `global/skills/*` (reliés à `~/.claude`) :
  commiter fichier par fichier, jamais `git add -A`, et lire `git log --oneline origin/main..` avant de pousser.
  Commit étranger : le recréer sur sa branche, quitter la branche, demander `! git branch -f <branche> <sha>` (le
  classifieur refuse `git reset --hard`).

## Hooks

- main-guard refuse un push vers main (refspec `main`, `--all`, push sans refspec depuis main…) ; un commit sur main
  passe, `/pr push` le rattrape. Sans shfmt 3.14 ou plus, ou si le hook échoue, tout appel qui cite `git` et `push`
  est refusé. Un `cd` ou un switch ne compte qu'après `&&`. Depuis main, pousser un worktree : `git -C <worktree> push`.
  Le détail est dans `tests/test_main_guard*.sh`, les limites en `shortcut:` en tête du hook (une limite s'y ajoute
  quand un cas réel la demande, avec une ligne dans « Limites » de la PR). bash-rewrite garde sa lecture maison : une
  syntaxe que Claude n'écrit pas s'y classe « à trancher », par défaut un `shortcut:`.
- Hook ajouté ou corrigé : il est actif dans toutes les sessions dès la branche extraite. Rejouer les scripts
  adverses de la relecture, puis une mutation par garde : `assert` du motif avant d'écrire, échecs non nuls après
  (« 0 FAIL » veut dire que rien n'a été muté). Une garde sans test qui échoue reçoit le sien avant le push.
- Test shell : alimenter un hook qui peut sortir sans lire par here-string (`<<<"$json"`), pas par un pipe (SIGPIPE,
  code 141). Une aide `jq` se lance sur une sortie vide et sur une ligne non objet (`select(type == "object" and …)`).
  Un test instable se mesure en boucle (`for i in $(seq 60)`).

## Règles et skills

- Règle ajoutée ou changée : avant le premier push, grepper ses formulations et ses copies (`global/skills/*/`,
  `global/agents/`, spec, `docs/domaine.md`, ce fichier, titre et description de la PR), les commandes qui produisent
  l'objet visé (`gh pr create`, `git commit`…), les décomptes qu'elle rend faux (« les deux reviews »), l'objet et les
  exemptions d'un seuil changé, et les phrases de l'ancienne décision (« hors », « inchangé »). Règle de `feature` :
  la reporter dans `bugfix`. Agent dont le rôle change : mettre à jour sa `description`.
- `git grep` lit ligne par ligne : chercher par un fragment tenu sur une ligne.
- Spec ou plan à commiter : `bash tests/run.sh` avant (120 colonnes, plafonds de lignes de `test_skills.sh`).
- Règle de cas (pile, draft, état…) : rejouer sa condition sur le cas réel visé avant le premier push (la PR du bas
  d'une pile a main pour base).
- Skill qui gagne un mode ou un état d'objet (draft…) : avant le premier push, écrire ce que fait chaque action du
  skill dans chaque état, entrée et sortie comprises.
- Texte français ou Markdown : Edit/Write, jamais `sed -i`, `python3 -c`, `printf` ni `echo`. Édition en masse par
  script : `assert` du motif, puis `git diff --stat`.
- Markdown : la prose ajoutée tient en 120 colonnes (`test_branch_respects_rules`, qui dit quoi faire d'une ligne déjà
  longue). Morceau de phrase retiré : relire la phrase entière.

## Textes reçus d'autres sessions

- Texte ou diff reçu par `/notify claude-config` : l'appliquer tel quel, sauf contre les 120 colonnes ; une
  reformulation se propose à part. Avant d'ouvrir la PR, le relire contre la grille de `feature`, écarts dans la
  description.

## Installation et réglages

- `bin/claude-config install` lancé dans un worktree relie `~/.claude` à ce worktree : le relancer depuis le dépôt
  principal après le merge.
- `install` génère `settings.json` (`settings/base.json` + `local.json`) et `capture` remonte dans `base.json`,
  public, toute clé absente de `local.json` : un secret va dans `settings/local.json`.
- `mods/<plugin>/` modifié : monter `version` dans son `plugin.json` (`test_branch_respects_rules`), sinon
  `claude plugin update` garde l'ancien code.
