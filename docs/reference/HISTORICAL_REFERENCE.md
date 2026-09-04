# Stone and Psalm — Historical Reference

**Version:** 1.0
**Date:** 2026-09-04

> The factual grounding for every system in this game. When a design question comes up,
> **check here before inventing an answer** — the historical answer is usually better, and
> is almost always more interesting than the invented one.
>
> **The research rule:** research produces a building, a chain, a number, or a named event.
> If it produces none of those four, it is flavour text — file it here and move on. Do not
> open a new research thread mid-implementation.

---

## 1. Setting: the window and the place

**Period: c. 1132–1348.** Chosen deliberately:

| Boundary | Why |
|---|---|
| **1132** | Foundation of Fountains and Rievaulx. The Cistercian expansion into northern England begins in earnest. |
| **1348** | The Black Death reaches England. Monastic communities were devastated; the conversi system in particular never recovered. |

Inside that window you get the great age of monastic land clearance, the wool boom, the
Romanesque→Gothic transition, and (at the far end, 1327) the exact year *The Name of the
Rose* is set.

**Place: a Yorkshire dale.** A fictional house — **Ashholt Abbey** (placeholder name) — in a
river valley on the edge of the moors, on the Fountains/Rievaulx model.

Why Yorkshire specifically:

- After the Harrying of the North (1069–70) large tracts were genuinely depopulated. "Found a
  house in the waste" is documented history, not a contrivance. Cistercian foundation charters
  describe sites as *eremus* — wilderness.
- The wool economy. Fountains was among England's largest wool exporters; Italian merchant
  handbooks graded English abbey wool house by house.
- Lead, iron and limestone are all locally available — the full building and metal chains work
  without imports.
- The climate gives a hard winter and a big daylight swing (§5), which is the engine of the
  whole simulation.
- The visual palette — northern, wooded, wet, grey stone, snow — is exactly the *Banished*
  register we are aiming at.

**Latitude for daylight maths: 54°N.**

---

## 2. The orders

Five playable founding orders. These are not stat variants of one thing — they are genuinely
different arguments about *how a day should be spent*, which is why they map so cleanly onto
this game's core loop.

### 2.1 Benedictine ("black monks") — the baseline

Rule of St Benedict, written c. 529 at Monte Cassino. By the 12th century the unreformed
Benedictine houses were typically old, well-endowed, sited near towns and roads, engaged with
secular society, and possessed of substantial libraries.

- **Starts with:** more capital, an existing patron relationship, a small library.
- **Day:** balanced three-way split (§4.1).
- **Weakness:** worldly. Higher exposure to patron politics and episcopal interference.
- **Plays like:** the generalist order.

### 2.2 Cistercian ("white monks") — the engineers

Cîteaux, 1098. A reform movement rejecting Cluniac elaboration and returning to a literal
reading of the Rule. Bernard of Clairvaux's *Apologia* is a real and vicious polemic against
Cluniac excess — that argument is this game's design spine.

Cistercian practice, all of it mechanically usable:

- Deliberate settlement in wilderness, far from towns.
- **Water engineering.** Leats, millraces, culverted drains, water-powered grain mills, fulling
  mills, tanneries and forges. The medieval description of Clairvaux's water system reads like
  a factory tour.
- **Granges** — outlying farms worked by lay brothers (§6).
- **Industrial sheep farming**, with wool as the primary cash crop.
- **The conversi** as a formal institution (§3.2).
- Austere architecture: no towers, no figurative sculpture, plain glass. Cheaper and faster to
  build — a real mechanical advantage.

- **Starts with:** almost no capital, a remote hard site, strong labour, engineering unlocks.
- **Weakness:** poor, isolated, no patron, a long road to solvency.
- **Plays like:** the production/logistics order. The Anno playstyle.

### 2.3 Cluniac — the liturgists

Cluny, 909. Over the 10th–11th centuries the Divine Office was inflated until it consumed
effectively the entire day — at its height Cluny's daily psalmody dwarfed the Rule's provision.
Manual labour became nominal; the house lived on endowments, serf labour and donations. Cluny
answered directly to Rome, bypassing local bishops. Cluny III was the largest church in
Christendom until the rebuilding of St Peter's.

