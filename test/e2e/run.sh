#!/bin/bash
# End-to-end tests of xl-llvm. They are platform related: they run the LLVM tools, link and execute the result.
#   test/e2e/run.sh [path/to/xlc] [name-regex]
# Environment:
#   XLC       the xlang compiler (default `xlc` on PATH)         XL_STD   the standard library directory (default ../xl-std)
#   CLANG     the C compiler driver used to link (default clang)  LLVM_BIN directory of opt, llc, llvm-nm (default: PATH)
#
# Every program in this folder builds one module through the xl-llvm API and prints the IR text (see emit.xl). The table in
# tests.txt says what to do with it; fields are separated by `|`, `#` starts a comment:
#   run|name|exit status|text the output must contain   verify with `opt`, build with clang (-O0), link, run, check status and output
#   cross|name                                          verify and compile to an object for every triple in `triples` (no run)
#   sym|name|present regex|absent regex                 compile to an object and check the symbol table with llvm-nm (not on Windows)
#   tool|name|exit status|text the output must contain  run the xlang program itself: it drives the tools of xl-llvm
set -u
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
xlc=${1:-${XLC:-xlc}}
filter=${2:-}
std=${XL_STD:-$root/../xl-std}
clang=${CLANG:-clang}
if [ -n "${LLVM_BIN:-}" ]; then PATH="$LLVM_BIN:$PATH"; fi
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
pass=0; fail=0
exe=""
case "$(uname -s)" in MINGW* | MSYS* | CYGWIN*) exe=.exe ;; esac

# The targets of the compile-only legs. Running them needs a host of that target; compiling needs only an LLVM built with
# the backend, which every release has.
triples="x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu x86_64-apple-macosx arm64-apple-macosx x86_64-pc-windows-msvc aarch64-pc-windows-msvc"

ok() { echo "ok   [$1]"; pass=$((pass + 1)); }
bad() { echo "FAIL [$1] $2"; [ -n "${3:-}" ] && echo "$3" | head -20; fail=$((fail + 1)); }

# build <name>: the program in this folder, into $work/<name>$exe
build() {
  "$xlc" "$here/$1.xl" -M "std=$std" -M "xl-llvm=$root" --import std -DfeatureDefaultAllocator=true -o "$work/$1$exe" 2>"$work/$1.build"
}

# emit <name> [triple]: the IR text of the program into $work/<name>[.<triple>].ll
emit() {
  local out="$work/$1${2:+.$2}.ll"
  "$work/$1$exe" ${2:+"$2"} >"$out" 2>"$work/$1.err" || { echo "the program failed: $(cat "$work/$1.err")"; return 1; }
}

while IFS='|' read -r kind name a b || [ -n "$kind" ]; do
  case "$kind" in '' | '#'*) continue ;; esac
  if [ -n "$filter" ] && ! [[ $name =~ $filter ]]; then continue; fi
  label="e2e/$kind/$name"
  if ! build "$name"; then bad "$label" "build" "$(cat "$work/$name.build")"; continue; fi

  case "$kind" in
    run)
      msg=$(emit "$name") || { bad "$label" "emit" "$msg"; continue; }
      if ! out=$(opt -passes=verify -disable-output "$work/$name.ll" 2>&1); then bad "$label" "opt -passes=verify rejected the text" "$out"; continue; fi
      if ! out=$("$clang" -O0 -Wno-override-module "$work/$name.ll" -o "$work/$name.bin$exe" 2>&1); then bad "$label" "clang" "$out"; continue; fi
      got=$("$work/$name.bin$exe" 2>&1); code=$?
      if [ "$code" != "$a" ]; then bad "$label" "exit status $code, want $a" "$got"; continue; fi
      if [ -n "$b" ] && ! grep -qF -- "$b" <<<"$got"; then bad "$label" "output lacks '$b'" "$got"; continue; fi
      ok "$label"
      ;;
    cross)
      leg_ok=1
      for triple in $triples; do
        if ! msg=$(emit "$name" "$triple"); then bad "$label ($triple)" "emit" "$msg"; leg_ok=0; continue; fi
        ll="$work/$name.$triple.ll"
        if ! out=$(opt -passes=verify -disable-output "$ll" 2>&1); then bad "$label ($triple)" "opt -passes=verify" "$out"; leg_ok=0; continue; fi
        if ! out=$(llc -mtriple="$triple" -filetype=obj "$ll" -o "$work/$name.$triple.o" 2>&1); then bad "$label ($triple)" "llc" "$out"; leg_ok=0; continue; fi
      done
      [ "$leg_ok" = 1 ] && ok "$label"
      ;;
    sym)
      if [ -n "$exe" ]; then echo "skip [$label] (symbol table check is not run on Windows)"; continue; fi
      msg=$(emit "$name") || { bad "$label" "emit" "$msg"; continue; }
      if ! out=$(llc -filetype=obj "$work/$name.ll" -o "$work/$name.o" 2>&1); then bad "$label" "llc" "$out"; continue; fi
      syms=$(llvm-nm --defined-only "$work/$name.o")
      if ! grep -Eq -- "$a" <<<"$syms"; then bad "$label" "symbol table lacks /$a/" "$syms"; continue; fi
      if [ -n "$b" ] && grep -Eq -- "$b" <<<"$syms"; then bad "$label" "symbol table has /$b/" "$syms"; continue; fi
      ok "$label"
      ;;
    tool)
      got=$("$work/$name$exe" 2>&1); code=$?
      if [ "$code" != "$a" ]; then bad "$label" "exit status $code, want $a" "$got"; continue; fi
      if [ -n "$b" ] && ! grep -qF -- "$b" <<<"$got"; then bad "$label" "output lacks '$b'" "$got"; continue; fi
      ok "$label"
      ;;
    *) bad "$label" "unknown kind" ;;
  esac
done <"$here/tests.txt"

echo "e2e: $pass passed, $fail failed"
[ "$fail" = 0 ]
