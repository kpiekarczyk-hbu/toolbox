#!/usr/bin/env bash
# Installer for https://github.com/kpiekarczyk-hbu/toolbox
#
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/kpiekarczyk-hbu/toolbox/main/install.sh | bash
#
# Clones the repo to ~/toolbox and adds a single sourcing line to your shell rc.
# Idempotent: safe to re-run; updates an existing checkout with `git pull --ff-only`.

set -euo pipefail
umask 022

REPO_HTTPS="https://github.com/kpiekarczyk-hbu/toolbox.git"
INSTALL_DIR="$HOME/toolbox"
RC_LINE='. ~/toolbox/.toolboxrc'
MARKER='# toolbox (managed by install.sh)'

# Match either HTTPS or SSH form of the canonical remote, with or without .git suffix.
REMOTE_RE='^(https://github\.com/kpiekarczyk-hbu/toolbox(\.git)?|git@github\.com:kpiekarczyk-hbu/toolbox(\.git)?)$'

if [ -t 1 ]; then
  c_red=$'\033[0;31m'; c_yellow=$'\033[0;33m'; c_green=$'\033[0;32m'
  c_dim=$'\033[2m'; c_reset=$'\033[0m'
else
  c_red=''; c_yellow=''; c_green=''; c_dim=''; c_reset=''
fi

err()  { printf '%sinstall.sh: %s%s\n' "$c_red" "$*" "$c_reset" >&2; }
info() { printf '%s%s%s\n' "$c_dim" "$*" "$c_reset"; }
step() { printf '\n%s==> %s%s%s\n' "$c_dim" "$c_yellow" "$*" "$c_reset"; }
ok()   { printf '%s%s%s\n' "$c_green" "$*" "$c_reset"; }

require_git() {
  if command -v git >/dev/null 2>&1; then
    return
  fi
  err "git not found in PATH"
  case "$(uname -s)" in
    Darwin) info "install with: brew install git  (or: xcode-select --install)";;
    Linux)  info "install with your package manager, e.g. apt install git / yum install git";;
    *)      info "install git and re-run";;
  esac
  exit 1
}

detect_rc_path() {
  local shell_name os rc
  shell_name=$(basename "${SHELL:-}")
  os=$(uname -s)
  case "$shell_name" in
    zsh)  rc="$HOME/.zshrc" ;;
    bash) if [ "$os" = "Darwin" ]; then rc="$HOME/.bash_profile"; else rc="$HOME/.bashrc"; fi ;;
    *)    if [ "$os" = "Darwin" ]; then rc="$HOME/.zshrc"; else rc="$HOME/.bashrc"; fi
          info "unknown shell '$shell_name'; defaulting to $rc" ;;
  esac
  printf '%s' "$rc"
}

verify_existing() {
  # Called only when $INSTALL_DIR already exists.
  if [ ! -d "$INSTALL_DIR/.git" ]; then
    err "$INSTALL_DIR exists but is not a git repository"
    info "move it aside or remove it, then re-run"
    exit 2
  fi
  local remote
  remote=$(git -C "$INSTALL_DIR" remote get-url origin 2>/dev/null || true)
  if [ -z "$remote" ]; then
    err "$INSTALL_DIR has no 'origin' remote"
    exit 2
  fi
  if ! printf '%s' "$remote" | grep -Eq "$REMOTE_RE"; then
    err "$INSTALL_DIR points at a different repository: $remote"
    info "expected origin to match $REPO_HTTPS"
    exit 2
  fi
}

clone_fresh() {
  step "Cloning $REPO_HTTPS -> $INSTALL_DIR"
  if ! git clone "$REPO_HTTPS" "$INSTALL_DIR"; then
    err "git clone failed"
    exit 3
  fi
}

update_existing() {
  step "Updating existing checkout at $INSTALL_DIR"
  local branch dirty
  branch=$(git -C "$INSTALL_DIR" symbolic-ref --short HEAD 2>/dev/null || echo "DETACHED")
  if [ "$branch" != "main" ]; then
    info "on branch '$branch' (not main); skipping pull"
    return
  fi
  if ! git -C "$INSTALL_DIR" diff --quiet || ! git -C "$INSTALL_DIR" diff --cached --quiet; then
    dirty=1
  else
    dirty=0
  fi
  if [ "$dirty" = "1" ]; then
    info "working tree is dirty; skipping pull"
    return
  fi
  if ! git -C "$INSTALL_DIR" pull --ff-only; then
    err "git pull --ff-only failed"
    exit 3
  fi
}

edit_rc() {
  local rc="$1"
  if [ ! -e "$rc" ]; then
    info "creating $rc"
    : > "$rc"
  fi
  if grep -Fq "$RC_LINE" "$rc" || grep -Fq "$MARKER" "$rc"; then
    info "$rc already sources .toolboxrc; nothing to do"
    return
  fi
  step "Adding toolbox source line to $rc"
  printf '\n%s\n%s\n' "$MARKER" "$RC_LINE" >> "$rc"
}

print_summary() {
  local rc="$1"
  printf '\n'
  ok "Toolbox installed."
  info "  repo: $INSTALL_DIR"
  info "  rc:   $rc"
  printf '\n'
  info "Activate in this shell:    exec \"\$SHELL\" -l"
  info "Or open a new terminal."
  info "List installed commands:   toolbox list"
  info "Switch to SSH for push:    git -C \"$INSTALL_DIR\" remote set-url origin git@github.com:kpiekarczyk-hbu/toolbox.git"
}

main() {
  step "Installing toolbox"
  require_git
  if [ -e "$INSTALL_DIR" ]; then
    verify_existing
    update_existing
  else
    clone_fresh
  fi
  rc=$(detect_rc_path)
  edit_rc "$rc"
  print_summary "$rc"
}

main "$@"
