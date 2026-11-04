# Glossaire du domaine

## Contexte : Profils

Responsabilité : dire quels réglages (plugins, skills, compte gh) valent pour un projet · Dans le code : `global/profile.sh`, `global/profiles.json`, skill `/profile` · Dépend de : rien (source amont des comptes gh)

| Terme | Définition métier | Dans le code | À ne pas dire |
|---|---|---|---|
| Profil | Ensemble de réglages propre à une famille de projets (vidal, perso) : plugins, skills, compte gh | clé de `profiles.json`, `env.CLAUDE_PROFILE` | configuration, environnement |
| Propriétaire du dépôt | Compte ou organisation GitHub qui possède le dépôt `origin` du projet | `origin_owner`, `owners` | organisation (seule), auteur |
| Profil détecté | Profil que désigne le propriétaire du dépôt | `profile.sh detect` | profil courant |
| Profil appliqué | Profil écrit dans les réglages locaux du projet, au démarrage ou à la main | `profile.sh current`, `CLAUDE_PROFILE` | profil actif |
| Compte du profil | Compte gh avec lequel on agit sur un projet, déduit du profil détecté | `profile.sh account`, `.account` | compte actif, compte courant |
| Compte actif | Compte gh par défaut de la machine, celui de `gh auth switch` | `gh auth status` (Active account) | compte du projet |
| Jeton ponctuel | Jeton d'un compte donné, passé à une seule commande ou un seul processus sans changer le compte actif | `GH_TOKEN=$(gh auth token -u <compte>)` | switch de compte |
| Projet sans profil | Projet dont le propriétaire n'est dans aucun profil, ou sans `origin` GitHub | `account` vide | projet inconnu |

Invariants : le compte du profil suit le propriétaire du dépôt, jamais le profil appliqué ; le compte actif n'est jamais changé ; un projet sans profil garde la configuration globale.

## Contexte : Statusline

Responsabilité : afficher l'état du projet (branche, PR, revue, CI, consommation) sans jamais bloquer · Dans le code : `global/statusline-command.sh` · Dépend de : Profils (en aval, via `profile.sh account`), GitHub (via `gh`)

| Terme | Définition métier | Dans le code | À ne pas dire |
|---|---|---|---|
| Compte de la statusline | Compte gh dont la statusline prend le jeton pour lire les PR du dépôt | `gh_user`, cache `ghuser-<dépôt>` | compte actif |
| Compte qui voit le dépôt | Repli quand le compte du profil manque (projet sans profil, compte invalide ou non connecté dans gh) : premier compte connecté de gh qui peut lire le dépôt. Sa recherche s'appelle la *sonde* | `probe_gh_user` (boucle sur `gh auth status` + `gh api repos/<dépôt>`), cache `ghuser-<dépôt>` | compte du profil |

Invariants : la statusline ne lit pas `profiles.json` elle-même, elle demande le compte à Profils ; elle ne change pas le compte actif (jeton ponctuel pour son seul processus).
