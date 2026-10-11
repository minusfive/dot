# Module Inventory: `ghostty`

## Metadata

- Module key: `ghostty`
- Story key: `MIG-MODULE-ghostty`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/ghostty.md`
- Current declaration: `.stowrc` plus the root Stow package (`stow -vR .`)
- New declaration: `home/.config/mise/conf.d/module.ghostty.toml`
- Current owner: `stow`
- New owner: `mise`
- Target root: `~/.config/ghostty`
- Mise mode: `symlink-each`
- Environment selector: `ghostty`
- Dependencies: `MIG-MODULE-mise`
- Approval state: `pending`
- Inventory status: `complete`

## Scope manifest

| Source path                                                | Tracked | Ignored | Current owner | Current target                                               | Target disposition | New source path                                                 | New target                                                   | New mode       | Notes                                                                    |
| ---------------------------------------------------------- | ------- | ------- | ------------- | ------------------------------------------------------------ | ------------------ | --------------------------------------------------------------- | ------------------------------------------------------------ | -------------- | ------------------------------------------------------------------------ |
| `.config/ghostty/config`                                   | `yes`   | `no`    | `stow`        | `~/.config/ghostty/config`                                   | `migrate`          | `home/.config/ghostty/config`                                   | `~/.config/ghostty/config`                                   | `symlink-each` | Tracked Ghostty configuration; line 5 references the target shader path. |
| `.config/ghostty/shaders/cursor_smear.glsl`                | `yes`   | `no`    | `stow`        | `~/.config/ghostty/shaders/cursor_smear.glsl`                | `migrate`          | `home/.config/ghostty/shaders/cursor_smear.glsl`                | `~/.config/ghostty/shaders/cursor_smear.glsl`                | `symlink-each` | Tracked shader; preserve the `shaders/` directory layout.                |
| `.config/ghostty/shaders/cursor_smear_fade.glsl`           | `yes`   | `no`    | `stow`        | `~/.config/ghostty/shaders/cursor_smear_fade.glsl`           | `migrate`          | `home/.config/ghostty/shaders/cursor_smear_fade.glsl`           | `~/.config/ghostty/shaders/cursor_smear_fade.glsl`           | `symlink-each` | Tracked shader; preserve the `shaders/` directory layout.                |
| `.config/ghostty/shaders/cursor_synesthaxia(tweened).glsl` | `yes`   | `no`    | `stow`        | `~/.config/ghostty/shaders/cursor_synesthaxia(tweened).glsl` | `migrate`          | `home/.config/ghostty/shaders/cursor_synesthaxia(tweened).glsl` | `~/.config/ghostty/shaders/cursor_synesthaxia(tweened).glsl` | `symlink-each` | Tracked shader named by the `custom-shader` setting.                     |

## Local and runtime inventory

| Path                                                       | Exists | Tracked | Ignored | Current location | Active use evidence                                                                                  | Classification  | Required action   | Runtime destination                                          | Metadata to preserve                         | Secret or sensitive data |
| ---------------------------------------------------------- | ------ | ------- | ------- | ---------------- | ---------------------------------------------------------------------------------------------------- | --------------- | ----------------- | ------------------------------------------------------------ | -------------------------------------------- | ------------------------ |
| `.config/ghostty/config`                                   | `yes`  | `yes`   | `no`    | `repo`           | `custom-shader` points to `~/.config/ghostty/shaders/cursor_synesthaxia(tweened).glsl`               | `active-global` | `copy-then-erase` | `~/.config/ghostty/config`                                   | `0644`, `villalj:staff`                      | `no`                     |
| `.config/ghostty/shaders/cursor_smear.glsl`                | `yes`  | `yes`   | `no`    | `repo`           | Included in the active target shader directory                                                       | `active-global` | `copy-then-erase` | `~/.config/ghostty/shaders/cursor_smear.glsl`                | `0644`, `villalj:staff`                      | `no`                     |
| `.config/ghostty/shaders/cursor_smear_fade.glsl`           | `yes`  | `yes`   | `no`    | `repo`           | Included in the active target shader directory                                                       | `active-global` | `copy-then-erase` | `~/.config/ghostty/shaders/cursor_smear_fade.glsl`           | `0644`, `villalj:staff`                      | `no`                     |
| `.config/ghostty/shaders/cursor_synesthaxia(tweened).glsl` | `yes`  | `yes`   | `no`    | `repo`           | Named by the active `custom-shader` setting                                                          | `active-global` | `copy-then-erase` | `~/.config/ghostty/shaders/cursor_synesthaxia(tweened).glsl` | `0644`, `villalj:staff`                      | `no`                     |
| `~/.config/ghostty`                                        | `yes`  | `no`    | `no`    | `target`         | Whole-directory symlink to `../dev/personal/dot/.config/ghostty`; target files are active through it | `active-global` | `preserve`        | `~/.config/ghostty`                                          | Parent symlink; source directory mode `0755` | `no`                     |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- <boundary>
git check-ignore -v <path>
```

