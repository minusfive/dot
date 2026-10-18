# BetterDisplay Configuration

This directory contains configuration files for [BetterDisplay](https://github.com/waydabber/BetterDisplay), a macOS utility for display management and HiDPI/scaling support.

## Files

- `config.plist` - Main configuration file containing all BetterDisplay settings
- Runtime backups are stored outside this directory under `${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/BetterDisplay/backups/`

## Usage

### Manual mise tasks

Run these `mise` tasks when you need to transfer settings:

```sh
mise run betterdisplay:settings:export
mise run betterdisplay:settings:import
```

`config.plist` is the tracked source. It must be a regular file inside the trusted repository; the tasks reject symlinked source files and resolved paths outside the repository. The export task writes to this file only when live settings differ. The task resolves the source from the repository, so it does not write through a deployed task symlink.

The export task writes a temporary file beside the tracked source, validates it, and compares the source before replacing it with a standard same-directory `mv`. It refuses source changes during the operation. If a conflict is detected, the exported settings are preserved under `${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/BetterDisplay/conflicts/` and the task fails without attempting a rollback.

The tasks do not run at login or on a timer. An export can change the working tree, but it does not stage, commit, or push the change. Review the change with normal `Git` commands.

The tasks use a manual contention lock under the same BetterDisplay runtime directory. They never reclaim an existing lock automatically. If a task is interrupted and leaves the lock behind, confirm that no BetterDisplay task is running, then remove `${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/BetterDisplay/lock` and retry.

## Important Notes

### Display-Specific Settings

BetterDisplay settings are tied to display hardware identifiers (UUIDs). When moving configurations between different Macs or after macOS reinstallation, display-specific settings may not apply correctly due to different system-assigned identifiers.

**Solutions:**

1. **Change identification method** (recommended): In BetterDisplay, go to `Settings > Displays > [display] > General Settings > Additional settings... > Display identification method` and select "Match basic identifiers" before exporting settings.

2. **Manual plist editing**: Use a plist editor (Xcode or BBEdit) to update display identifier data under the `storedIdentifier@(...)` keys.

3. **Transfer settings UI**: Use BetterDisplay's built-in transfer feature at `Settings > Displays > [current display] > Additional settings > Transfer settings from:` to copy settings from a disconnected display.

### Version Compatibility

- Settings from BetterDisplay v4.x are not compatible with v1.x
- Avoid importing settings from newer app versions to older versions
- The bundle identifier changed between versions:
  - v4.x: `pro.betterdisplay.BetterDisplay`
  - v1.x: `me.waydabber.BetterDummy`

### Import Requirements

- BetterDisplay **must be closed** before importing settings
- The import task refuses to continue while the app is running; quit the app and rerun the task
- The import task asks for confirmation before it replaces live settings
- The task saves a runtime backup under `${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/BetterDisplay/backups/`
- Restart BetterDisplay after importing settings

RISK: macOS provides no lock that BetterDisplay itself honors. If the app launches after the task's final pre-import check, the import can still require manual verification.

RISK: An external writer can act after the export task's final verification. The task detects and preserves changes observed during replacement, but no shell-level operation can prevent a writer that runs after that verification.

## Troubleshooting

### Export Fails

- Ensure BetterDisplay has been configured at least once
- Check that the app is installed in `/Applications/` or `~/Applications/`

### Import Fails

- Verify the config file exists and is valid
- Ensure BetterDisplay is completely closed
- Check file permissions on the config file

### Settings Don't Apply

- Verify display hardware compatibility (see Display-Specific Settings above)
- Check app version compatibility
- Try transferring settings using BetterDisplay's built-in transfer feature

## Resources

- [BetterDisplay Wiki - Export and Import Settings](https://github.com/waydabber/BetterDisplay/wiki/Export-and-import-app-settings)
- [BetterDisplay GitHub Repository](https://github.com/waydabber/BetterDisplay)
