# WezTerm agent rules

- Apply these rules when you change files in `home/.config/wezterm/`.
- Validate pane and split changes before you finish. For split work, run repeated `Left`, `Right`, `Up`, and `Down` stress checks.
- Use `wezterm.org` as the canonical documentation site.
- Treat `wezfurlong.org/wezterm` as legacy and non-canonical.
- If split behavior differs by direction, reason from pane geometry and split-tree insertion order. If one direction pair passes and the opposite pair fails, inspect the active band before you change code.
- If attempts stall, pause and probe action semantics with small `wezterm cli` cases before another large rewrite.
- Keep rebalance work synchronous unless you can prove retries are required. Timer-heavy loops have crashed WezTerm here.
