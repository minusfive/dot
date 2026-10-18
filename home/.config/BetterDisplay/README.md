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

`config.plist` is the tracked source. The export task writes to this file only when live settings differ. The task resolves the source from the repository, so it does not write through a deployed task symlink.

The export task uses atomic replacement with source snapshots and rollback. It refuses source changes during the operation. It preserves conflicting content under `${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/BetterDisplay/conflicts/`.

The tasks do not run at login or on a timer. An export can change the working tree, but it does not stage, commit, or push the change. Review the change with normal `Git` commands.

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

RISK: macOS provides no lock that BetterDisplay itself honors. If the app launches in the small interval around `defaults import`, the task detects that state and restores the backup, but an app that changes its preferences concurrently can still require manual verification.

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
