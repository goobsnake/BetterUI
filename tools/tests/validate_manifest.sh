#!/bin/bash
# Validates all concrete file entries in BetterUI.txt exist on disk.
set -u

missing=0
while IFS= read -r line; do
  trimmed="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  case "$trimmed" in
    ""|\#\#*|\;*) continue ;;
  esac

  # ESO expands manifest substitution tokens at load time; validate concrete paths only.
  if [[ "$trimmed" == *'$('* ]]; then
    continue
  fi

  file="${trimmed//\\//}"
  if [ ! -f "$file" ]; then
    echo "MISSING: $file"
    missing=1
  fi
done < BetterUI.txt

exit "$missing"
