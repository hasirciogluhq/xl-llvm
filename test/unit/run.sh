#!/bin/bash
# Unit suites of xl-llvm: every `*.test.xl` here is a program that ends in `suiteRun` (std/testing); a non-zero exit status fails
# the file. Unit tests are platform independent: they build IR through the API and compare the printed text; they never start a
# tool or touch the OS. Each one is built with `xlc` against this repository as the module root `xl-llvm`.
#   test/unit/run.sh [path/to/xlc] [name-regex]
# Environment: XLC (compiler, default `xlc` on PATH), XL_STD (the standard library directory, default ../xl-std).
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
xlc=${1:-${XLC:-xlc}}
filter=${2:-}
std=${XL_STD:-$root/../xl-std}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
pass=0; fail=0

for src in "$here"/*.test.xl; do
  name=$(basename "$src" .test.xl)
  if [ -n "$filter" ] && ! [[ $name =~ $filter ]]; then continue; fi
  if ! "$xlc" "$src" -M "std=$std" -M "xl-llvm=$root" --import std -DfeatureDefaultAllocator=true -DxlTestNoColor -o "$work/$name" 2>"$work/$name.err"; then
    echo "FAIL [unit/$name] build"; cat "$work/$name.err"; fail=$((fail + 1)); continue
  fi
  out=$("$work/$name" 2>&1); code=$?
  if [ "$code" = 0 ]; then
    echo "ok   [unit/$name]"; pass=$((pass + 1))
  else
    echo "FAIL [unit/$name] exit $code"; echo "$out"; fail=$((fail + 1))
  fi
done

echo "unit: $pass passed, $fail failed"
[ "$fail" = 0 ]
