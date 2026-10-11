# Module Inventory: `tools`

## Metadata

- Module key: `tools`
- Story key: `MIG-MODULE-tools`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/tools.md`
- Current declaration: `.config/mise/conf.d/tools.toml`
- New declaration: `home/.config/mise/conf.d/module.tools.toml`
- Current owner: `stow`
- New owner: `mise`
- Target root: `none`
- Mise mode: `tool versions`
- Environment selector: `tools`
- Dependencies: `MIG-MODULE-packages`
- Approval state: `pending`
- Inventory status: `complete`

## Scope manifest

| Source path                                                            | Tracked | Ignored | Current owner | Current target                                           | Target disposition | New source path                                             | New target                                               | New mode        | Notes                                                                                                                      |
| ---------------------------------------------------------------------- | ------- | ------- | ------------- | -------------------------------------------------------- | ------------------ | ----------------------------------------------------------- | -------------------------------------------------------- | --------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `.config/mise/conf.d/tools.toml`                                       | `yes`   | `no`    | `stow`        | `~/.config/mise/conf.d/tools.toml`                       | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `~/.config/mise/conf.d/module.tools.toml`                | `tool versions` | Keep all selectors and hooks unchanged.                                                                                    |
| `.config/mise/conf.d/tools.toml:[tools].rust`                          | `yes`   | `no`    | `mise`        | `none`                                                   | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `none`                                                   | `tool versions` | Selector `nightly`. Lock resolves `nightly-2026-10-09` with backend `core:rust`.                                           |
| `.config/mise/conf.d/tools.toml:[tools].cargo-binstall`                | `yes`   | `no`    | `mise`        | `none`                                                   | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `none`                                                   | `tool versions` | Selector `latest`. Lock resolves `1.24.0` with backend `aqua:cargo-bins/cargo-binstall`.                                   |
| `.config/mise/conf.d/tools.toml:[tools].node`                          | `yes`   | `no`    | `mise`        | `none`                                                   | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `none`                                                   | `tool versions` | Version `25`. Postinstall runs `global-install-packages-npm`. Lock resolves `25.9.0`.                                      |
| `.config/mise/conf.d/tools.toml:[tools].python`                        | `yes`   | `no`    | `mise`        | `none`                                                   | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `none`                                                   | `tool versions` | Version `3.13`. Postinstall runs `global-install-packages-python`. Lock resolves `3.13.16`.                                |
| `.config/mise/conf.d/tools.toml:[tools].ruby`                          | `yes`   | `no`    | `mise`        | `none`                                                   | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `none`                                                   | `tool versions` | Selector `latest`. Postinstall runs `global-install-packages-ruby`. Lock resolves `4.0.7`.                                 |
| `.config/mise/conf.d/tools.toml:[tools].bun`                           | `yes`   | `no`    | `mise`        | `none`                                                   | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `none`                                                   | `tool versions` | Selector `latest`. Lock resolves `1.3.14` with backend `core:bun`.                                                         |
| `.config/mise/conf.d/tools.toml:[tools].go`                            | `yes`   | `no`    | `mise`        | `none`                                                   | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `none`                                                   | `tool versions` | Selector `latest`. Lock resolves `1.27.1` with backend `core:go`.                                                          |
| `.config/mise/conf.d/tools.toml:[tools].uv`                            | `yes`   | `no`    | `mise`        | `none`                                                   | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `none`                                                   | `tool versions` | Selector `latest`. Lock resolves `0.12.22` with backend `aqua:astral-sh/uv`.                                               |
| `.config/mise/conf.d/tools.toml:[tools].delta`                         | `yes`   | `no`    | `mise`        | `none`                                                   | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `none`                                                   | `tool versions` | Selector `latest`. Lock resolves `0.19.2`. `scripts/zsh.zsh` refreshes its theme.                                          |
| `.config/mise/conf.d/tools.toml:[tools].stylua`                        | `yes`   | `no`    | `mise`        | `none`                                                   | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `none`                                                   | `tool versions` | Selector `latest`. Lock resolves `2.5.2`. `hk.pkl` uses the tool.                                                          |
| `.config/mise/conf.d/tools.toml:[tools].prettier`                      | `yes`   | `no`    | `mise`        | `none`                                                   | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `none`                                                   | `tool versions` | Selector `latest`. Lock resolves `3.9.9`. `hk.pkl` uses the tool.                                                          |
| `.config/mise/conf.d/tools.toml:[tools].tree-sitter`                   | `yes`   | `no`    | `mise`        | `none`                                                   | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `none`                                                   | `tool versions` | Selector `latest`. Lock resolves `0.27.0` with backend `aqua:tree-sitter/tree-sitter`.                                     |
| `.config/mise/conf.d/tools.toml:[tools].markdownlint-cli2`             | `yes`   | `no`    | `mise`        | `none`                                                   | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `none`                                                   | `tool versions` | Selector `latest`. Lock resolves `0.22.1`. `hk.pkl` uses the tool.                                                         |
| `.config/mise/conf.d/tools.toml:[tools].opencode`                      | `yes`   | `no`    | `mise`        | `none`                                                   | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `none`                                                   | `tool versions` | Selector `latest`. Lock resolves `1.18.34` with backend `aqua:anomalyco/opencode`.                                         |
| `.config/mise/conf.d/tools.toml:[tools."npm:@mermaid-js/mermaid-cli"]` | `yes`   | `no`    | `mise`        | `none`                                                   | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `none`                                                   | `tool versions` | Selector `latest`. Preserve `PUPPETEER_SKIP_DOWNLOAD=1`. Lock resolves `12.0.0`.                                           |
| `.config/mise/conf.d/tools.toml:[tools."npm:mermaid-formatter"]`       | `yes`   | `no`    | `mise`        | `none`                                                   | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `none`                                                   | `tool versions` | Selector `latest`. Lock resolves `0.3.0` with backend `npm:mermaid-formatter`.                                             |
| `.config/mise/conf.d/tools.toml:[tools."npm:mcp-hub"]`                 | `yes`   | `no`    | `mise`        | `none`                                                   | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `none`                                                   | `tool versions` | Selector `latest`. Lock resolves `4.2.1` with backend `npm:mcp-hub`.                                                       |
| `.config/mise/conf.d/tools.toml:[tools."npm:@github/copilot"]`         | `yes`   | `no`    | `mise`        | `none`                                                   | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `none`                                                   | `tool versions` | Selector `latest`. Lock resolves `1.0.91`. Keep tool runtime outside tracked sources.                                      |
| `.config/mise/conf.d/tools.toml:[tools."npm:@tobilu/qmd"]`             | `yes`   | `no`    | `mise`        | `none`                                                   | `migrate`          | `home/.config/mise/conf.d/module.tools.toml`                | `none`                                                   | `tool versions` | Selector `latest`. Lock resolves `2.8.3` with backend `npm:@tobilu/qmd`.                                                   |
| `.config/mise/tasks/global-install-packages-npm.sh`                    | `yes`   | `no`    | `stow`        | `~/.config/mise/tasks/global-install-packages-npm.sh`    | `migrate`          | `home/.config/mise/tasks/global-install-packages-npm.sh`    | `~/.config/mise/tasks/global-install-packages-npm.sh`    | `none`          | Node postinstall installs `npm@latest` and `neovim@latest`.                                                                |
| `.config/mise/tasks/global-install-packages-python.sh`                 | `yes`   | `no`    | `stow`        | `~/.config/mise/tasks/global-install-packages-python.sh` | `migrate`          | `home/.config/mise/tasks/global-install-packages-python.sh` | `~/.config/mise/tasks/global-install-packages-python.sh` | `none`          | Python postinstall runs `uv tool install --upgrade pynvim`.                                                                |
| `.config/mise/tasks/global-install-packages-ruby.sh`                   | `yes`   | `no`    | `stow`        | `~/.config/mise/tasks/global-install-packages-ruby.sh`   | `migrate`          | `home/.config/mise/tasks/global-install-packages-ruby.sh`   | `~/.config/mise/tasks/global-install-packages-ruby.sh`   | `none`          | Ruby postinstall runs `gem install neovim`.                                                                                |
| `.config/mise/tasks/global-install-packages-all.sh`                    | `yes`   | `no`    | `stow`        | `~/.config/mise/tasks/global-install-packages-all.sh`    | `migrate`          | `home/.config/mise/tasks/global-install-packages-all.sh`    | `~/.config/mise/tasks/global-install-packages-all.sh`    | `none`          | Aggregate task calls the `npm`, `python`, and `ruby` tasks.                                                                |
| `.config/mise/mise.lock`                                               | `yes`   | `no`    | `stow`        | `~/.config/mise/mise.lock`                               | `migrate`          | `home/.config/mise/mise.lock`                               | `~/.config/mise/mise.lock`                               | `none`          | Generated lockfile. It contains the 19 declared tools and an extra `pitchfork` entry. Do not refresh it in this inventory. |

## Local and runtime inventory

| Path                                                   | Exists    | Tracked | Ignored   | Current location | Active use evidence                                                              | Classification     | Required action | Runtime destination                                      | Metadata to preserve                                | Secret or sensitive data |
| ------------------------------------------------------ | --------- | ------- | --------- | ---------------- | -------------------------------------------------------------------------------- | ------------------ | --------------- | -------------------------------------------------------- | --------------------------------------------------- | ------------------------ |
| `.config/mise/conf.d/tools.toml`                       | `yes`     | `yes`   | `no`      | `repo`           | `mise` reads its `[tools]` table from the global config.                         | `active-global`    | `move`          | `~/.config/mise/conf.d/module.tools.toml`                | `0644`. Preserve selectors and hooks.               | `no`                     |
| `.config/mise/tasks/global-install-packages-npm.sh`    | `yes`     | `yes`   | `no`      | `repo`           | Node postinstall names `global-install-packages-npm`.                            | `active-global`    | `move`          | `~/.config/mise/tasks/global-install-packages-npm.sh`    | `0755`. Preserve executable mode.                   | `no`                     |
| `.config/mise/tasks/global-install-packages-python.sh` | `yes`     | `yes`   | `no`      | `repo`           | Python postinstall names `global-install-packages-python`.                       | `active-global`    | `move`          | `~/.config/mise/tasks/global-install-packages-python.sh` | `0755`. Preserve executable mode.                   | `no`                     |
| `.config/mise/tasks/global-install-packages-ruby.sh`   | `yes`     | `yes`   | `no`      | `repo`           | Ruby postinstall names `global-install-packages-ruby`.                           | `active-global`    | `move`          | `~/.config/mise/tasks/global-install-packages-ruby.sh`   | `0755`. Preserve executable mode.                   | `no`                     |
| `.config/mise/tasks/global-install-packages-all.sh`    | `yes`     | `yes`   | `no`      | `repo`           | The aggregate task calls all three postinstall tasks.                            | `active-global`    | `move`          | `~/.config/mise/tasks/global-install-packages-all.sh`    | `0755`. Preserve executable mode.                   | `no`                     |
| `.config/mise/mise.lock`                               | `yes`     | `yes`   | `no`      | `repo`           | `config.toml` sets `lockfile = true`. The tools lock contains resolved versions. | `active-global`    | `move`          | `~/.config/mise/mise.lock`                               | `0644`. Preserve generated lock data.               | `no`                     |
| `.mise/conf.d/tools.toml`                              | `yes`     | `yes`   | `no`      | `repo`           | Project tasks use `bun`, `markdownlint-cli2`, and `stylua`.                      | `active-repo-only` | `preserve`      | `none`                                                   | `0644`. Keep separate from global tools.            | `no`                     |
| `.mise/mise.lock`                                      | `yes`     | `yes`   | `no`      | `repo`           | `.mise/conf.d/tools.toml` has a separate project lockfile.                       | `active-repo-only` | `preserve`      | `none`                                                   | `0644`. Do not merge with `.config/mise/mise.lock`. | `no`                     |
| `mise` tool install state                              | `unknown` | `no`    | `unknown` | `other`          | `scripts/mise.zsh` runs `mise install`, `mise upgrade`, and `mise reshim -f`.    | `active-global`    | `exclude`       | `mise-managed data directory`                            | `mise` ownership. Preserve local installs.          | `no`                     |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- <boundary>
git check-ignore -v <path>
```

