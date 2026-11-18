---
name: profile
description: Use when the user invokes /profile, asks which profile, plugins, telemetry or gh account a project uses, or wants to switch a project to the vidal or perso profile (« passe ce projet en perso », « quel profil ici ? », « la télémétrie part-elle ici ? »).
argument-hint: "[vidal|perso]"
---

# Profile

Un profil règle les plugins, les skills, les variables d'environnement (télémétrie coupée en perso) et le compte gh
selon le propriétaire du dépôt. Les profils vivent dans `profiles.json` du dossier de config de
Claude Code (`${CLAUDE_CONFIG_DIR:-$HOME/.claude}`) ; `apply` les écrit dans `.claude/settings.local.json` du projet,
exclu de git.

Toutes les commandes passent par `bash "${CLAUDE_PLUGIN_ROOT}/scripts/profile.sh" <sous-commande>`, lancées depuis le
dossier du projet, après avoir vérifié que `profiles.json` existe dans le dossier de config (sinon : « Sans
`profiles.json` »). Tout code non nul → rapporter la sortie telle quelle et s'arrêter ; « detected dubious
ownership » : proposer `git config --global --add safe.directory <dossier du projet>`.

## Sans argument

Lancer `current`, `detect`, `account` et `telemetry` (on, off ou sans jeton : la télémétrie de
`~/.claude/settings.json`, sauf coupure par `OTEL_METRICS_EXPORTER` à `none` dans `settings.local.json` ou dans les
réglages utilisateur ; le shell n'est pas lu). Répondre par un tableau :

| Profil appliqué | Profil détecté | Compte gh | Télémétrie |
|---|---|---|---|

Une sortie vide s'écrit « aucun ». Puis, selon le cas :

- profil détecté « aucun » : `origin` absent, hors `github.com`, ou propriétaire dans aucun `owners` ; proposer
  d'ajouter le propriétaire au bon profil de `profiles.json` ;
- profil appliqué différent du détecté : proposer `/profile <détecté>` ;
- télémétrie « sans jeton » : voir « Télémétrie » ;
- profil perso appliqué et télémétrie « on » : projet passé en perso avant la coupure, proposer `/profile perso` ;
- `.claude/settings.local.json` porte encore `CLAUDE_CODE_ENABLE_TELEMETRY`, `OTEL_METRICS_INCLUDE_REPOSITORY` ou
  `OTEL_EXPORTER_OTLP_METRICS_` suivi de `PROTOCOL`, `ENDPOINT` ou `HEADERS` (lire les noms par
  `jq -r '.env // {} | keys[]'`, jamais les valeurs) : ancien profil, jeton possible ; proposer
  `/profile <appliqué>`, qui retire ces cinq clés ;
- compte attendu mais `GH_TOKEN` absent de l'environnement (`[ -n "$GH_TOKEN" ]`, sans jamais afficher la valeur) :
  tester `[ -n "$(gh auth token -u <compte>)" ]`. Sans jeton : `gh auth login` sur ce compte, puis relancer la
  session. Avec un jeton : le hook n'a pas tourné (session ouverte avant l'installation du plugin), relancer la
  session.
- `profile.sh require-token` signale le jeton d'un autre compte : un `GH_TOKEN` posé dans le shell (le retirer), ou
  un `cd` hors des répertoires de travail que Claude Code a annulé après que le hook a posé le jeton du dossier visé.
  Relancer la session depuis le dépôt.

## Avec un nom

Lancer `apply <nom>`. En cas d'erreur (profil inconnu, JSON invalide), la rapporter telle quelle. Un avertissement
« … omise, fichier … absent » veut dire profil appliqué sans ce secret : demander à l'utilisateur de créer le fichier
(`chmod 600`). Dans tous les cas où le fichier a changé, demander de relancer la session : plugins et `env` ne sont
lus qu'au démarrage.

Un projet passé en perso avant la coupure par `OTEL_METRICS_EXPORTER` ne la reçoit qu'en relançant `/profile perso` :
le hook de démarrage n'applique un profil qu'aux projets qui n'en ont pas. De même, un projet passé en vidal avant
#144 garde le jeton Exploradora dans `settings.local.json` jusqu'à `/profile vidal`.

## Sans `profiles.json`

Les sous-commandes ne rendent rien. Proposer de créer `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/profiles.json` à partir
de l'exemple du plugin (`../../profiles.example.json` depuis le dossier de ce skill) :

1. Lister les comptes connectés avec `gh auth status`.
2. Pour chaque compte, demander quelles organisations ou quels utilisateurs GitHub il sert. `owners` contient au
   moins le compte lui-même, casse indifférente ; un même propriétaire ne va pas dans deux profils.
3. Copier l'exemple, remplacer chaque `mon-compte-…` par le vrai compte et les `owners` par les réponses. Demander
   s'il faut garder `OTEL_METRICS_EXPORTER` et `OTEL_LOGS_EXPORTER` à `none` du profil perso (coupe la télémétrie
   d'équipe sur ces dépôts).
4. Écrire le fichier, montrer son contenu, puis lancer `detect` dans le projet pour vérifier.

## Télémétrie

Claude Code ignore `CLAUDE_CODE_ENABLE_TELEMETRY` et les variables `OTEL_EXPORTER_*` d'un fichier projet : la
télémétrie Exploradora vit dans `~/.claude/settings.json`. Dans claude-config, elle se pose dans
`settings/local.json` (non versionné, fusionné dans `~/.claude/settings.json` par `install`), jamais directement
dans `~/.claude/settings.json` (écrasé par `install`, remonté dans `settings/base.json` par `capture`) ni dans
`settings/base.json` (dépôt public). Un profil peut seulement la couper, par `OTEL_METRICS_EXPORTER` à `none`
(le seul exporteur que lit `telemetry`), `OTEL_LOGS_EXPORTER` ou `OTEL_TRACES_EXPORTER`. « Sans jeton » : il manque
`OTEL_EXPORTER_OTLP_METRICS_HEADERS` (`Authorization=Bearer <jeton>`, jeton de la configuration harnais) dans
`~/.claude/settings.json` ; le demander à l'utilisateur, jamais l'écrire soi-même.

## À savoir

- Le compte gh suit le propriétaire du dépôt (`account`) : le plugin exporte le jeton de session, et les skills
  lancent `gh`, `git push`, `git fetch` et `git pull` sans préfixe, après `profile.sh require-token`. Jeton absent
  ou d'un autre compte : ils s'arrêtent et renvoient ici (diagnostic plus haut). Un `cd` ne change le jeton qu'à
  l'appel Bash suivant ; hors profil, gh prend le compte actif. Jamais `gh auth switch`.
- Changer de profil retire les clés `enabledPlugins`, `skillOverrides` et `env` que déclare un autre profil, et garde
  celles de l'utilisateur. Une variable de `secretEnv` dont le fichier manque est retirée, même posée à la main :
  pas de secret périmé envoyé. Les variables de télémétrie que Claude Code ignore en projet (jeton compris) sont
  retirées aussi.
- Pour modifier un profil, éditer `profiles.json` du dossier de config (dans claude-config : `global/profiles.json`).
  Une valeur secrète va dans `secretEnv` (variable → fichier local), jamais dans `env`.
- Jamais afficher, recopier ni écrire un jeton dans un fichier du projet.
