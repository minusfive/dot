# Module Inventory: `zsh`

## Metadata

- Module key: `zsh`
- Story key: `MIG-MODULE-zsh`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/zsh.md`
- Current declaration: `none`
- New declaration: `~/dev/personal/dot/home/.config/mise/conf.d/module.zsh.toml`
- Current owner: `Stow`
- New owner: `mise`
- Target root: `~/.config/zsh`
- Mise mode: `symlink-each`
- Environment selector: `zsh` in both profile branches
- Dependencies: `MIG-MODULE-bat, MIG-MODULE-btop, MIG-MODULE-delta`
- Approval state: `approved`
- Inventory status: `complete`

## Scope manifest

| Source path                                  | Tracked | Ignored | Current owner | Current target                                 | Target disposition | New source path                                                      | New target                                     | New mode       | Notes                                                                                                                                                                              |
| -------------------------------------------- | ------- | ------- | ------------- | ---------------------------------------------- | ------------------ | -------------------------------------------------------------------- | ---------------------------------------------- | -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.config/zsh/.aliases`                       | `yes`   | `no`    | `Stow`        | `~/.config/zsh/.aliases`                       | `migrate`          | `~/dev/personal/dot/home/.config/zsh/.aliases`                       | `~/.config/zsh/.aliases`                       | `symlink-each` | Regular source file; current metadata is `0644 villalj:staff`.                                                                                                                     |
| `.config/zsh/.p10k.zsh`                      | `yes`   | `no`    | `Stow`        | `~/.config/zsh/.p10k.zsh`                      | `migrate`          | `~/dev/personal/dot/home/.config/zsh/.p10k.zsh`                      | `~/.config/zsh/.p10k.zsh`                      | `symlink-each` | Regular source file; current metadata is `0644 villalj:staff`.                                                                                                                     |
| `.config/zsh/.zprofile`                      | `yes`   | `no`    | `Stow`        | `~/.config/zsh/.zprofile`                      | `migrate`          | `~/dev/personal/dot/home/.config/zsh/.zprofile`                      | `~/.config/zsh/.zprofile`                      | `symlink-each` | Regular source file; current metadata is `0644 villalj:staff`.                                                                                                                     |
| `.config/zsh/.zshrc`                         | `yes`   | `no`    | `Stow`        | `~/.config/zsh/.zshrc`                         | `migrate`          | `~/dev/personal/dot/home/.config/zsh/.zshrc`                         | `~/.config/zsh/.zshrc`                         | `symlink-each` | Regular source file; current metadata is `0644 villalj:staff`; sources local functions, aliases, prompt, plugin configuration, completion, Docker, WezTerm, and other XDG targets. |
| `.config/zsh/custom_functions.zsh`           | `yes`   | `no`    | `Stow`        | `~/.config/zsh/custom_functions.zsh`           | `migrate`          | `~/dev/personal/dot/home/.config/zsh/custom_functions.zsh`           | `~/.config/zsh/custom_functions.zsh`           | `symlink-each` | Regular source file; current metadata is `0644 villalj:staff`.                                                                                                                     |
| `.config/zsh/plugins/zsh-vi-mode/config.zsh` | `yes`   | `no`    | `Stow`        | `~/.config/zsh/plugins/zsh-vi-mode/config.zsh` | `migrate`          | `~/dev/personal/dot/home/.config/zsh/plugins/zsh-vi-mode/config.zsh` | `~/.config/zsh/plugins/zsh-vi-mode/config.zsh` | `symlink-each` | Regular source file; current metadata is `0644 villalj:staff`; sourced by `.zshrc` from the target path.                                                                           |
| `.config/zsh/.zsh_history`                   | `no`    | `yes`   | `Stow`        | `~/.config/zsh/.zsh_history`                   | `preserve`         | `none`                                                               | `~/.config/zsh/.zsh_history`                   | `none`         | Runtime history; keep outside repository and `~/dev/personal/dot/home/`; move only after detaching the old whole-directory link; preserve `0600 villalj:staff`.                    |
| `.config/zsh/.zcompdump`                     | `no`    | `yes`   | `Stow`        | `~/.config/zsh/.zcompdump`                     | `preserve`         | `none`                                                               | `~/.config/zsh/.zcompdump`                     | `none`         | Runtime completion state; keep outside repository and `~/dev/personal/dot/home/`; move only after detaching the old whole-directory link; preserve `0644 villalj:staff`.           |

