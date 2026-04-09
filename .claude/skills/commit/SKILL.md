---
name: commit
description: Generate a commit message and commit staged changes
disable-model-invocation: true
---

# Commit

1. Run `git diff` to review changes
2. Run `git log --oneline -5` for recent style reference
3. Generate a short, single-line commit message:
   - Imperative mood, no period, under 50 characters
   - No co-author trailer
4. Present the message and ask the user to confirm before committing
