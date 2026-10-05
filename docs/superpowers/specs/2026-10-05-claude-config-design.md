# claude-config — Design

Date : 2026-10-05
Statut : en revue

## 1. Objectif

Regrouper la configuration personnelle de Claude Code dans un repo git afin de :

1. **Synchroniser** la config entre plusieurs machines (Linux, WSL).
2. **Bootstrapper** une config Claude dans de nouveaux repos à partir de templates.
3. **Versionner** la config pour suivre ses évolutions et pouvoir revenir en arrière.

Hors périmètre : partage avec une équipe, packaging en plugin/marketplace, macOS, Windows natif.

**Critère de succès** : sur un poste vierge, `git clone` + `bin/claude-config install` reproduit
l'environnement Claude ; dans un repo, `bin/claude-config init-project <dir>` y pose la config projet.

## 2. Hébergement et emplacement

- Remote : repo GitHub **privé** `Dahiorus/claude-config`.
- Clone local de référence : `~/IdeaProjects/claude-config` (le script fonctionne quel que soit
  l'emplacement du clone).

## 3. Périmètre de la config

### 3.1 Versionné

| Élément (dans le repo)            | Destination                          | Mode            |
|-----------------------------------|--------------------------------------|-----------------|
| `global/CLAUDE.md`                | `$CLAUDE_HOME/CLAUDE.md`             | symlink         |
| `global/RTK.md`                   | `$CLAUDE_HOME/RTK.md`                | symlink         |
| `global/statusline-command.sh`    | `$CLAUDE_HOME/statusline-command.sh` | symlink         |
| `global/skills/<skill>/`          | `$CLAUDE_HOME/skills/<skill>`        | symlink par skill |
| `settings/base.json` (+ `local.json`) | `$CLAUDE_HOME/settings.json`     | fusion `jq`, **copie** |
| `deps.sh`                         | —                                    | exécuté par `install` |
| `templates/<nom>/`                | racine du repo cible                 | copie via `init-project` |

`$CLAUDE_HOME` vaut `~/.claude` par défaut.

### 3.2 Dépendances externes (déclarées, non copiées)

Ces éléments sont installés par leur propre outil ; le repo ne contient que la commande qui les installe
(dans `deps.sh`) :

| Dépendance | Présence testée | Installation |
|---|---|---|
| `jq` | `command -v jq` | non automatisée : erreur bloquante avec un message (`sudo apt install jq`) |
| `shellcheck` | `command -v shellcheck` | non automatisée : utilisé par les tests seulement |
| `rtk` (binaire) | `command -v rtk` | `brew install rtk` si `brew` est disponible, sinon le script officiel `curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh \| sh` |
| Plannotator (CLI + skills `plannotator*`) | `command -v plannotator` | `curl -fsSL https://plannotator.ai/install.sh \| bash` |
| skill `angular-developer` | `$CLAUDE_HOME/skills/angular-developer` existe | `npx skills add affaan-m/ecc --skill angular-developer -g -a claude-code -y` (source relevée dans `~/.agents/.skill-lock.json` ; flags exacts à confirmer avec `npx skills --help` pendant l'implémentation) |
| Plugins Claude Code | `claude plugin list` | `claude plugin marketplace add` pour chaque entrée de `extraKnownMarketplaces`, puis `claude plugin install <nom>` pour chaque clé de `enabledPlugins` absente (syntaxe exacte du CLI `claude plugin` à confirmer) |

**rtk** : on n'exécute **pas** `rtk init -g`. Le hook `PreToolUse` et `RTK.md` sont déjà gérés par le
repo (`settings/base.json` et `global/RTK.md`). Lancer `rtk init` réécrirait ces fichiers et créerait un
écart avec le repo.

**Plugin Plannotator** : il est déclaré dans `settings/base.json` :

```json
"extraKnownMarketplaces": {
  "plannotator": { "source": { "source": "github", "repo": "backnotprop/plannotator" } }
},
"enabledPlugins": { "plannotator@plannotator": true }
```

Il est ensuite installé par l'étape « Plugins Claude Code ». L'ordre compte : la CLI d'abord, le plugin
ensuite.

### 3.3 Jamais versionné

`.gitignore` du repo (garde-fou) : `.credentials.json`, `history.jsonl`, `projects/`, `sessions/`,
`session-env/`, `shell-snapshots/`, `file-history/`, `plugins/`, `cache/`, `skills/synced/`,
`policy-limits*`, `stats-cache.json`, `*.bak`, `*.bak-*`, `settings/local.json`.

Le script ne lit ni n'écrit aucun de ces fichiers.

## 4. Arborescence

```
claude-config/
  README.md
  .gitignore
  bin/claude-config
  deps.sh
  global/
    CLAUDE.md
    RTK.md
    statusline-command.sh
    skills/.gitkeep
  settings/
    base.json
  templates/
    default/
      .claude/settings.json
      CLAUDE.md
  tests/
    run.sh
  docs/superpowers/specs/
```

## 5. Settings

### 5.1 Sources

- `settings/base.json` : toute la config commune, y compris `enabledPlugins` (Atlassian, Sonar inclus) et
  le bloc `autoMode` actuel. Pas de profils.
- `settings/local.json` : facultatif, ignoré par git, surcharges propres à une machine.

### 5.2 Fusion

`jq -s '.[0] * .[1]' base.json local.json` (ou `base.json` seul si `local.json` est absent) :
fusion profonde des objets, remplacement des tableaux et des scalaires par la valeur de `local.json`.

### 5.3 Pourquoi une copie et non un symlink

Claude Code réécrit `settings.json` lui-même (`/config`, activation de plugins…). Ces écritures casseraient
un symlink ou passeraient inaperçues ; on choisit donc une copie générée, avec un retour explicite via
`capture`.

### 5.4 Chemins

Les chemins sont écrits sous la forme `~/.claude/...` (ex. statusline) et restent portables tels quels.
Aucune substitution n'est nécessaire.

## 6. Script `bin/claude-config`

### 6.1 Interface

```
claude-config install [--dry-run] [--no-deps]
claude-config status
claude-config capture
claude-config init-project <dir> [--template <nom>] [--force]
```

- Bash, `set -euo pipefail`, dépendances : `jq`, `git` (coreutils supposés présents).
- Racine du repo calculée à partir de l'emplacement du script ; aucune variable obligatoire.
- `CLAUDE_HOME` surcharge la destination (défaut `~/.claude`), notamment pour les tests.
- Sortie : une ligne par action, avec un statut parmi `linked`, `ok`, `relinked`, `backup`, `skipped`,
  `written`, `warn`.
- Code de sortie non nul sur erreur bloquante (repo introuvable, `jq` absent, cible `init-project`
  inexistante, sous-commande inconnue).

### 6.2 `install`

1. Vérifie la présence de `jq`.
2. Pour chaque fichier de `global/` (hors `skills/`) et chaque dossier `global/skills/*` :

   | État de la destination          | Action                                         | Statut     |
   |---------------------------------|------------------------------------------------|------------|
   | absente                         | `ln -s`                                        | `linked`   |
   | symlink vers la bonne source    | rien                                           | `ok`       |
   | symlink vers autre chose        | remplacé                                       | `relinked` |
   | fichier ou dossier réel         | `mv` vers `<nom>.bak-<YYYYmmdd-HHMMSS>`, puis `ln -s` | `backup` + `linked` |

3. Génère les settings fusionnés. Si `$CLAUDE_HOME/settings.json` existe et diffère (comparaison
   `jq -S`), il est sauvegardé en `settings.json.bak-<date>` avant écriture (`written`) ; s'il est
   identique : `ok`.
4. Sauf `--no-deps` : source `deps.sh` et exécute `ensure_all`.
5. Ne touche jamais aux entrées de `$CLAUDE_HOME` qui ne correspondent à aucun élément du repo
   (ex. `skills/plannotator*`, `skills/synced`, `skills/angular-developer`).

`--dry-run` affiche les mêmes lignes sans rien modifier et sans exécuter `deps.sh`.

### 6.3 `status` (lecture seule)

- Pour chaque élément symlinké : `ok`, absent, cassé, ou pointant ailleurs.
- Settings : diff entre le fusionné attendu et le fichier réel, après normalisation `jq -S`.
- Code de sortie 0 si tout est conforme, 1 sinon.

### 6.4 `capture`

- Lit `$CLAUDE_HOME/settings.json`.
- Si `local.json` existe, pour chaque chemin feuille de `local.json` (chemin dont la valeur n'est pas un
  objet ; un tableau compte comme une feuille), le résultat reprend la valeur de `base.json` à ce chemin
  si elle existe, sinon le chemin est supprimé. Les surcharges locales ne remontent donc jamais dans la
  base, et la base ne perd pas ses propres valeurs.
- Écrit le résultat, formaté (`jq --indent 2`), dans `settings/base.json`.
- Affiche `git diff --stat settings/base.json`. **Aucun commit automatique.**

Limite assumée : si une clé de `local.json` a aussi été modifiée volontairement dans Claude Code,
la modification n'est pas remontée ; il faut alors éditer `base.json` à la main.

### 6.5 `init-project <dir>`

- `<dir>` doit exister (sinon erreur) ; un avertissement s'affiche si ce n'est pas un repo git.
- Copie récursive de `templates/<nom>/` (défaut `default`) vers `<dir>`.
- Fichier existant : conservé (`skipped (exists)`) ; avec `--force`, sauvegardé en `.bak-<date>` puis
  écrasé.
- Remplace le placeholder `{{PROJECT_NAME}}` du `CLAUDE.md` copié par `basename <dir>`.
- Si `<dir>/.gitignore` existe et ne contient pas `.claude/settings.local.json`, ajoute cette ligne.

## 7. `deps.sh`

- Fichier sourcé par `install`, qui définit les fonctions `ensure_rtk`, `ensure_plannotator`,
  `ensure_angular_developer` et `ensure_plugins`, puis une fonction `ensure_all` qui les appelle dans cet
  ordre (voir le tableau du §3.2). `jq` est vérifié par le script lui-même, avant `deps.sh`.
- `ensure_plugins` lit `extraKnownMarketplaces` et `enabledPlugins` dans les settings fusionnés ; il
  s'exécute donc après l'écriture de `settings.json`.
- Chaque fonction vérifie d'abord si la dépendance est présente (`command -v …`, présence du dossier
  du skill) et n'installe qu'en cas d'absence.
- Un échec produit un `warn` et n'interrompt pas `install` (sauf `jq`, déjà vérifié avant).
- Les points marqués « à confirmer » au §3.2 sont vérifiés avec le `--help` de chaque outil avant
  l'écriture du code.

## 8. Templates

`templates/default/` :

- `.claude/settings.json` :
  ```json
  { "permissions": { "deny": ["Read(./.env)", "Read(./.env.*)", "Read(./secrets/**)"] } }
  ```
- `CLAUDE.md` : squelette avec les sections `# {{PROJECT_NAME}}`, `## Stack`,
  `## Commandes` (build / test / lint) et `## Conventions`.

Pour ajouter un template, il suffit de créer `templates/<nom>/`, sans modifier le script.

## 9. Import initial depuis ce poste

Avant la première exécution, on copie l'existant dans le repo :

- `~/.claude/CLAUDE.md`, `RTK.md` et `statusline-command.sh` → `global/`
- `~/.claude/settings.json` → `settings/base.json`, avec en plus l'ajout de la marketplace et du plugin
  Plannotator (§3.2)

Le premier `install` sur ce poste sauvegarde ensuite les originaux en `.bak-<date>` et les remplace par
des symlinks vers un contenu identique.

## 10. Tests

`tests/run.sh` : runner bash minimal, sans dépendance. Chaque test s'exécute dans un `mktemp -d` avec
`CLAUDE_HOME` pointant dessus et `--no-deps`. Le vrai `~/.claude` n'est jamais touché.

Cas :

1. `install` sur un home vide crée tous les symlinks et le `settings.json` attendu.
2. Un second `install` est idempotent (statuts `ok` uniquement, aucun `.bak` créé).
3. `install` face à un fichier réel fait une sauvegarde `.bak-*`, puis crée le symlink.
4. Les entrées étrangères au repo (faux `skills/synced/`, faux `skills/other`) restent intactes.
5. La fusion avec un `local.json` est correcte : objet fusionné, scalaire surchargé.
6. `status` renvoie 0 quand tout est conforme et 1 après une modification manuelle de `settings.json`.
7. `capture` remonte une modification dans `base.json`. Une clé surchargée par `local.json` garde sa
   valeur de base, et une clé présente uniquement dans `local.json` n'apparaît pas dans la base.
8. `init-project` copie les fichiers, remplace `{{PROJECT_NAME}}`, conserve l'existant, honore `--force`
   et met à jour le `.gitignore`.
9. `--dry-run` ne modifie rien (arborescence identique avant et après).

Pour éviter de modifier `settings/base.json` réel, les tests travaillent sur une copie du repo dans
`mktemp -d`.

`shellcheck` est lancé sur `bin/claude-config`, `deps.sh` et `tests/run.sh`. Un avertissement est un échec.
Si l'outil est absent, l'étape est ignorée avec un message.

**Validation manuelle finale (ce poste)** : `install --dry-run`, relecture, `install`, `status` (doit
renvoyer 0), puis nouvelle session Claude pour vérifier la statusline, le hook RTK et la liste des
skills.
