# Profils par projet (vidal, perso)

## 1. Demande initiale

> « j'imagine aussi un plugin qui permet de switch entre des profiles qui activent ou non des skills (jira, sonarqube
> par exemple) et de compte gh en fonction du projet, je vois 2 profils : vidal pour le développement des projets
> Vidal avec le compte brondon-ung, et perso avec le compte Dahiorus sur des projets qui n'ont pas accès aux outils
> vidal »

Précisions données ensuite :
- le profil se reconnaît au dépôt GitHub du projet ; `Dahiorus` et `tuonick` sont perso ;
- ce qui gêne : changer de compte gh pour agir sur ses projets, et couper des plugins à la main pour alléger le
  contexte ;
- dépôt d'un autre propriétaire ou projet local : « je déciderai au moment voulu » ;
- contenu des profils : `php-lsp` perso seulement (GECCO), `typescript-lsp` et `angular-developer` vidal, `sonarqube`
  vidal, `github` « n'a pas l'air d'être utilisé (peut-être à supprimer) », `code-simplifier` inutile (`/simplify` et
  ponytail couvrent), `skill-creator` seulement à la création d'un skill ;
- « commence le développement du skill /profile et son branchement » (forme validée : hook au démarrage, skill
  `/profile`, réécriture des commandes gh dans le hook Bash, retirée en recette (voir §2 « Compte gh »), tout dans claude-config, sans plugin séparé).

## 2. Portée

### Les profils

Nouveau fichier `global/profiles.json` (lié dans `~/.claude/` comme le reste de `global/`) :

```json
{
  "vidal": {
    "owners": ["softwarevidal"],
    "account": "brondon-ung",
    "enabledPlugins": {
      "atlassian@claude-plugins-official": true,
      "jk@harnais": true,
      "sonarqube@claude-plugins-official": true,
      "typescript-lsp@claude-plugins-official": true,
      "php-lsp@claude-plugins-official": false
    },
    "skillOverrides": {}
  },
  "perso": {
    "owners": ["Dahiorus", "tuonick"],
    "account": "Dahiorus",
    "enabledPlugins": {
      "atlassian@claude-plugins-official": false,
      "jk@harnais": false,
      "sonarqube@claude-plugins-official": false,
      "typescript-lsp@claude-plugins-official": false,
      "php-lsp@claude-plugins-official": true
    },
    "skillOverrides": { "angular-developer": "off" }
  }
}
```

Un propriétaire absent des deux listes, ou un projet sans `origin` GitHub : aucun profil, configuration globale
inchangée.

### Endroits touchés

