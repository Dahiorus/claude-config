---
name: profile
description: Use when the user invokes /profile, asks which profile, plugins, telemetry or gh account a project uses, or wants to switch a project to the vidal or perso profile (« passe ce projet en perso », « quel profil ici ? », « la télémétrie part-elle ici ? »).
argument-hint: "[vidal|perso]"
---

# Profile

Un profil règle les plugins, les skills, les variables d'environnement (télémétrie Exploradora pour vidal, coupée en
perso) et le compte gh selon le propriétaire du dépôt. Les profils vivent dans `profiles.json` du dossier de config de
Claude Code (`${CLAUDE_CONFIG_DIR:-$HOME/.claude}`) ; `apply` les écrit dans `.claude/settings.local.json` du projet,
exclu de git.

Toutes les commandes passent par `bash "${CLAUDE_PLUGIN_ROOT}/scripts/profile.sh" <sous-commande>`, lancées depuis le
dossier du projet, après avoir vérifié que `profiles.json` existe dans le dossier de config (sinon : « Sans
`profiles.json` »). Tout code non nul → rapporter la sortie telle quelle et s'arrêter ; « detected dubious
ownership » : proposer `git config --global --add safe.directory <dossier du projet>`.

## Sans argument

Lancer `current`, `detect`, `account` et `telemetry` (on, off ou sans jeton : l'état écrit par le profil dans
`settings.local.json`, pas celui de `~/.claude/settings.json` ni du shell). Répondre par un tableau :

| Profil appliqué | Profil détecté | Compte gh | Télémétrie |
|---|---|---|---|

Une sortie vide s'écrit « aucun ». Puis, selon le cas :

- profil détecté « aucun » : `origin` absent, hors `github.com`, ou propriétaire dans aucun `owners` ; proposer
  d'ajouter le propriétaire au bon profil de `profiles.json` ;
- profil appliqué différent du détecté : proposer `/profile <détecté>` ;
- télémétrie « sans jeton » : voir « Jeton Exploradora » ;
- compte attendu mais `GH_TOKEN` absent de l'environnement (`[ -n "$GH_TOKEN" ]`, sans jamais afficher la valeur) :
  tester `[ -n "$(gh auth token -u <compte>)" ]`. Sans jeton : `gh auth login` sur ce compte, puis relancer la
  session. Avec un jeton : le hook n'a pas tourné (session ouverte avant l'installation du plugin), relancer la
  session.

## Avec un nom

Lancer `apply <nom>`. En cas d'erreur (profil inconnu, JSON invalide), la rapporter telle quelle. Un avertissement
« … omise, fichier … absent » veut dire profil appliqué sans le secret : renvoyer à « Jeton Exploradora ». Dans tous
les cas où le fichier a changé, demander de relancer la session : plugins et `env` ne sont lus qu'au démarrage.

Un projet passé en vidal avant l'ajout de la télémétrie ne la reçoit qu'en relançant `/profile vidal` : le hook de
démarrage n'applique un profil qu'aux projets qui n'en ont pas.

## Sans `profiles.json`

Les sous-commandes ne rendent rien. Proposer de créer `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/profiles.json` à partir
de l'exemple du plugin (`../../profiles.example.json` depuis le dossier de ce skill) :

1. Lister les comptes connectés avec `gh auth status`.
2. Pour chaque compte, demander quelles organisations ou quels utilisateurs GitHub il sert. `owners` contient au
   moins le compte lui-même, casse indifférente ; un même propriétaire ne va pas dans deux profils.
3. Copier l'exemple, remplacer chaque `mon-compte-…` par le vrai compte et les `owners` par les réponses. Demander
   s'il faut garder `CLAUDE_CODE_ENABLE_TELEMETRY: "0"` du profil perso (coupe la télémétrie d'équipe sur ces
   dépôts).
4. Écrire le fichier, montrer son contenu, puis lancer `detect` dans le projet pour vérifier.

## Jeton Exploradora

claude-config est public : le jeton n'est jamais dans `profiles.json`, ni dans un commit, ni dans une réponse. Le
profil vidal le lit dans `~/.claude/exploradora.token` (`secretEnv`), qui contient la valeur entière de
`OTEL_EXPORTER_OTLP_METRICS_HEADERS` : `Authorization=Bearer <jeton>`. Le jeton vient de la configuration harnais.
Demander à l'utilisateur de créer le fichier (`chmod 600`), puis relancer `/profile vidal`.

## À savoir

- Le compte gh suit le propriétaire du dépôt (`account`) : les skills le passent en jeton ponctuel testé, en une
  commande : `t=$(gh auth token -u <compte>); [ -n "$t" ] && GH_TOKEN=$t gh …` (même forme devant `git push`,
  `git fetch` et `git pull`), jamais le jeton recopié en clair ; jeton vide → s'arrêter (gh prendrait le compte
  actif). Le plugin exporte le jeton de session ; une commande sans préfixe prend le compte du profil du dossier
  courant, ou le compte actif hors profil. Jamais `gh auth switch`.
- Changer de profil retire les clés `enabledPlugins`, `skillOverrides` et `env` que déclare un autre profil, et garde
  celles de l'utilisateur. Une variable de `secretEnv` dont le fichier manque est retirée, même posée à la main :
  pas de jeton périmé envoyé, et `telemetry` répond « sans jeton ».
- Pour modifier un profil, éditer `profiles.json` du dossier de config (dans claude-config : `global/profiles.json`).
  Une valeur secrète va dans `secretEnv` (variable → fichier local), jamais dans `env`.
- Jamais afficher, recopier ni écrire un jeton dans un fichier du projet.
