# toolbox

Personal `~/toolbox`: small shell scripts wrapped behind a single `toolbox` command.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/kpiekarczyk-hbu/toolbox/main/install.sh | bash
```

[install.sh](install.sh) clones this repo to `~/toolbox` and appends a single source line to your shell rc (`~/.zshrc` for zsh, `~/.bash_profile` on macOS bash, `~/.bashrc` on Linux bash). It's idempotent — re-running updates the checkout with `git pull --ff-only` and leaves the rc alone if the line is already there.

Open a new shell (`exec "$SHELL" -l`). The `toolbox` command is now on `PATH`; run `toolbox list` to see what's available.

### Manual install

If you'd rather not pipe to bash:

```sh
git clone https://github.com/kpiekarczyk-hbu/toolbox.git ~/toolbox
echo '. ~/toolbox/.toolboxrc' >> ~/.zshrc   # or ~/.bashrc / ~/.bash_profile
```

## How it works

[.toolboxrc](.toolboxrc) prepends `~/toolbox/bin` to `PATH` (idempotently — re-sourcing is a no-op). Only [bin/toolbox](bin/toolbox) is exposed as a shell command; everything in [scripts/](scripts/) is invoked through it (`toolbox release …`, `toolbox sync-subdir-repos …`). This keeps the shell command namespace clean.

Shared helpers live in [scripts/.lib/common.sh](scripts/.lib/common.sh) and are sourced by each script for colored output, logging, and a few preflight checks (`require_cmd`, `require_git_repo`, `require_clean_tree`).

Under zsh, `.toolboxrc` also wires up tab completion: it generates `~/toolbox/completions/_toolbox` on first source and adds the directory to `fpath`. It does **not** call `compinit` — that's left to your existing zsh setup (oh-my-zsh, prezto, or a hand-rolled `.zshrc` will already run it). If you don't have `compinit` anywhere, add `autoload -Uz compinit && compinit` to your `.zshrc` after the toolbox source line.

## Commands

`toolbox` has built-in commands for managing the checkout itself, and dispatches into [scripts/](scripts/) for everything else. Run `toolbox list` for the full inventory; each script supports `--help`.

### Built-in

```sh
toolbox check                       # Is there a new version on origin? (read-only)
toolbox update                      # Fast-forward the current branch
toolbox update --branch feature-x   # Switch to feature-x first, then fast-forward
toolbox reset                       # Roll back to main and fast-forward
toolbox list                        # List built-ins and dispatchable scripts
toolbox completions [--write]       # Print or write the zsh completion file
toolbox help                        # Show usage
```

`update` and `reset` require a clean working tree. After a successful update or reset, completions are regenerated so newly-added scripts show up in `toolbox <TAB>`.

### Scripts

Run any of these as `toolbox <name> [args]`:

- **[gh-clone-prefix](scripts/gh-clone-prefix)** — Bulk-clone every repo in a GitHub org or user whose name starts with a prefix. Requires [`gh`](https://cli.github.com), authenticated.

  ```sh
  toolbox gh-clone-prefix myorg service-
  toolbox gh-clone-prefix --force --include-archived myorg service-
  ```

- **[release](scripts/release)** — Cut and maintain release branches paired with a git tag and GitHub release.

  ```sh
  toolbox release prepare 2605-a
  toolbox release prepare --repair 2605-a
  toolbox release update
  ```

- **[sync-subdir-repos](scripts/sync-subdir-repos)** — In every git repo directly under the current directory, fetch (with tags) and fast-forward the main branch (`develop`, `main`, or `master`, preferring `origin/HEAD`). Dirty trees are skipped at the pull step.

  ```sh
  toolbox sync-subdir-repos
  ```

- **[run-in-subdirs](scripts/run-in-subdirs)** — Run a shell command in every visible subdirectory. Stops on the first failure unless `-c` / `--continue` is passed. The command is a single string evaluated by the shell, so pipes and `&&` work:

  ```sh
  toolbox run-in-subdirs 'git pull --ff-only'
  toolbox run-in-subdirs -c 'git status --short'
  ```

## Adding a new command

Drop an executable file in [scripts/](scripts/) — it's immediately callable as `toolbox <name>`. If it wants the shared helpers, source them with the snippet at the top of [scripts/.lib/common.sh](scripts/.lib/common.sh):

```sh
__lib="$(dirname -- "${BASH_SOURCE[0]}")/.lib/common.sh"
. "$__lib" || { echo "fatal: cannot source $__lib" >&2; exit 1; }
```

Run `toolbox completions --write` afterwards to refresh the zsh completion file (or just `toolbox update` / `toolbox reset`, which do it for you).

## Upgrading from the pre-dispatcher layout

Earlier versions of `.toolboxrc` put `~/toolbox/scripts` on `PATH`, so each script was its own shell command (`release prepare 2605-a`). That's no longer the case — call them as `toolbox release prepare 2605-a` instead. Re-run `install.sh` or `toolbox update` to pick up the new `.toolboxrc`.
