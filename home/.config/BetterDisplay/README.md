# BetterDisplay Configuration

This directory contains configuration files for [BetterDisplay](https://github.com/waydabber/BetterDisplay), a macOS utility for display management and HiDPI/scaling support.

## Files

- `config.plist` - Main configuration file containing all BetterDisplay settings
- `config.backup.*.plist` - Automatic backups created before importing settings

## Usage

### Via Bootstrap Script

The BetterDisplay settings can be managed through the main bootstrap script:

```bash
# Export current BetterDisplay settings to config.plist
./scripts/init.zsh -d

# Import settings from config.plist (interactive)
./scripts/init.zsh -d
```

### Manual Export/Import

You can also manually export and import settings using the `defaults` command:

```bash
# Export settings
defaults export pro.betterdisplay.BetterDisplay ~/.config/BetterDisplay/config.plist

# Import settings (BetterDisplay must be closed)
defaults import pro.betterdisplay.BetterDisplay ~/.config/BetterDisplay/config.plist
```

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
- The script will attempt to quit the app automatically with user confirmation
- Settings take effect when the app is restarted

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
