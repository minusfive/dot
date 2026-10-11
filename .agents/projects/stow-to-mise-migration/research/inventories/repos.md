# Module Inventory: `repos`

## Metadata

- Module key: `repos`
- Story key: `MIG-MODULE-repos`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/repos.md`
- Current declaration: `.config/mise/conf.d/bootstrap-repos.toml`
- New declaration: `home/.config/mise/conf.d/module.repos.toml`
- Current owner: `mise`
- New owner: `mise`
- Target root: `none`
- Mise mode: `bootstrap repos`
- Environment selector: `repos`
- Dependencies: `MIG-MODULE-packages`
- Approval state: `pending`
- Inventory status: `complete`

## Scope manifest

| Source path                                                         | Tracked | Ignored | Current owner | Current target                                                | Target disposition | New source path                                                     | New target                                                    | New mode          | Notes                                                                                                                                                                                                               |
| ------------------------------------------------------------------- | ------- | ------- | ------------- | ------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------- | ------------------------------------------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `https://github.com/romkatv/powerlevel10k.git`                      | `yes`   | `no`    | `mise`        | `~/.config/oh-my-zsh/custom/themes/powerlevel10k`             | `migrate`          | `https://github.com/romkatv/powerlevel10k.git`                      | `~/.config/oh-my-zsh/custom/themes/powerlevel10k`             | `bootstrap repos` | Preserve checkout; no configured ref. `apply` clones missing repositories and checks out configured refs. `update` fast-forwards this repository. Dirty checkouts stop the operation unless `--skip-dirty` is used. |
| `https://github.com/zdharma-continuum/fast-syntax-highlighting.git` | `yes`   | `no`    | `mise`        | `~/.config/oh-my-zsh/custom/plugins/fast-syntax-highlighting` | `migrate`          | `https://github.com/zdharma-continuum/fast-syntax-highlighting.git` | `~/.config/oh-my-zsh/custom/plugins/fast-syntax-highlighting` | `bootstrap repos` | Preserve checkout; no configured ref. `apply` clones missing repositories and checks out configured refs. `update` fast-forwards this repository. Dirty checkouts stop the operation unless `--skip-dirty` is used. |
| `https://github.com/zsh-users/zsh-autosuggestions.git`              | `yes`   | `no`    | `mise`        | `~/.config/oh-my-zsh/custom/plugins/zsh-autosuggestions`      | `migrate`          | `https://github.com/zsh-users/zsh-autosuggestions.git`              | `~/.config/oh-my-zsh/custom/plugins/zsh-autosuggestions`      | `bootstrap repos` | Preserve checkout; no configured ref. `apply` clones missing repositories and checks out configured refs. `update` fast-forwards this repository. Dirty checkouts stop the operation unless `--skip-dirty` is used. |
| `https://github.com/Aloxaf/fzf-tab.git`                             | `yes`   | `no`    | `mise`        | `~/.config/oh-my-zsh/custom/plugins/fzf-tab`                  | `migrate`          | `https://github.com/Aloxaf/fzf-tab.git`                             | `~/.config/oh-my-zsh/custom/plugins/fzf-tab`                  | `bootstrap repos` | Preserve checkout; no configured ref. `apply` clones missing repositories and checks out configured refs. `update` fast-forwards this repository. Dirty checkouts stop the operation unless `--skip-dirty` is used. |
| `https://github.com/Freed-Wu/fzf-tab-source.git`                    | `yes`   | `no`    | `mise`        | `~/.config/oh-my-zsh/custom/plugins/fzf-tab-source`           | `migrate`          | `https://github.com/Freed-Wu/fzf-tab-source.git`                    | `~/.config/oh-my-zsh/custom/plugins/fzf-tab-source`           | `bootstrap repos` | Preserve checkout; no configured ref. `apply` clones missing repositories and checks out configured refs. `update` fast-forwards this repository. Dirty checkouts stop the operation unless `--skip-dirty` is used. |
| `https://github.com/jeffreytse/zsh-vi-mode.git`                     | `yes`   | `no`    | `mise`        | `~/.config/oh-my-zsh/custom/plugins/zsh-vi-mode`              | `migrate`          | `https://github.com/jeffreytse/zsh-vi-mode.git`                     | `~/.config/oh-my-zsh/custom/plugins/zsh-vi-mode`              | `bootstrap repos` | Preserve checkout; no configured ref. `apply` clones missing repositories and checks out configured refs. `update` fast-forwards this repository. Dirty checkouts stop the operation unless `--skip-dirty` is used. |
| `https://github.com/Pilaton/OhMyZsh-full-autoupdate.git`            | `yes`   | `no`    | `mise`        | `~/.config/oh-my-zsh/custom/plugins/ohmyzsh-full-autoupdate`  | `migrate`          | `https://github.com/Pilaton/OhMyZsh-full-autoupdate.git`            | `~/.config/oh-my-zsh/custom/plugins/ohmyzsh-full-autoupdate`  | `bootstrap repos` | Preserve checkout; no configured ref. `apply` clones missing repositories and checks out configured refs. `update` fast-forwards this repository. Dirty checkouts stop the operation unless `--skip-dirty` is used. |
| `git@github.com:minusfive/LazyVim.git`                              | `yes`   | `no`    | `mise`        | `~/dev/personal/nvim-plugins/LazyVim`                         | `migrate`          | `git@github.com:minusfive/LazyVim.git`                              | `~/dev/personal/nvim-plugins/LazyVim`                         | `bootstrap repos` | Preserve checkout at configured ref `minusfive`. `apply` checks out the configured ref. `update` checks out that ref. Dirty checkouts stop the operation unless `--skip-dirty` is used.                             |

