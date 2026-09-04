---
description: Branch, commit, push, merge into the main branch, and clean up — leaves you on main ready for the next task
---

Wrap up the current work:

1. Run `git status` and `git diff` to see what's changed.
2. Create a new branch off the current branch. Name it based on the actual changes (e.g. `fix/`,
   `feat/`, `chore/` prefix + short kebab-case description) — don't ask me for a name unless the
   changes are too ambiguous to summarize.
3. Stage all local changes (`git add -A`).
4. Write a clear, concise commit message that reflects what actually changed (not a generic
   message). Match the existing commit style in `git log`.
5. Commit.
6. Push the new branch to origin, setting upstream (`git push -u origin <branch-name>`).
7. Determine the repo's main branch (`main` — check `origin/HEAD`, don't assume). Check it out
   and pull latest.
8. Merge the new branch into main with `--no-ff` (matches this repo's existing merge history —
   no squash/rebase), then push main to origin.
9. Delete the feature branch, both local (`git branch -d`) and remote
   (`git push origin --delete <branch-name>`), now that it's merged in — no dangling branches.
10. Run the project's test suite on main to confirm main is green post-merge — see `CLAUDE.md`
    for the GUT command. If a `class_name` was added anywhere in this work, run the import pass
    first (`godot --headless --import --path .`) and check the warning count, not just the pass
    line — GUT reports an unloadable test file as a warning while still printing "All tests passed".
11. Report back: branch name, commit message, push status, merge result, verification result,
    and confirm you're left on main.

Don't create a PR unless I ask for one — this workflow merges directly.

If the merge hits a real conflict, stop and report it rather than resolving it unilaterally —
ask how I want it handled.

If origin has no remote configured, do steps 1-5 and 7-10 locally and skip the pushes, noting that.
