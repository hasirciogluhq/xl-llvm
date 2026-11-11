#!/bin/bash
# Checks FEATURES.md against the tests: every `done` row names a unit test (or `n/a`) and an e2e test that exist, and every test
# file belongs to at least one row.
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
fail=0
used=" "

while IFS='|' read -r _ feature section api unit e2e status _; do
  status=$(echo "$status" | tr -d ' ')
  [ "$status" = done ] || continue
  feature=$(echo "$feature" | sed 's/^ *//; s/ *$//')
  for name in $(echo "$unit" | tr -d '`' | tr ',' ' '); do
    [ "$name" = "n/a" ] && continue
    used="$used$name "
    [ -f "$here/unit/$name" ] || { echo "missing unit test $name for: $feature"; fail=1; }
  done
  [ -n "$(echo "$unit" | tr -d ' ')" ] || { echo "no unit test column for: $feature"; fail=1; }
  for name in $(echo "$e2e" | tr -d '`' | tr ',' ' '); do
    used="$used$name "
    [ -f "$here/e2e/$name" ] || { echo "missing e2e test $name for: $feature"; fail=1; }
  done
  [ -n "$(echo "$e2e" | tr -d ' ')" ] || { echo "no e2e test column for: $feature"; fail=1; }
done <"$root/FEATURES.md"

for file in "$here"/unit/*.test.xl "$here"/e2e/*.xl; do
  name=$(basename "$file")
  case "$name" in emit.xl) continue ;; esac
  case "$used" in *" $name "*) ;; *) echo "test file without a feature row: ${file#"$root"/}"; fail=1 ;; esac
done

[ "$fail" = 0 ] && echo "features: table and tests agree"
exit "$fail"