## Local and runtime inventory

| Path                                                          | Exists | Tracked | Ignored | Current location | Active use evidence                                                                                                                                       | Classification  | Required action | Runtime destination                                           | Metadata to preserve                                                                             | Secret or sensitive data |
| ------------------------------------------------------------- | ------ | ------- | ------- | ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------- | --------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | ------------------------ |
| `~/.config/oh-my-zsh/custom/themes/powerlevel10k`             | `yes`  | `no`    | `no`    | `target`         | `.config/zsh/.zshrc` sets `ZSH_THEME="powerlevel10k/powerlevel10k"`                                                                                       | `active-global` | `preserve`      | `~/.config/oh-my-zsh/custom/themes/powerlevel10k`             | Git history, remote, current branch, configured URL, and directory mode `drwxr-xr-x`             | `unknown`                |
| `~/.config/oh-my-zsh/custom/plugins/fast-syntax-highlighting` | `yes`  | `no`    | `no`    | `target`         | `.config/zsh/.zshrc` loads `fast-syntax-highlighting`                                                                                                     | `active-global` | `preserve`      | `~/.config/oh-my-zsh/custom/plugins/fast-syntax-highlighting` | Git history, remote, current branch, configured URL, and directory mode `drwxr-xr-x`             | `unknown`                |
| `~/.config/oh-my-zsh/custom/plugins/zsh-autosuggestions`      | `yes`  | `no`    | `no`    | `target`         | `.config/zsh/.zshrc` loads `zsh-autosuggestions`                                                                                                          | `active-global` | `preserve`      | `~/.config/oh-my-zsh/custom/plugins/zsh-autosuggestions`      | Git history, remote, current branch, configured URL, and directory mode `drwxr-xr-x`             | `unknown`                |
| `~/.config/oh-my-zsh/custom/plugins/fzf-tab`                  | `yes`  | `no`    | `no`    | `target`         | `.config/zsh/.zshrc` loads `fzf-tab`                                                                                                                      | `active-global` | `preserve`      | `~/.config/oh-my-zsh/custom/plugins/fzf-tab`                  | Git history, remote, current branch, configured URL, and directory mode `drwxr-xr-x`             | `unknown`                |
| `~/.config/oh-my-zsh/custom/plugins/fzf-tab-source`           | `yes`  | `no`    | `no`    | `target`         | `.config/zsh/.zshrc` loads `fzf-tab-source`                                                                                                               | `active-global` | `preserve`      | `~/.config/oh-my-zsh/custom/plugins/fzf-tab-source`           | Git history, remote, current branch, configured URL, and directory mode `drwxr-xr-x`             | `unknown`                |
| `~/.config/oh-my-zsh/custom/plugins/zsh-vi-mode`              | `yes`  | `no`    | `no`    | `target`         | `.config/zsh/.zshrc` loads `zsh-vi-mode` and its config file                                                                                              | `active-global` | `preserve`      | `~/.config/oh-my-zsh/custom/plugins/zsh-vi-mode`              | Git history, remote, current branch, configured URL, and directory mode `drwxr-xr-x`             | `unknown`                |
| `~/.config/oh-my-zsh/custom/plugins/ohmyzsh-full-autoupdate`  | `yes`  | `no`    | `no`    | `target`         | `.config/zsh/.zshrc` loads the plugin; `scripts/zsh.zsh` sources it to update custom plugins and themes                                                   | `active-global` | `preserve`      | `~/.config/oh-my-zsh/custom/plugins/ohmyzsh-full-autoupdate`  | Git history, remote, current branch, configured URL, and directory mode `drwxr-xr-x`             | `unknown`                |
| `~/dev/personal/nvim-plugins/LazyVim`                         | `yes`  | `no`    | `no`    | `target`         | `.config/nvim/lua/config/lazy.lua` adds `~/dev/personal/nvim-plugins` as a local plugin path; `.config/nvim/lua/plugins/core.lua` loads `LazyVim/LazyVim` | `active-global` | `preserve`      | `~/dev/personal/nvim-plugins/LazyVim`                         | Git history, remote, configured ref `minusfive`, current branch, and directory mode `drwxr-xr-x` | `unknown`                |