- **Starts with:** wealth, prestige, papal protection, a large founding grant.
- **Day:** office-dominated. Very little monk labour available.
- **Weakness:** you cannot work your way out of a crisis. You must *buy* labour (famuli) and
  income (patrons, pilgrims, corrodies) — and every one of those has strings.
- **Plays like:** an economy/politics order where labour is a purchased commodity.

### 2.4 Carthusian — hard mode

La Grande Chartreuse, 1084. Semi-eremitical: each monk lives, works, eats and sleeps alone in a
private cell opening onto a great cloister, meeting the community only for some offices and a
weekly walk. Houses were deliberately capped at around twelve monks plus a prior, imitating
Christ and the apostles. Their assigned manual labour was **copying manuscripts** — they
"preach with their hands."

- **Starts with:** tiny population, a hard cap on growth, high literacy, high devotion.
- **Weakness:** you will never have enough hands. Everything must be bought, or made by very
  few very skilled people.
- **Plays like:** a tall, low-headcount, high-value-per-worker challenge order.

### 2.5 Premonstratensian (Norbertine) — the outward-facing

Prémontré, 1120. **Canons regular, not monks** — they follow the Rule of St Augustine, live
communally, but also serve parish churches and do pastoral work outside the walls.

- **Starts with:** appropriated parish churches (steady tithe income), local goodwill.
- **Weakness:** canons are constantly *away*. Labour leaks out of the precinct.
- **Plays like:** an influence order — you develop the surrounding countryside, not just the
  precinct.

### 2.6 Not playable: the mendicants

Franciscans (1209) and Dominicans (1216) are **friars, not monks**. They are urban,
propertyless by rule, and do not build abbeys in wilderness. They appear here as external
forces — the Dominicans in particular, as the order that supplied inquisitors.

---

## 3. The people

### 3.1 Choir monks

Literate (Latin), bound to the full round of offices, tonsured, professed for life. They do
skilled and light work: scriptorium, infirmary, administration, garden, church. A typical
12th-century house ran **12–40 choir monks**; the great houses reached 60–100 at peak.

Progression: **postulant → novice** (a year under the novice master) **→ profession**. The
Rule's vows are stability, *conversatio morum*, and obedience — not the later
poverty/chastity/obedience formula.

### 3.2 Conversi (lay brothers) — the Cistercian workforce

The most mechanically important institution in the game.

- Illiterate by design; **bearded**, unlike the tonsured choir monks — visually distinct at a
  glance, which matters at our camera distance.
- Recited a short memorised office at their work rather than attending the full round in choir.
  **They keep working while the monks pray.**
- Housed separately in the **west range**, with their own refectory and dormitory and a separate
  entrance to the church nave.
- Staffed the granges, often living out there for weeks at a time.
- Could not be ordained and could not become choir monks.
- **Revolted.** Conversi risings are documented at several houses, over food, drink rations and
  discipline. A real pressure system, not an invention.

At the great Yorkshire houses conversi *outnumbered* choir monks, sometimes two or three to one.

### 3.3 Famuli (hired servants)

Paid wages in cash and kind. Live outside the precinct. Not bound by the Rule, not subject to
monastic discipline, and **can be dismissed** — the only genuinely elastic labour you have.
Cost silver you may not have.

### 3.4 Tenants

Peasants on abbey lands paying rent and tithe. Not directly commandable. A passive income
stream plus a *justice* dial: rack-renting raises income and lowers goodwill.

### 3.5 Guests, pilgrims, corrodians, the poor

- **Guests** — Rule ch. 53: *all guests are to be received as Christ.* Hospitality is
  **obligatory**, not optional. A guest house, a guestmaster, and a real drain, occasionally
  offset by gifts.
- **Pilgrims** — drawn by relics. Income and prestige; also crowding and disease.
- **Corrodians** — see §7.3.
- **The poor at the gate** — the almoner distributes alms. Neglect is a visitation offence.

### 3.6 Obedientiaries — the named offices

Each is a real monastic office and each should be an assignable job with a distinct effect:

