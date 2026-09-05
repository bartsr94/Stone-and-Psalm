# Stone and Psalm — Game Design Document

**Version:** 1.0
**Date:** 2026-09-04

> What this game *is*. For what the simulation must **compute**, see `SIMULATION_SPEC.md`.
> For the facts everything rests on, see `reference/HISTORICAL_REFERENCE.md`. For how the code
> is organised, see `ARCHITECTURE_GUIDE.md`.

---

## 1. Vision Statement

**You found a monastery in a Yorkshire valley in 1132, and you spend the next fifty years
trying to keep it alive.**

*Stone and Psalm* is a small-scale, historically grounded 3D settlement builder in the mould of
*Banished*, with the production-chain depth of the *Anno* series and the intellectual texture of
*The Name of the Rose*. There is no combat. The antagonists are winter, arithmetic, the
liturgical calendar, and your own ambition.

You choose which religious order founds the house, and that choice is not a stat block — it is
an argument about **how a day should be spent**. A Cistercian house works. A Cluniac house
prays and buys its labour. A Carthusian house has twelve men and copies books. Same buildings,
completely different game.

The house outlives its monks. You will bury the men you started with.

---

## 2. Core Pillars

**1. The day is the resource.**
Not wood, not stone — *hours*. The Divine Office claims eight fixed intervals of every day, and
medieval hours were unequal: a summer hour ran ~84 minutes, a winter hour ~36. Winter takes
your daylight and leaves the interruptions. Everything else in the game is downstream of this.

**2. History is the design document.**
Nothing is invented where a real answer exists. The buildings, the chains, the offices, the
corrodies, the frost rule for mortar, the conversi revolts — all documented. The research
constraint is a feature: it produces better systems than invention does.

**3. Depth through fidelity, not breadth.**
Twenty production chains, but each with real internal texture — seasonality, skill, quality,
spoilage, and a physical location things must be carried from. A single illuminated manuscript
costs a skilled monk more than a year. We would rather have thirty honest buildings than a
hundred shallow ones.

**4. Look at it. It should be beautiful.**
This project exists to learn 3D. The visual target is *Banished*'s northern melancholy at a
smaller scale: stone, wet grass, woodsmoke, low sun, snow. **Every roadmap phase ends with a
screenshot or it isn't finished.**

**5. The house can die.**
Starvation spirals, insolvency, dissolution, or simply an ageing community that stopped
attracting novices. Failure must be reachable through ordinary mismanagement, and legible in
hindsight.

---

## 3. Setting

**Ashholt Abbey** (placeholder name), a fictional house in a Yorkshire dale, founded 1132.
A river valley on the edge of the moors — woodland on the slopes, meadow on the flat, moorland
above, limestone and iron in the hillside, and nothing else for a day's ride.

Campaign window **1132–1348**, ending at the Black Death (optional). Full grounding in
`reference/HISTORICAL_REFERENCE.md` §1.

No fantasy elements. No magic. This is deliberately, completely different from the rest of the
portfolio, and that is the point.

---

## 4. The Founding Choice — the Orders

The first and most consequential decision. Full detail in `HISTORICAL_REFERENCE.md` §2.

| Order | Starting position | The day | Plays like |
|---|---|---|---|
| **Benedictine** | Endowed, a patron, a small library, £20 | Balanced | The generalist. Recommended first game. |
| **Cistercian** | Remote, poor (£2), strong lay-brother workforce, water engineering | Work-heavy, short offices | Production and logistics. The *Anno* playstyle. |
| **Cluniac** | Wealthy, prestigious, papal protection | **Office-dominated** — 7 h/day of liturgy | Economics and politics. You *buy* labour. |
| **Carthusian** | Twelve monks, hard cap, high literacy | Solitary; cell-based | Hard mode. Tall, not wide. |
| **Premonstratensian** | Appropriated parishes, tithe income, goodwill | Split between house and parish | Influence. Develop the countryside. |

Each order changes: starting capital and grant, population composition and cap, office durations
and thus available labour, available buildings, recruitment rates, architectural style, and
which institutional pressures apply.

**Design test for each order:** if two orders play the same after ten hours, one of them is
wrong.

---

## 5. The Loop

**Minute to minute** — watch the precinct. Monks file into the church for Terce; the conversi
keep working. A hauler carries fleece from the sheepfold to the wool store. A mason dresses
stone. Snow starts.

**Day to day** — assign labour. Someone must haul the barley to the malthouse, and the man you
take off the fields is a man not harvesting.