Do not print credential-bearing contents. Record metadata, references, and
target paths only.

## Ownership and cutover

- Current target shape: `whole-directory symlink for ~/.config/mise`. No tool target root exists.
- Current target manifest path: `~/.config/mise/conf.d/tools.toml`
- Old owner cleanup command: `mise dot unapply --dry-run ~/.config/mise`
- New owner dry-run command: `mise install --dry-run`
- New owner apply command: `mise install && mise reshim -f`
- Duplicate-owner check: `stow -nvR . 2>&1 | grep -E '(^|/)\.config/mise'`
- Target-content disposition check: `not applicable`. The target root is `none`. Compare the tool manifest and lockfile.
- Relative-link check: `not applicable`. Tool versions do not create dotfile links.

## Coupling

- Scripts:
  - `.config/mise/tasks/global-install-packages-npm.sh` is the `node` postinstall task. It installs `npm@latest` and `neovim@latest`.
  - `.config/mise/tasks/global-install-packages-python.sh` is the `python` postinstall task. It installs `pynvim` with `uv`.
  - `.config/mise/tasks/global-install-packages-ruby.sh` is the `ruby` postinstall task. It installs the `neovim` gem.
  - `.config/mise/tasks/global-install-packages-all.sh` calls the three postinstall tasks but is not a direct tool hook.
  - `scripts/init.zsh` sources `scripts/mise.zsh` after the Homebrew, Stow, and Zsh phases.
  - `scripts/mise.zsh` needs no new phase. Its existing tool phase applies the `[tools]` declarations.
  - Within `scripts/mise.zsh`, the order is mise availability, self-update, package bootstrap, workspace files, profile trust, tool prune, tool install, tool upgrade, reshim, repository bootstrap, and dotfiles.
  - `scripts/zsh.zsh` updates the `delta` theme through `XDG_CONFIG_HOME`.
