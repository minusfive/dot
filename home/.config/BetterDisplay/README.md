# BetterDisplay Configuration

This directory contains the tracked `BetterDisplay` property list. The `BetterDisplay` module owns the application package and this directory. `mise` links the property list into `~/.config/BetterDisplay`.

## Export and import

Run the repository-local `mise` task from the repository root. It exports live settings to `config.plist` by default:

```bash
mise -C ~/dev/personal/dot run betterdisplay:sync
```

Use `--import` or `-i` to import the tracked settings:

```bash
mise -C ~/dev/personal/dot run betterdisplay:sync --import
```

The task asks for native `mise` confirmation before either operation. Use `--yes` or `MISE_YES=1` for a non-interactive run.

The export operation writes a temporary file beside `config.plist`. It validates and compares the file before it replaces the tracked file.

The import operation checks the tracked file before it changes live settings. It stops `BetterDisplay` only when the application is running. It starts the application again only when it was running before the import.

If the task cannot confirm that a previously running application is running within 10 seconds, it reports the backup path and leaves the application in its current state. The task does not retry or restore the backup. In the normal timeout case, `BetterDisplay` remains stopped. Restore the backup manually after the application stops.

The task does not synchronize settings in the background. A bootstrap run does not export or import application settings.

## Backup recovery

Before an import, the task saves one live backup under:

```text
${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/BetterDisplay/backups/
```

The task reports the backup path. If an import or restart fails, use the reported backup with `defaults import` after `BetterDisplay` stops:

```bash
defaults import pro.betterdisplay.BetterDisplay path/to/backup
```

The backup is a runtime file. It is not part of the repository.

## Property list limits

The tracked file must remain a valid property list. Run `plutil -lint` after manual edits. Property-list syntax does not preserve comments or formatting metadata during export.

Display settings can contain hardware identifiers. A display identifier differs between computers, user accounts, and system installations. Settings for one display can fail to apply to another display.

Use the `BetterDisplay` display identification setting to match basic identifiers before export when the file will move to another computer. The application transfer feature can also copy settings between displays.

## Version compatibility

Use a `BetterDisplay` version that matches the version that created the tracked file. A newer file can use keys that an older version does not understand. The current bundle identifier is `pro.betterdisplay.BetterDisplay`. Older releases used a different bundle identifier and are not compatible with this task.
