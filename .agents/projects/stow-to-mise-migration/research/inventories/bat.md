# Module Inventory: `bat`

## Metadata

- Module key: `bat`
- Story key: `MIG-MODULE-bat`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/bat.md`
- Current declaration: `.stowrc` (`--target=~`) with `.config/bat` as a repository-root Stow source
- New declaration: `~/dev/personal/dot/home/.config/mise/conf.d/module.bat.toml`
- Current owner: `stow`
- New owner: `mise`
- Target root: `~/.config/bat`
- Mise mode: `symlink-each`
- Environment selector: `bat`
- Dependencies: `MIG-MODULE-mise`
- Approval state: `approved`
- Inventory status: `complete`

## Scope manifest

| Source path                                   | Tracked | Ignored | Current owner | Current target                                  | Target disposition | New source path                                                       | New target                                      | New mode       | Notes                                                                |
| --------------------------------------------- | ------- | ------- | ------------- | ----------------------------------------------- | ------------------ | --------------------------------------------------------------------- | ----------------------------------------------- | -------------- | -------------------------------------------------------------------- |
| `.config/bat/config`                          | `yes`   | `no`    | `stow`        | `~/.config/bat/config`                          | `migrate`          | `~/dev/personal/dot/home/.config/bat/config`                          | `~/.config/bat/config`                          | `symlink-each` | Selects the `Catppuccin Mocha` bat theme.                            |
| `.config/bat/themes/Catppuccin Mocha.tmTheme` | `yes`   | `no`    | `stow`        | `~/.config/bat/themes/Catppuccin Mocha.tmTheme` | `migrate`          | `~/dev/personal/dot/home/.config/bat/themes/Catppuccin Mocha.tmTheme` | `~/.config/bat/themes/Catppuccin Mocha.tmTheme` | `symlink-each` | Tracked theme source; do not download or modify it during inventory. |

## Local and runtime inventory

| Path                         | Exists | Tracked | Ignored | Current location | Active use evidence                                                     | Classification  | Required action | Runtime destination          | Metadata to preserve                                                   | Secret or sensitive data |
| ---------------------------- | ------ | ------- | ------- | ---------------- | ----------------------------------------------------------------------- | --------------- | --------------- | ---------------------------- | ---------------------------------------------------------------------- | ------------------------ |
| `.config/bat`                | `no`   | `no`    | `no`    | `historical`     | Retired Stow source; the two files moved to `home/.config/bat`.         | `historical`    | `remove`        | `none`                       | `retired source path`                                                  | `no`                     |
| `~/.config/bat`              | `yes`  | `no`    | `no`    | `target`         | Physical directory with two relative per-file links to the mise source. | `active-global` | `preserve`      | `~/.config/bat`              | Physical directory, owner `villalj:staff`, mode `0755`; relative links | `no`                     |
| `~/.cache/bat/metadata.yaml` | `yes`  | `no`    | `no`    | `other`          | `bat --cache-dir` reports `~/.cache/bat`; file is present.              | `active-global` | `exclude`       | `~/.cache/bat/metadata.yaml` | `0644`, owner `villalj:staff`                                          | `no`                     |
| `~/.cache/bat/syntaxes.bin`  | `yes`  | `no`    | `no`    | `other`          | `bat --cache-dir` reports `~/.cache/bat`; file is present.              | `active-global` | `exclude`       | `~/.cache/bat/syntaxes.bin`  | `0644`, owner `villalj:staff`                                          | `no`                     |
| `~/.cache/bat/themes.bin`    | `yes`  | `no`    | `no`    | `other`          | `bat --cache-dir` reports `~/.cache/bat`; file is present.              | `active-global` | `exclude`       | `~/.cache/bat/themes.bin`    | `0644`, owner `villalj:staff`                                          | `no`                     |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- .config/bat
git check-ignore -v <path>
```

The first command returned no paths, and the second command returned no
matches for the source boundary. There are no target-only files under
`~/.config/bat`; the target contains only `config` and
`themes/Catppuccin Mocha.tmTheme`, as per-file mise links.
The cache files are outside the target and remain tool-owned runtime state.
Do not print credential-bearing contents. Record metadata, references, and
target paths only.

## Ownership and cutover

- Current target shape: `physical directory with relative symlink-each links`
- Current target manifest path: `~/.config/bat`
- Old owner cleanup command: `target="${XDG_CONFIG_HOME:-$HOME/.config}/bat"; test -L "$target" && test "$(readlink "$target")" = "../dev/personal/dot/.config/bat" && rm "$target"`
- New owner dry-run command: `mise -E bat bootstrap dotfiles apply --dry-run`
- New owner apply command: `mise -E bat bootstrap dotfiles apply --yes`
- Duplicate-owner check: `if stow -nvR . 2>&1 | grep -Fq '.config/bat'; then exit 1; fi`
- Target-content disposition check: `target="${XDG_CONFIG_HOME:-$HOME/.config}/bat"; source="$HOME/dev/personal/dot/home/.config/bat"; test -f "$target/config" && test -f "$target/themes/Catppuccin Mocha.tmTheme" && test -z "$(comm -23 <(find -H "$target" -type f -print | sed "s#^$target/##" | sort) <(find "$source" -type f -print | sed "s#^$source/##" | sort))"`
- Relative-link check: `target="${XDG_CONFIG_HOME:-$HOME/.config}/bat"; find "$target" -type l -exec readlink {} \; | grep -q '^/' && exit 1 || true`

