# Docs

Everything written down about the mod, apart from the front page ([README.md](../README.md)) and the contributing guide
([CONTRIBUTING.md](../CONTRIBUTING.md)).

| Page | Who it's for |
| --- | --- |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Players: the game won't start, the online game, crashes, reporting a bug |
| [DEVELOPING.md](DEVELOPING.md) | Contributors: how the mod works, the folder map, setting it up on your PC |
| [notes/](#notes) | Contributors: the research log, one file per system |
| [internals/](#internals) | Contributors: reference chains and number tables read out of the running game |

## notes/

The research log: what was found, what was tried, what worked and what didn't, and why the code is the way it is. One
file per system; [NOTES.md](../NOTES.md) at the top of the repo lists every file and every section title in it, so
search there first. Sections are in the order they were written, and a later one can correct an earlier one.

## internals/

How the game works inside, read out of the running game: chains of calls with flowcharts, number tables, what is still
unknown. Each file tags its facts by source: measured live, read from Blueprint bytecode, hooked, or a marked guess.
A reference here is for a chain or a table too big for a section of the research log, written so the next person does
not have to probe the same system again.

| File | What it covers |
| --- | --- |
| [SALVAGE_CHAIN.md](internals/SALVAGE_CHAIN.md) | Salvage from wreck to hold to airlock, offline behaviour, docking, the purge guard, how a refusal is shown on screen. |
| [DAMAGE_REFERENCE.md](internals/DAMAGE_REFERENCE.md) | How a shot becomes damage on a bot: health, hit zones, every vest and helmet rating, base damage per gun, shotguns. |
| [SPACE_GATE.md](internals/SPACE_GATE.md) | When the space gate arrives, why the on screen countdown disagreed with it, the launcher's Space gate setting, and the test record. |
| [BULLET_IMPACTS.md](internals/BULLET_IMPACTS.md) | How a shot becomes an impact effect: the pool of impact actors, why no bullet holes appeared offline, how the mod stamps them, surfaces, settings, cost. |
| [SPACE_OBJECT_DEATH.md](internals/SPACE_OBJECT_DEATH.md) | What happens when a space turret is destroyed or a mine goes off, why nothing showed or sounded offline, how the mod puts it back, and the test record. |

Two older references still sit at the top of the repo, written by the maintainers: [OFFLINE_AUDIT.md](../OFFLINE_AUDIT.md)
(code that never runs offline) and [AI_DESIGN.md](../AI_DESIGN.md). They can move into `internals/` when the maintainers
want that.

Adding one: give it its own file in `internals/` when a finding needs a diagram or a table, tag each fact with its
source, add it to the table above and link it from the research log section that explains why. Game files, decompiled
output, bytecode dumps and the pak key never go in here (see CONTRIBUTING.md); describe what was found instead of
pasting the dump.
