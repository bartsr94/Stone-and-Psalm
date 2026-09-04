We have just completed a piece of work in this conversation. Go through what we built or
changed and update the relevant existing documentation to reflect it.

## Protocol

1. Review the work completed in this conversation — code written, decisions made, patterns
   established, config changed, commands added or removed

2. Identify which existing documentation files are affected using the guide below

3. For each affected file, propose what needs to change:
   - Section to update and why
   - New content to add
   - Anything now outdated that should be removed or corrected

4. Wait for approval, then update one file at a time

## File Routing Guide

| Change type | File to update |
|-------------|---------------|
| New feature completed / test count changed / a risk resolved | `STATUS.md` — update the relevant task table, test count, and Open Risks section |
| Architecture change, new autoload, new `scripts/sim/` calculator, new data schema | `CLAUDE.md` — Folder Layout, Key Patterns, or Anti-patterns section |
| A `docs/ARCHITECTURE_GUIDE.md` section (the Fundamental Rule, 3D conventions, determinism, save/load, performance targets) changed | `docs/ARCHITECTURE_GUIDE.md` — update the specific section, and add to §12 Known Deviations if it's a deliberate compromise rather than a bug |
| What the simulation must compute changed — a formula, a tick-order step, a new field, a tuning constant's meaning | `docs/SIMULATION_SPEC.md` — update the specific section; if it's the tick order (§18), treat that as a contract change and call it out explicitly |
| System dependency added, changed, or a boundary violation fixed | `docs/ARCHITECTURE_GUIDE.md` §2 and flag it for `/system-interconnections` to re-check |
| Upcoming priorities changed, a roadmap item completed or reprioritized, a phase's screenshot/clip exit criterion met | `docs/planning/ROADMAP.md` — update the task table and, if a phase completed, its milestone summary |
| A SPEC open question (§22) got resolved, or a design decision changed | `docs/SIMULATION_SPEC.md` §22 and/or `docs/GDD_STONE_AND_PSALM.md` — update the entry directly and note the resolution |
| A historical detail that produced a building, a chain, a number, or a named event | the relevant `data/*.json` plus a note in `docs/reference/HISTORICAL_REFERENCE.md`; pure flavour goes only in `HISTORICAL_REFERENCE.md` |
| A new decision was made worth remembering later | `STATUS.md` — add a row to the Decision Log with date and rationale |
| Implementation detail worth remembering (why this approach, what was hard) | Create / update `docs/implementations/<YYYY-MM-DD>_<slug>.md` |
| A new balance number or a changed constant | `data/tuning.json` (never a `.gd` file), and `docs/SIMULATION_SPEC.md` §21 if its role is documented there |

## Rules

- Only update what the completed work actually affects — do not do a general audit
- Match the existing tone, voice, and formatting of each document
- Do not add sections that don't already exist unless explicitly asked
- Keep updates concise — reflect the change, don't over-document it
- If something was removed or deprecated, remove or strike it from the docs too
- Never add day-to-day implementation detail to `CLAUDE.md` — that belongs in `STATUS.md` or
  `docs/implementations/`
- If a change resolves a documented risk (`STATUS.md` Open Risks) or a SPEC open question
  (§22), always update that entry rather than leaving it stale — that's exactly the doc drift
  this command exists to catch
- If a change violates or narrows the Fundamental Rule (`docs/ARCHITECTURE_GUIDE.md` §2) or the
  determinism rules (§7), that must be reflected in §12 Known Deviations, not silently left for
  someone else to discover
- If a change altered the tick order (`docs/SIMULATION_SPEC.md` §18), that is a contract change
  — update §18 and note it prominently