| Office | Responsibility |
|---|---|
| **Abbot** | Head of house. External relations, patron, visitation, discipline. |
| **Prior** | Deputy; runs the house day to day. |
| **Cellarer** | Provisions and estates. The Rule gives him his own chapter (ch. 31). |
| **Sacrist** | Church fabric, vessels, and **the candle supply**. |
| **Precentor** | Choir, chant, the library and the scriptorium. |
| **Infirmarer** | The sick and the aged. |
| **Almoner** | Alms to the poor at the gate. |
| **Guestmaster (hosteller)** | Guests and their provisioning. |
| **Kitchener** | The kitchen and the weekly cooking rota. |
| **Chamberlain** | Clothing, bedding, the bath and shaving rota. |
| **Novice master** | Training of novices. |
| **Master of the conversi** | Discipline and deployment of the lay brothers. |

Twelve meaningful assignment decisions, all historical.

---

## 4. The day

### 4.1 The three-way split

The Rule divides the monk's day between:

1. **Opus Dei** — "the Work of God", the Divine Office in choir. Ch. 43: *nothing is to be
   preferred to the Work of God.*
2. **Lectio divina** — prayerful reading. A genuine, protected claim on the day, and the reason
   a library and literacy matter mechanically.
3. **Opus manuum** — manual labour.

> **Note:** *"ora et labora"* is **not** a medieval motto. It is a 19th-century summary
> popularised by Maurus Wolter. Use the real three-way split — it is a better system anyway,
> because reading competes with work for the same hours.

### 4.2 The eight offices

| Office | Timing | Notes |
|---|---|---|
| **Vigils / Nocturns** | c. 2:00 a.m. | The long night office. Breaks sleep in two. |
| **Lauds** | First light | Follows Vigils after an interval. |
| **Prime** | Sunrise + 1 hour | Followed by the daily chapter meeting. |
| **Terce** | 3rd hour (mid-morning) | Followed by the morrow Mass. |
| **Sext** | 6th hour (noon) | Then the main meal. |
| **None** | 9th hour (mid-afternoon) | |
| **Vespers** | Late afternoon / sunset | |
| **Compline** | Dusk, before bed | Then the Great Silence until Vigils. |

The Rule (ch. 16) grounds this in Psalm 118/119:164 — *seven times a day have I praised thee* —
plus the night rising. Ch. 18 requires the whole **150-psalm Psalter each week**; Cluny
multiplied this several times over, the Cistercians held it to the Rule.

### 4.3 Unequal hours — the single most important mechanic in the game

Medieval time divided **daylight into twelve hours regardless of season**. A summer hour and a
winter hour were different lengths.

At 54°N:

| | Daylight | One "hour" |
|---|---|---|
| **Midsummer** | ~16 h 53 m | ~84 min |
| **Equinox** | 12 h | 60 min |
| **Midwinter** | ~7 h 06 m | ~36 min |

The offices are anchored to those unequal hours, and work happens *between* them. So in winter
you have both **less daylight** and **the same eight interruptions**, compressing the work
blocks brutally. The community's productive capacity collapses in the dark half of the year
through the calendar alone, before weather is even applied.

This is real, it is free, and it is the engine of the whole simulation.

### 4.4 Fasting and the food calendar

- **Meat of quadrupeds is forbidden to the healthy** (ch. 39). Fish, eggs, cheese and beans
  carry the protein. The sick in the infirmary are exempt — a real loophole that later houses
  abused via the *misericord*.
- Two meals a day in summer; **one** in winter and on fast days.
- **Lent** (40 days), **Advent**, and weekly Friday abstinence.
- The Rule allows roughly a *hemina* of wine daily; in northern houses **ale** substitutes.
  Water was not safely drinkable — **small beer was the daily drink**, at a substantial per-head
  allowance.

---

## 5. Climate and the year

Yorkshire dale, 54°N. Placeholder values for the sim:

