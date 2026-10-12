# `.config` cleanup recommendations

**Review date:** 2026-10-11
**Scope:** Tracked `.config` files with a current recommendation for removal.

## Current state

The `.config/` boundary has no remaining tracked files. The Hammerspoon
`.luarc.json` file and the WezTerm instruction files moved to their canonical
`home/.config/...` source directories. The legacy `.config/` paths are removed.

No further `.config/` cleanup is required. Keep active, deferred,
repository-only, historical, and already-removed paths in their module
inventories or supporting research instead of this file.