## Coupling

- Scripts:
  - `scripts/zsh.zsh`: the bat theme refresh currently writes through
    the tracked
    `~/dev/personal/dot/home/.config/bat/themes/Catppuccin Mocha.tmTheme` source.
    Keep `bat cache --build` for standalone `./scripts/init.zsh --zsh` runs.
  - `scripts/symlink.zsh`: the `stow -vR .` phase currently owns the
    whole-directory target; it must not recreate the target after the Stow
    source is retired or excluded.
  - `scripts/mise.zsh`: the existing mise dotfiles phase already applies the
    module; no new initialization phase is required. The module's
    `post-dotfiles = "bat cache --build"` hook must run after the per-file
    links apply.
- Environment variables:
  - `XDG_CONFIG_HOME` controls the current bat configuration directory and
    the existing target paths used by `scripts/zsh.zsh`.
  - `FZF_DEFAULT_OPTS_FILE` is set by `.config/zsh/.zshrc` to
    `~/.config/fzf/fzf.conf`; that file uses bat for previews.
  - `MISE_ENV=bat` or `mise -E bat` selects the bat module environment.
- Includes or external paths:
  - `~/.cache/bat` is generated by bat and remains outside tracked sources
    and mise declarations.
  - `scripts/zsh.zsh` references the public Catppuccin bat theme URL. No
    download was run for this inventory.
- Other modules:
  - `fzf`: `.config/fzf/fzf.conf` runs `bat --color=always` for previews, so
    `~/.config/bat` must remain available when fzf is used.
  - `delta`: `.config/delta/themes/catppuccin.gitconfig` names
    `Catppuccin Mocha` as the matching bat syntax theme.
  - `zsh`: `.config/zsh/.aliases` aliases `cat` to bat, and the zsh module
    depends on `MIG-MODULE-bat`.
  - `mise`: the control-plane module must be applied before this module.
- User-facing behavior:
  - Preserve the `Catppuccin Mocha` default theme, fzf previews, the `cat`
    alias, and the generated bat cache. Keep live edits visible through
    relative per-file symlinks.

## Validation

- Syntax or source checks:
  - `test -f home/.config/bat/config && test -f 'home/.config/bat/themes/Catppuccin Mocha.tmTheme'`
  - `test -f "$HOME/dev/personal/dot/home/.config/bat/config" && test -f "$HOME/dev/personal/dot/home/.config/bat/themes/Catppuccin Mocha.tmTheme"`
  - `zsh -n scripts/zsh.zsh`
- Focused test:
  - `tests/scripts/test_mise_bootstrap_bat.zsh` (planned; assert the bat source
    paths, `symlink-each` declaration, `bat` post-dotfiles hook,
    source-only theme download destination, exclusion of cache files, and
    one-owner boundary)
- Target smoke test:
  - `bat --list-themes | grep -Fx 'Catppuccin Mocha'`
- Security or token check:
  - `! git grep -nEi '(password|secret|token|api[_-]?key|private[_-]?key)' -- home/.config/bat`
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - Record `git ls-files --stage -- .config/bat`, the `find -H` source and
    target manifests, `ls -ld ~/.config/bat`, and `readlink ~/.config/bat`.
    Leave `~/.cache/bat` untouched.
- Rollback dry run: `mise -E bat bootstrap dotfiles unapply --dry-run`
- Rollback apply: `mise -E bat bootstrap dotfiles unapply --yes && stow -vR .`
- Stop condition: Stop if unapply names any target outside `~/.config/bat`, if
  the target contains unmanaged files, or if Stow cannot recreate the
  recorded whole-directory link without overwriting local content.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `.config/bat/config` and
    `.config/bat/themes/Catppuccin Mocha.tmTheme` are the only tracked source
    files.
  - `git ls-files --others --ignored --exclude-standard -- .config/bat`
    returned no ignored files.
  - `~/.config/bat` is a whole-directory relative symlink to the Stow source,
    and the target contains no target-only files.
  - `bat --config-dir` resolves to `~/.config/bat`; `bat --cache-dir` resolves
    to `~/.cache/bat`, where metadata, syntax, and theme caches are present.
  - `scripts/zsh.zsh` downloads the bat theme through the current target and
    then runs `bat cache --build`.
- Residual risk:
  - The migration must redirect the theme refresh to the tracked mise source
    before detaching the Stow link. The cache hook must run after the new
    symlinks apply, and the cache must remain outside tracked sources.
- Open blocker: Migration approval and the planned module-focused test are
  still pending; do not apply the ownership cutover from this inventory alone.