- Environment variables:
  - `XDG_CONFIG_HOME` selects the global `mise` configuration root.
  - `DOT_PROFILE` selects the persisted profile input.
  - `MISE_ENV` is currently set to the profile inside `scripts/mise.zsh`.
  - `PUPPETEER_SKIP_DOWNLOAD` is an install environment value for Mermaid CLI.
- Includes or external paths:
  - `.config/mise/mise.lock` couples the global declaration to resolved tool versions.
  - `.config/mise/config.toml` enables `lockfile = true` and defines global `mise` settings.
  - The postinstall tasks call external package managers and network-backed registries.
- Other modules:
  - `MIG-MODULE-mise` moves the `mise` control-plane source and enables the
    module declaration chain.
  - `.mise/conf.d/tools.toml` is a separate project tool set. It overlaps with `bun`, `markdownlint-cli2`, and `stylua`.
  - `.mise/mise.lock` is the separate project lockfile. Do not merge it with `.config/mise/mise.lock`.
  - The planned `tools` environment is selected for both `work` and `personal` profiles.
- User-facing behavior:
  - `mise` provides the same global tool selectors and postinstall behavior.
  - This inventory does not install tools, refresh the lockfile, or change versions.

## Validation

- Syntax or source checks:
  - `bash -n .config/mise/tasks/global-install-packages-all.sh .config/mise/tasks/global-install-packages-npm.sh .config/mise/tasks/global-install-packages-python.sh .config/mise/tasks/global-install-packages-ruby.sh`
  - `git diff --check -- .agents/projects/stow-to-mise-migration/research/inventories/tools.md`
