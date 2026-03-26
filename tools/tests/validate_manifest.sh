#!/bin/bash
# Validates all files in BetterUI.txt exist on disk
while read -r line; do
  file=$(echo "$line" | tr '\\' '/')
  [ -f "$file" ] || echo "MISSING: $file"
done < BetterUI.txt
