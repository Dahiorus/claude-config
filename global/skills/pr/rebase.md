# `rebase`

L'invocation vaut demande de réécrire la branche et de la pousser.

1. Noter le SHA local et le SHA distant (`git rev-parse origin/<headRefName>`) : retour par `git reset --hard <sha>`.
2. `git fetch origin main`, puis `git rebase origin/main` dans l'arbre de la PR.
3. Conflits : l'agent Opus lit les deux versions et propose, fichier par fichier, la résolution qui garde
   l'intention de chacune ; jamais `--ours`/`--theirs` en bloc. Intention ambiguë → montrer le conflit et attendre la décision (rebase laissé en cours).
4. Vérification du projet dans l'arbre de la PR. Rouge → ne pas pousser, rapporter, laisser l'arbre en l'état.
5. Approbations existantes (`approvals`, `SKILL.md`) → prévenir qu'un push forcé peut les invalider, puis pousser :
   `git push --force-with-lease=<headRefName>:<SHA distant noté> origin <headRefName>`, jamais `--force` seul.
6. Frictions dans `lecons.md`. Rapport : commits rejoués, fichiers en conflit et résolution choisie, résultat des tests, nouveau SHA.
