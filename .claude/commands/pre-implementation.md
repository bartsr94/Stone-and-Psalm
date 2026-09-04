# Pre-Implementation Protocol

Before writing a single line of code, complete the following steps in order.
Do not skip steps or combine them. Wait for explicit approval before proceeding to
implementation.

**Task:** $ARGUMENTS

---

## Step 1: Understand the Project Structure

Read the key orientation files:
- `CLAUDE.md` — the Fundamental Rule (authoritative state outside the scene tree, transient
  physical state inside it), folder structure, key patterns, 3D conventions, anti-patterns,
  and the mechanic everything rests on (unequal hours)
- `STATUS.md` — current phase, what's complete, test count, known gaps and risks
- `docs/GDD_STONE_AND_PSALM.md` — the design source; any task touching game rules (orders,
  horarium, economy, construction, population) is checked against the relevant section
- `docs/SIMULATION_SPEC.md` — the authoritative spec for what the simulation must compute;
  §1 is the acceptance checklist, §18 is the tick-order contract, §6 is the labour system
- `docs/ARCHITECTURE_GUIDE.md` — where things live and why, especially §2 (the
  authoritative/transient split and its contract) and §7 (determinism)

---

## Step 2: Review Relevant Planning Docs

Check the following if the task relates to planned work:
- `docs/planning/ROADMAP.md` — which phase this task belongs to, and whether earlier phases
  it depends on are actually done (check `STATUS.md`, not just the roadmap's intent)
- `docs/implementations/` — dated implementation records for in-progress/recent work
- `docs/SIMULATION_SPEC.md` §22 — open design questions; if the task touches one, resolve or
  explicitly punt on it before proceeding

**Phase-order check:** the roadmap is deliberately inverted — Phases 1–3 build a lit, seasonal
3D valley with a monk walking around in it *before* a single production chain exists. This
counteracts this portfolio's documented failure mode (a deep, well-tested simulation that never
gets rendered — Star Routes: 134 tests, zero rendering). If this task would build simulation
depth (a production chain, the labour system, population dynamics) and Phase 3 isn't done, flag
that explicitly rather than proceeding quietly.

**Research check:** if this task needs historical grounding, apply the research rule — research
produces a building, a chain, a number, or a named event. If it produces none of those four,
it's flavour text: file it in `docs/reference/HISTORICAL_REFERENCE.md` and move on. Don't open
a new research thread mid-implementation.

---

## Step 3: Analyse the Test Suite

Review the existing tests to understand the established QA approach:
- `test/unit/` — mirrors `autoloads/` and `scripts/sim/`; test file naming conventions, what
  is and isn't tested
- `test/integration/`, `test/soak/` — headless world runs and long determinism soaks
- `addons/gut/` — GUT 9.6.0 (tests extend `GutTest`, assertions via `assert_*`)
- Run tests with the command in `CLAUDE.md` (`Start-Process` + `-RedirectStandardOutput` —
  never pipe Godot headless output with `*>&1`, it hangs). A fresh checkout needs one
  `godot --headless --import --path .` pass first.

Identify:
- Which autoloads or `scripts/sim/` calculators the task touches — check if tests exist
- Whether the task introduces new authoritative state that needs a `serialize()`/`deserialize()`
  entry (`docs/ARCHITECTURE_GUIDE.md` §8)
- **The testing split**: authoritative state and `scripts/sim/` calculators get exhaustive
  GUT tests; 3D presentation (camera, meshes, materials, VFX, weather) gets a screenshot or a
  clip per the roadmap's exit criteria, not a unit test that needs a renderer to be meaningful
- Whether this touches determinism — if so, it must survive a soak test (`docs/ARCHITECTURE_GUIDE.md`
  §7): injected `Dice` not `randf()`, sorted iteration of unordered containers, tick order per
  `SIMULATION_SPEC.md` §18

---

## Step 4: Identify Relevant Existing Code

Before proposing anything new, find what already exists:
- Are there existing scripts, scenes, or data files that overlap with the task?
- Is there shared logic in an existing autoload or `scripts/sim/` calculator that should be
  used rather than duplicated?
- Are there similar mechanics already implemented that should serve as a reference pattern —
  or that this task should actually replace?
- Is there a data-driven way to do this? If the task tempts you to write
  `if building_id == "brewhouse"`, the answer is a field in `data/*.json`, not a branch.
- Are there any TODO comments or stubs relevant to this task (`/feature-audit` covers this
  exhaustively if needed)?

Flag any code that would need to be modified (not just added to) and note the risk level.

---

## Step 5: Clarify Ambiguities Before Planning

If any of the following are unclear after reviewing the codebase, ask now — do not make assumptions:
- The exact scope of what needs to be built or changed
- Which existing patterns should be followed vs intentionally deviated from
- Whether this task crosses the authoritative/transient boundary (`docs/ARCHITECTURE_GUIDE.md`
  §2.3) — if so, confirm exactly what state is authoritative, what is transient, and that only
  `world_renderer.gd` touches the scene tree
