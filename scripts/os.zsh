#!/usr/bin/env zsh
# Configure macOS settings
# Resources:
# - https://developer.apple.com/documentation/devicemanagement/profile-specific-payload-keys
# - https://marslo.github.io/ibook/osx/defaults.html
# - https://gist.github.com/sbolel/f6985346a33c65f5f7ce37b963a22531
# - https://ss64.com/mac/syntax-defaults.html
# - https://github.com/ryuichi1208/homecmd/blob/master/conf/macos.sh

# FIX: Safari: developer menu

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

# Immediately invoked anonymous function with the script's path as its only argument
# used to contain variables and functions in a local scope
function {
    local __hammerspoon_config_file="$HOME/.config/hammerspoon/init.lua"
    local __screenshots_dir="$HOME/Pictures/screenshots"
    local __dock_icon_size_px=64
    local __dock_icon_magnified_size_px=72

    # Screenshots
    # Create screenshots dir if it doesn't exist
    if [[ -d "$__screenshots_dir" ]]; then
        _v::log::ok "Screenshots dir exists: $__screenshots_dir"
    else
        _v::log::info "Creating screenshots dir: $__screenshots_dir"
        mkdir -p "$__screenshots_dir"

        if [[ $? == 0 ]]; then
            _v::log::ok "Screenshots dir created: $__screenshots_dir"
        fi
    fi

    _v::log::info "Moving screenshots from ~/Desktop to $__screenshots_dir"
    mv "$HOME/Desktop/Screenshot*" "$__screenshots_dir" 2>/dev/null || true
    _v::log::ok "Screenshots moved to $__screenshots_dir"

    _v::log::info "Set $(_v::fmt::u Screenshots) save location to $__screenshots_dir"
    defaults write com.apple.screencapture location -string "$__screenshots_dir"
    _v::log::ok "$(_v::fmt::u Screenshots) location set to $__screenshots_dir"


    # Trackpad
    _v::log::info "Set $(_v::fmt::u Trackpad) to use tap to click"
    defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
    _v::log::ok "$(_v::fmt::u Trackpad) set to use tap to click"

    _v::log::info "Set $(_v::fmt::u Trackpad) speed"
    defaults write -g com.apple.trackpad.scaling -float 3.0
    _v::log::ok "$(_v::fmt::u Trackpad) speed set"

    _v::log::info "Set $(_v::fmt::u Trackpad) to disable 3-finger lookup"
    # 0: Disable
    # 1: Force Click with one finger
    # 2: Tap with Three fingers
    defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerTapGesture -int 0
    _v::log::ok "$(_v::fmt::u Trackpad) set to disable 3-finger lookup"

    _v::log::info "Set $(_v::fmt::u Trackpad) 3-finger horizontal swipe to switch pages"
    # Whether to enable three-finger horizontal swipe gesture:
    # 0: disable
    # 1: swipe between pages
    # 2: swipe between full-screen applications.
    defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture -int 1
    _v::log::ok "$(_v::fmt::u Trackpad) 3-finger horizontal swipe set to switch pages"


    # Keyboard
    _v::log::info "Enable $(_v::fmt::u Keyboard) UI navigation"
    defaults write -g AppleKeyboardUIMode -int 2
    _v::log::ok "$(_v::fmt::u Keyboard) UI navigation enabled"


    # System
    _v::log::info "Set $(_v::fmt::u System) to require password immediately after sleep or screen saver begins"
    defaults write com.apple.screensaver askForPassword -bool true
    defaults write com.apple.screensaver askForPasswordDelay -int 0
    _v::log::ok "$(_v::fmt::u System) set to require password immediately after sleep or screen saver begins"

    _v::log::info "Set $(_v::fmt::u System) to dark mode"
    defaults write -g AppleInterfaceStyle -string "Dark"
    _v::log::ok "$(_v::fmt::u System) set to dark mode"

    _v::log::info "Set $(_v::fmt::u System) to use 24hr time"
    defaults write -g AppleICUForce24HourTime -bool true
    _v::log::ok "$(_v::fmt::u System) set to use 24hr time"

    _v::log::info "Set $(_v::fmt::u Printing) to quit printer app once the print jobs complete"
    defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true
    _v::log::ok "$(_v::fmt::u Printing) set to quit printer app once the print jobs complete"

    # _v::log::info "Set $(_v::fmt::u System) wallpaper"
    # osascript -e "tell application 'Finder' to set desktop picture to POSIX file '$HOME/.config/minusfive/wallpaper.jpg'"
    # _v::log::ok "$(_v::fmt::u System) wallpaper set"

    # Menu bar
    _v::log::info "Set $(_v::fmt::u Menu Bar) to show date and 24hr time"
    defaults write com.apple.menuextra.clock DateFormat -string "EEE d MMM H:mm"
    defaults write com.apple.menuextra.clock Show24Hour -bool true
    defaults write com.apple.menuextra.clock ShowAMPM -bool false
    defaults write com.apple.menuextra.clock ShowDay -bool true
    defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true
    defaults write com.apple.menuextra.clock ShowMonth -bool true
    defaults write com.apple.menuextra.clock ShowSeconds -bool false
    defaults write com.apple.menuextra.clock IsAnalog -bool false
    # Menu Bar Only > Clock Options > Show Date: Never
    # defaults write "com.apple.menuextra.clock" ShowDate -int 2
    _v::log::ok "$(_v::fmt::u Menu Bar) set to show date and 24hr time"

    # Control Centre Modules > Bluetooth > hide in Menu Bar
    _v::log::info "Set $(_v::fmt::u Menu Bar) to hide Bluetooth status"
    defaults write "com.apple.controlcenter" "NSStatusItem Visible Bluetooth" -bool false
    _v::log::ok "$(_v::fmt::u Menu Bar) set to hide Bluetooth status"

    # Control Centre Modules > Sound > Always hide in Menu Bar
    _v::log::info "Set $(_v::fmt::u Menu Bar) to hide Sound status"
    defaults write "com.apple.controlcenter" "NSStatusItem Visible Sound" -bool false
    _v::log::ok "$(_v::fmt::u Menu Bar) set to hide Sound status"

    # Control Centre Modules > Screen Mirroring > Don't Show in Menu Bar
    _v::log::info "Set $(_v::fmt::u Menu Bar) to hide Screen Mirroring status"
    defaults write "com.apple.airplay" showInMenuBarIfPresent -bool false
    _v::log::ok "$(_v::fmt::u Menu Bar) set to hide Screen Mirroring status"

    # Control Centre Modules > Now Playing > Don't Show in Menu Bar
    _v::log::info "Set $(_v::fmt::u Menu Bar) to hide Now Playing status"
    defaults write "com.apple.airplay" "NSStatusItem Visible NowPlaying" -bool false
    _v::log::ok "$(_v::fmt::u Menu Bar) set to hide Now Playing status"

    # Menu Bar Only > Spotlight > Don't Show in Menu Bar
    _v::log::info "Set $(_v::fmt::u Menu Bar) to hide Spotlight status"
    defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1
    _v::log::ok "$(_v::fmt::u Menu Bar) set to hide Spotlight status"

    # Enable subpixel font rendering on non-Apple LCDs
    _v::log::info "Set $(_v::fmt::u font smoothing) to subpixel font rendering on non-Apple displays"
    defaults write -g AppleFontSmoothing -int 2
    _v::log::ok "$(_v::fmt::u font smoothing) set to subpixel font rendering on non-Apple displays"


    # Hammerspoon
    _v::log::info "Set $(_v::fmt::u "Hammerspoon") to read config from $__hammerspoon_config_file"
    defaults write org.hammerspoon.Hammerspoon MJConfigFile "$__hammerspoon_config_file"
    _v::log::ok "$(_v::fmt::u "Hammerspoon") config dir set to $__hammerspoon_config_file"


    # Safari
    _v::log::info "Set $(_v::fmt::u Safari) to show develop menu"
    defaults write com.apple.Safari IncludeDevelopMenu -bool true
    defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
    defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" -bool true
    defaults write -g WebKitDeveloperExtras -bool true
    _v::log::ok "$(_v::fmt::u Safari) set to show develop menu"

    _v::log::info "Set $(_v::fmt::u Safari) to show full URL in address bar"
    defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true
    _v::log::ok "$(_v::fmt::u Safari) set to show full URL in address bar"

    _v::log::info "Set $(_v::fmt::u Safari) to use the compact tab bar"
    defaults write com.apple.Safari ShowStandaloneTabBar -bool false
    _v::log::ok "$(_v::fmt::u Safari) set to use the compact tab bar"

    _v::log::info "Set $(_v::fmt::u Safari) to always show website title"
    defaults write com.apple.Safari EnableNarrowTabs -bool false
    _v::log::ok "$(_v::fmt::u Safari) set to always show website title"

    _v::log::info "Set $(_v::fmt::u Safari) to always open new pages in tabs vs. windows"
    defaults write com.apple.Safari TabCreationPolicy -int 2
    _v::log::ok "$(_v::fmt::u Safari) set to always open new pages in tabs vs. windows"

    _v::log::info "Set $(_v::fmt::u Safari) to activate tabs when opened"
    defaults write com.apple.Safari OpenNewTabsInFront -bool true
    _v::log::ok "$(_v::fmt::u Safari) set to activate tabs when opened"

    _v::log::info "Set $(_v::fmt::u Safari) to clear downloads on success"
    defaults write com.apple.Safari DownloadsClearingPolicy -int 2
    _v::log::ok "$(_v::fmt::u Safari) set to clear downloads on success"

    _v::log::info "Set $(_v::fmt::u Safari) to NOT preload top hit"
    defaults write com.apple.Safari PreloadTopHit -bool false
    _v::log::ok "$(_v::fmt::u Safari) set to NOT preload top hit"

    _v::log::info "Set $(_v::fmt::u Safari) to NOT use website specific search"
    defaults write com.apple.Safari WebsiteSpecificSearchEnabled -bool false
    _v::log::ok "$(_v::fmt::u Safari) set to NOT use website specific search"

    _v::log::info "Set $(_v::fmt::u Safari) to NOT show favorites under smart search field"
    defaults write com.apple.Safari ShowFavoritesUnderSmartSearchField -bool false
    _v::log::ok "$(_v::fmt::u Safari) set to NOT show favorites under smart search field"

    _v::log::info "Set $(_v::fmt::u Safari) to NOT offer to store autofill data"
    defaults write com.apple.Safari AutoFillCreditCardData -bool false
    defaults write com.apple.Safari AutoFillFromAddressBook -bool false
    defaults write com.apple.Safari AutoFillMiscellaneousForms -bool false
    defaults write com.apple.Safari AutoFillPasswords -bool false
    _v::log::ok "$(_v::fmt::u Safari) set to NOT offer to store autofill data"


    # Finder

    _v::log::info "Set $(_v::fmt::u Finder) to start at $HOME"
    defaults write com.apple.finder NewWindowTarget -string "$HOME"

    _v::log::info "Set $(_v::fmt::u Finder) to show all filename extensions"
    defaults write -g AppleShowAllExtensions -bool true
    _v::log::ok "$(_v::fmt::u Finder) set to show all filename extensions"

    _v::log::info "Set $(_v::fmt::u Finder) to show all files"
    defaults write com.apple.finder AppleShowAllFiles -bool true
    _v::log::ok "$(_v::fmt::u Finder) set to show all files"

    _v::log::info "Set $(_v::fmt::u Finder) to show path bar"
    defaults write com.apple.finder ShowPathbar -bool true
    _v::log::ok "$(_v::fmt::u Finder) set to show path bar"

    _v::log::info "Set $(_v::fmt::u Finder) to show status bar"
    defaults write com.apple.finder ShowStatusBar -bool true
    _v::log::ok "$(_v::fmt::u Finder) set to show status bar"

    _v::log::info "Set $(_v::fmt::u Finder) to show sidebar"
    defaults write com.apple.finder ShowSidebar -bool true
    _v::log::ok "$(_v::fmt::u Finder) set to show sidebar"

    _v::log::info "Set $(_v::fmt::u Finder) to show preview pane"
    defaults write com.apple.finder ShowPreviewPane -bool true
    _v::log::ok "$(_v::fmt::u Finder) set to show preview pane"

    _v::log::info "Set $(_v::fmt::u Finder) default view to $(_v::fmt::u Column)"
    defaults write com.apple.finder FXPreferredViewStyle -string "clmv"
    _v::log::ok "$(_v::fmt::u Finder) default view set to $(_v::fmt::u Column)"

    _v::log::info "Set $(_v::fmt::u Finder) to show dirs first"
    defaults write com.apple.finder _FXSortFoldersFirst -bool true
    defaults write com.apple.finder _FXSortFoldersFirstOnDesktop -bool true
    _v::log::ok "$(_v::fmt::u Finder) set to show dirs first"

    _v::log::info "Set $(_v::fmt::u Finder) to open dirs in tabs on command + double-click"
    defaults write com.apple.finder FinderSpawnTab -bool true
    _v::log::ok "$(_v::fmt::u Finder) set to open dirs in tabs on command + double-click"

    _v::log::info "Set $(_v::fmt::u Finder) default search scope to current dir"
    defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
    _v::log::ok "$(_v::fmt::u Finder) default search scope set to current dir"

    _v::log::info "Set $(_v::fmt::u Finder) to empty trash after 30 days"
    defaults write com.apple.finder FXRemoveOldTrashItems -bool true
    _v::log::ok "$(_v::fmt::u Finder) set to empty trash after 30 days"

    _v::log::info "Set $(_v::fmt::u Finder) to show file extension change warning"
    defaults write com.apple.finder FXEnableExtensionChangeWarning -bool true
    _v::log::ok "$(_v::fmt::u Finder) set to show file extension change warning"

    _v::log::info "Set $(_v::fmt::u Finder) to use full POSIX path in title"
    defaults write com.apple.finder _FXShowPosixPathInTitle -bool false
    _v::log::ok "$(_v::fmt::u Finder) set to use full POSIX path in title"

    _v::log::info "Set $(_v::fmt::u Finder) to show window titlebar icons"
    defaults write com.apple.universalaccess showWindowTitlebarIcons -bool true
    _v::log::ok "$(_v::fmt::u Finder) set to show window titlebar icons"

    _v::log::info "Set $(_v::fmt::u Finder) to show window titlebar icons on hover immediately"
    defaults write -g NSToolbarTitleViewRolloverDelay -float "0"
    _v::log::ok "$(_v::fmt::u Finder) set to show window titlebar icons on hover immediately"

    _v::log::info "Set $(_v::fmt::u Finder) to sort dirs first on desktop"
    defaults write com.apple.finder _FXSortFoldersFirstOnDesktop -bool true
    _v::log::ok "$(_v::fmt::u Finder) set to sort dirs first on desktop"

    _v::log::info "Set $(_v::fmt::u Finder) to show hard drives on desktop"
    defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
    _v::log::ok "$(_v::fmt::u Finder) set to show hard drives on desktop"

    _v::log::info "Set $(_v::fmt::u Finder) to show external hard drives on desktop"
    defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
    _v::log::ok "$(_v::fmt::u Finder) set to show external hard drives on desktop"

    _v::log::info "Set $(_v::fmt::u Finder) to show removable media on desktop"
    defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
    _v::log::ok "$(_v::fmt::u Finder) set to show removable media on desktop"

    _v::log::info "Set $(_v::fmt::u Finder) to show mounted servers on desktop"
    defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
    _v::log::ok "$(_v::fmt::u Finder) set to show mounted servers on desktop"

    _v::log::info "Set $(_v::fmt::u Finder) and desktop icons to sort by name"
    defaults write com.apple.finder DesktopViewSettings.IconViewSettings.arrangeBy -string name
    defaults write com.apple.finder FK_StandardViewSettings.IconViewSettings.arrangeBy -string name
    defaults write com.apple.finder StandardViewSettings.IconViewSettings.arrangeBy -string name
    _v::log::ok "$(_v::fmt::u Finder) and desktop icons set to sort by name"

    _v::log::info "Set $(_v::fmt::u Finder) to NOT add DS_Store files to USB and network drives"
    defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
    _v::log::ok "$(_v::fmt::u Finder) set to NOT add DS_Store files to USB and network drives"


    # Dock
    _v::log::info "Set $(_v::fmt::u Dock) icon size to ${__dock_icon_size_px}px"
    defaults write com.apple.dock tilesize -int $__dock_icon_size_px
    _v::log::ok "$(_v::fmt::u Dock) icon size set to ${__dock_icon_size_px}px"

    _v::log::info "Set $(_v::fmt::u Dock) to magnify icons on hover"
    defaults write com.apple.dock magnification -bool true
    defaults write com.apple.dock largesize -int $__dock_icon_magnified_size_px
    _v::log::ok "$(_v::fmt::u Dock) set to magnify icons on hover"

    _v::log::info "Set $(_v::fmt::u Dock) to autohide"
    defaults write com.apple.dock autohide -bool true
    _v::log::ok "$(_v::fmt::u Dock) set to autohide"

    _v::log::info "Ensure $(_v::fmt::u Dock) is NOT set to show only running apps"
    # WARN: Enabling this will prevent folders from being displayed in the Dock
    defaults write com.apple.dock "static-only" -bool false
    _v::log::ok "$(_v::fmt::u Dock) NOT set to show only running apps"

    _v::log::info "Set $(_v::fmt::u Dock) to spring load items"
    defaults write com.apple.dock "enable-spring-load-actions-on-all-items" -bool true
    _v::log::ok "$(_v::fmt::u Dock) set to spring load items"

    _v::log::info "Empty $(_v::fmt::u Dock)"
    dockutil --remove all --no-restart
    _v::log::ok "$(_v::fmt::u Dock) emptied"

    _v::log::info "Add Screenshots directory to $(_v::fmt::u Dock)"
    dockutil --add "$__screenshots_dir" --label "Screenshots" --replacing "Screenshots" --section "others" --view "fan" --display "stack" --sort "dateadded" --no-restart
    _v::log::ok "Screenshots directory added to $(_v::fmt::u Dock)"

    _v::log::info "Add Downloads directory to $(_v::fmt::u Dock)"
    dockutil --add "$HOME/Downloads" --label "Downloads" --replacing "Downloads" --after "Screenshots" --section "others" --view "fan" --display "stack" --sort "dateadded"
    _v::log::ok "Downloads directory added to $(_v::fmt::u Dock)"

    # Mission Control
    _v::log::info "Set $(_v::fmt::u Dock) to group app windows in Mission Control"
    defaults write com.apple.dock "expose-group-apps" -bool true
    _v::log::ok "$(_v::fmt::u Dock) set to group app windows in Mission Control"


    # Spaces
    _v::log::info "Set $(_v::fmt::u Spaces) to switch on app activation"
    defaults write -g AppleSpacesSwitchOnActivate -bool true
    _v::log::ok "$(_v::fmt::u Spaces) set to switch spaces on app activation"

    _v::log::info "Set $(_v::fmt::u Spaces) to be unique per display"
    defaults write com.apple.spaces "spans-displays" -bool false
    _v::log::ok "$(_v::fmt::u Spaces) set to be unique per display"


    # Restart processes to apply changes
    _v::log::info "Clearing $(_v::fmt::u cfprefsd) cache"
    killall cfprefsd
    _v::log::ok "$(_v::fmt::u cfprefsd) cache cleared"

    _v::log::info "Restarting $(_v::fmt::u SystemUIServer) to apply changes"
    killall SystemUIServer
    _v::log::ok "$(_v::fmt::u SystemUIServer) restarted"

    _v::log::info "Restarting $(_v::fmt::u Finder) to apply changes"
    killall Finder
    _v::log::ok "$(_v::fmt::u Finder) restarted"

    _v::log::info "Restarting $(_v::fmt::u Dock) to apply changes"
    killall Dock
    _v::log::ok "$(_v::fmt::u Dock) restarted"

    # Restart Safari if running
    if [[ $(pgrep -x "Safari") ]]; then
        _v::log::ok "Restarting $(_v::fmt::u Safari) to apply changes"
        killall -q Safari 2>/dev/null || true
        open --background -a Safari
        _v::log::ok "$(_v::fmt::u Safari) restarted"
    fi
}