Record ignored paths with:

```bash
git ls-files --others --ignored --exclude-standard -- .config/mise/conf.d/bootstrap-repos.toml
git check-ignore -v .config/mise/conf.d/bootstrap-repos.toml
```

The declaration is tracked and not ignored. The eight target paths are
independent Git checkouts outside the dotfiles repository. Their contents were
not copied or printed; treat their contents as unknown until a separate
content-level review is approved.

## Ownership and cutover

- Current target shape: `physical directory`
- Current target manifest path: `.config/mise/conf.d/bootstrap-repos.toml`
- Old owner cleanup command: `mise bootstrap unapply repos --dry-run` (unapply does not remove repositories; it only reports that repository cleanup is separate)
- New owner dry-run command: `mise bootstrap repos apply --dry-run`
- New owner apply command: `mise bootstrap repos apply --yes`
- Duplicate-owner check: `test "$(git grep -lE 'powerlevel10k|fast-syntax-highlighting|zsh-autosuggestions|fzf-tab|fzf-tab-source|zsh-vi-mode|ohmyzsh-full-autoupdate|LazyVim' -- .config/mise home/.config/mise 2>/dev/null | grep -E 'bootstrap-repos|module\.repos' | wc -l | tr -d ' ')" -eq 1`
- Target-content disposition check: `XDG_CONFIG_HOME="$PWD/.config" mise -C "$PWD" bootstrap repos status`
- Relative-link check: `for path in "$HOME/.config/oh-my-zsh/custom/themes/powerlevel10k" "$HOME/.config/oh-my-zsh/custom/plugins/fast-syntax-highlighting" "$HOME/.config/oh-my-zsh/custom/plugins/zsh-autosuggestions" "$HOME/.config/oh-my-zsh/custom/plugins/fzf-tab" "$HOME/.config/oh-my-zsh/custom/plugins/fzf-tab-source" "$HOME/.config/oh-my-zsh/custom/plugins/zsh-vi-mode" "$HOME/.config/oh-my-zsh/custom/plugins/ohmyzsh-full-autoupdate" "$HOME/dev/personal/nvim-plugins/LazyVim"; do test ! -L "$path"; done`

The declaration move changes only the mise configuration source location. Do
not replace, copy, or delete the existing Git checkouts during the cutover.

## Coupling

- Scripts:
  - `scripts/mise.zsh`: runs `mise bootstrap repos apply --yes` after tools and before dotfiles; no phase change is required.
  - `scripts/zsh.zsh`: the Oh My Zsh full-autoupdate plugin updates custom plugins and themes; preserve its target path.
