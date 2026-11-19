# space_test: the F9 tools for testing space maps

Test tools that were used to find out what space objects do offline (issue 15, turret and mine explosions) and how salvage works
(issue 134 and the purge bug). They add rows to the F9 debug menu, start a space raid without the lobby, spawn the game's own space
objects, explosions and wrecks ahead of your ship, kill and read them, and write what happened to text files in `bridge/`. They are
for test installs only: not part of the shipped mod, and the installer changes a test copy, not the repo.

The chain they uncovered is written up in [docs/internals/SPACE_OBJECT_DEATH.md](../../docs/internals/SPACE_OBJECT_DEATH.md) and,
for salvage, in `docs/internals/SALVAGE_CHAIN.md`. Read those for what the game does; this file is how to repeat the testing.

## What is here

| File | What it is |
| --- | --- |
| `testtools.lua` | The F9 rows: start a space raid, the space object spawner with kill, remove, poke and read buttons, the exploder and salvage spawners, ship teleports. Drives the other two |
| `explowatch.lua` | "Log explosions": what a destroyed turret, radar dish or mine makes (every particle, sound and actor), written to `bridge/explosions.txt` |
| `salvagewatch.lua` | "Log salvage": the whole salvage chain, wreck to hold to dock, written to `bridge/salvage.txt` |
| `spacetest_hook.lua` | Gives `testtools.lua` its tick from `botdamage.lua`'s per frame call, from one line at the end of that file |
| `install.py` | Copies the four files into a test install and adds the three hooks (or takes them out again with `--remove`) |
| `kdis_logged.py` | Decompiles the Blueprint functions a log named, with `tools/offline-audit/kdis.py` |

## Install

1. Make a test copy of the install: a folder that is not inside a git working tree, holding the repo's current `debugactions.lua`,
   `botdamage.lua` and `launch.lua`. (The installer refuses a folder inside a git working tree, so the shipped mod can never pick the
   tools up by accident.) If the game also has its own copy of the mods (`RaidGame\Binaries\Win64\Mods\PvEDirector\Scripts`), run
   the installer on that folder too, or switch the install to offline again with `scripts\mode.ps1` so the copy is made.
2. Close the game, then:

   `python tools\space_test\install.py <test install>\mods\PvEDirector\Scripts`

3. Start the game and press F9 (in the lobby or in a raid). The space rows are at the end of the menu. The ones that need a raid
   say "Not usable" and why (you must control your character or your ship) until you are in one.

`--remove` takes the files and the three hooks out again and restores the folder byte for byte. The installer adds, each marked
`SPACE TEST`:

| File | What it gets |
| --- | --- |
| `debugactions.lua` | One line after `Debug.addActions(Give.actions())`: the tools' F9 rows, in the menu from the start |
| `botdamage.lua` | One line before its final `return B`: `spacetest_hook.lua`, the per frame tick |
| `launch.lua` | `M.testSearch`, the "Start a space raid" button's way into the same offline search and launch that START RAID uses |

It can sit next to the armour test (`tools/armour_test`): both hook `botdamage.lua` with their own marked line.

## The F9 rows

| Row | What it does |
| --- | --- |
| Log explosions: ON or off | Starts `explowatch.lua`. While on, `bridge/explosions.txt` gets what happens around every watched turret, radar dish and mine |
| Start a space raid | START RAID from the menu, on the lobby's picked map, `bridge/map_pin`, or a random one: stash loadout, ship, wages, loading screen as in a normal start |
| Try explosion fix: ON or off | The first experiment (see "Superseded" below): leave it off |
| Space object N of M: name | Click: next kind. Right click: previous. The list is the stationary turret and mine kinds alive in the current level (so a map with no rocket turret offers none) |
| Spawn distance: N m ahead | Click: 40, 80, 150, 300 m. At 80 m a ship gun reaches it |
| Spawn it ahead of your ship | Spawns the picked kind ahead of your ship (also at the helm: fly at it and shoot it) |
| Kill what I spawned | Hits it with 1,000,000 damage the game's way, and writes every actor, particle and sound that appears (0.15, 1 and 3 s after) to `bridge/space_explosion.txt`. A second hit follows if it is still alive after a second |
| Remove what I spawned | Destroys it with no death, so no explosion |
| Poke it (bridge/poke.txt) | Runs the lines of `bridge/poke.txt` on the last thing you spawned: `call <Function> [args]`, `get <Property>`, `set <Property> <value>`, `sound <asset path>`, `spawn <class path>`, `hide`, `destroy`. Edit the file, press again: no restart |
| Read everything off it | Writes every readable value of it, and its authority, to `bridge/space_explosion.txt` |
| Exploder: name | Click: next explosion Blueprint (`Radar_Exploder_Child`, `FlakTurret_Exploder_Child`, `RocketTurret_Exploder_Child`, `TripleTurret_Exploder_Child`, `Mine_Exploder_Child`, `NuclearMine_Exploder_Child`, `Exploder_Base`). Right click: previous |
| Spawn that exploder ahead | The game's own explosion made by hand: particles, flying pieces, damage. Shows that an exploder works by itself |
| Salvage N of M: name | Click: next wreck kind (`Industrial_`, `Ammo_`, `Medic_`, `Rare_SpaceSalvage_01`) |
| Spawn that salvage ahead | 10 m ahead, inside the frigate's salvage scan (1500 cm): press R |
| Fly my ship to a level wreck | 8 m from the nearest wreck the game made |
| Fly my ship to the nearest dock | 20 m out from a docking area that looks usable: fly in |
| Log salvage: ON or off | Starts `salvagewatch.lua`; it also starts by itself the first time you are in a ship in a space raid |

