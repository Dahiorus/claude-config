---
name: profile
description: Use when the user invokes /profile, asks which profile, plugins or gh account a project uses, or wants to switch a project to the vidal or perso profile (« passe ce projet en perso », « quel profil ici ? »).
argument-hint: "[vidal|perso]"
---

# Profile

Un profil règle les plugins du projet et le compte gh selon le propriétaire du dépôt. Les profils vivent dans
`global/profiles.json` de claude-config.

## Sans argument

Lancer `bash ~/.claude/profile.sh current` et `bash ~/.claude/profile.sh detect` dans le dossier courant, plus
`bash ~/.claude/profile.sh account` pour le compte gh. Répondre par un tableau :

| Profil appliqué | Profil détecté | Compte gh |
|---|---|---|

## Avec un nom

Lancer `bash ~/.claude/profile.sh apply <nom>`. En cas d'erreur (profil inconnu, JSON invalide), la rapporter telle
quelle. Sinon, demander de relancer la session pour que les plugins changent.

## À savoir

- Le compte gh suit le propriétaire du dépôt (`bash ~/.claude/profile.sh account`) : les skills le passent en jeton ponctuel testé, en une commande : `t=$(gh auth token -u <compte>); [ -n "$t" ] && GH_TOKEN=$t gh …` (même forme devant `git push`, `git fetch` et `git pull`), jamais le jeton recopié en clair ; jeton vide → s'arrêter (gh prendrait le compte actif). Rien ne l'ajoute tout seul : une commande `gh` sans jeton prend le compte actif. Jamais `gh auth switch`.
- Pour modifier un profil, éditer `global/profiles.json` dans claude-config.
