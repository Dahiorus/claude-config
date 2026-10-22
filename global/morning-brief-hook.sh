#!/usr/bin/env bash
# Hook SessionStart (startup) : génère en arrière-plan le point du matin du jour s'il n'existe pas encore.
# Rien sur stdout : la sortie d'un hook SessionStart part dans le contexte de Claude.
set -uo pipefail

script="$(dirname "$(readlink -f "$0")")/../scripts/morning_brief.py"
dir="$HOME/morning-brief"
brief="$dir/$(date +%F).md"
[[ -s "$brief" ]] && exit 0
mkdir -p "$dir"

# flock : deux sessions ouvertes en même temps ne lancent qu'une génération.
# Écrit dans .tmp puis renommé : un point à moitié écrit ne compte pas comme fait, l'échec se retente à la session suivante.
# shellcheck disable=SC2016 # $1 et $2 sont développés par le bash -c, pas ici.
setsid flock -n "$dir/.lock" bash -c '
  if "$1" > "$2.tmp" 2> "$2.log"; then
    mv "$2.tmp" "$2" && rm -f "$2.log"
    command -v notify-send >/dev/null && notify-send "Point du matin prêt" "$2"
  else
    rm -f "$2.tmp"
    command -v notify-send >/dev/null && notify-send "Point du matin en échec" "$2.log"
  fi' _ "$script" "$brief" </dev/null >/dev/null 2>&1 &
exit 0
