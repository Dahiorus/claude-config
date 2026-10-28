#!/usr/bin/env python3
"""PreToolUse (Bash) : refuse Gradle lancé sans `build-brief` pour garder une sortie condensée."""
import json
import re
import sys

commande = json.load(sys.stdin).get("tool_input", {}).get("command", "")

# Un segment de commande qui commence par ./gradlew ou gradle (hors build-brief).
gradle_brut = re.search(r"(?:^|[;&|(]\s*|\b(?:ba)?sh -c\s+['\"])\s*(?:\./)?gradlew?\b(?!-)", commande)
if gradle_brut:
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": "Lancer Gradle via build-brief (sortie condensée), par exemple "
                                    "`build-brief ./gradlew build`. Voir CLAUDE.md.",
    }}))
sys.exit(0)