Do not print credential-bearing contents. Record metadata, references, and
target paths only.

## Ownership and cutover

- Current target shape: `whole-directory symlink`
- Current target manifest path: `~/.config/ghostty` (the parent link; inspect with `find -L "$HOME/.config/ghostty" -maxdepth 2 -print | sort`)
- Old owner cleanup command: `test "$(readlink "$HOME/.config/ghostty")" = "../dev/personal/dot/.config/ghostty" && unlink "$HOME/.config/ghostty"`
- New owner dry-run command: `mise bootstrap dotfiles apply --dry-run`
- New owner apply command: `mise bootstrap dotfiles apply`
- Duplicate-owner check: `test ! -e .config/ghostty && mise bootstrap dotfiles status | grep -F '.config/ghostty' && ! stow -nvR . 2>&1 | grep -F '.config/ghostty'`
- Target-content disposition check: `find -L "$HOME/.config/ghostty" -maxdepth 2 -type f -print | sort`
- Relative-link check: `find "$HOME/.config/ghostty" -type l -exec sh -c 'for path do case "$(readlink "$path")" in /*) exit 1;; esac; done' sh {} +`

## Coupling

- Scripts:
  - `none; no repository script references the Ghostty configuration boundary`
- Environment variables:
  - `none`
- Includes or external paths:
  - `~/.config/ghostty/shaders/cursor_synesthaxia(tweened).glsl` from `.config/ghostty/config` line 5; preserve the target-relative shader path and filename
- Other modules:
  - `MIG-MODULE-mise` supplies the mise control plane; the packages boundary installs `brew-cask:ghostty` separately
- User-facing behavior:
  - Preserve Ghostty theme, font, split, keybind, shell-integration, and custom-shader behavior with no intentional configuration change.

## Validation

- Syntax or source checks:
  - `git ls-files -- .config/ghostty && grep -Fx 'custom-shader = ~/.config/ghostty/shaders/cursor_synesthaxia(tweened).glsl' .config/ghostty/config`
- Focused test:
  - `tests/scripts/test_mise_bootstrap_ghostty.zsh` (planned module test;
    runtime smoke remains deferred because the binary is unavailable)
- Target smoke test:
  - `command -v ghostty && ghostty --version` (deferred: the Ghostty binary is not installed on this machine)
- Security or token check:
  - `! rg -n -i '(api[_-]?key|token|password|secret|private[ -]?key|auth\.db)' .config/ghostty`
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `readlink "$HOME/.config/ghostty"; find -L "$HOME/.config/ghostty" -maxdepth 2 -print | sort; retain .config/ghostty until the mise dry run and target manifest checks pass`
- Rollback dry run:
  - `mise bootstrap dotfiles unapply --dry-run`
- Rollback apply:
  - `mise bootstrap dotfiles unapply && ./scripts/init.zsh --link`
- Stop condition:
  - `Stop if the mise dry run proposes an unrelated target, the post-detach manifest differs from the preserved manifest, or the custom shader path is missing.`

## Findings and decisions

- Decision: `approved`
- Decision evidence:
  - `module-registry.toml` assigns ghostty to story `MIG-MODULE-ghostty` with
    a dependency on `MIG-MODULE-mise`.
  - `plans/migration-roadmap-v1.md` defines the four tracked source files and the module declaration.
  - `stow -nvR .` reports the current `.config/ghostty` parent link and no Ghostty-specific conflict.
- Residual risk:
  - `The current whole-directory Stow link must be detached before per-file mise links are applied; the Ghostty binary is unavailable for a runtime smoke test.`
- Open blocker:
  - `Ghostty target smoke test is deferred because command -v ghostty returns no executable; source, declaration, and ownership checks remain available.`
