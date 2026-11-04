# claude-config

- `bash tests/run.sh` : tests + shellcheck. `lib/*.sh` et `tests/*.sh` y passent par glob ; tout autre script `.sh` est à nommer dans la liste shellcheck de `tests/run.sh`.
- `global/bash-rewrite-hook.sh` ne doit réécrire que pour build-brief et rtk : le mode auto refuse toute commande d'écriture qu'un hook a modifiée (« a hook changed this call's input »). Un compte gh ou un jeton ne s'ajoute pas par hook : les skills le passent dans la commande.
- Compte gh : `bash ~/.claude/profile.sh account` ; jeton ponctuel `GH_TOKEN=$(gh auth token -u <compte>)`, hors session `EnterWorktree` (voir ligne suivante). `GH_CONFIG_DIR` ne change pas de compte sans jeton en clair dans `hosts.yml` (trousseau partagé) : piste écartée.
- Session `EnterWorktree` : Claude Code refuse `git -c`, `VAR=$(…) git/gh`, les heredocs qui citent git et les longs `gh api -f body=…`. Écrire un fichier puis `--input` / `--body-file`, ou sortir du worktree (`ExitWorktree` `keep`) pour pousser.
- Le hook « main-guard » refuse un `git commit` tapé dans un appel Bash quand la branche est main, même dans un dépôt bac à sable (`git -C <bac à sable> commit`) : y passer par la plomberie (`commit-tree`, `update-ref`). Un commit lancé par un script de `tests/` lui échappe. Depuis le dépôt principal sur main, `cd <worktree> && git commit` est aussi refusé : passer par `git -C <worktree> commit`.
- Agent lancé avec `isolation: "worktree"` : il part de `main`, pas de la branche. Une tâche qui touche un fichier déjà modifié sur la branche ne part pas en worktree, et son rapport s'écrit par chemin absolu dans le dépôt principal (le `.superpowers/` du worktree disparaît avec lui).
- Plan SDD : titres « Task N », pas « Tâche N », sinon `task-brief` ne trouve pas la tâche.
- Décision qui change une règle : chercher l'ancienne formulation (grep) dans la spec, `docs/domaine.md`, les skills et la description de la PR avant le merge.
- `bin/claude-config install` lancé dans un worktree relie `~/.claude` à ce worktree (le `claude-config` du PATH pointe vers le dépôt principal) : le relancer depuis le dépôt principal une fois la branche mergée.
- Un `GH_TOKEN` vide fait choisir à gh le compte actif : tester `[ -n "$token" ]` avant de le passer à gh.
