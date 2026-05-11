# shellcheck shell=bash
# Shared helpers for ~/toolbox scripts. Source from each script:
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

# Subdirectory filtering by glob pattern.
#
# Populate via filter_add_include / filter_add_exclude (each accepts a
# single pattern OR a comma-separated list). Patterns are bash globs
# matched against the basename of each direct subdirectory.
#
# Then call collect_filtered_subdirs to populate the global `subdirs`
# array with matching names (no trailing slash).
_filter_includes=()
_filter_excludes=()

filter_add_include() {
  local IFS=',' p
  for p in $1; do
    [[ -n $p ]] && _filter_includes+=( "$p" )
  done
}

filter_add_exclude() {
  local IFS=',' p
  for p in $1; do
    [[ -n $p ]] && _filter_excludes+=( "$p" )
  done
}

filter_match() {
  local name=$1 p matched
  if (( ${#_filter_includes[@]} > 0 )); then
    matched=0
    for p in "${_filter_includes[@]}"; do
      # shellcheck disable=SC2053
      if [[ $name == $p ]]; then matched=1; break; fi
    done
    (( matched )) || return 1
  fi
  if (( ${#_filter_excludes[@]} > 0 )); then
    for p in "${_filter_excludes[@]}"; do
      # shellcheck disable=SC2053
      if [[ $name == $p ]]; then return 1; fi
    done
  fi
  return 0
}

collect_filtered_subdirs() {
  subdirs=()
  local entry name all
  shopt -s nullglob
  all=( */ )
  shopt -u nullglob
  for entry in "${all[@]}"; do
    name="${entry%/}"
    filter_match "$name" && subdirs+=( "$name" )
  done
}

# Shared help text for --include/--exclude options, indented to match
# the surrounding Options block.
filter_options_help() {
  cat <<'EOF'
  -i, --include PATTERN
                Only operate on subdirs whose name matches PATTERN.
                Repeatable; PATTERN may be a comma-separated list.
                Globs are supported (e.g. 'web-*,api').
  -x, --exclude PATTERN
                Skip subdirs whose name matches PATTERN. Same syntax
                as --include. Excludes are applied after includes.
EOF
}
