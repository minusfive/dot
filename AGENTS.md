Also look for skills in the local project @.agents and global @~/.agents directories, in addition to the default directories. **NOTE**: `~/.agents` points to `~/dev/personal/dot/.agents`, so local and global skill paths refer to the same files when working in `~/dev/personal/dot`. Do not assume this relation in other directories.

Prefer dedicated tools over Bash commands: Glob (not find/ls), Grep (not grep/rg), Read (not cat/head/tail), Edit (not sed/awk), Write (not echo/cat heredoc).

Planning sessions must complete exploration, evaluation, and decision-making before execution starts. Treat `planning-determinism` as the canonical planning completeness policy, and use it to gate transitions from planning to execution for scoped work.
