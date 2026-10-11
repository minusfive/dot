# Module Inventory: `fd`

## Metadata

- Module key: `fd`
- Story key: `MIG-MODULE-fd`
- Inventory version: `1`
- Inventory path: `.agents/projects/stow-to-mise-migration/research/inventories/fd.md`
- Current declaration: `.config/fd` (implicit in Stow package `.`)
- New declaration: `~/dev/personal/dot/home/.config/mise/conf.d/module.fd.toml`
- Current owner: `stow`
- New owner: `mise`
- Target root: `~/.config/fd`
- Mise mode: `symlink-each`
- Environment selector: `fd`
- Dependencies: `MIG-MODULE-mise`
- Approval state: `pending`
- Inventory status: `complete`

## Scope manifest

| Source path         | Tracked | Ignored | Current owner | Current target        | Target disposition | New source path                             | New target            | New mode       | Notes                                                                    |
| ------------------- | ------- | ------- | ------------- | --------------------- | ------------------ | ------------------------------------------- | --------------------- | -------------- | ------------------------------------------------------------------------ |
| `.config/fd/ignore` | `yes`   | `no`    | `stow`        | `~/.config/fd/ignore` | `migrate`          | `~/dev/personal/dot/home/.config/fd/ignore` | `~/.config/fd/ignore` | `symlink-each` | The only source file. Its fd ignore rules are `.git` and `node_modules`. |

## Local and runtime inventory

| Path                | Exists | Tracked | Ignored | Current location | Active use evidence                                                                                                       | Classification  | Required action   | Runtime destination   | Metadata to preserve                                         | Secret or sensitive data |
| ------------------- | ------ | ------- | ------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------- | --------------- | ----------------- | --------------------- | ------------------------------------------------------------ | ------------------------ |
| `.config/fd/ignore` | `yes`  | `yes`   | `no`    | `repo`           | The deployed `~/.config/fd/ignore` resolves through the current Stow directory link; rules are `.git` and `node_modules`. | `active-global` | `copy-then-erase` | `~/.config/fd/ignore` | `0644`, `villalj:staff`                                      | `no`                     |
| `~/.config/fd`      | `yes`  | `no`    | `no`    | `target`         | Whole-directory relative symlink to `../dev/personal/dot/.config/fd`; it currently exposes the tracked `ignore` file.     | `active-global` | `preserve`        | `~/.config/fd`        | Whole-directory `lrwxr-xr-x`, `villalj:staff`, relative link | `no`                     |

Record ignored paths with:

```text
git ls-files --others --ignored --exclude-standard -- .config/fd
# no output

git check-ignore -v .config/fd/ignore
# no output; the source file is not Git-ignored

git ls-files --others --exclude-standard -- .config/fd
# no output
```

The source file is not excluded by `.stow-local-ignore`. The `.git` and
`node_modules` entries are fd runtime ignore rules, not repository ignore
rules.

## Ownership and cutover

- Current target shape: `whole-directory symlink`
- Current target manifest path: `~/.config/fd` -> `../dev/personal/dot/.config/fd`; `~/.config/fd/ignore` resolves to `.config/fd/ignore`
- Old owner cleanup command: `test -L "$HOME/.config/fd" && test "$(readlink "$HOME/.config/fd")" = "../dev/personal/dot/.config/fd" && unlink "$HOME/.config/fd"`
- New owner dry-run command: `mise -E fd bootstrap dotfiles apply --dry-run`
- New owner apply command: `mise -E fd bootstrap dotfiles apply --yes`
- Duplicate-owner check: `test -z "$(stow -nvR . 2>&1 | grep -F -- '.config/fd' || true)" && mise -E fd bootstrap dotfiles status | grep -F -- '.config/fd/ignore'`
- Target-content disposition check: `test -d "$HOME/.config/fd" && test -z "$(find -P "$HOME/.config/fd" -mindepth 1 -maxdepth 1 ! -name ignore -print -quit)"`
- Relative-link check: `python3 -c 'from pathlib import Path; p = Path.home() / ".config/fd/ignore"; assert p.is_symlink() and not p.readlink().is_absolute() and p.resolve() == Path.home() / "dev/personal/dot/home/.config/fd/ignore"'`