**Season to season** — the real cycle. Spring: sow, and open the building season. Summer: shear,
hay, build. Autumn: harvest, salt, get the mortar laid before frost. Winter: seven hours of
light, no building, and everything you didn't store in autumn is a problem now.

**Year to year** — the visitation. The wool buyers. Novices professed, old monks buried, the
church one course of stone higher.

**Decade to decade** — the transept is finished. The library has forty books, three of which
should probably not be there. Your founding abbot is dead. You send twelve monks out to found a
daughter house.

---

## 6. Simulation

The full specification is `SIMULATION_SPEC.md`. Summary of what makes it Banished-grade:

- Every person is an individual with a name, an age, a body, skills, and a history.
- Every good exists in a specific place and moves only because someone carries it.
- Labour is limited by daylight and the liturgical calendar, computed per person per day.
- Construction needs materials delivered, progresses over years, and stops in frost.
- Needs go unmet, health falls, people die, and death cascades.
- Population grows by **recruitment, not birth** — you cannot breed out of a labour shortage.

---

## 7. Production and Economy

Twenty-plus chains (`SIMULATION_SPEC.md` §9). The distinctly monastic ones carry the depth:

- **Beeswax → altar candles.** Liturgically obligatory, consumed continuously. The Rule needs
  what the bees make.
- **Hides → parchment; oak galls → ink; + a literate monk + 400 hours → one manuscript.**
- **Barley → malt → ale.** The daily drink, at a gallon a head. Not a luxury.
- **Stew ponds → fish.** Meat is forbidden to the healthy, so protein means fishponds.
- **Quarry → dressed stone → the church**, over fifty years.

External economy: wool is the cash crop, sold by grade to Flemish and Italian buyers, with
forward contracts available and ruinous. Plus rents, tithes, burial fees, pilgrim offerings,
manuscript commissions — and **corrodies**, the pension-for-a-lump-sum instrument that looks
like salvation and is usually the beginning of the end.

---

## 8. The Library — the *Name of the Rose* thread

Books are individual objects, not a number: title, subject, rarity, condition, and an
**orthodoxy risk**.

A growing library raises prestige, attracts scholars and novices, enables higher lectio and
better copying — and attracts scrutiny. Rare texts, pagan philosophy, medical works and
anything touching the poverty controversy raise the house's profile with people you would
rather not interest.

Late in the campaign this can bring an episcopal inquiry or an inquisitor to the gate: books
examined, some burned, monks questioned, and a genuine choice about what to hide and what to
surrender.

**Explicitly not a murder mystery.** The tension is institutional, not a whodunit. That would be
a second game bolted onto this one.

---

## 9. Institutional Pressure

Three external relationships, each with its own demands (`SIMULATION_SPEC.md` §15):

- **The Order / the Bishop** — annual **visitation**, the recurring exam. Scores observance,
  fabric, solvency, care of the poor, discipline, liturgy, learning. Outcomes run from
  commendation to deposition of your abbot to dissolution of the house.
- **The Patron** — the local baron who founded you. Wants burial rights, perpetual prayers, and
  hospitality on demand. Gives land and money. Can take them back.
- **The Countryside** — tenants, the poor at the gate, and neighbouring lords. Rack-rent them
  and you get income and enemies.

You cannot fully satisfy all three. That is the *Name of the Rose* situation, mechanised.

---

## 10. Art Direction

**Target: *Banished*'s northern melancholy, at monastery scale.**

Grey stone, wet green, mud, woodsmoke, low raking sun, and real snow. Restrained and
naturalistic, never storybook. Legibility at the working camera distance beats detail.

Technical approach (rationale in `ARCHITECTURE_GUIDE.md` §4):

- **Low-poly with vertex colours**, one shared material, one small palette texture. This gives a
  coherent look, runs fast, and — critically for a first 3D project — **skips UV unwrapping and
  texturing**, which is where 3D beginners actually lose their months.
- **Lighting is the quality lever, not model detail.** One good `WorldEnvironment` with SSAO,
  volumetric fog and a well-tuned sun does more than a dozen extra building types. Invest there
  before adding the second building.
- **Seasons are the biggest visual payoff available.** A season is a set of environment and
  material parameters lerped across the year: sun colour and angle, fog density, ground colour
  ramp, snow coverage, tree state. Cheap to implement, transforms the game, and drives the sim
  too.
- **Architectural style follows the order.** Cistercian austerity (plain, no tower, no figurative
  carving) versus Cluniac elaboration is a real, visible difference — and the Cistercian version
  is *less* geometry, so the austere order is also the cheaper one to ship first.

