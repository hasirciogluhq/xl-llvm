#!/usr/bin/env bash
# Installs the xlang compiler `xlc` for this runner and puts it on PATH for the following workflow steps.
#
# Which release: the newest stable release of the compiler repository when there is one; otherwise the newest pre-release (the latest
# `-rc.N`), so this repository can be tested while the compiler has only release candidates. XLC_VERSION (a tag such as v1.0.0-rc.1)
# pins one release instead.
#
# Environment:
#   GH_TOKEN        token that may read the compiler repository (needed while it is private; `github.token` is enough once it is public)
#   XLC_REPO        compiler repository (default hasirciogluhq/xlc)
#   XLC_VERSION     tag to install instead of the newest one (optional)
#   XLC_HOME        directory that holds the install (default ~/.xl-ci); an install of the wanted version there is reused
#   GITHUB_PATH     set by GitHub Actions; outside Actions PATH is not touched and the directory is printed
#
# Assets (see the compiler's release workflow): xlc_<version>_<os>_<arch>.tar.gz (zip on Windows) and checksums.txt, with os
# darwin|linux|windows and arch amd64|arm64.
set -euo pipefail

repo=${XLC_REPO:-hasirciogluhq/xlc}

case "$(uname -s)" in
  Darwin) os=darwin; ext=tar.gz ;;
  Linux) os=linux; ext=tar.gz ;;
  MINGW* | MSYS* | CYGWIN*) os=windows; ext=zip ;;
  *) echo "error: unsupported OS $(uname -s)" >&2; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64 | amd64) arch=amd64 ;;
  arm64 | aarch64) arch=arm64 ;;
  *) echo "error: unsupported CPU $(uname -m)" >&2; exit 1 ;;
esac

tag=${XLC_VERSION:-}
if [ -z "$tag" ]; then
  # `releases/latest` never returns a pre-release or a draft, and answers 404 while the repository has only pre-releases.
  if tag=$(gh api "repos/$repo/releases/latest" --jq .tag_name 2>/dev/null) && [ -n "$tag" ]; then
    echo "xlc: newest stable release is $tag" >&2
  else
    # The list is not ordered by date (rc.9 comes before rc.10), so the newest is the one published last.
    tag=$(gh api "repos/$repo/releases?per_page=100" --jq '[.[] | select(.draft | not) | select(.prerelease)] | sort_by(.published_at) | last | .tag_name // empty')
    [ -n "$tag" ] || { echo "error: $repo has no stable release and no pre-release" >&2; exit 1; }
    echo "xlc: no stable release yet, using the newest pre-release $tag" >&2
  fi
fi
version=${tag#v}

dest=${XLC_HOME:-$HOME/.xl-ci}/xlc
if [ -x "$dest/bin/xlc" ] || [ -x "$dest/bin/xlc.exe" ]; then
  if [ "$("$dest/bin/xlc" --version 2>/dev/null)" = "$version" ]; then
    echo "xlc: $version is already installed in $dest"
    if [ -n "${GITHUB_PATH:-}" ]; then echo "$dest/bin" >>"$GITHUB_PATH"; else echo "add $dest/bin to PATH"; fi
    exit 0
  fi
fi
mkdir -p "$dest/bin" "$dest/download"
asset="xlc_${version}_${os}_${arch}.${ext}"
gh release download "$tag" -R "$repo" -D "$dest/download" -p "$asset" -p checksums.txt --clobber

# The archive must match the checksum the release published for it.
want=$(awk -v a="$asset" '$2 == a || $2 == "*" a { print $1 }' "$dest/download/checksums.txt")
[ -n "$want" ] || { echo "error: checksums.txt has no entry for $asset" >&2; exit 1; }
if command -v sha256sum >/dev/null 2>&1; then got=$(sha256sum "$dest/download/$asset" | awk '{ print $1 }')
else got=$(shasum -a 256 "$dest/download/$asset" | awk '{ print $1 }'); fi
# GNU sha256sum starts the line with `\` when the file name contains a backslash (a Windows path): that is not part of the hash.
got=${got#\\}
[ "$got" = "$want" ] || { echo "error: checksum mismatch for $asset (got $got, want $want)" >&2; exit 1; }

if [ "$ext" = zip ]; then unzip -q -o "$dest/download/$asset" -d "$dest/bin"; else tar -xzf "$dest/download/$asset" -C "$dest/bin"; fi
chmod +x "$dest/bin/xlc"* 2>/dev/null || true
"$dest/bin/xlc" --version

if [ -n "${GITHUB_PATH:-}" ]; then echo "$dest/bin" >>"$GITHUB_PATH"; else echo "add $dest/bin to PATH"; fi
