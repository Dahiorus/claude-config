---
name: profile
description: Use when the user invokes /profile, asks which profile, plugins, telemetry or gh account a project uses, or wants to switch a project to the vidal or perso profile (« passe ce projet en perso », « quel profil ici ? », « la télémétrie part-elle ici ? »).
argument-hint: "[vidal|perso]"
---

# Profile

Un profil règle les plugins, les skills, les variables d'environnement (télémétrie Exploradora pour vidal, coupée en
perso) et le compte gh selon le propriétaire du dépôt. Les profils vivent dans `global/profiles.json` de
claude-config ; `profile.sh apply` les écrit dans `.claude/settings.local.json` du projet, exclu de git.

## Sans argument

Lancer `bash ~/.claude/profile.sh current` et `bash ~/.claude/profile.sh detect` dans le dossier courant, plus
`bash ~/.claude/profile.sh account` pour le compte gh et `bash ~/.claude/profile.sh telemetry` (on, off ou sans
jeton : l'état écrit par le profil dans `settings.local.json`, pas celui de `~/.claude/settings.json` ni du shell).
Répondre par un tableau :

| Profil appliqué | Profil détecté | Compte gh | Télémétrie |
|---|---|---|---|

Profil appliqué différent du détecté : proposer `/profile <détecté>`. Télémétrie « sans jeton » : voir « Jeton
Exploradora ».

## Avec un nom

Lancer `bash ~/.claude/profile.sh apply <nom>`. En cas d'erreur (profil inconnu, JSON invalide), la rapporter telle
quelle. Un avertissement « … omise, fichier … absent » veut dire profil appliqué sans le secret : renvoyer à « Jeton
Exploradora ». Dans tous les cas où le fichier a changé, demander de relancer la session : plugins et `env` ne sont
lus qu'au démarrage.

Un projet passé en vidal avant l'ajout de la télémétrie ne la reçoit qu'en relançant `/profile vidal` : le hook de
démarrage n'applique un profil qu'aux projets qui n'en ont pas.

## Jeton Exploradora

claude-config est public : le jeton n'est jamais dans `profiles.json`, ni dans un commit, ni dans une réponse. Le
profil vidal le lit dans `~/.claude/exploradora.token` (`secretEnv`), qui contient la valeur entière de
`OTEL_EXPORTER_OTLP_METRICS_HEADERS` : `Authorization=Bearer <jeton>`. Le jeton vient de la configuration harnais.
Demander à l'utilisateur de créer le fichier (`chmod 600`), puis relancer `/profile vidal`.

## À savoir

- Le compte gh suit le propriétaire du dépôt (`bash ~/.claude/profile.sh account`) : les skills le passent en jeton ponctuel testé, en une commande : `t=$(gh auth token -u <compte>); [ -n "$t" ] && GH_TOKEN=$t gh …` (même forme devant `git push`, `git fetch` et `git pull`), jamais le jeton recopié en clair ; jeton vide → s'arrêter (gh prendrait le compte actif). Rien ne l'ajoute tout seul : une commande `gh` sans jeton prend le compte actif. Jamais `gh auth switch`.
- Changer de profil retire les clés `enabledPlugins`, `skillOverrides` et `env` que déclare un autre profil, et garde
  celles de l'utilisateur. Une variable de `secretEnv` dont le fichier manque est retirée, même posée à la main :
  pas de jeton périmé envoyé, et `telemetry` répond « sans jeton ».
- Pour modifier un profil, éditer `global/profiles.json` dans claude-config. Une valeur secrète va dans `secretEnv`
  (variable → fichier local), jamais dans `env`.