**Reference:** Fontenay, Fountains, Rievaulx, Le Thoronet, Tintern
(`HISTORICAL_REFERENCE.md` §8.3). We are not inventing what a chapter house looks like. We are
observing one. This is the chief advantage of the historical setting for a project whose whole
purpose is learning to make things look right.

---

## 11. Camera and Presentation

- **Orthographic `Camera3D`**, fixed ~40° pitch, freely rotating around the vertical axis by
  middle-mouse drag (with Q/E 90° steps), and a zoom range from
  precinct overview down to reading a monk's habit colour.
- Never a free-pitch camera. The fixed tilt keeps silhouettes and ground readability predictable
  while allowing players the familiar continuous orbit used by city builders.
- Agents are individually visible and individually identifiable at mid zoom: **tonsured monks in
  the order's habit colour, bearded conversi in undyed russet**, and lay famuli in ordinary
  clothes. The visual distinction is historical and it is also the UI.

---

## 12. UI

The information problem in a deep-chain game is the real design work.

- **The Horarium** — the day as a ring or bar, showing offices, work blocks and their lengths,
  updating visibly as the year turns. This is the game's signature screen and should be built
  early, because it teaches the core mechanic without words.
- **Chain view** — Anno-style graph of what feeds what, with live throughput and the bottleneck
  highlighted.
- **The community roster** — every person by name, age, role, health, devotion, skill. You should
  be able to find out who is ill and who is idle in one click.
- **The chapter house** — governance: appoint obedientiaries, set rations, set the lectio/labour
  balance, decide disciplinary cases.
- **The ledger** — income, expenditure, debts, contracts, corrodies.

---

## 13. Explicit Non-Goals

| Not doing | Why |
|---|---|
| **Combat** | Not what this game is. Raids resolve as events, not battles. |
| **A murder mystery** | Narrative branching plus a deep sim is two games (§8). |
| **A Rimworld needs/mood/relationship sim** | Named individuals with roles and skills give the flavour at a fraction of the cost. |
| **Enterable building interiors** | Exterior-only. Agents despawn at doors. (Sim Spec Open Q 3.) |
| **Free-look camera** | Fixed rig is a deliberate art-risk reduction (§11). |
| **A trade network of rival settlements** | One town market and a road out is enough. |
| **Fantasy or invented religion** | The whole point is the historical work. Palusteria stays in the other projects. |
| **Multiplayer, procedural narrative, mod support** | Out of scope entirely. |

---

## 14. Open Design Questions

Placeholders are **in force** — implementation is never blocked waiting on these.

| # | Question | Placeholder |
|---|---|---|
| 1 | Final name — *Stone and Psalm* or something else? | **Stone and Psalm.** |
| 2 | Abbey name? | **Ashholt Abbey.** |
| 3 | Is the campaign open-ended or does it end at 1348? | **Open-ended, with 1348 as a toggleable event.** |
| 4 | How much Latin in the UI? | **Office and building names in Latin with English gloss on hover.** |
| 5 | Are all five orders in v1? | **No — Cistercian and Benedictine in v1.** The other three post-vertical-slice. |
| 6 | Difficulty settings? | **Site quality + starting endowment**, chosen at founding. No abstract sliders. |
| 7 | Tutorial? | **The Benedictine start is the tutorial**, with contextual prompts. |
| 8 | Do we ever show the inside of the church during an office? | **Deferred.** Would be gorgeous; costs an interior pipeline. Revisit after the vertical slice. |

---

## 15. The Portfolio Risk

This project's stated purpose is **learning 3D and visual work**. This portfolio's documented
failure mode is building a deep, well-tested simulation and never rendering it — Star Routes,
134 tests and zero rendering; Frontiers Unknown, 1251 tests and paused.

*Stone and Psalm* is, by design, exactly the kind of project that fails that way. `SIMULATION_SPEC.md`
is 22 sections of extremely tempting headless work.

The countermeasures, which are structural rather than aspirational:

1. **Phase 1 is a rendered 3D scene**, before any production-chain code exists.
2. **Every roadmap phase has a screenshot as an exit criterion.**
3. **Greybox with a free asset kit** so the sim never blocks on art, and replace piece by piece.
4. **The Horarium UI is built in Phase 3**, not Phase 8 — the core mechanic must be *visible*
   early.

See `planning/ROADMAP.md` for how the phase order enforces this.