| Season | Months | Character |
|---|---|---|
| **Spring** | Mar–May | Ploughing, sowing, lambing. Building season opens. Stores at their lowest — the **hungry gap** before harvest. |
| **Summer** | Jun–Aug | Long hours, haymaking, shearing (June), peak building. |
| **Autumn** | Sep–Nov | Harvest, threshing, slaughter and salting, last mortar before frost. |
| **Winter** | Dec–Feb | Seven hours of light. No mortar. Indoor crafts only: scriptorium, smithy, weaving, brewing. Consumption without production. |

**Mortar cannot be laid in frost.** The medieval building season ran roughly March to November;
unfinished walls were capped with thatch or dung over winter to stop frost splitting the fresh
mortar. An excellent, entirely real construction mechanic.

---

## 6. Land, granges and expansion

Expansion is **not** a bigger precinct. It is **granges** — outlying farms up to about a day's
travel out, worked by conversi who lived there under a grange master and came in to the abbey
only for major feasts.

That gives the game its map structure: one detailed core precinct, plus a ring of satellite
nodes with travel times, each specialising (sheep grange, arable grange, iron grange, fishery,
quarry). Much better for a small-scale builder than urban sprawl.

**The endgame is a daughter house.** A Cistercian abbey that prospered founded a colony —
canonically **an abbot and twelve monks**, echoing Christ and the apostles — sent out to found a
new house that remained subordinate to its mother. Founding daughter houses is the natural
victory arc, and it is exactly how Fountains and Rievaulx propagated across the north.

---

## 7. Money and obligation

### 7.1 Income

- **Wool** — the primary cash crop. Sold by grade to Flemish and Italian buyers, often
  **forward-sold years in advance** (a real practice that repeatedly ruined houses when the clip
  failed).
- **Rents and tithes** from tenants and appropriated churches.
- **Burial fees, obits and chantries** — payment for perpetual prayers for the dead.
- **Pilgrim offerings** at relics.
- **Manuscript sales** and copying commissions.
- Surplus produce: cheese, ale, salt fish, iron, lead.

### 7.2 Expenditure

Famuli wages, purchased salt, wine for the Mass, spices, parchment when not self-made, iron,
building materials, hospitality, alms, and **taxation** — royal, papal, and the General
Chapter's levies.

### 7.3 Corrodies — the trap

A layman pays the house a lump sum; in return he receives **food, drink, fuel and lodging for
life**. Real, common, and a documented cause of monastic insolvency: cash today, a permanent
drain forever, and the corrodian may live for thirty years. This should be an available,
tempting, and dangerous instrument.

### 7.4 Patronage

The founding patron (a local baron) expects burial rights within the church, perpetual prayers
for his soul and his line, and hospitality on demand. Patron goodwill gates endowments; patron
displeasure can mean withdrawn grants or seized lands.

---

## 8. The buildings

The claustral plan was near-standardised across Europe. **This is a gift for a builder game** —
there is a historically correct arrangement, so the game can reward the player for discovering
it rather than inventing an arbitrary adjacency rule.

The **Plan of St Gall** (c. 820) is a surviving 9th-century drawing of an ideal monastery,
labelled down to the brewhouse and the physic garden. It is, functionally, a free design
document.

### 8.1 The core claustral plan

```
                       [ Presbytery ]
      N transept ---- [   CHURCH    ] ---- S transept
                             |  (night stairs down from the dormitory)
   +-------------------------+--------------------------+
   |  WEST RANGE   |     CLOISTER GARTH     | EAST RANGE |
   |  cellarer's   |     (covered walks)    | chapter    |
   |  undercroft;  |                        | house,     |
   |  lay brothers |                        | parlour;   |
   |  above        |                        | DORMITORY  |
   |               |                        | above      |
   +-------------------------+--------------------------+
                       [ SOUTH RANGE ]
            warming house | refectory | kitchen
```

