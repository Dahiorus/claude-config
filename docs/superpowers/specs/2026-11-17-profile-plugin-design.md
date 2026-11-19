# Plugin `profile` dans claude-config

## 1. Demande initiale

> « transforme le skill /profile en plugin claude »
> « les deux, surtout la bascule de compte gh »
> « la 1 » (un hook exporte `GH_TOKEN` dans `CLAUDE_ENV_FILE`)
> « Message seulement » (compte sans jeton : un message, gh garde le compte actif)
> « Hook posé par configure (Recommandé) » (le hook `CwdChanged` vient des réglages, pas du plugin seul)
> « le plugin est à créer dans mon repo claude-config »
> Le skill perso `global/skills/profile` : « Remplacé par le plugin ». La PR harnais #30 : « Fermée ».

Une première version a été écrite dans harnais (`feat/profils-projet`, PR #30 fermée). Ses constats techniques
(§ « Comportement de Claude Code ») et ses correctifs de review valent ici ; son code Node ne couvre ni `secretEnv`
ni la télémétrie de `profile.sh`.

## Intention

Le poste sert à des dépôts VIDAL (compte `brondon-ung`) et perso (`Dahiorus`). Aujourd'hui chaque skill doit
préfixer ses commandes `gh` et `git push` par `GH_TOKEN=$(gh auth token -u …)` : une commande oubliée, ou tapée par
Claude hors skill, part sur le compte actif. Le plugin exporte le bon `GH_TOKEN` pour toute la session et le suit
après un `cd`. Il emporte aussi ce que fait déjà `profile.sh` (plugins, skills, `env`, `secretEnv`, télémétrie).

## Objectifs

- Toute commande Bash de la session, sous-agents compris, utilise le compte gh du propriétaire du dépôt courant.
- Un `cd` vers un dépôt d'un autre propriétaire bascule le compte ; vers un dépôt sans profil, le jeton posé par
  le plugin est vidé ; un dossier hors dépôt (`/tmp`, scratchpad) garde le compte du dossier quitté.
- Le profil, ses plugins, skills, `env` et `secretEnv`, et le skill `/profile` vivent dans un plugin
  `mods/profile/` du marketplace `claude-config`.

## Non-objectifs

- Pas de `gh auth switch` : le compte actif de gh ne change jamais.
- Aucun jeton dans un fichier du projet ni dans un commit (dépôt public).
- Windows et PowerShell.

## Anti-objectifs

- Une commande `gh` qui part en silence sur le mauvais compte parce que le profil n'a pas pu s'appliquer : un échec
  (profil mal formé, compte non connecté, git en panne) se dit au démarrage, sans bloquer gh.
- Un poste sans `~/.claude/profiles.json` qui change de comportement : sans fichier, le plugin ne fait rien.

## Comportement de Claude Code (constaté dans harnais, Claude Code 2.1.326)

1. L'`export` d'un hook dans `CLAUDE_ENV_FILE` gagne sur `env` de `settings.local.json`.
2. Les sous-agents voient la variable.
3. Un hook `CwdChanged` de plugin ne part **que si** un hook `CwdChanged` existe dans les réglages ; alors celui
   du plugin part aussi.
4. `CLAUDE_ENV_FILE` est un fichier par hook (`session-env/<session>/<événement>-hook-<n>.sh`), enchaînés dans
   l'ordre sessionstart puis cwdchanged ; les fichiers `cwdchanged-*` sont vidés avant chaque `cd`. Rien ne dit
   si un `sessionstart-hook-*.sh` est vidé entre deux SessionStart (`/clear`, `resume`) : `session-start` le vide
   lui-même avant tout, pour ne pas garder le jeton d'un démarrage précédent (relecture de la PR #143).
5. Hors Bash, Claude Code ne relit que des affectations simples : `# marqueur` sur sa propre ligne,
   `export GH_TOKEN='…'`, et `export GH_TOKEN=` (vide, que gh traite comme absent) à la place de `unset`.
6. Entrée de `CwdChanged` : `old_cwd`, `new_cwd`. Les dossiers de session sont en 755 : le fichier du jeton se
   met en 600.
7. Un `systemMessage` rendu par un hook `CwdChanged` s'affiche-t-il ? Constaté le 2026-11-17 en `claude -p
   --settings` (hook déclaré par les réglages) : le hook part après le `cd` et le debug montre `Parsed initial
   response: {"systemMessage":…}`, mais aucun message n'apparaît dans le flux `stream-json`. Tranché par la recette
   du 2026-11-18 en session interactive : le message de `CwdChanged` ne s'affiche pas non plus, celui de
   `SessionStart` si. Un compte non connecté après un `cd` ne se dit qu'au démarrage d'une session dans ce dépôt.

## Conception

Le script reste en bash (décision de l'utilisateur) : `profile.sh` est déplacé dans le plugin avec ses 31 tests,
`secretEnv` et la télémétrie, et y gagne `cwd-changed` et l'export du jeton. Le Node de harnais n'est pas repris.

1. **Plugin** `mods/profile/` : `.claude-plugin/plugin.json`, `hooks/hooks.json` (`SessionStart` →
   `scripts/profile.sh session-start`), `skills/profile/SKILL.md`, `scripts/profile.sh`,
   `profiles.example.json`. Déclaré dans `.claude-plugin/marketplace.json`, activé dans `settings/base.json`
   (`profile@claude-config`).
2. **Profils** : lus dans `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/profiles.json` (variable `PROFILES_FILE` gardée
   pour les tests). Sur ce poste, `claude-config install` y lie déjà `global/profiles.json` : rien ne change pour
   les profils perso. Fichier absent : toutes les sous-commandes et les hooks ne font rien, sauf `apply`, qui
   échoue avec un message. Chaque profil est un objet ; `owners` une liste de noms ; `enabledPlugins`,
   `skillOverrides`, `env`, `secretEnv` des objets ; `account` de la forme `[A-Za-z0-9-]+` ; un propriétaire dans
   deux profils est une erreur. Message qui nomme le profil.
3. **Chemin stable** : `global/profile.sh` devient un lien symbolique vers `../mods/profile/scripts/profile.sh`.
   `~/.claude/profile.sh` (installé par `claude-config install`) reste le point d'entrée des skills (`pr`,
   `notify`, `release`, `todo`, `pr-risk`), de `statusline-gh.sh` et du hook `CwdChanged`.
4. **Hooks** :
   - `SessionStart` (plugin) : comme aujourd'hui, applique le profil détecté si le projet n'en a pas ; puis écrit
     dans `CLAUDE_ENV_FILE` `# claude-config-profile` et `export GH_TOKEN='<jeton>'` du compte du profil détecté
     (`gh auth token -u <compte>`), fichier passé en 600 avant d'y écrire (échec : aucun `export`, message).
     Compte non connecté : aucun `export`, message qui nomme le compte et `gh auth login` ; gh absent : message
     « gh introuvable ». Jeton hors `[A-Za-z0-9_-]+` : refusé, message. Dans un dépôt à profil, le jeton
     de session remplace un `GH_TOKEN` du dev (constat 1) : c'est voulu, le compte suit le dépôt.
   - `CwdChanged` (dans `settings/base.json`, vers `bash ~/.claude/profile.sh cwd-changed`) : recalcule le compte
     de `new_cwd` et réécrit le jeton ; dossier hors dépôt git : compte de `old_cwd` (correctif du 2026-11-19 :
     Claude Code annule un `cd` hors des dossiers de travail sans relancer le hook, le jeton vidé pour `/tmp` restait
     vide dans le dépôt) ; dépôt sans profil, `old_cwd` sans profil ou compte non connecté : `export GH_TOKEN=`, si
     un hook du plugin a posé un jeton dans la session (marqueur présent) ; un `GH_TOKEN` du dev n'est touché que
     là où un profil s'applique. Compte non connecté : message qui nomme le compte, non affiché (constat 7).
     `profiles.json` mal formé ou git en échec : traité comme un compte non connecté (vidé si marqueur, message),
     pour ne pas garder le compte du dépôt précédent (décision de l'utilisateur, revue du plan).
   - Le `SessionStart` du plugin n'a pas de matcher : le jeton revient après `/clear`, `resume` et `compact`
     (décision de l'utilisateur, revue du plan).
   - Le compte suit toujours le profil **détecté**, même quand le profil appliqué en diffère.
   - Échec de git autre que « pas un dépôt » ou « pas de origin » (propriété douteuse, git absent) : message au
     démarrage, pas de silence.
   - Le hook `SessionStart` de `settings/base.json` vers `profile.sh session-start` est retiré (le plugin le porte).
     L'invariant de `docs/domaine.md` « tout hook voulu sur la machine figure dans `base.json` » devient « … ou dans
     un plugin activé par `base.json` ».

   - **Copies du script** (décision de l'utilisateur) : le hook `SessionStart` et le skill du plugin passent par
     `${CLAUDE_PLUGIN_ROOT}/scripts/profile.sh` (copie du cache marketplace) ; le hook `CwdChanged` de
     `base.json` passe par `~/.claude/profile.sh` (arbre du dépôt). Deux versions peuvent donc se croiser : le
     marqueur `# claude-config-profile` et le format du fichier d'env sont un contrat, testé (`cwd-changed`
     reconnaît un fichier écrit par `session-start`) et gardé stable d'une version à l'autre.
   - **Livraison** (décision de l'utilisateur) : entre le merge, qui retire le `SessionStart` de `base.json`, et
     `claude plugin update`, aucun profil ne s'applique au démarrage. Trou accepté : la PR donne l'étape
     `claude plugin update profile@claude-config` après `claude-config install`.
5. **Skill `/profile`** : celui de `global/skills/profile`, déplacé dans le plugin et `global/skills/profile`
   supprimé. Il garde la colonne Télémétrie et la section « Jeton Exploradora ». La phrase « Rien ne l'ajoute tout
   seul : une commande `gh` sans jeton prend le compte actif » devient « Le plugin exporte le jeton de session ; une
   commande sans préfixe prend le compte du profil du dossier courant, ou le compte actif hors profil. » Il ajoute :
   `GH_TOKEN` absent de la session alors qu'un compte est attendu (tester `[ -n "$GH_TOKEN" ]` sans l'afficher) ;
   erreur `profile.sh` →
   la rapporter et s'arrêter ; « detected dubious ownership » → proposer `git config --global --add
   safe.directory` ; sans `profiles.json` → proposer de le créer depuis l'exemple et `gh auth status` ; profil
   détecté vide → l'écrire « aucun » et proposer d'ajouter le propriétaire au bon profil (repris du skill
   harnais, décision de review).

Le préfixe `GH_TOKEN=$(gh auth token -u …)` des skills `pr`, `notify`, `release`, `todo`, `pr-risk` et de
`CLAUDE.md` est gardé dans ce lot (décision de l'utilisateur) : il sert encore quand le hook n'a pas tourné. Son
retrait, une fois le hook éprouvé, va au reste à faire.

## 2. Portée

| Endroit | Ce qu'il devient |
|---|---|
| `global/profile.sh` | Lien vers `mods/profile/scripts/profile.sh` ; le script gagne `cwd-changed`, l'export du jeton, la validation des profils, le chemin `profiles.json` du dossier de config |
| `global/profiles.json` | Inchangé (lié à `~/.claude/profiles.json`) |
| `deps.sh` (`enabled_plugin_ids`), `tests/test_deps.sh` | Inchangés : lisent `global/profiles.json` du dépôt pour installer les plugins des profils |
| `tests/test_profile.sh` sans `PROFILES_FILE` | Lisaient le `profiles.json` voisin du script ; le défaut devient le dossier de config : le test fixe `PROFILES_FILE` (ou `CLAUDE_CONFIG_DIR` jetable) pour ne jamais lire `~/.claude` |
| `docs/reste-a-faire.md` (point 3) | Inchangé : cite `session_start`, qui garde son nom |
| `global/skills/profile/` | Supprimé, déplacé dans `mods/profile/skills/profile/` |
| `~/.claude/skills/profile` | Lien orphelin après la suppression : à retirer (`install` ne nettoie pas), dit dans la PR |
| `settings/base.json` | `SessionStart` `profile.sh session-start` retiré ; `CwdChanged` ajouté ; `profile@claude-config` activé |
| `.claude-plugin/marketplace.json` | Entrée `profile`, source `./mods/profile` |
| `global/statusline-gh.sh` | Inchangé : appelle `profile.sh account` à côté de lui-même, le lien suit |
| Skills `pr`, `notify`, `release`, `todo`, `pr-risk` | Inchangés : `bash ~/.claude/profile.sh account` (selon la question « préfixe ») |
| `tests/test_profile.sh` | Chemin du script inchangé (lien) ; tests ajoutés (critères ci-dessous) |
| `tests/test_settings.sh` | `test_base_settings_profile_hook` change : `CwdChanged` présent, `SessionStart` profil absent |
| `tests/test_statusline.sh` | `run_statusline` fixe `PROFILES_FILE` sur `global/profiles.json` (le défaut ne suit plus le script) ; son faux `gh` passe dans `tests/helpers.sh` pour `test_profile.sh` |
| `tests/helpers.sh` | `setup_sandbox` retire `CLAUDE_CONFIG_DIR` et `CLAUDE_ENV_FILE` hérités : un test ne lit ni n'écrit la vraie config |
| `README.md`, `docs/domaine.md` | Chemins du script et du skill mis à jour ; glossaire : « jeton de session », invariant des hooks |
| `CLAUDE.md` | Inchangé : cite `~/.claude/profile.sh`, chemin gardé |

Le plugin arrive par le marketplace GitHub : il ne tourne qu'une fois mergé sur `main` et mis à jour. Avant, la
recette passe par `claude --plugin-dir mods/profile`.

## 3. Données existantes

- Projets déjà passés en vidal ou perso : `settings.local.json` inchangé ; le jeton s'exporte dès la session suivante.
- `profiles.json` actuel : valide pour la nouvelle validation (vérifié par un test sur le fichier du dépôt).

## 4. Critères d'acceptation

**P1 : le compte gh suit le dépôt.**
- Démarrage dans un dépôt `softwarevidal` : fichier d'env en 600 avec le jeton de `brondon-ung`.
- `cd` vers un dépôt `Dahiorus` : jeton de `Dahiorus` ; vers `/tmp` : compte du dossier quitté ; vers un dépôt sans
  profil : vidé ; vers un dépôt dont le compte n'a pas de jeton : vidé, message qui nomme le compte.
- Démarrage hors profil (`~/IdeaProjects`) : rien d'exporté ; `cd` vers un dépôt vidal → jeton de `brondon-ung` ;
  puis `cd /tmp` → jeton de `brondon-ung` (dossier quitté). Démarrage hors profil puis `cd /tmp` → rien d'écrit
  (Claude Code vide le fichier `cwdchanged` : `GH_TOKEN` d'origine).
  « Un hook du plugin a posé un jeton » se lit au marqueur dans les fichiers `sessionstart-hook-*.sh` du dossier
  de `CLAUDE_ENV_FILE`.
- Combinés : profil appliqué perso dans un dépôt vidal → plugins perso, compte `brondon-ung` ; `GH_TOKEN` du dev,
  démarrage et `cd` hors profil → pas touché ; fichier d'env déjà créé en 644 → 600.
- Refus : compte non connecté au démarrage → message, aucun export ; jeton hors format → message ; git en panne →
  message ; `profiles.json` mal formé (profil non objet, `owners` chaîne, section non objet) → message qui nomme le
  profil, rien d'appliqué ; propriétaire dans deux profils → message qui nomme les deux ; sans `profiles.json` →
  rien.

**P2 : le skill et le profil dans le plugin.**
- `/profile` affiche profil appliqué, détecté, compte gh, télémétrie ; `/profile perso` applique et demande de
  relancer ; une 2e fois, rien à relancer ; `apply` sans `profiles.json` → code 1 et message.
- Tous les tests existants de `test_profile.sh` restent verts (secretEnv, télémétrie, exclusion git).

## 5. Filet sur l'existant

`profile.sh` est couvert par `tests/test_profile.sh` (detect, account, apply, session-start, secretEnv,
télémétrie). Rien à ajouter avant de le déplacer : le premier commit déplace le fichier et pose le lien, suite verte.

## 6. Origine

- Bascule automatique du compte : demande de l'utilisateur, reprise de harnais `feat/profils-projet` (PR #30
  fermée, code non repris).
- Validation des profils, git en panne, fichier en 600, vidage après `cd` : correctifs de review de harnais
  (I1, M1-M4, P1-P2, I3), *défauts anciens* de `profile.sh` pour la validation.

## 7. Dette du code touché

- `session_start` (`profile.sh`) grossit avec l'export du jeton : en extraire `write_token` (*corrigé dans cette PR*).
- `profile.sh` passe 200 lignes avec `cwd-changed` : *reporté au reste à faire* si la suite le dépasse de plus de
  quelques lignes.
