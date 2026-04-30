# shellcheck shell=bash
# Shared helpers for ~/commands scripts. Source from each script:
#
#   __lib="$(dirname -- "${BASH_SOURCE[0]}")/.lib/common.sh"
#   . "$__lib" || { echo "fatal: cannot source $__lib" >&2; exit 1; }
#
# Provides: TTY-aware color vars, err/info/step/run helpers, and a few
# require_* preflight checks. Does not touch `set` flags — leaves that
# to each caller.

__cmd=${0##*/}

if [[ -t 1 ]]; then
  c_red=$'\033[0;31m'
  c_yellow=$'\033[0;33m'
  c_green=$'\033[0;32m'
  c_dim=$'\033[2m'
  c_reset=$'\033[0m'
else
  c_red='' c_yellow='' c_green='' c_dim='' c_reset=''
fi

err() {
  printf '%s%s: %s%s\n' "$c_red" "$__cmd" "$*" "$c_reset" >&2
}

info() {
  printf '%s%s%s\n' "$c_dim" "$*" "$c_reset"
}

step() {
  printf '\n%s==> %s%s%s\n' "$c_dim" "$c_yellow" "$*" "$c_reset"
}

run() {
  printf '%s   $ %s%s\n' "$c_dim" "$*" "$c_reset"
  "$@"
}

require_cmd() {
  local name=$1 url=${2-}
  if ! command -v "$name" >/dev/null 2>&1; then
    if [[ -n $url ]]; then
      err "$name not found in PATH ($url)"
    else
      err "$name not found in PATH"
    fi
    exit 1
  fi
}

require_git_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    err "not inside a git repository"
    exit 1
  fi
}

require_clean_tree() {
  if ! git diff --quiet || ! git diff --cached --quiet; then
    err "working tree is not clean — commit or stash changes first"
    exit 1
  fi
}
