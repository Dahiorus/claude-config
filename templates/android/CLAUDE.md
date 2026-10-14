# CLAUDE.md

Ce dépôt documente ses conventions pour les agents IA dans [AGENTS.md](AGENTS.md) — lis-le en entier avant toute
modification : il couvre le projet, la stack, l'architecture, les conventions, les documents de référence, les
commandes et les règles de contribution.

## Rappels clés

- **Exécution d'un plan** : modèle par tâche, revues et montée en gamme dans [WORKFLOW.md](WORKFLOW.md).
- Commits et pushes uniquement à la demande ; format des messages dans [CONTRIBUTING.md](CONTRIBUTING.md) ; ne pas
  commiter de secrets ni `local.properties`.

## Commandes essentielles

Tout build Gradle passe par `build-brief` (sortie condensée ; un hook refuse `./gradlew` nu) ; `--mode raw` pour la
sortie brute.

Pour tout le reste, voir [AGENTS.md](AGENTS.md).