The complete physical file set is the six tracked files and two ignored files
listed above. `git ls-files --others --exclude-standard -- .config/zsh`
returned no non-ignored untracked paths. The ignored paths are confirmed by
`git ls-files --others --ignored --exclude-standard -- .config/zsh` and
`git check-ignore -v --no-index .config/zsh/.zsh_history .config/zsh/.zcompdump`.

## Local and runtime inventory

| Path                              | Exists | Tracked | Ignored | Current location | Active use evidence                                                                                      | Classification  | Required action | Runtime destination          | Metadata to preserve                                                                                                     | Secret or sensitive data |
| --------------------------------- | ------ | ------- | ------- | ---------------- | -------------------------------------------------------------------------------------------------------- | --------------- | --------------- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------ |
| `.config/zsh`                     | `no`   | `no`    | `no`    | `historical`     | Retired Stow source boundary; tracked files moved to `home/.config/zsh`.                                 | `historical`    | `remove`        | `none`                       | `retired source path`                                                                                                    | `no`                     |
| `.config/zsh/plugins`             | `no`   | `no`    | `no`    | `historical`     | Retired source directory for the tracked local plugin configuration.                                     | `historical`    | `remove`        | `none`                       | `retired source path`                                                                                                    | `no`                     |
| `.config/zsh/plugins/zsh-vi-mode` | `yes`  | `no`    | `no`    | `repo`           | Contains the tracked `config.zsh` sourced by `.zshrc`.                                                   | `active-global` | `exclude`       | `none`                       | Directory `0755`, owner/group `villalj:staff`.                                                                           | `no`                     |
| `.config/zsh/.zsh_history`        | `no`   | `no`    | `no`    | `historical`     | Runtime history moved to the detached target without reading its contents.                               | `historical`    | `remove`        | `~/.config/zsh/.zsh_history` | `moved; target mode 0600, owner/group villalj:staff`                                                                     | `yes`                    |
| `.config/zsh/.zcompdump`          | `no`   | `no`    | `no`    | `historical`     | Runtime completion state moved to the detached target without reading its contents.                      | `historical`    | `remove`        | `~/.config/zsh/.zcompdump`   | `moved; target mode 0644, owner/group villalj:staff`                                                                     | `yes`                    |
| `~/.config`                       | `yes`  | `no`    | `no`    | `target`         | `.zshenv` sets `XDG_CONFIG_HOME=$HOME/.config`; current parent is a physical directory.                  | `active-global` | `preserve`      | `none`                       | Physical directory `0700`, owner/group `villalj:staff`; do not replace it with a link or change its ownership.           | `no`                     |
| `~/.config/zsh`                   | `yes`  | `no`    | `no`    | `target`         | `ZDOTDIR=$XDG_CONFIG_HOME/zsh`; physical target contains six mise links and two preserved runtime files. | `active-global` | `preserve`      | `~/.config/zsh`              | Physical directory owned by villalj:staff, mode 0700; runtime files remain regular and managed files are relative links. | `no`                     |
| `~/.zshenv`                       | `yes`  | `no`    | `no`    | `target`         | Current symlink resolves to `dev/personal/dot/.zshenv`, which defines the XDG variables and `ZDOTDIR`.   | `active-global` | `preserve`      | `none`                       | Symlink `lrwxr-xr-x`, owner/group `villalj:staff`; leave this entry and its source unchanged in this boundary.           | `no`                     |

Runtime protection and destination plan:

- Do not copy `.zsh_history` or `.zcompdump` into `~/dev/personal/dot/home/`, into the new
  declaration, or into any research artifact. Do not print, parse, or include
  their contents in logs.
- Confirm the current `~/.config/zsh` link resolves exactly to
  `../dev/personal/dot/.config/zsh` before changing it. Stop if it is a
  physical directory, points elsewhere, or contains unexpected entries.
- Preserve the physical `~/.config` parent as `0700 villalj:staff`. Do not use
  a parent-directory symlink. Create `~/.config/zsh` as a real
  `0700 villalj:staff` directory after the old link is detached; mise must
  link files inside this directory rather than replace the directory.
