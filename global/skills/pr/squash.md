# `squash`

L'invocation vaut demande de réécrire l'historique et de le pousser.

1. PR multiples d'une feature (plan à stories sur la branche) : marquer d'abord la story « livrée : PR #n » à son
   titre dans le plan et commiter, avant de noter les SHA. Puis `git fetch origin main`, noter le SHA local et le SHA distant (`git rev-parse origin/<headRefName>`) : retour par
   `git reset --hard <sha>`. Puis repartir de `origin/main` : `git reset --soft $(git merge-base HEAD origin/main)`,
   en rebasant d'abord sur `origin/main` si la branche est en retard. Messages dans la langue et au format de
   `CONTRIBUTING.md` (attribution du system-reminder), passés par `humanizer:humanizer`.
   - **PR de taille normale** : un seul commit qui résume la feature (spec + plan + code pour la première d'une
     feature).
   - **PR volumineuse** (plus de ~30-40 fichiers modifiés hors fichiers générés) : un commit par pan fonctionnel
     métier, chacun avec son code, ses tests et sa doc, découpage proposé par l'agent Opus (fichiers et message de
     chaque commit). Ordre de dépendance, pas de commit « correctifs de review ».
     Chaque commit doit compiler : compiler les intermédiaires (`git rebase --exec '<build>' origin/main`).
2. Arbre final identique à celui du SHA de départ (`git diff <sha>` vide), puis vérification du projet sur le dernier
   commit. Rouge → ne pas pousser, rapporter.
3. Approbations existantes (`approvals`, `SKILL.md`) → prévenir qu'un push forcé peut les invalider, puis
   `git push --force-with-lease=<headRefName>:<SHA distant noté> origin <headRefName>`, jamais `--force` seul.
4. Rapport : découpage en commits (SHA et sujet), résultat de la vérification.
