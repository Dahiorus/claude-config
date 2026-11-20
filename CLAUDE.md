# claude-config

- `bash tests/run.sh` : tests + shellcheck, plus de 120 s ; `git push` les relance par le hook pre-push. Lancer l'un et l'autre avec `timeout: 580000`. shellcheck prend ses fichiers dans git (`*.sh` partout et `bin/*`, fichiers non suivis compris) ; un script sans `.sh` hors de `bin/` est à ajouter au motif de `tests/run.sh`. Avant de commiter un script ou un test shell, lancer `shellcheck` sur les fichiers modifiés : le pre-push le refuserait après 2 minutes (`printf "$var"` SC2059, motif grep avec accents graves SC2016). Lire la sortie du push ou des tests par `grep -v '^PASS'`, jamais `tail` : une sortie coupée cache le nom du test en échec (« ÉCHEC : code »). Un test qui échoue au push et passe seul : relancer le push une fois avant de chercher la cause.
- `git commit` (ou une autre écriture modifiée par un hook), `git push` et `bash tests/run.sh` ne partent jamais dans
  le même message qu'un autre appel Bash, lecture comprise (`git grep`, `gh`) : le classifieur répond « no verdict »
  à l'autre appel. Le relancer seul, à l'identique.
- `git push` d'une branche : le lancer depuis l'arbre où elle est extraite (dépôt principal ou worktree, `git worktree list`). Le pre-push refuse une branche qui n'est pas extraite (« tests impossibles ») et un arbre aux modifications non commitées, souvent celles d'une autre session dans le dépôt principal : ne pas les remiser ni les commiter, pousser depuis un worktree propre de la branche (`git worktree add ../claude-config.worktrees/<nom> <branche>`).
- Script de `githooks/` qui lance les tests ou crée des dépôts : `unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_COMMON_DIR` d'abord. Lancé depuis un worktree, un hook en hérite, et les dépôts jetables des tests visent alors la vraie branche et `.git/config`.
- `global/bash-rewrite-hook.sh` ne doit réécrire que pour build-brief et rtk : le mode auto refuse toute commande d'écriture qu'un hook a modifiée (« a hook changed this call's input »). Un compte gh ou un jeton ne s'ajoute pas par réécriture de commande. Seul le plugin `profile` exporte `GH_TOKEN` pour la session, par `CLAUDE_ENV_FILE` et non en réécrivant une commande.
- Compte gh : `bash ~/.claude/profile.sh account`, porté par le jeton de session du plugin `profile` ; les skills le
  vérifient par `profile.sh require-token` (jeton absent ou d'un autre compte → `/profile`). `GH_CONFIG_DIR` ne
  change pas de compte sans jeton en clair dans `hosts.yml` (trousseau partagé) : piste écartée.
- Session `EnterWorktree` : Claude Code refuse `git -c`, `VAR=$(…) git/gh`, les heredocs qui citent git et les longs `gh api -f body=…`. Écrire un fichier puis `--input` / `--body-file`, ou sortir du worktree (`ExitWorktree` `keep`) pour pousser.
- `gh pr comment`, `gh pr edit` et `git` se lancent depuis l'arbre du dépôt : après un `cd` vers le scratchpad, ils
  échouent (« pas un dépôt git »). Ne pas changer de dossier : passer le fichier par son chemin absolu.
- Le hook « main-guard » refuse un push vers main tapé dans un appel Bash : refspec de destination `main` (y compris `--delete`, `--tags` avec refspec, `"main"`, `heads/main`, globs `*:*`, `:`), `--all`/`--branches`/`--mirror`, ou push sans refspec ou vers `HEAD`/`@` depuis main (selon `push.default` et l'upstream). Un commit sur main passe : `/pr push` le rattrape. Il lit la commande avec `shfmt --to-json` (installé par `claude-config install`) : sans shfmt 3.14 ou plus, si shfmt ne la lit pas, si le hook plante ou s'il dépasse un plafond (64 états possibles, 40 s, 2000 processus), tout appel qui cite `git` et `push` est refusé. Il garde l'ensemble des états possibles (dossier, branche prise par `git switch`/`checkout`) : un `cd`/`pushd` ou un switch ne compte qu'après `&&` ; après `;`, `||` ou un saut de ligne, la suite est jugée dans chaque état possible (avec et sans le `cd`), donc `cd ../wt; git push` depuis main est refusé. Pipeline, `( )`, `&`, `$( )` et backtick tournent dans un sous-shell : leurs `cd` ne comptent pas pour la suite (`x=$(cd ../wt) && git push` depuis main est refusé) ; if, case, boucles et fonctions sont jugés en un passage. Un switch donne la branche qu'il crée (`-c`, `-b`, `-C`, `-B`, `--create`, `--force-create`, `--orphan`), sinon une branche inconnue, jugée comme main ; un switch dans un dépôt inconnu (`git -C "$X"`) ou dans un second dépôt rend la branche inconnue partout ; un dossier calculé (`cd $W`, `cd -`) ou absent et un mot calculé (`"$B"`) aussi. Le corps d'un heredoc n'est pas jugé ; `bash -c '…'` d'un script littéral l'est. Options globales de git (`-C`, `-c`, `--git-dir`, `--work-tree`, `--namespace`) et préfixes (`env`, `sudo`, `command`, `builtin`, `nice`, `nohup`, `time`, `timeout`, `rtk`, `VAR=x`) sont lus ; alias git, `eval`, `xargs`, `exec`, `trap`, `watch`, `export GIT_DIR`, options abrégées et `remote.*.push` ne le sont pas (`shortcut:` en tête du hook). Depuis le dépôt principal sur main, pousser un worktree passe par `git -C <worktree> push`.
- Hook qui analyse une commande shell : main-guard s'appuie sur l'arbre de shfmt, donc toute syntaxe bash est lue ; il ne juge que les commandes et options listées ci-dessus. Le reste (exécution, formes rares) est un `shortcut:` en tête du hook, montré par `test_guard_ast_shows_shortcuts`, et une ligne dans « Limites » de la PR : l'ajouter quand un cas réel le demande, pas à chaque relecture. bash-rewrite garde sa lecture maison : une syntaxe que Claude n'écrit pas s'y classe « à trancher », par défaut un `shortcut:`. Tout correctif : rejouer les scripts adverses de la relecture et les `git push` que les skills écrivent (`grep -rn 'git push' global/skills`), le hook étant actif dans toutes les sessions dès la branche extraite, et muter le correctif pour voir le test échouer, avant de pousser.
- Agent lancé avec `isolation: "worktree"` : il part de `main`, pas de la branche, et le worktree disparaît s'il s'arrête sans commit (les bugs en parallèle de `bugfix` commitent un `WIP` avant de répondre). Les lots parallèles de `feature` passent par un worktree créé par le contrôleur sur la branche (étape 4).
- Plan SDD : titres « Task N », N entier, pas « Tâche N » ni « Task C1 », sinon `task-brief` ne trouve pas la tâche ou la fond dans la précédente.
- Règle ajoutée, changée ou exception à une règle : avant le premier push, chercher (grep) toutes ses formulations dans `global/skills/*/` (SKILL.md et fichiers d'action), la spec, `docs/domaine.md`, ce CLAUDE.md et la description de la PR. Une règle d'un skill est souvent recopiée dans les autres : celle du jeton gh l'était dans six skills. Règle sur un objet (description de PR, commit, worktree) : grepper aussi les commandes qui le produisent (`gh pr create`, `gh pr edit`, `git commit`, `git worktree add`), pas seulement les mots de la règle. Règle ajoutée à `feature` : `bugfix` a souvent la même étape (agents, review), l'y reporter.
  - Étape de skill qui gagne un élément (une review, un agent, une condition) : grepper les décomptes et énumérations
    qu'elle rend faux (« les deux reviews », « les trois »), et relire l'étape entière contre les phrases voisines :
    un ajout contredit souvent une phrase déjà là. Agent dont le rôle s'étend : mettre à jour sa description
    (frontmatter), que le skill appelant et la liste des agents recopient.
  - Règle qui change un seuil ou un chiffre (« 200 lignes ») : grepper l'objet qu'elle mesure et ses exemptions
    voisines (« longueur libre », « test », « fixtures », « script shell »), pas le seul chiffre : la règle se
    recopie sans lui. Relire aussi les étapes qui la citent par renvoi (plan, review, rationalisations).
  - Règle qui prescrit une commande (`git grep`, `git push`, `gh`) : la jouer sur un cas réel avant de l'écrire. Un
    `git grep` lit ligne par ligne : une phrase coupée à 120 colonnes ne se trouve pas entière, il faut un fragment
    tenu sur une ligne.
  - Agent qui lit ou cherche dans un dépôt : sa consigne nomme la racine que le brief lui donne (arbre de la PR,
    pas le dépôt principal) et écrit la commande avec elle (`git -C <racine> grep …`), sur tout le dépôt, sans
    liste de dossiers. Sans cela il cherche dans son dossier courant, celui de la session.
  - Règle changée en cours de PR (correctif de review compris) : relire aussi le titre de la PR, pas seulement la
    description (`gh pr edit --title`). `pr-risk` compte un titre resté sur l'ancienne règle comme écart d'intention.
  - Liste fermée changée (points de publication du hook humanizer, par exemple) : grepper aussi les phrases de
    l'ancienne décision (« hors », « inchangé », « reste hors ») dans la spec (tableau d'impact, Origine, cas de test),
    `docs/domaine.md` et la description de la PR. Deux PR de suite ont laissé une phrase qui excluait le nouveau point.
  - Skill qui gagne un mode ou un état d'objet (draft d'une PR, par exemple) : avant le premier push, lister chaque
    action du skill (`global/skills/<skill>/*.md`) et chaque entrée ou sortie de cet état, et écrire ce que chacune
    fait : objet déjà dans l'état visé ou dans l'état inverse, travail restant à la sortie, vérification impossible
    dans l'état (pre-push, tests), action qui lit l'objet sans le modifier (`merge`, `squash`, `review`). Les cas de
    bord de cette liste sont ce que les reviews trouvent un par un, en autant de tours.
- `bin/claude-config install` lancé dans un worktree relie `~/.claude` à ce worktree (le `claude-config` du PATH pointe vers le dépôt principal) : le relancer depuis le dépôt principal une fois la branche mergée.
- Skill, doc ou script qui fait écrire dans `~/.claude/` (jeton, réglage) : `install` génère `settings.json` depuis
  `settings/base.json` (+ `local.json`) et `capture` remonte toute clé absente de `local.json` dans `base.json`,
  public. Une valeur posée à la main dans `settings.json` est écrasée, un secret fuit : il va dans
  `settings/local.json` (ignoré par git).
- Test shell qui alimente un hook ou `jq` : here-string (`<<<"$json"`), pas `jq … | hook`. Un hook qui sort sans
  lire son entrée tue l'écrivain par SIGPIPE, code 141 sous `pipefail` : test instable. Un test instable se mesure
  en boucle (`for i in $(seq 60)`) avant d'être mis hors périmètre.
- Hook à motifs : une mutation par garde (motif, option, branche), pas seulement pour les gardes que l'on juge
  importantes. Une mutation scriptée se vérifie par un `assert ancien in texte` avant l'écriture et par un nombre
  d'échecs non nul après : « 0 FAIL » sur une mutation est un signal d'alarme (motif non trouvé, rien muté), pas
  un succès. Une garde sans test qui échoue reçoit son test avant le push.
- Test shell qui lit la sortie d'un hook avec `jq` : `jq … // "x"` n'imprime rien sur une entrée vide, et
  `select(.champ)` échoue en entier sur une ligne JSONL qui n'est pas un objet (`123`). Lancer l'aide de test sur
  la sortie vide et sur une ligne non objet avant de la recopier ; filtrer par `select(type == "object" and …)`.
- Branche qui modifie `mods/<plugin>/` : monter `version` dans `mods/<plugin>/.claude-plugin/plugin.json` dans la
  même PR. Claude Code range le plugin installé par version : sans changement, `claude plugin update` répond « already
  at the latest version » et garde l'ancien code.
- Un `GH_TOKEN` vide fait choisir à gh le compte actif : tester `[ -n "$token" ]` avant de le passer à gh.
- Les skills du dépôt sont reliés à `~/.claude` : une autre session peut modifier `global/skills/*` pendant le travail sur une branche (les sessions des autres projets passent par `/notify claude-config` : `global/CLAUDE.md`, « Skills globaux »). Commiter fichier par fichier, jamais `git add -A`.
- Texte ou diff demandé par une autre session (`/notify claude-config`) : l'appliquer tel quel. Une fusion avec une phrase voisine ou un changement de portée se propose à part, dans la PR.
- Texte demandé, ou leçon venue d'un autre projet, qui affirme un comportement d'un hook du dépôt (main-guard, bash-rewrite, pre-push) : le rejouer sur ce hook (dépôt jetable ou `tests/test_main_guard.sh`) avant de l'appliquer ; s'il est faux, le dire à la session d'origine au lieu de l'écrire.
  - Même règle pour un hook de plugin (`CwdChanged` du plugin `profile`…) ou un comportement de Claude Code
    rapporté par une autre session : le rejouer par une commande réelle dans cette session avant de l'écrire.
  - Même contrôle pour ce qu'il affirme d'un skill ou d'un agent, simple parenthèse comprise : le relire dans le
    fichier concerné, retirer ce qui est inexact.
  - Même contrôle pour un remède de code qu'il prescrit (« dans un bloc », « avec X ») : le jouer sur chaque langage
    du dépôt (bash, Python, JS) avant de l'écrire. Faux pour l'un d'eux → un remède qui vaut partout, sinon limiter
    la règle au langage où il vaut.
  - Sonder un hook de plugin qui exporte dans `CLAUDE_ENV_FILE` : un fichier écrit dans
    `~/.claude/session-env/<session>/` ne change pas l'env des appels Bash (Claude Code met le script en cache
    jusqu'à un hook), donc poser un hook temporaire dans `.claude/settings.local.json`. Le fichier d'env reste fait
    d'affectations simples (un `case` y est refusé) : la logique va dans le hook. Un `cd` hors des dossiers de
    travail lance CwdChanged, mais Claude Code annule le `cd` sans relancer le hook.
- Une autre session peut aussi commiter sur la branche extraite dans le dépôt principal. Avant de pousser, `git log --oneline origin/main..` ne doit montrer que les commits de la branche. Pour retirer un commit étranger, le classifieur refuse `git reset --hard` : recréer le commit sur sa propre branche, quitter la branche (`git switch`), puis demander à l'utilisateur `! git branch -f <branche> <sha>`.
- Texte français ou Markdown (skill, spec, description de PR, réponse de fil ou de review) : l'écrire ou le modifier avec Edit/Write, jamais `sed -i`, `python3 -c`, `printf` ni `echo` en ligne. Apostrophes et backticks cassent le quoting ou font rater le motif sans erreur. Une édition en masse par script s'assure que le motif est présent (`assert`) et se vérifie avec `git diff --stat`.
- Ligne de skill ou de Markdown ajoutée ou réécrite : 120 colonnes au plus. Quand on retire un morceau d'une
  phrase (commande, incise), relire la phrase entière : le raccord casse souvent. Ligne déjà plus longue que 120
  colonnes : ne pas la réécrire, ajouter le texte sur une sous-ligne ou une sous-puce.