- Focused test:
  - `zsh tests/scripts/test_mise_tools.zsh`
  - The current tools test checks only `rust`, `node`, `python`, `ruby`, `bun`, `go`, `uv`, and `opencode`. It does not check all 19 tools, hooks, or lock coupling.
- Target smoke test:
  - `mise install --dry-run` after the module rename. Do not run an install during inventory.
- Security or token check:
  - `git grep -nE 'gh[pousr]_|AKIA[0-9A-Z]{16}|BEGIN .*PRIVATE KEY' -- .agents/projects/stow-to-mise-migration/research/inventories/tools.md`
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `.config/mise/conf.d/tools.toml`
  - `.config/mise/tasks/global-install-packages-*.sh`
  - `.config/mise/mise.lock`
  - The current `~/.config/mise` Stow link and the tool manifest
- Rollback dry run:
  - `mise dot unapply --dry-run ~/.config/mise`
  - `stow -nvR .`
- Rollback apply:
  - `mise dot unapply ~/.config/mise`
  - `stow -R .`
- Stop condition:
  - Stop if any selector, resolved version, hook, lock entry, or tool ownership result changes unexpectedly.

## Findings and decisions

- Decision: `preserve`
- Decision evidence:
  - `.config/mise/conf.d/tools.toml`
  - `.config/mise/mise.lock`
  - `.config/mise/tasks/global-install-packages-*.sh`
  - `tests/scripts/test_mise_tools.zsh`
  - `tests/scripts/test_mise_config.zsh`
  - `scripts/init.zsh`
  - `scripts/mise.zsh`
- Residual risk:
  - The declaration uses several `latest` selectors.
  - Postinstall tasks install unpinned package versions from external registries.
  - The global lock contains an extra `pitchfork` entry that is not in `tools.toml`.
  - The current test does not cover all tools, hooks, or lockfile coupling.
  - Global and project tool sets share three tool names but use separate lockfiles.
- Open blocker:
  - The `MIG-MODULE-packages` dependency and the `MIG-MODULE-tools` approval
    must complete before the declaration moves.