- Whether any new balance number belongs in `data/tuning.json` (it does — no magic numbers in
  `.gd` files, ever)
- Whether this task depends on data (`data/*.json`) or assets (own `.glb` in `assets/models/`,
  or third-party greybox in `assets/kit/`) that don't exist yet — if so, is greybox acceptable
  (it usually is — the sim never waits on art), or should it wait?
- Test coverage expectations for the new work
- Design questions: does the GDD / SIMULATION_SPEC fully specify this, or does it require a
  judgment call that should be flagged as a new `SIMULATION_SPEC.md` §22 open question rather
  than silently decided in code?

List any assumptions you are making if questions are not raised here.

---

## Step 6: Summarise Your Findings

Provide a structured summary covering:

**Project Overview**
- Stack, frameworks, and key dependencies relevant to this task
- Overall architecture pattern in use

**Documentation Insights**
- Key conventions or constraints found in docs
- Anything documented that directly affects this task

**Test Suite Patterns**
- How tests are structured and named (or note that none exist yet for this system)
- Relevant existing test files to be aware of

**Relevant Existing Code**
- What already exists that overlaps with or should inform this task
- Any files that will need to be modified (not just new files added)
- Risk level of any required modifications: Low / Medium / High

**Assumptions Made**
- List any gaps in information that you filled with a reasonable assumption
- Flag anything that should be confirmed before implementation begins

---

## Step 7: Propose an Implementation Plan

Present a step-by-step implementation plan with the following structure:

**Task Breakdown**
Break the work into logical, ordered steps. For each step include:
- What will be built or changed
- Which files will be created or modified
- Which existing patterns it follows
- Dependencies on other steps

**Impact Classification**
Rate the overall change as:
- 🟢 Small — isolated changes, low risk, minimal surface area
- 🟡 Medium — touches multiple files or components, moderate rework required
- 🔴 Large — significant restructuring, broad impact, or high risk of regression

**File Change Summary**
Provide a clear list:
- 🆕 New files to be created (with proposed path and purpose)
- ✏️  Existing files to be modified (with a note on what changes and why)
- ⚠️  Files that may be indirectly affected (flagged for awareness)

**Test Coverage Plan**
Describe what tests will be written or updated:
- What scenarios will be covered (GUT, for authoritative state / `scripts/sim/`)
- What visual output proves it (screenshot / clip, for 3D presentation)
- How the new tests fit into the existing suite structure (or establish the first pattern)

**Risks & Considerations**
- Any edge cases the implementation needs to handle
- Potential side effects of the proposed changes
- Anything that should be manually verified after implementation
- Any design-fidelity risk (does this match the GDD / SIMULATION_SPEC, or approximate it?)
- Any determinism risk (`randf()`, unordered iteration, tick-order deviation)

---

## Step 8: Generate Implementation Document

Before awaiting final approval, produce a concise implementation document as a standalone
artefact. Save it to `docs/implementations/` using the naming convention:
`YYYY-MM-DD_[feature-or-task-slug].md`

The document must contain the following sections:

---

### Implementation Document Template

# [Task Title]

**Date:** [YYYY-MM-DD]
**Status:** PENDING APPROVAL

---

## Summary
One short paragraph describing what this implementation does and why.

## Scope
What is included in this implementation and what is explicitly out of scope.

## Affected Areas
| File / Module | Change Type | Risk |
|---|---|---|
| path/to/file.gd | Modified | Low / Medium / High |
| path/to/new-file.gd | Created | Low / Medium / High |

## Implementation Steps
Ordered list of what will be done, mirroring the Task Breakdown from Step 7.
Each step should be a single, verifiable action.

1.
2.
3.

## Test Coverage
- What will be tested and at what level (GUT vs. screenshot/clip)
- New helpers being introduced
- Existing tests being updated

## Assumptions & Decisions
Any choices made during planning that the approver should be aware of,
including alternatives that were considered and ruled out.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Description | Low / Med / High | Low / Med / High | How it will be handled |

## Rollback Plan
How to revert this change if something goes wrong after implementation.

## Acceptance Criteria
A checklist of conditions that must be true for this task to be considered complete:
- [ ]
- [ ]
- [ ]

---
**Approved by:** ______________________
**Approval date:** ______________________

---

## Step 9: Await Approval

Do not write any code until the implementation document has been explicitly approved.

Once the document is presented:
- Await confirmation or feedback
- If changes are requested, update the document and resubmit
- Once approved, update the document status from PENDING APPROVAL to APPROVED and record the
  approval date before beginning any work

After completing each step in the implementation:
- Summarise what was completed
- Note anything that differed from the approved plan and why
- Update the implementation document to reflect any deviations
- Confirm the next step before continuing

When the implementation is fully complete, update the document status to COMPLETE and run
`/update-docs` to reflect the work in all relevant documentation.
