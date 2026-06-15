#!/usr/bin/env bash
set -euo pipefail

forge clean >/dev/null
forge build --build-info --skip '*/test/**' '*/script/**' --force >/dev/null 2>&1

# Slither 0.11.x expects every Foundry build-info file to contain `output`.
# Foundry may emit metadata-only build-info files for dependency paths; remove
# those before crytic-compile parses the build-info directory.
find out/build-info -name '*.json' -exec sh -c '
  for file do
    jq -e "has(\"output\")" "$file" >/dev/null || rm "$file"
  done
' sh {} +
