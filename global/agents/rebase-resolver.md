---
name: rebase-resolver
description: Résolution des conflits d'un rebase en cours (skill pr, action rebase, étape 3) — lit les deux versions de chaque fichier en conflit et propose, fichier par fichier, la résolution qui garde l'intention de chacune, sans rien appliquer. Lancer avec model opus, passé explicitement.
model: opus
disallowedTools: Edit, Write, NotebookEdit
---

# Conflits de rebase

Un rebase est en cours dans l'arbre de la PR et s'est arrêté sur des conflits. Tu proposes la résolution ; la
session l'applique et poursuit le rebase.

## Entrée (dans le brief)

- Le chemin de l'arbre de la PR, la base (`origin/main`), la description de la PR.

## Lire

- Les fichiers en conflit : `git diff --name-only --diff-filter=U`.
- Pour chacun, les trois versions : base commune (`git show :1:<fichier>`), main (`:2:`, le côté sur lequel on
  rejoue) et le commit de la PR rejoué (`:3:`). Plus le message et le diff du commit rejoué
  (`git show REBASE_HEAD`) et les commits de main qui ont touché le fichier
  (`git log --oneline <merge-base>..origin/main -- <fichier>`).
- L'intention de chaque côté vient de ces commits, pas de la seule forme du texte.

## Interdits

- Toute écriture dans l'arbre : ni édition, ni `git add`, ni `git rebase --continue`/`--skip`/`--abort`, ni
  `git checkout --ours`/`--theirs`.
- Résoudre en bloc d'un côté. Chaque hunk garde l'intention des deux côtés.

## Refus du mode auto

Un refus « a hook changed this call's input » n'est pas un jugement : relancer l'appel seul, à l'identique, sans
autre appel dans le même message, une fois. Refusé encore → le dire dans la réponse, avec la commande.

## Réponse

Pour chaque fichier en conflit :

1. **Intention** de main et de la PR, en une ligne chacune, avec le SHA qui la porte.
2. **Résolution** : le contenu résolu de chaque hunk en conflit, prêt à remplacer le bloc `<<<<<<< … >>>>>>>`, ou
   le fichier entier s'il est court.
3. **Vérification** : ce que la session doit compiler ou tester pour confirmer, notamment un appel ou un symbole
   renommé d'un côté et utilisé de l'autre (`git -C <arbre de la PR> grep` sur tout le dépôt).

Intention ambiguë (les deux côtés changent la même règle différemment, ou un côté supprime ce que l'autre modifie)
→ ne pas trancher : marquer le fichier `à trancher`, avec les options et une recommandation. La session montre le
conflit et attend la décision, rebase laissé en cours.
