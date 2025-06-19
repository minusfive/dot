This is my macOS system configuration repository which I use to setup a new machine just the way I like it by running a few simple commands. It's primarily composed of:

- The `scripts` directory contains the `zsh` scripts I use to install software, symlink my dotfiles and configure OS settings.

- The `.config` directory contains most of my software configuration files, and is symlinked to the standard `$XDG_CONFIG_HOME` location (`~/.config`), using GNU `stow`

- The `.zshenv` file at the root of the repo is symlinked by GNU `stow` to my `$HOME` (`~`) directory, and configures the base `zsh` environment variables, most importantly the standard `$XDG_` locations which are used by the rest of the configuration, and `$ZDOTDIR` which tells `zsh` where to find the rest of the `zsh` configurations.

- The `.stowrc` and `.stow-local-ignore` files at the root of the repo are used by GNU `stow` to manage the symlinks and ignore certain files or directories.

- The `assets` directory contains some static assets, such as images, etc.

- The `tests` directory contains relevant tests used for development of this project itself.

- Most of the other files at the root of this project are used for development environment configuration of this project itself, and are not symlinked or used for system configuration.