- Environment variables:
  - `XDG_CONFIG_HOME`, `ZSH`, `ZSH_CUSTOM`, `ZSH_THEME`, and the Oh My Zsh `plugins` list in `.config/zsh/.zshrc`.
  - The Neovim local plugin path in `.config/nvim/lua/config/lazy.lua` is `~/dev/personal/nvim-plugins`.
- Includes or external paths:
  - `.config/zsh/.zshrc` consumes the seven Oh My Zsh repositories.
  - `.config/zsh/plugins/zsh-vi-mode/config.zsh` is loaded alongside the `zsh-vi-mode` checkout.
  - `.config/nvim/lua/config/lazy.lua` and `.config/nvim/lua/plugins/core.lua` consume the LazyVim checkout.
- Other modules:
  - `zsh` consumes the Oh My Zsh theme and plugins.
  - `nvim` consumes the local LazyVim fork.
- User-facing behavior:
  - Preserve shell startup, prompt rendering, completion, syntax highlighting, vi mode, full-autoupdate behavior, and the local LazyVim `minusfive` ref.
  - Keep repository updates explicit. The initialization flow applies repositories; the full-autoupdate plugin may update custom Oh My Zsh repositories during its existing update flow.

## Validation

- Syntax or source checks:
  - `git ls-files -- .config/mise/conf.d/bootstrap-repos.toml`
  - `XDG_CONFIG_HOME="$PWD/.config" mise -C "$PWD" bootstrap repos status`
  - `XDG_CONFIG_HOME="$PWD/.config" mise -C "$PWD" bootstrap repos apply --dry-run`
- Focused test:
  - `zsh ./tests/scripts/test_mise_bootstrap_repos.zsh`
  - The current test checks five repository names. The status and dry-run checks cover all eight resources and the configured `minusfive` ref.
- Target smoke test:
  - `XDG_CONFIG_HOME="$PWD/.config" mise -C "$PWD" bootstrap repos status`
  - Current result: all eight repositories report `current`; all eight local Git checkouts have zero dirty entries.
- Security or token check:
  - `git diff --check -- .agents/projects/stow-to-mise-migration/research/inventories/repos.md`
  - `grep -nE 'oauth_token|password|BEGIN .*PRIVATE KEY|ghp_|github_pat_' .config/mise/conf.d/bootstrap-repos.toml` must return no matches.
  - Do not print or copy checkout contents. The declaration contains public repository URLs and no credential values.
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `.config/mise/conf.d/bootstrap-repos.toml`, the proposed `home/.config/mise/conf.d/module.repos.toml`, and the eight existing physical Git checkouts with their remotes, refs, and clean-status result.
- Rollback dry run:
  - Restore the saved `.config/mise/conf.d/bootstrap-repos.toml` declaration, then run `mise bootstrap repos apply --dry-run`.
- Rollback apply:
  - With the saved declaration restored and the dry run reviewed, run `mise bootstrap repos apply --yes`.
- Stop condition:
  - Stop on any dirty checkout, non-Git target, origin or ref mismatch, unexpected target removal, or any plan that proposes deleting a repository. `mise bootstrap unapply repos --yes` does not remove repositories; repository cleanup remains a separate, explicitly approved operation.

## Findings and decisions

- Decision: `preserve`
- Decision evidence:
  - `.config/mise/conf.d/bootstrap-repos.toml` declares eight resources under `[bootstrap.repos]`.
  - `XDG_CONFIG_HOME="$PWD/.config" mise -C "$PWD" bootstrap repos status` reports all eight resources as `current`.
  - The existing target paths are physical Git checkouts, not symlinks, and all eight are clean.
  - `scripts/mise.zsh` already applies the repository phase in the required order; no initialization change is needed.
- Residual risk:
  - `mise bootstrap unapply` does not remove repositories. A removed `repos` environment leaves all eight checkouts on disk, so cleanup requires a separate review of each checkout and must preserve dirty work.
  - The current focused test does not assert all eight URLs, the `minusfive` ref, dirty-state handling, or cleanup behavior.
  - Local checkout contents were not inspected for secrets or untracked user data.
- Open blocker:
  - `none for inventory; migration approval remains pending`
