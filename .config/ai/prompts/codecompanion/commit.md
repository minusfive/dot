---
name: "Commit changes"
interaction: chat
description: "Commit the staged changes to the repository with a message."
opts:
  adapter: "copilot"
  model: "gpt-5-mini"
  rules:
    - default
    - work
---

## user

Review, commit, push changes. Use a new branch if not already on a feature branch. Check, and if a PR doesn't already exist, create one.