The older "Bottomless mags" code at the top of `testtools.lua` is not wired to a row any more: the Give menu (F9) has the real one.

## What the logs hold

All in `bridge/` of the install folder. `t` is seconds since the game started.

| File | Written by | Lines |
| --- | --- | --- |
| `explosions.txt` | `explowatch.lua` | `WATCH` what is watched (a count per class, each one's place), `HP` a health or dying change, `DEATH` a watched actor died, `NEW` a new actor, particle, Niagara or sound read 0.25 s after it was made, `ACTIVE` everything playing within 8000 cm of a death at 0.15, 1 and 3 s, `PARAMS` each Blueprint function and its address |
| `space_explosion.txt` | `testtools.lua` | `SPAWNED`, `KILL` with the values before, then a report at each mark: new actors and new particle and sound components within 8000 cm, with owner and distance; `SWEEP` lines from Read everything |
| `salvage.txt` | `salvagewatch.lua` | `WORLD`, `SHIP`, `PROPS`, `ALL`, `CHG`, `REF`, `WRECK`, `REACH`, `DOCK`, `KEY` (R pressed), `SNAP`, `FUNCS`, `CALL`, `DESTROY`, `PARAMS`, `MENU` (the header of `salvagewatch.lua` explains each) |
| `kdis_explosions.txt`, `kdis_salvage.txt` | `kdis_logged.py` | The decompiled functions |
| `poke.txt`, `sweep_names.txt` | you, `testtools.lua` | The poke commands, the names the sweep reads |

Reading `explosions.txt`: what plays at a death with a name worth hearing or seeing (explosion, fire, smoke, boom) is what the game
does offline. Nothing `ACTIVE` or `NEW` near a death means the game made no effect for it. The game parks pooled effect actors at
0, 0, 0 and switches them on, so a pooled effect that turns on is not `NEW`; the log reads from your place when the dead actor's own
place is the world's origin.

## Recipes

### What does a death make offline? (the issue 15 method)

1. Start a space raid (F9). Turn Log explosions on.
2. Pick a kind, spawn it ahead, fly or walk to where you can see and hear it, press Kill what I spawned.
3. Read the `KILL` report in `space_explosion.txt`: new particles and sounds near the death, or none. Offline, a turret showed none.
4. Press Poke it with `call OnDeathEvent` to try the Blueprint function by name with no restart, or `spawn`/`sound` lines to try an
   effect by hand. Spawn the exploder Blueprints directly (Exploder rows) to see that they work on their own.
5. Run `kdis_logged.py <install> explosions` in the same game session to read the bytecode of the functions the log named.

### Try one effect at a time before writing a hook

The method that made the fix safe: the blast and the sound made by hand, one at a time, asking the tester what they saw and heard,
before any hook was written. It uses the probe runner (`bridge/profile_on` present, then `bridge/dir_eval.lua`, run once in the
game's Lua state, its return value written to `bridge/dir_eval.out`: search `docs/notes/` for `bridge/profile_on`). The probe is in
[SPACE_OBJECT_DEATH.md](../../docs/internals/SPACE_OBJECT_DEATH.md), "The probe". Rules that mattered:

- Write a step note to a file before each effect that could crash, so the last line shows where the game died.
- Count the tester down (8 to 23 s) so they are looking; announce it.
- Fire the nuclear mine last: it is the one that crashed a first version of the hooks.
- Move nearby AI ships away first (`K2_SetActorLocation` 6000 m up; they drift back): their gunfire hides the sound you are testing.
- Use `SpawnSoundAtLocation` for sound; `PlaySoundAtLocation` and `PlaySound2D` seemed silent from a probe.

### Salvage

Switch Log salvage on (it starts in a ship), look at the wrecks, fly to one (Fly my ship to a level wreck), press R, look at the hold,
loot or purge, dock (Fly my ship to the nearest dock), and see whether the salvage is still there. Then `kdis_logged.py <install>
salvage`. What the lines mean is in the header of `salvagewatch.lua`.

## Decompiling (kdis)

`kdis_logged.py <install folder> explosions|salvage` reads the PARAMS lines of the log and runs `kdis.py` on each address. The addresses
die with the game: run it while the SAME game session is open. For a function the log did not name, get its address from the probe
runner (`return string.format('%x', StaticFindObject('<function path>'):GetAddress())`) and run
`python tools\offline-audit\kdis.py <address>`. Memory offsets in kdis are for the current game build.

## Superseded and known limits

- "Try explosion fix" was the first experiment: when a watched turret dies, call the functions of its class that look like death
  handlers (`tryFix` in `explowatch.lua`, logged in `explosions.txt`). It is superseded by `spacefx.lua` in the mod. Leave the row off
  when testing the real fix, so one death is not handled by two things.
- The spawner only offers kinds alive in the current level. A kind with no instance (the rocket turret, on the maps tried) cannot
  be spawned from here; `GetCDO` and `Default__` lookups on it failed too.
- Only numbers, booleans and text are read off objects: reading a pointer of a just made object can crash the game. `salvagewatch.lua`
  writes the name of what it is about to read to `bridge/salvage_crumb.txt` first, so a crash shows where.
- Test installs only. Nothing here is loaded by the shipped mod, and `install.py` refuses a git working tree.
