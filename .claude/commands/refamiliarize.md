---
description: Re-orient on the current repo's structure, conventions, and recent activity
---

Get up to speed on this repository before doing anything else. Work through this systematically:

1. **Project identity**: Read `CLAUDE.md`, `STATUS.md`, `docs/GDD_STONE_AND_PSALM.md`, and
   `docs/SIMULATION_SPEC.md` §1 to identify the stack, current phase, and design intent.

2. **Structure**: List the top-level directory tree (2-3 levels deep, skip `.godot/`,
   `addons/gut/`, `assets/kit/`). Note where autoloads, scenes, `scripts/sim/`, `scripts/view/`,
   `scripts/ui/`, and `data/` live.

3. **Git state**:
   - Current branch and its relation to `main` (ahead/behind)
   - `git status` for uncommitted changes
   - Last 15-20 commits (`git log --oneline -20`) to see what's been worked on recently
   - Any open stashes

4. **Conventions**: Check `docs/ARCHITECTURE_GUIDE.md` §9 for GDScript conventions and §7 for
   the determinism rules, confirm the GUT version pinned in `CLAUDE.md` (9.6.0, not 9.7.1),
   and check for any CI config (`.github/workflows`).

5. **In-flight work**: Grep for TODO/FIXME/XXX markers, check `STATUS.md`'s task tables and
   Decision Log for what's currently being built or decided, and check `docs/SIMULATION_SPEC.md`
   §22 for open design questions still on placeholder values.

Once done, give me a concise summary (not a wall of text) covering:
- What this repo is and its stack, and which roadmap phase it's currently in
- Current branch + any uncommitted work
- What the last few commits were doing (the "story" of recent work)
- Anything that looks unfinished or in-progress
- Anything unusual/notable I should know before making changes — especially any drift from
  the authoritative/transient state boundary (`docs/ARCHITECTURE_GUIDE.md` §2) or from the
  roadmap's deliberately inverted 3D-first phase order

Don't propose changes or start any task yet — this is orientation only. Wait for my next instruction.
