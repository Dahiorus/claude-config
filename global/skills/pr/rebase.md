# `rebase`

L'invocation vaut demande de réécrire la branche et de la pousser.

1. Noter le SHA local et le SHA distant (`git rev-parse origin/<headRefName>`) : retour par `git reset --hard <sha>`.
2. `<base>` = `gh pr view <n°> --json baseRefName --jq .baseRefName`. `git fetch origin <base>`, puis dans
   l'arbre de la PR `git log --oneline origin/<base>..HEAD`. Commits qui ne sont pas ceux de la PR (base réécrite
   par squash ou rebase, ou base mergée puis PR repointée sur `main`) : `git rebase --onto origin/<base> <plus
   récent d'entre eux>`, sinon ils sont rejoués en double ; `git merge-base --fork-point origin/<base> HEAD` le
   donne quand la base est réécrite. Sinon `git rebase origin/<base>`.
3. Conflits : l'agent `rebase-resolver` (modèle `opus` passé explicitement) lit les deux versions et propose, fichier par fichier, la résolution qui garde
   l'intention de chacune ; jamais `--ours`/`--theirs` en bloc. Intention ambiguë → montrer le conflit et attendre la décision (rebase laissé en cours).
   Le brief de l'agent donne la base (`origin/<base>`).
4. Vérification du projet dans l'arbre de la PR. Rouge → ne pas pousser, rapporter, laisser l'arbre en l'état.
5. Approbations existantes (`approvals`, `SKILL.md`) → prévenir qu'un push forcé peut les invalider, puis pousser :
   `git push --force-with-lease=<headRefName>:<SHA distant noté> origin <headRefName> # humanizer: sans objet`
   (aucun texte publié : sans le marqueur, le hook `humanizer-hook.sh` refuse ce push forcé), jamais `--force` seul.
6. Leçons dans `lecons.md`. Rapport : commits rejoués, fichiers en conflit et résolution choisie, résultat des tests,
   nouveau SHA.
