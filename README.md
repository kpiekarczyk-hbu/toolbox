# toolbox

Personal `~/toolbox`: small shell scripts that get auto-added to `PATH`.

## Install

Clone this repo to `~/toolbox`, then source `.toolboxrc` from your shell rc:

```sh
git clone <this-repo> ~/toolbox
echo '. ~/toolbox/.toolboxrc' >> ~/.zshrc   # or ~/.bashrc
```

Open a new shell. Every executable file in `~/toolbox/scripts` is now a command. The checked-in scripts already have the executable bit set; for anything new, `chmod +x` it.

## How it works

[.toolboxrc](.toolboxrc) prepends `~/toolbox/scripts` to `PATH` (idempotently — re-sourcing is a no-op). Shared helpers live in [scripts/.lib/common.sh](scripts/.lib/common.sh) and are sourced by each script for colored output, logging, and a few preflight checks (`require_cmd`, `require_git_repo`, `require_clean_tree`).

## Commands

Each script supports `--help` for the full option list.

### [gh-clone-prefix](scripts/gh-clone-prefix)

Bulk-clone every repo in a GitHub org or user whose name starts with a prefix. Per-repo failures are isolated. Requires [`gh`](https://cli.github.com), authenticated.

```sh
gh-clone-prefix myorg service-
gh-clone-prefix --force --include-archived myorg service-
```

### [release](scripts/release)

Cut and maintain release branches paired with a git tag and a GitHub release.

```sh
release prepare 2605-a            # cuts release/2605-a, tags it, publishes the GH release
release prepare --repair 2605-a   # fills in missing pieces of a partial state
release update                    # run on a release/* branch: sync, re-tag HEAD, refresh notes
```

Release-name format: `yymm-(a|b|c)` (main cycle) or `yymm-(a|b|c)-N0` where `N` is 1–9 (off-cycle). `prepare` is idempotent. Requires `gh`, a git repo, and a clean working tree.

### [run-in-subdirs](scripts/run-in-subdirs)

Run a shell command in every visible subdirectory of the current directory. Stops on the first failure unless `-c` / `--continue` is passed. The command is a single string evaluated by the shell, so pipes and `&&` work:

```sh
run-in-subdirs 'git pull --ff-only'
run-in-subdirs -c 'git status --short'
```

## Adding a new command

Drop an executable file in [scripts/](scripts/). If it wants the shared helpers, source them with the snippet at the top of [scripts/.lib/common.sh](scripts/.lib/common.sh):

```sh
__lib="$(dirname -- "${BASH_SOURCE[0]}")/.lib/common.sh"
. "$__lib" || { echo "fatal: cannot source $__lib" >&2; exit 1; }
```
