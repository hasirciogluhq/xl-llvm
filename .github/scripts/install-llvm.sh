#!/usr/bin/env bash
# Installs the LLVM tools for CI and puts their directory on PATH for the following workflow steps.
#   install-llvm.sh lld    the lld linker only (what `xlc` needs to link the unit and e2e programs)
#   install-llvm.sh all    also opt, llc, llvm-as, llvm-nm and clang (what the e2e tests drive)
#
# The pinned version is LLVM 18 on Linux (the oldest release xl-llvm supports, see FEATURES.md); macOS takes the newest Homebrew
# release. On Windows the runner's own LLVM supplies clang and lld; opt, llc, llvm-as and llvm-nm come from MSYS2 (the Windows
# LLVM installer does not ship them), which the `setup-llvm` action installs before this script runs.
#
# Environment: GITHUB_PATH (set by GitHub Actions); outside Actions the directory is only printed.
set -euo pipefail

what=${1:-all}
bin=""
case "$(uname -s)" in
  Linux)
    packages=(lld)
    [ "$what" = all ] && packages+=(llvm-18 clang-18)
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends "${packages[@]}"
    if [ "$what" = all ]; then
      bin=/usr/lib/llvm-18/bin
      # `clang` without a version suffix is what run.sh calls.
      [ -x "$bin/clang" ] || sudo ln -s "$(command -v clang-18)" "$bin/clang"
    fi
    ;;
  Darwin)
    packages=(lld)
    [ "$what" = all ] && packages+=(llvm)
    brew install "${packages[@]}"
    [ "$what" = all ] && bin="$(brew --prefix llvm)/bin"
    ;;
  MINGW* | MSYS* | CYGWIN*)
    # clang and lld are on the runner already (C:\Program Files\LLVM).
    bin="/c/Program Files/LLVM/bin"
    [ -x "$bin/clang.exe" ] || { echo "error: the runner has no LLVM in $bin" >&2; exit 1; }
    ;;
  *) echo "error: unsupported OS $(uname -s)" >&2; exit 1 ;;
esac

if [ -n "$bin" ]; then
  if [ -n "${GITHUB_PATH:-}" ]; then
    case "$(uname -s)" in
      MINGW* | MSYS* | CYGWIN*) cygpath -w "$bin" >>"$GITHUB_PATH" ;;
      *) echo "$bin" >>"$GITHUB_PATH" ;;
    esac
  else
    echo "add $bin to PATH"
  fi
fi
