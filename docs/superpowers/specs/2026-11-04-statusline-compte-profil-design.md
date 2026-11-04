# Statusline : compte gh du profil

Issue #70. Vocabulaire : `docs/domaine.md` (contextes Profils et Statusline).

## But

La statusline prend le **compte du profil** (`profile.sh account`) pour lire les PR, la revue et la CI d'un dépôt.
Elle ne cherche le **compte qui voit le dépôt** (boucle `gh api` sur chaque compte) que si le compte du profil
manque : **projet sans profil**, compte invalide ou non connecté dans gh. Une seule source dit quel compte utiliser, et un dépôt vidal ou perso ne coûte plus aucun appel réseau
pour le trouver.

Hors but : changer `profile.sh`, `profiles.json` ou le compte actif ; vérifier que le compte du profil voit
réellement le dépôt.

## 1. Demande initiale

Issue #70, « Statusline : lire le compte gh du profil » :

> `global/statusline-command.sh:144-156` cherche lui-même quel compte gh voit le dépôt. Il essaie chaque compte de
> `gh auth status` avec un appel `gh api repos/<dépôt>`, puis met le résultat en cache un jour. Depuis #68,
> `bash ~/.claude/profile.sh account` donne ce compte directement, d'après le propriétaire du dépôt.
>
> Au premier affichage d'un dépôt, et une fois par jour ensuite, la statusline lance jusqu'à un appel réseau par
> compte, avec 5 s de timeout chacun. Deux sources disent quel compte utiliser et peuvent se contredire.
>
> Piste : lire `profile.sh account` d'abord, et ne garder la boucle sur les comptes que pour un projet sans profil.

Demande de l'utilisateur : `/feature issue 70`.

## 2. Portée

### Règle : la statusline prend le compte du profil, la boucle n'est qu'un repli

| Endroit | Devient |
|---|---|
| `global/statusline-command.sh:144-157`, bloc « compte gh » | Appelle `profile.sh account "$cwd"` d'abord. Compte non vide → `gh_user` = ce compte, sans `gh auth status`, sans `gh api`, sans lire ni écrire le cache `ghuser-*`. Compte vide (projet sans profil, ou profil au compte invalide) → boucle actuelle, inchangée, avec son cache d'un jour |
| Localisation de `profile.sh` | À côté du script réel : `$(dirname "$(readlink -f "$0")")/profile.sh`, comme `profile.sh` trouve `profiles.json`. Installé, `~/.claude/statusline-command.sh` est un lien vers `global/`, donc le même fichier que `~/.claude/profile.sh` ; en test, le script du bac à sable trouve son `profile.sh` |
| Condition du bloc | Le compte du profil se lit dès que `cwd` est connu et `gh` installé, même sans `workspace.repo` (`fetch_threads_count` sait alors retrouver le dépôt seul). La boucle garde sa condition actuelle (`workspace.repo` connu) |
| `tests/run.sh`, liste shellcheck | Ajoute `global/statusline-command.sh` (décision du §7) |
| Erreurs de `profile.sh` | Sortie d'erreur jetée (`2>/dev/null`) : la statusline n'affiche jamais de message de `profile.sh`. Une sortie en échec compte comme « vide » |

Compte du profil non connecté dans gh (`gh auth token --user <compte>` en échec ou vide) : repli sur la boucle,
comme pour un projet sans profil. La boucle écrit alors son cache d'un jour pour ce projet.

Le compte du profil se relit à chaque affichage, sans cache (environ 75 ms) : une modification de `profiles.json`
vaut tout de suite, et la statusline n'a pas à connaître `profiles.json`.

### Lecteurs et écrivains touchés

| Donnée | Lecteurs / écrivains | Devient |
|---|---|---|
| `gh_user` | écrit par le bloc ; lu par la ligne `GH_TOKEN=$(gh auth token --user "$gh_user")` | Même usage, nouvelle source en premier |
| `GH_TOKEN` exporté | lu par `fetch_ci_state`, `fetch_threads_count`, `fetch_branch_pr`, `fetch_pr_state` (sous-processus de `cached`) | Inchangé : ils héritent du jeton comme aujourd'hui |
| Cache `$cache_dir/ghuser-<dépôt>` | lu et écrit par la boucle seule (aucun autre usage dans le dépôt) | Inchangé quand la boucle tourne ; ni lu ni écrit quand le compte du profil est connu |
| `profile.sh account` | appelé par les skills (`pr`, `feature`, `profile`, `release`, `todo`, `notify`) | Inchangé, un appelant de plus |
| `workspace.repo` (Claude Code) et `origin` du `cwd` | `ci_repo_full` vient du premier, le compte du profil du second | Ils désignent le même dépôt en pratique ; s'ils divergeaient, le compte suit `origin`, comme pour les skills |

