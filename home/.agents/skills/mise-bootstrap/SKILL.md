---
name: mise-bootstrap
description: Use when bootstrapping a machine with `mise`, checking bootstrap state, or editing bootstrap packages, files, repos, dotfiles, services, firewall, compose, macOS defaults, LaunchAgents, systemd units, user settings, shell activation, or remote bootstrap config.
---

## MCP first

If `mise` MCP is available, inspect the live bootstrap state first.
Use MCP reads before shell commands when they can answer the question.

Use the command effect labels from `mise` MCP before you run a bootstrap command.

## Canonical docs

Start at `https://mise.jdx.dev/bootstrap.html`.
Use the linked bootstrap docs as the source of truth for command names, flags, and area-specific behavior.
