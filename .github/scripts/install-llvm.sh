#!/usr/bin/env bash
# Installs the LLVM command-line tools the e2e tests drive (opt, llc, llvm-as, llvm-nm, clang) and the lld linker that `xlc` uses, and
# puts their directory on PATH for the following workflow steps.
#
# The pinned version is LLVM 18 on Linux (the oldest release xl-llvm supports, see FEATURES.md); macOS and Windows take the newest
# release of their package manager, so every CI run covers both ends of the supported range.
#
# Environment: GITHUB_PATH (set by GitHub Actions); outside Actions the directory is only printed.
set -euo pipefail

bin=""
case "$(uname -s)" in
  Linux)
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends llvm-18 clang-18 lld
    bin=/usr/lib/llvm-18/bin
    # `clang` without a version suffix is what run.sh calls: the versioned package only ships clang-18.
    [ -x "$bin/clang" ] || sudo ln -s "$(command -v clang-18)" "$bin/clang"
    ;;
  Darwin)
    brew install llvm lld
    bin="$(brew --prefix llvm)/bin"
    ;;
  MINGW* | MSYS* | CYGWIN*)
    choco install llvm -y --no-progress
    bin="/c/Program Files/LLVM/bin"
    ;;
  *) echo "error: unsupported OS $(uname -s)" >&2; exit 1 ;;
esac

if [ -n "${GITHUB_PATH:-}" ]; then
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*) cygpath -w "$bin" >>"$GITHUB_PATH" ;;
    *) echo "$bin" >>"$GITHUB_PATH" ;;
  esac
else
  echo "add $bin to PATH"
fi
PATH="$bin:$PATH" opt --version | head -3
PATH="$bin:$PATH" clang --version | head -1