Inchangés : `global/profile.sh`, `global/profiles.json`, `global/skills/profile/SKILL.md` (il décrit déjà la règle « le
compte suit le propriétaire »), `README.md`.

## 3. Données existantes

Aucune validation ajoutée. Les caches `ghuser-*` déjà écrits :

- compte du profil connu : ignorés, puisque le profil est lu avant eux. Un ancien cache qui désigne un autre compte ne
  masque donc pas le profil ;
- boucle en repli (projet sans profil, compte invalide ou non connecté) : relus comme aujourd'hui, renouvelés au bout d'un jour.

Rien à migrer ni à supprimer.

## 4. Critères d'acceptation

### P1 : la statusline suit le compte du profil

Une seule story : la demande ne se découpe pas.

Nominaux :

1. Dépôt d'un propriétaire perso (`origin` `github.com/Dahiorus/…`) : les appels `gh` de la statusline portent le
   jeton de `Dahiorus` ; aucun `gh auth status` ni `gh api repos/…` n'est lancé.
2. Dépôt vidal (`softwarevidal/…`) : idem avec `brondon-ung`.
3. Projet sans profil (propriétaire inconnu) : la boucle tourne comme aujourd'hui, le premier compte qui voit le
   dépôt est retenu et mis en cache un jour.

Refus et dégradés :

4. Pas d'`origin` GitHub et pas de `workspace.repo` : aucun jeton exporté, aucun appel pour trouver un compte.
5. `profile.sh` sort en erreur (compte invalide dans `profiles.json`) : rien ne s'affiche de son erreur, la boucle
   prend le relais.

Combinés :

6. Dépôt perso avec un cache `ghuser-*` de moins d'un jour qui désigne un autre compte : le compte du profil gagne,
   le cache n'est pas lu.
7. Compte du profil non connecté dans gh : la boucle prend le relais et écrit son cache, comme au critère 3.
8. Dossier du projet supprimé pendant la session (`cwd` introuvable) : les appels `gh` d'arrière-plan ne partent pas
   (shellcheck, §7).
9. Dépôt perso sans `workspace.repo` transmis : le jeton du profil est quand même exporté.

## 5. Filet sur l'existant

`global/statusline-command.sh` n'a aucun test. Avant de le modifier, un nouveau fichier `tests/test_statusline.sh`
fige le comportement actuel de la boucle, vert sur `main` :

- projet sans profil, deux comptes connectés dont le second seul voit le dépôt : le second est retenu, écrit dans le
  cache `ghuser-*`, et son jeton accompagne les appels `gh` suivants ;
- cache `ghuser-*` récent : aucun `gh api repos/…` lancé.

`gh` y est un faux exécutable placé en tête du `PATH`, qui journalise ses arguments et le `GH_TOKEN` reçu.

## 6. Origine

- Issue #70 : *hors périmètre* de la spec des profils (`docs/superpowers/specs/2026-11-04-profils-projet-design.md`,
  §6), PR #68.

## 7. Dette du code touché

Le bloc `global/statusline-command.sh:144-157` est modifié, plus les lignes que shellcheck relève (ci-dessous).

| Écart | Décision |
|---|---|
| Aucun test sur la statusline | Corrigé dans cette PR : `tests/test_statusline.sh` (§5) |
| Le bloc mêle deux niveaux d'imbrication (`if` > `if` > `for`) au niveau du script | Corrigé dans cette PR : la boucle passe dans une fonction `probe_gh_user` (repli), appelée seulement sans compte du profil |
| Le script dépasse 200 lignes (environ 238 avant la PR, 265 après) | Laissé tel quel : le dépassement précède la PR, et sortir la sélection du jeton dans un autre fichier ajouterait un `source` à chaque rafraîchissement de la statusline |

Shellcheck : `global/statusline-command.sh` entre dans la liste de `tests/run.sh` dans cette PR. Ses avertissements
actuels :

| Ligne | Avertissement | Décision |
|---|---|---|
| 91 (`cached`) | SC2164, `cd` sans repli | Corrigé : `cd … \|\| exit` dans le sous-processus, la commande ne tourne pas hors du dossier du projet (aujourd'hui elle tournerait dans le dossier courant de Claude Code) |
| 119 (`fetch_threads_count`) | SC2016, `$o`, `$n`, `$p` entre apostrophes | Directive `disable` : ce sont des variables GraphQL, pas du shell |
| 102, 114, 125, 137 | SC2329, fonctions `fetch_*` « jamais appelées » | Directive `disable` : elles sont appelées par `cached`, via `"$@"` |
