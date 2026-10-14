# claude-config

Ma configuration Claude Code versionnée : installation sur une machine Linux/WSL,
détection des écarts et bootstrap de nouveaux repos.

## Installation sur une nouvelle machine

```bash
git clone git@github.com:Dahiorus/claude-config.git ~/IdeaProjects/claude-config
cd ~/IdeaProjects/claude-config
bin/claude-config install --dry-run   # relire ce qui va changer
bin/claude-config install
ln -s "$PWD/bin/claude-config" ~/.local/bin/claude-config   # facultatif
```

Prérequis : `jq` et `git`. `install` s'occupe de rtk, build-brief, Plannotator, du skill
`angular-developer` et des plugins listés dans `settings/base.json`.

## Commandes

| Commande | Effet |
|---|---|
| `install [--dry-run] [--no-deps]` | Symlinke `global/*` dans `~/.claude`, génère `settings.json`, installe les dépendances |
| `status` | Liste les écarts entre le repo et `~/.claude` (code 1 en cas d'écart) |
| `capture` | Recopie `~/.claude/settings.json` dans `settings/base.json` (à relire avec `git diff`, puis à commiter) |
| `init-project <dir> [--template <nom>] [--force]` | Copie `templates/<nom>/` (défaut `default`) dans un repo |

Les fichiers existants sont toujours sauvegardés en `<nom>.bak-<date>` avant d'être remplacés.

## Où modifier quoi

- `CLAUDE.md`, `RTK.md`, statusline, skills perso : directement dans `global/` (ils sont symlinkés).
- Plugins perso : dans `mods/<nom>/`, déclarés dans `.claude-plugin/marketplace.json` et activés dans `settings/base.json` (`<nom>@claude-config`). Pas de dossier `plugins/` : ignoré par `.gitignore`.
- Settings : via Claude Code (`/config`…), puis `claude-config capture`. On peut aussi éditer
  `settings/base.json` à la main, puis lancer `claude-config install`.
- Surcharges propres à une machine : `settings/local.json` (non versionné), fusionné par-dessus la base.
- Nouveau template : créer `templates/<nom>/`. `{{PROJECT_NAME}}` y est remplacé par le nom du dossier cible.

## Jamais versionné

Credentials, historique, sessions, caches, `skills/synced/` : voir `.gitignore`.

## Tests

```bash
tests/run.sh           # tous les tests + shellcheck
tests/run.sh capture   # seulement les tests dont le nom contient « capture »
```