| Endroit | Ce qu'il devient |
|---|---|
| `global/profiles.json` | Nouveau, contenu ci-dessus |
| `global/profile.sh` | Nouveau script, cinq commandes : `detect` (nom du profil d'après `origin`, vide sinon), `apply <profil>` (écrit le profil dans le projet), `account` (compte gh du profil du dossier courant, vide sinon), `current` (profil appliqué dans `settings.local.json`, vide sinon), `session-start` (le hook de démarrage) |
| `settings/base.json`, `hooks.SessionStart` | Une entrée ajoutée, matcher `startup`, qui lance `bash ~/.claude/profile.sh session-start` : profil détecté et projet sans profil → `apply`, puis `systemMessage` « Profil <nom> appliqué à ce projet : relance la session pour l'alléger ». Projet qui a déjà un profil, ou aucun profil détecté → rien |
| `settings/base.json`, `enabledPlugins` | `github@claude-plugins-official` passe à `false` (coupé partout, sans désinstallation). `jdtls-lsp@claude-plugins-official` ajouté à `true` dans la configuration globale, pour les projets Java vidal comme perso ; le binaire jdtls reste à installer à la main. Le reste inchangé : c'est la configuration des projets sans profil |
| `global/bash-rewrite-hook.sh` | Inchangé. Le préfixe `GH_TOKEN` prévu d'abord a été retiré après recette (voir « Compte gh ») |
| `global/skills/profile/SKILL.md` | Nouveau skill `/profile` : sans argument, affiche le profil du projet (appliqué, détecté) et le compte gh qui en découle ; `/profile vidal\|perso` l'applique à la main (projet local ou inconnu), puis demande de relancer la session |
| `global/skills/pr/SKILL.md` l.16-17, l.143-144 | La consigne « compte indiqué par la mémoire du projet (jeton ponctuel …) » devient « le compte gh vient du profil du projet (`/profile`) ; projet sans profil : compte actif » |
| `global/skills/feature/SKILL.md` l.28 (étape 8), l.46 (`report`) | Même remplacement |
| `global/skills/release/SKILL.md` l.37-40 | Même remplacement, la recette `credential.helper` disparaît ; « aucun compte en mémoire » devient « projet sans profil » |
| `global/skills/todo/SKILL.md` l.37-39 | Même remplacement |
| `global/skills/notify/SKILL.md` l.28-29 | Même remplacement |
| `global/statusline-command.sh` l.144-156 | Inchangé : il trouve seul le compte qui voit le dépôt, avec cache, et ne passe pas par le hook Bash |
| `deps.sh`, `ensure_plugins` (l.77-107) | Installe aussi les plugins à `true` dans un profil de `global/profiles.json`, en plus de ceux de `settings.json` : un plugin coupé globalement mais activé par un profil (`sonarqube`) doit être installé pour que le profil l'active. Test dans `tests/test_deps.sh` |
| `tests/run.sh` (shellcheck) | `global/profile.sh` ajouté à la liste |
| `README.md` | Une ligne sur les profils et `/profile` |
| Mémoire `gh-account-push` | Réécrite après le merge : le profil perso remplace la commande à rallonge |

### Ce qu'écrit `apply`

Dans `<racine du projet>/.claude/settings.local.json`, fusion avec le contenu existant (jamais écrasé) :
`enabledPlugins` et `skillOverrides` du profil, plus `env.CLAUDE_PROFILE = "<nom>"`, qui sert de marque « profil
appliqué ». Puis `.claude/settings.local.json` ajouté à `.git/info/exclude` s'il n'est ignoré ni par `.gitignore` ni
par `exclude`, pour que le fichier n'apparaisse pas dans `git status` du projet.

### Compte gh

`account` lit `origin` depuis le dossier de la commande et renvoie le compte du profil détecté, pas de celui écrit
dans `settings.local.json` : un worktree, où ce fichier n'existe pas, prend le bon compte. Décision : le compte suit le
propriétaire du dépôt, pas le profil appliqué. Le compte actif de gh (`gh auth switch`) n'est jamais changé.

Rien n'ajoute le compte tout seul aux commandes. Les skills (`pr`, `feature`, `release`, `todo`, `notify`) le lisent
par `account` et le passent en jeton ponctuel, écrit dans la commande : `GH_TOKEN=$(gh auth token -u <compte>)`
devant `gh` comme devant `git push`, parce que le credential helper global est `gh auth git-credential`
(`~/.gitconfig`). `GH_TOKEN` n'agit sur `git push`/`fetch` qu'en HTTPS ; avec un remote SSH (`git@github.com:`,
`ssh://`), c'est la clé SSH qui choisit l'identité. Une commande `gh` sans jeton prend le compte actif.

Décision prise en recette (2026-11-04) : le hook Bash ne préfixe plus les commandes. Le préfixe
`export GH_TOKEN="$(gh auth token -u <compte>)"; ` ajouté par le hook était refusé : en mode auto, le classifieur juge
la commande avant le hook et refuse la version modifiée (« a hook changed this call's input after auto mode reviewed
it ») pour toute commande qui écrit (`git fetch`, `git push`, `gh pr create`) ; en session `EnterWorktree`, toute
valeur calculée à l'exécution est refusée, `gh` comme `git`. Écartés : `permissionDecision: "allow"` dans le hook
(toute commande git/gh passerait sans contrôle) ; un `GH_CONFIG_DIR` par profil (gh ne change de compte qu'avec le
jeton écrit en clair dans `hosts.yml`, le trousseau n'a qu'un jeton actif par hôte). Un jeton écrit dans la commande
est vu par le classifieur, qui le juge. En session `EnterWorktree`, il est refusé aussi : en sortir avant de pousser.

## 3. Données existantes

- `.claude/settings.local.json` déjà présent (permissions accordées pendant les sessions) : ses clés sont gardées ;
  seules `enabledPlugins`, `skillOverrides` et `env.CLAUDE_PROFILE` reçoivent les valeurs du profil, clé par clé.
  Fichier illisible (JSON invalide) → `apply` s'arrête sans rien écrire et le dit.
- Projet qui a déjà `env.CLAUDE_PROFILE` : le hook de démarrage n'y touche plus, même si `origin` change. Seul
  `/profile <nom>` le réécrit.
- Projets existants sans profil : profil appliqué à leur prochain démarrage de session, une fois.

## 4. Critères d'acceptation

Une seule story : profil détecté, appliqué et utilisé, plugins et compte ensemble.

**P1 — le projet prend son profil tout seul**

Nominal :
1. Session lancée dans un dépôt `Dahiorus/*` sans profil → `settings.local.json` reçoit les plugins perso et
   `CLAUDE_PROFILE=perso`, message « relance la session » affiché une fois. Session suivante : `atlassian`, `jk`,
   `sonarqube`, `typescript-lsp` absents, `php-lsp` présent.
2. Même chose dans un dépôt `softwarevidal/*` avec le profil vidal.
3. Dans un projet perso, `bash ~/.claude/profile.sh account` renvoie Dahiorus, et les skills poussent et ouvrent la
   PR avec ce compte (jeton ponctuel), même si le compte actif de gh est brondon-ung. Inverse dans un projet vidal.
4. `/profile` affiche le profil appliqué et le profil détecté ; `/profile perso` dans un projet local l'applique.

Refus et cas limites :
5. Dépôt d'un autre propriétaire, ou sans `origin` → aucun fichier écrit, aucun message, `account` vide.
6. `/profile inconnu` → refus avec la liste des profils.
7. `settings.local.json` invalide → rien écrit, message d'erreur.

8bis. `claude-config install` installe `sonarqube` même s'il est à `false` dans `settings/base.json`, parce que le
   profil vidal l'active.

Cas combinés :
8. `settings.local.json` avec des permissions + profil appliqué → permissions intactes, plugins ajoutés.
9. Projet perso marqué à la main `/profile vidal` → le démarrage ne le remet pas en perso ; `account` renvoie
   quand même le compte du propriétaire du dépôt (Dahiorus), parce que le compte suit `origin`.
10. Worktree d'un projet perso → le fichier du worktree reçoit son profil au premier démarrage dedans ; `account`
    renvoie Dahiorus.
11. Retiré avec le préfixe du hook (voir §2 « Compte gh »).

## 5. Filet sur l'existant

- `settings/base.json` est couvert par `tests/test_settings.sh` ; la nouvelle entrée `SessionStart` ne demande pas de
  test de caractérisation.

## 6. Origine

- Demande de l'utilisateur dans cette session (2026-11-04), après la revue des automatisations possibles.
- Hors périmètre : brancher `pr-review-toolkit` sur `/pr review` (à trancher plus tard)  ; détecter le compte dans `statusline-command.sh` par le profil.

## 7. Dette du code touché

- Aucune : `global/bash-rewrite-hook.sh`, seul script existant qui devait changer, reste inchangé (préfixe retiré).
