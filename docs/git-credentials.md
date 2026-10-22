# Git credential profiles

## Ownership

Repository paths select profiles for [`Git`](https://git-scm.com/). Repositories under `~/dev/work/` and `~/Notes/Work/` include `~/dev/work/.gitconfig`. Repositories under `~/dev/personal/` and `~/Notes/Personal/` include `~/dev/personal/.gitconfig`.

The checked-in `Git` config contains shared values. The profile includes appear after these values. Later scalar values override earlier values. Credential helpers accumulate unless a later empty value resets the list.

The personal domain list has a tracked source at `home/dev/personal/.domains`. The `Git` module deploys it to `~/dev/personal/.domains`. The work domain list and work config stay local at `~/dev/work/.domains` and `~/dev/work/.gitconfig`.

The personal and work profiles use separate `GH_CONFIG_DIR` paths. `~/dev/personal/mise.toml` selects `~/.config/gh/personal`. `~/dev/work/mise.toml` selects `~/.config/gh/work`. The setup task uses the selected path directly, including when both profiles use the same hostname.

## Domain list format

The `.domains` file contains one hostname per line. Blank lines and full-line comments that start with `#` are allowed. The parser trims surrounding whitespace, converts hostnames to lowercase, and removes one final dot.

Use ASCII DNS hostnames. Do not include a scheme, port, path, wildcard, or IP address. A listed domain matches its exact hostname and subdomains at label boundaries. For example, `example.test` matches `api.example.test` but not `example.test.attacker.invalid`.

The tracked personal list contains `github.com`. Add work hostnames only to the local work domain list. Do not add inline comments after a hostname.

## Setup

Add each profile's hostname to its `.domains` file before you configure authentication.

Authenticate the personal profile with its separate config directory:

```bash
cd ~/dev/personal
mise run gh:auth:login --hostname github.com
```

Replace `<hostname>` with a hostname from the selected domain list before you run either work command.

Authenticate the work profile with its separate config directory:

```bash
cd ~/dev/work
mise run gh:auth:login --hostname <hostname>
```

Configure the Git helper for the selected profile and hostname:

```bash
mise run git:auth:setup --profile personal --hostname github.com
mise run git:auth:setup --profile work --hostname <hostname>
```

The task requires both flags. It rejects a hostname that is not in the selected domain list. It also rejects a profile that is not authenticated for that hostname.

The task runs `gh auth setup-git --hostname` with `GIT_CONFIG_GLOBAL` set to the selected local `.gitconfig`. It then replaces the generated helper with a portable command that uses the selected `GH_CONFIG_DIR`. An empty host-specific helper value resets inherited helpers before the profile helper is added.

## Pre-commit policy

The `hk` pre-commit hook runs a read-only check on tracked `Git` config sources. The checker reads `home/dev/personal/.domains` directly. It does not read the effective global config or inspect local work files.

The checker rejects unscoped credential, HTTP, and URL-rewrite settings. It also rejects hostnames outside the personal domain list. Credential and HTTP scopes use host-only HTTPS URLs. URL rewrite destinations and prefixes use host-only HTTPS or SSH URLs. These URLs can omit the path or use one trailing slash.

A tracked credential section can use only `useHttpPath`, with a boolean value. Credential usernames and all tracked credential helpers fail, even when the hostname appears in the personal list. A shared tracked helper would apply to both profiles. The setup task writes the helper to the selected profile's local `.gitconfig`. Tracked `user.name`, `user.email`, and `user.signingKey` values also fail.

Tracked HTTP sections can use only `sslVerify`, `followRedirects`, `lowSpeedLimit`, `lowSpeedTime`, and `postBuffer`. `sslVerify` must enable certificate checks. Boolean and numeric values must have valid forms. HTTP headers, proxies, cookies, certificate paths, and unknown keys fail, even for a listed host. This prevents work identity or authentication data from entering tracked config.

Tracked `remote.*.url` and `remote.*.pushurl` entries also fail. Keep remote URLs in the local `.git/config` file for each repository.

The checker reports a fixed config source label and setting category. It does not print hostnames or config values. It blocks the commit and does not move or rewrite config. Remove work-specific entries from tracked files. Then run the setup task for the correct profile.

## Migration

Keep personal identity and credential settings in `~/dev/personal/.gitconfig`. Keep work identity, domains, and credential settings in `~/dev/work/.gitconfig` and `~/dev/work/.domains`.

If `gh auth setup-git` wrote a helper to a tracked config source, remove that entry after review. Then run the setup task with the correct profile and hostname. The task writes Git credential settings only to the selected local `.gitconfig`.

The setup task does not move existing entries. The pre-commit check fails until tracked config follows the policy.

## Browser routing

The `.domains` file lists profile membership only. Future browser or browser-profile routing belongs in a separate mapping file. Keep that mapping independent from `Git` credential settings.

## References

- [`gh auth setup-git`](https://cli.github.com/manual/gh_auth_setup-git)
- [`gitcredentials`](https://git-scm.com/docs/gitcredentials)
- [`git-config`](https://git-scm.com/docs/git-config)