- Move `.zsh_history` to the detached target while preserving `0600` and
  `villalj:staff`. Move `.zcompdump` to the same target while preserving
  `0644` and `villalj:staff`. A move is preferred to a copy so no runtime
  duplicate remains in the repository source; if a copy is required for
  rollback, keep it outside the repository with the same metadata and erase
  it only after verification.
- The configured OMZ cache path `$XDG_CACHE_HOME/omz/.zcompdump` is separate
  tool-owned state and is currently absent; do not create or migrate it as
  part of this boundary. `.zsh_history.LOCK` is also absent; if it appears
  before cutover, stop and preserve it beside the history file with its
  observed mode and owner.
- Keep all six tracked source files in `~/dev/personal/dot/home/.config/zsh/` with their current
  `0644 villalj:staff` source metadata. The target files are relative mise
  symlinks; runtime files remain regular files in the target directory.

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- .config/zsh
git check-ignore -v .config/zsh/.zsh_history
git check-ignore -v .config/zsh/.zcompdump
```

Do not print credential-bearing contents. Record metadata, references, and
target paths only.

## Ownership and cutover

- Current target shape: `physical directory with relative symlink-each links and runtime files`
- Current target manifest path: `~/.config/zsh`
- Old owner cleanup command: `test "$(readlink "$HOME/.config/zsh")" = "../dev/personal/dot/.config/zsh" && rm "$HOME/.config/zsh"`
- New owner dry-run command: `mise bootstrap dotfiles apply --dry-run`
- New owner apply command: `mise bootstrap dotfiles apply --yes`
- Duplicate-owner check: `stow -nvR . --target="$HOME" 2>&1 | grep -F -- '.config/zsh'` must return no Zsh ownership proposal after the old source is retired.
- Target-content disposition check: `find "$HOME/.config/zsh" -mindepth 1 -maxdepth 1 -print | sort` must show only the two preserved runtime files and the six intended mise-managed entries, with no unexpected physical content.
- Relative-link check: `find "$HOME/.config/zsh" -type l -exec sh -c 'for link do case "$(readlink "$link")" in /*) exit 1;; esac; done' sh {} +`

## Coupling

- Scripts:
  - `scripts/init.zsh` sources the repository `.zshenv`, then can invoke both
    `scripts/symlink.zsh` for Stow and `scripts/mise.zsh` for mise. Keep the
    existing order and do not add a new phase; the existing mise dotfiles
    phase applies the new declaration.
  - `scripts/symlink.zsh` currently runs `stow -vR .`; retire the old
    `.config/zsh` Stow ownership before applying per-file mise links.
  - `scripts/mise.zsh` applies `mise bootstrap dotfiles apply --yes`; preserve
    this existing initialization wiring.
  - `scripts/zsh.zsh` installs and updates Oh My Zsh and external plugins under
    `~/.config/oh-my-zsh`; it does not own the local Zsh source files. Keep
    its plugin and theme behavior separate from this boundary.
- Environment variables:
  - `.zshenv` sets `XDG_CONFIG_HOME="$HOME/.config"` and
    `ZDOTDIR="$XDG_CONFIG_HOME/zsh"`; preserve both values.
  - `.zshrc` sets `ZSH="$XDG_CONFIG_HOME/oh-my-zsh"`,
    `ZSH_CACHE_DIR="$XDG_CACHE_HOME/omz"`, and
    `ZSH_COMPDUMP="$ZSH_CACHE_DIR/.zcompdump"`; do not confuse this cache
    path with the ignored source-side `.zcompdump`.
  - `.zshrc` also reads `FZF_DEFAULT_OPTS_FILE`, `LG_CONFIG_FILE`,
    and `RIPGREP_CONFIG_PATH` below the XDG target.
- Includes or external paths:
  - `.zshrc` sources `custom_functions.zsh`, `.aliases`, `.p10k.zsh`,
    `plugins/zsh-vi-mode/config.zsh`, WezTerm shell integration and
    completion files, Docker's `~/.docker/init-zsh.sh`, and
    `~/.config/oh-my-zsh/oh-my-zsh.sh`.
  - `bootstrap-repos.toml` owns external Oh My Zsh plugin repositories,
    including `zsh-vi-mode`; retain that separate repository ownership.
  - The 1Password SSH agent socket is machine-local runtime state referenced
    by `.zshrc`; it is not part of this source boundary.
- Other modules:
  - `MIG-MODULE-mise` supplies the mise control plane and dotfiles phase.
  - `MIG-MODULE-bat`, `MIG-MODULE-btop`, and `MIG-MODULE-delta` are recorded
    as prerequisites in the module registry for terminal theme/bootstrap
    coupling. `wezterm`, `fzf`, `lazygit`, and `ripgrep` are target paths read
    by `.zshrc` and must remain available.
- User-facing behavior:
  - New shells must continue to load the same Zsh configuration through
    `ZDOTDIR`; tracked edits remain visible through relative mise links.
    History and completion state must remain machine-local and writable
    without modifying repository sources.

## Validation

- Syntax or source checks:
  - `zsh -n ~/dev/personal/dot/home/.config/zsh/.zprofile`
  - `zsh -n ~/dev/personal/dot/home/.config/zsh/.zshrc`
  - `zsh -n ~/dev/personal/dot/home/.config/zsh/custom_functions.zsh`
  - `zsh -n ~/dev/personal/dot/home/.config/zsh/plugins/zsh-vi-mode/config.zsh`
  - Compare the six tracked paths from `git ls-files -- home/.config/zsh` with the
    six copied paths under `~/dev/personal/dot/home/.config/zsh`; assert that runtime files are
    absent from `~/dev/personal/dot/home/`.
- Focused test:
  - `tests/scripts/test_mise_bootstrap_zsh.zsh` (planned module test; it must assert the Zsh source manifest,
    `symlink-each` mode, `ZDOTDIR`, runtime exclusions, and one-owner
    behavior).
- Target smoke test:
  - After cutover, run `ZDOTDIR="$HOME/.config/zsh" zsh -lic 'exit'` and
    verify that the shell starts without missing-source errors. Defer this
    until the target is detached and the six mise links plus both runtime
    files are present.
- Security or token check:
  - `test ! -e ~/dev/personal/dot/home/.config/zsh/.zsh_history && test ! -e ~/dev/personal/dot/home/.config/zsh/.zcompdump`
  - `git check-ignore -q --no-index .config/zsh/.zsh_history && git check-ignore -q --no-index .config/zsh/.zcompdump`
  - Verify runtime file modes and owners with `stat`; do not read their
    contents.
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - Save the six-file source manifest, the two runtime file `stat` records,
    the `~/.config` metadata, and the exact target-link result
    `readlink "$HOME/.config/zsh"` outside the repository. Do not save runtime
    contents in the repository.
- Rollback dry run:
  - `mise bootstrap dotfiles unapply --dry-run`
- Rollback apply:
  - After the dry run names only this module's links, run
    `mise bootstrap dotfiles unapply --yes`, restore the guarded Stow link,
    move the runtime files back to `.config/zsh` with their recorded metadata,
    and run `stow -R . --target="$HOME"`.
- Stop condition:
  - Stop if the target is not the expected Stow link before cleanup, if any
    physical target content is not in the recorded manifest, if runtime
    permissions or ownership change unexpectedly, if a secret-bearing file is
    found in `~/dev/personal/dot/home/`, or if either mise or Stow proposes ownership outside
    this boundary.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `.stowrc` targets `$HOME`; `.stow-local-ignore` does not currently exclude
    this boundary or its runtime files.
  - `~/.config/zsh` is the confirmed whole-directory Stow link
    `../dev/personal/dot/.config/zsh`.
  - `.zshenv` confirms `ZDOTDIR="$XDG_CONFIG_HOME/zsh"`.
  - The roadmap assigns only the six tracked source files to mise and
    explicitly excludes `.zsh_history` and `.zcompdump`.
  - No non-ignored untracked paths exist under `.config/zsh`.
- Residual risk:
  - `.zsh_history` is sensitive local data and must be moved without content
    exposure. `.zcompdump` is generated runtime state whose existing location
    differs from the configured OMZ cache path. The current parent symlink must
    be detached before applying `symlink-each` to prevent write-through to the
    repository.
- Open blocker:
  - None. The guarded detach-and-move transition preserved both runtime files
    and the new mise links.
