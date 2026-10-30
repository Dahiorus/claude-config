@RTK.md

# Réponses

Écris pour qu'un humain ait envie de lire : le résultat d'abord, en quelques lignes, jamais un long pavé de texte.
Un tableau est bienvenu quand il résume la réponse. Pas de récapitulatif de ce que tu viens de faire. Le contexte de
fin de ponytail (ce qui n'a pas été vérifié, les risques) reste, en une ou deux lignes.

# Navigation dans le code

Pour trouver une définition, un appel ou la structure d'un fichier dans un langage couvert par un plugin LSP (PHP,
TypeScript…), charger l'outil `LSP` (`ToolSearch select:LSP`) et l'utiliser avant `grep` ou `sed -n` : chaque
lecture en Bash est un tour de plus sur tout le contexte.

# Humanizer

Before publishing a commit message, a PR description or a review comment you wrote, run it through the
`humanizer:humanizer` skill, then use the rewritten text. Leave code, commands, identifiers and quoted output as is.
