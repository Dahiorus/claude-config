---
name: release
description: Use when the user invokes /release, or asks to release, publish or ship a new version of the project (« lance une release », « déploiement de version », « publie la 1.8.1 », « nouvelle version », « sors une RC », « release candidate de la 1.2.0 »).
argument-hint: "[correctif|mineur|majeur|<version>] [rc]"
---

# Release

La procédure de livraison du projet fait foi : `git ls-files | grep -iE '(^|/)(livraison|release|releasing)\.md$'`,
sinon la section de livraison de AGENTS.md ou CLAUDE.md. Aucune → le dire et s'arrêter, sans improviser de
procédure. Ce skill l'enchaîne de bout en bout. L'invocation vaut accord pour pousser la PR de version, la merger et
pousser le tag ; le reste attend l'accord de l'utilisateur, même quand la procédure le prescrit (retirer un tag,
recommencer).

1. **Version** — l'argument ; sinon d'après les commits depuis la dernière version finale
   (`git describe --tags --abbrev=0 --exclude '*-rc.*'`, après `git fetch --tags origin`) : `💥` ou `BREAKING CHANGE`
   → majeur, un `✨` → mineur, sinon correctif. Aucun commit depuis le dernier tag (`git describe --tags --abbrev=0`)
   → le dire et s'arrêter. Que des commits sans effet sur le livrable (`📝`, `✅`, `👷`…) → le dire et demander avant
   de continuer. Annoncer la version et les commits qu'elle embarque.
   - **Release candidate** — `rc` dans la demande (« une RC de la 1.2.0 », `/release mineur rc`) : la version
     calculée prend le suffixe `-rc.<n>` (format de la procédure, sinon `-rc.<n>`), `<n>` = la plus haute RC déjà
     taguée pour cette version + 1, sinon 1. Procédure sans release candidates → le dire et s'arrêter.
   - Dernier tag = une RC (`v1.2.0-rc.2`) et pas de `rc` dans la demande → proposer la version finale `1.2.0`
     plutôt qu'un nouveau calcul, et attendre l'accord.
2. **PR de version** — branche (nom de la procédure, sinon `build/version-<version>`) depuis `origin/main` à jour ;
   branche ou PR déjà là → la reprendre, sans en recréer. Monter la version là où la procédure l'indique (compteurs
   compris, comme le `versionCode` Android), commit au format de la procédure, complété par celui de
   `CONTRIBUTING.md` et la ligne d'attribution, puis `/pr push`.
3. **Merge** — `/pr <n°> merge` (il attend la CI de la PR). CI rouge ou relecture demandée → s'arrêter et rapporter.
4. **Tag** — `main` à jour, vérifier que `HEAD` porte la nouvelle version (le fichier monté à l'étape 2), tag au
   format de la procédure (`v<version>` par défaut), push du tag, puis `gh run watch` sur le workflow qu'il déclenche.
   Échec → rapporter avec le lien du run, sans retirer le tag ni recommencer.
5. **Rapport** — version, lien de la release publiée (une RC doit sortir en pré-version : sinon le signaler), branches
   supprimées. Si la procédure a une checklist avant diffusion, la rappeler et proposer de la dérouler (sur l'appareil
   branché pour une app mobile, `adb devices` ; aucun → le dire) : elle se fait avant de diffuser le lien.

Compte : celui de la mémoire du projet, comme pour `/pr`, jamais `gh auth switch`. Pour `gh`,
`GH_TOKEN=$(gh auth token -u <compte>)` ; pour `git fetch` et `git push`, qui ignorent `GH_TOKEN`,
`git -c credential.helper= -c "credential.helper=!f(){ echo username=<compte>; echo password=$(gh auth token -u <compte>); }; f" …`.
Aucun compte en mémoire et accès refusé → demander lequel utiliser.