| Building | Function | Notes |
|---|---|---|
| **Church** | Opus Dei | Monks' choir separated from the lay nave by the pulpitum. The multi-decade build project. |
| **Cloister** | Circulation, lectio | Covered walks; the sunniest walk used for reading. |
| **Chapter house** | Daily governance | A chapter of the Rule read aloud each morning — hence the name. |
| **Dormitory** | Sleep | Above the east range, with **night stairs** direct into the transept for Vigils. |
| **Reredorter** | Latrine | Built over the main drain. Water engineering is a hard constraint on siting. |
| **Warming house (calefactory)** | Heat | **The only heated room in the monastery.** One fire, lit roughly November to Easter. |
| **Refectory** | Meals | Reading from a pulpit during meals; silence otherwise. |
| **Kitchen** | Cooking | Weekly rota per the Rule. |
| **Cellarer's range** | Stores | West range undercroft. Cistercian houses put the conversi above it. |
| **Infirmary** | Sick and aged | Own kitchen and chapel; meat permitted here. |
| **Abbot's lodging** | The abbot | Starts modest, grows scandalously over time — a real trajectory. |
| **Guest house** | Obligatory hospitality | Segregated by rank. |
| **Novitiate** | Training | Under the novice master. |
| **Gatehouse** | Control, almonry | Alms distributed here; the boundary between world and precinct. |
| **Precinct wall** | Enclosure | Defines the claustral boundary. |

### 8.2 The working precinct (outer court)

Brewhouse, bakehouse, malthouse, granary, **tithe barn**, watermill, fulling mill, smithy,
bloomery, tannery, chandlery, parchmenter's workshop, masons' lodge, sawpit, lime kiln, stables,
byres, dovecote, **stew ponds** (fishponds), orchard, physic garden, cemetery.

### 8.3 Reference houses for modelling

| House | Why |
|---|---|
| **Fontenay** (Burgundy, 1118) | The best-preserved Cistercian abbey anywhere — essentially intact, including the forge. First stop for any interior. |
| **Fountains** (Yorkshire, 1132) | Magnificent ruin, extensively surveyed. The cellarer's undercroft is the iconic image. |
| **Rievaulx** (Yorkshire, 1132) | Ruin in a dale — closest to our fictional siting. |
| **Le Thoronet** (Provence) | Cistercian austerity at its purest. |
| **Tintern** (Wales) | Ruin, well documented. |

Ruins are *ideal* modelling reference: the structure is exposed and the massing is legible
without a roof in the way.

---

## 9. Heresy, orthodoxy and the late window

For a house that grows a serious library, the late end of the window (c. 1300–1327) supplies
real pressure:

- The **poverty controversy** — Pope John XXII against the Franciscan Spirituals over whether
  Christ and the apostles owned property. A live, dangerous theological question.
- The **Avignon papacy** (from 1309) and its taxation.
- **Bernard Gui**, a real Dominican inquisitor who wrote an actual inquisitor's manual, and who
  appears in *The Name of the Rose* as himself.
- Documented, ordinary tension over **which books a house may hold and who may read them** — the
  *Name of the Rose* premise is closer to record than to invention.

The design use: a library is an asset *and* a liability. Rare and suspect texts raise the
scriptorium's value and the house's scrutiny at the same time.

---

## 10. Primary sources worth actually reading

| Source | Use |
|---|---|
| **The Rule of St Benedict** | 73 short chapters, public domain, an afternoon's read. The design document for the daily loop. Ch. 16, 18 (office), 31 (cellarer), 39–40 (food and drink), 48 (labour and reading), 53 (guests). |
| **The Plan of St Gall** (c. 820) | The ideal monastery, labelled. Building list and adjacency. |
| **Bernard of Clairvaux,** *Apologia* | The Cistercian case against Cluniac excess. The game's central argument. |
| **Cistercian *Carta Caritatis*** | Constitution of the order — visitation, General Chapter, daughter houses. |
| **Pegolotti,** *Pratica della mercatura* (c. 1340) | Lists English monastic wool by house and grade. Your wool price table. |

---

## 11. Games to study

| Game | What to take |
|---|---|
| **Banished** | The whole simulation model. Needs, seasons, hauling, death spirals. Our baseline. |
| **Pentiment** (Obsidian, 2022) | Historical care with manuscripts, scriptorium and abbey life. The closest existing thing to this project. |
| **Ora et Labora** (Uwe Rosenberg, 2011) | A board game that is literally a medieval monastery production engine. Steal the chain structure. |
| **Manor Lords** | Small-team 3D medieval settlement look and feel. |
| **Anno 1800** | Production chain legibility and UI. Depth done readably. |
