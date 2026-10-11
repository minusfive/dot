# Migration Baseline Record

## Metadata

- Run key: `<timestamp or id>`
- Repository: `~/dev/personal/dot`
- Branch: `<branch>`
- Profile: `<work or personal>`
- Mise version: `<version>`
- Stow version: `<version>`
- Recorded at: `<timestamp>`
- Scope: `<story or module>`

## Commands

| Command     | Output record | Exit status |
| ----------- | ------------- | ----------- |
| `<command>` | `<path>`      | `<status>`  |

## Target manifest

| Target   | Type                                     | Owner     | Resolved source  | Content disposition                               | Metadata               |
| -------- | ---------------------------------------- | --------- | ---------------- | ------------------------------------------------- | ---------------------- |
| `<path>` | `<symlink, file, directory, or missing>` | `<owner>` | `<path or none>` | `<preserve, migrate, remove, or repository-only>` | `<mode, owner, group>` |

## Source manifest

| Boundary | Tracked manifest | Ignored manifest | Non-ignored untracked manifest |
| -------- | ---------------- | ---------------- | ------------------------------ |
| `<path>` | `<path>`         | `<path>`         | `<path>`                       |

## Differences

- Pre-existing differences:
  - `<difference>`
- Expected migration differences:
  - `<difference>`
- Unexpected differences:
  - `none`