## Coupling

- Scripts:
  - `scripts/mise.zsh` applies the existing mise dotfiles phase after package, workspace, tool, and repository bootstrap; no fd-specific phase or script change is required.
  - `scripts/symlink.zsh` runs `stow -vR .`; it must not recreate the fd target after the Stow source is retired or excluded.
  - `.config/mise/tasks/md/preview.ts` invokes the `fd` executable for Markdown selection; this is package/runtime coupling, not a source-path reference.
- Environment variables:
  - `DOT_PROFILE` selects the rendered mise profile in `.config/mise/miserc.toml`; the migration roadmap includes the planned `fd` module in both profile module lists.
  - `MISE_ENV` is set to the selected profile by the current `scripts/mise.zsh`; use `mise -E fd` for module-focused validation.
  - No fd-specific configuration environment variable or `FD_*` reference exists.
- Includes or external paths:
  - `none`; `.config/fd/ignore` has no includes or external file references.
- Other modules:
  - `MIG-MODULE-mise` provides the control-plane dependency recorded in `module-registry.toml`.
  - The `packages` module installs the `fd` executable through `"brew:fd" = "latest"` in `.config/mise/conf.d/bootstrap-packages.toml`.
- User-facing behavior:
  - Preserve fd's global ignore behavior for `.git` and `node_modules`; change only the ownership mechanism from the whole-directory Stow link to mise per-file linking.

## Validation

- Syntax or source checks:
  - `test -f .config/fd/ignore && grep -Fx '.git' .config/fd/ignore && grep -Fx 'node_modules' .config/fd/ignore`
- Focused test:
  - `tests/scripts/test_mise_bootstrap_fd.zsh` (planned module test; not present in the current baseline)
- Target smoke test:
  - `fd --version >/dev/null && test -r "$HOME/.config/fd/ignore" && test -L "$HOME/.config/fd/ignore"`
- Security or token check:
  - `test -f .config/fd/ignore && test -f ~/dev/personal/dot/home/.config/fd/ignore && ! grep -Eiq 'token|password|secret|credential|private[[:space:]-]?key|auth[.]db' .config/fd/ignore ~/dev/personal/dot/home/.config/fd/ignore`
- Aggregate checks:
  - `mise run check`
  - `stow -nvR .`

## Rollback

- Preserve before cutover:
  - `.config/fd/ignore` with mode `0644` and the current `~/.config/fd` symlink manifest.
- Rollback dry run:
  - `mise -E fd bootstrap dotfiles unapply --dry-run`
- Rollback apply:
  - `mise -E fd bootstrap dotfiles unapply --yes && test ! -e "$HOME/.config/fd" -o -L "$HOME/.config/fd" && stow -vR .`
- Stop condition:
  - Stop if the target contains any child other than `ignore`, if the existing whole-directory link does not match the recorded target, if mise or Stow reports a conflict, or if any sensitive/runtime file appears in the source set.

## Findings and decisions

- Decision: `deferred`
- Decision evidence:
  - `.agents/projects/stow-to-mise-migration/module-registry.toml` records
    `fd` and its dependency on `MIG-MODULE-mise`.
  - The roadmap and this inventory specify `.config/fd/ignore` ->
    `~/dev/personal/dot/home/.config/fd/ignore`, target `~/.config/fd`, and `symlink-each`.
  - `stow -nvR .` currently proposes unlinking and relinking the existing fd directory symlink; no fd-specific conflict was reported.
- Residual risk:
  - `low`; the boundary has one tracked, non-sensitive file and no unmanaged target content, but cutover must remove only the recorded whole-directory symlink before mise applies per-file links.
- Open blocker:
  - Explicit migration approval is required before changing ownership.
