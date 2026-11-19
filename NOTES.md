# Marauders PvE — working notes

Goal: offline singleplayer PvE Marauders that keeps working after the official servers close.
Game: `<game folder>` (Steam app 1789480). Engine **UE 4.26.2** (crash context), one pak
(`pakchunk0-WindowsNoEditor.pak`, v11 footer, encrypted index and data, zlib). Exe is Denuvo-protected.

This is the project's research log and memory: what was found, what was tried, what worked and what didn't, and why
the code is the way it is. It is split by system into files under [`docs/notes/`](docs/notes/). This page is the
index: every section title is listed below, so searching this page for a title (or a module name such as
`rivals.lua`) finds the file it lives in.

## How to use it

- **Before changing a system,** open its file below and read the sections about it. Sections are in the order they
  were written, and a later one can correct an earlier one, so read to the end.
- **When you learn something,** add it to the file it belongs to: a new `##` section at the end of that file (title,
  date, issue number, which module), saying what was verified in game and what wasn't. Then add the title to that
  file's list below and to the Contents list at the top of the file.
- **A finding with a diagram or a big table** (a chain of calls, a number table) gets its own file under
  [`docs/internals/`](docs/README.md), linked from the section here that explains why.
- **Nothing goes in** that comes from the game's files: no decompiled output, no dumps, no pak key, no account IDs.

## Topics

| File | What it covers |
| --- | --- |
| [Foundations: engine, UE4SS, tooling, code layout](docs/notes/foundations.md) | Goals and ground rules, how the repository is laid out, UE4SS quirks, the native helpers, reading the exe, probing the running game safely, and how main.lua and rivals.lua are split into modules. |
| [Backend stand-in](docs/notes/backend.md) | What the live backend did and how `backend/nakama_standin.py` replaces it offline. |
| [Raid flow: matchmaking, loadout, extraction, conditions](docs/notes/raids.md) | Getting into a raid and out of it again: matchmaking, loadout from the stash, loading, the space gate, raid length, raid conditions, quitting. |
| [Inventory, stash and loot](docs/notes/inventory.md) | The SIGIS inventory, equipping, the stash grid, containers, bodies and loot windows. |
| [Weapons, damage and hit effects](docs/notes/combat.md) | Player guns, damage to and from bots, hit zones, armour, recoil, bullet impacts and holes. Number tables are in [DAMAGE_REFERENCE.md](docs/internals/DAMAGE_REFERENCE.md). |
| [AI soldiers, station guards, civilians and cover](docs/notes/ai.md) | The shared AI brain, station garrisons, cover, AI tuning (F3), difficulty presets, bot kits, civilians. |
| [Rival crews and their ships](docs/notes/rivals.md) | Rival crews: their ships, docking, ship combat, boarding (theirs and yours), pods, the Red Baron. |
| [Your ship, space and stations](docs/notes/space.md) | Flying, docking, turrets, ship damage, salvage, level props, space objects and map geometry. |
| [Your crew](docs/notes/crew.md) | Hired AI teammates: hiring, the lobby, following you, gunnery, price and levels. |
| [Missions, minimap and guild](docs/notes/missions.md) | Progression, missions offline, the task minimap and the offline guild. |
| [Looks, sound, menus and debug tools](docs/notes/presentation.md) | Loading screens, the startup video, footsteps, outfits and voices, wording, the F9 debug menu, god mode. |
| [Performance, stutter and crashes](docs/notes/performance.md) | Frame cost of the director, stutter hunts, garbage collection, and crashes that were found and fixed. |
| [Launcher, releases, Linux and Steam Deck](docs/notes/launcher.md) | The launcher and saves, building the public release, trailer tooling, Linux and the Steam Deck. |
| [Co-op multiplayer](docs/notes/coop.md) | Getting a second player into a raid: the investigation from first look to a working join, in order. |

## Every section, by topic

### [Foundations: engine, UE4SS, tooling, code layout](docs/notes/foundations.md)

- [Goals (user's words, 2026-10-30)](docs/notes/foundations.md#goals-users-words-2026-10-30)
- [Ground rules](docs/notes/foundations.md#ground-rules)
- [Layout](docs/notes/foundations.md#layout)
- [UE4SS quirks in this game](docs/notes/foundations.md#ue4ss-quirks-in-this-game)
- [Pak key (not found yet; may not be needed)](docs/notes/foundations.md#pak-key-not-found-yet-may-not-be-needed)
- [Native helper (native/pvenative.c, built by native/build.sh with WinLibs MinGW) — 2026-10-30](docs/notes/foundations.md#native-helper-nativepvenativec-built-by-nativebuildsh-with-winlibs-mingw--2026-10-30)
- [Offline audit (2026-10-31)](docs/notes/foundations.md#offline-audit-2026-10-31)
- [main.lua and its modules (refactor, 2026-11-17)](docs/notes/foundations.md#mainlua-and-its-modules-refactor-2026-11-17)
- [Lua and launcher practices made into checks (2026-11-17)](docs/notes/foundations.md#lua-and-launcher-practices-made-into-checks-2026-11-17)
- [rivals.lua and its modules (issue 149, 2026-11-17)](docs/notes/foundations.md#rivalslua-and-its-modules-issue-149-2026-11-17)
- [Blueprint authority branches: bpbranch.py (issue 143, 2026-11-18; tools/offline-audit/bpbranch.py, kdis.py)](docs/notes/foundations.md#blueprint-authority-branches-bpbranchpy-issue-143-2026-11-18-toolsoffline-auditbpbranchpy-kdispy)
- [Reading this exe (2026-11-18)](docs/notes/foundations.md#reading-this-exe-2026-11-18)
- [Probing hazards that cost crashes (2026-11-18)](docs/notes/foundations.md#probing-hazards-that-cost-crashes-2026-11-18)
- [Reading the bridge with the `lua` verb (2026-11-18)](docs/notes/foundations.md#reading-the-bridge-with-the-lua-verb-2026-11-18)
- [Bridge chunks must be one line (2026-11-19)](docs/notes/foundations.md#bridge-chunks-must-be-one-line-2026-11-19)

### [Backend stand-in](docs/notes/backend.md)

- [Online backend (what offline mode must replace)](docs/notes/backend.md#online-backend-what-offline-mode-must-replace)
- [Backend capture (2026-10-30, session 5)](docs/notes/backend.md#backend-capture-2026-10-30-session-5)
- [Local Nakama stand-in — WORKING (2026-10-30, session 5)](docs/notes/backend.md#local-nakama-stand-in--working-2026-10-30-session-5)
- [French female voice free from the start (2026-11-16, tested; backend/nakama_standin.py)](docs/notes/backend.md#french-female-voice-free-from-the-start-2026-11-16-tested-backendnakama_standinpy)
- [Offline backend: coverage tally, tournaments, the gift box (issue 80, 2026-11-18; backend/nakama_standin.py)](docs/notes/backend.md#offline-backend-coverage-tally-tournaments-the-gift-box-issue-80-2026-11-18-backendnakama_standinpy)

### [Raid flow: matchmaking, loadout, extraction, conditions](docs/notes/raids.md)

- [Raids offline — WORKS (first test)](docs/notes/raids.md#raids-offline--works-first-test)
- [Raid loadout from the stash (WORKING, 2026-10-30)](docs/notes/raids.md#raid-loadout-from-the-stash-working-2026-10-30)
- [End of raid: extraction and death (WORKING, 2026-10-30)](docs/notes/raids.md#end-of-raid-extraction-and-death-working-2026-10-30)
- [Start Matchmaking -> space raid in your ship (WORKING, 2026-10-30)](docs/notes/raids.md#start-matchmaking---space-raid-in-your-ship-working-2026-10-30)
- [Space gate extraction (WORKING, 2026-11-06)](docs/notes/raids.md#space-gate-extraction-working-2026-11-06)
- [Faster space raid loads (2026-11-06)](docs/notes/raids.md#faster-space-raid-loads-2026-11-06)
- [Map variety (2026-11-07, later)](docs/notes/raids.md#map-variety-2026-11-07-later)
- [No captain's key card at raid start (2026-11-16, tested; main.lua guardKeyCard)](docs/notes/raids.md#no-captains-key-card-at-raid-start-2026-11-16-tested-mainlua-guardkeycard)
- [Quit Game in the pause menu (2026-11-16, tested in a raid; mods/PvEDirector/Scripts/quit.lua)](docs/notes/raids.md#quit-game-in-the-pause-menu-2026-11-16-tested-in-a-raid-modspvedirectorscriptsquitlua)
- [Raid length from the launcher (issue 159, 2026-11-18; raidtime.lua, launcher "Raid length")](docs/notes/raids.md#raid-length-from-the-launcher-issue-159-2026-11-18-raidtimelua-launcher-raid-length)
- [Raid conditions (issue 78, 2026-11-18; conditions.lua, config/raid_conditions.txt)](docs/notes/raids.md#raid-conditions-issue-78-2026-11-18-conditionslua-configraid_conditionstxt)
- [Space gate time (2026-11-18; raidtime.lua, docs/internals/SPACE_GATE.md)](docs/notes/raids.md#space-gate-time-2026-11-18-raidtimelua-docsinternalsspace_gatemd)
- [Minefield raid condition (2026-11-19, no issue)](docs/notes/raids.md#minefield-raid-condition-2026-11-19-no-issue)

### [Inventory, stash and loot](docs/notes/inventory.md)

- [Inventory / loot system (SIGIS plugin) — findings](docs/notes/inventory.md#inventory--loot-system-sigis-plugin--findings)
- [Offline inventory/equip findings — 2026-10-30 (session 3)](docs/notes/inventory.md#offline-inventoryequip-findings--2026-10-30-session-3)
- [Container loot (WORKING, 2026-10-31)](docs/notes/inventory.md#container-loot-working-2026-10-31)
- [Enemy bodies (WORKING, user-confirmed 2026-10-31)](docs/notes/inventory.md#enemy-bodies-working-user-confirmed-2026-10-31)
- [Bot corpses: empty loot, frozen ragdolls (2026-11-06)](docs/notes/inventory.md#bot-corpses-empty-loot-frozen-ragdolls-2026-11-06)
- [Typed stash size, ambient ship fights (2026-11-07, evening)](docs/notes/inventory.md#typed-stash-size-ambient-ship-fights-2026-11-07-evening)
- [Stash capped at 25 rows: the game's grid wraps past 256 cells (2026-11-14)](docs/notes/inventory.md#stash-capped-at-25-rows-the-games-grid-wraps-past-256-cells-2026-11-14)
- [Stuck in a loot window after rotating an item (2026-11-16, tested; invkeys.lua)](docs/notes/inventory.md#stuck-in-a-loot-window-after-rotating-an-item-2026-11-16-tested-invkeyslua)

### [Weapons, damage and hit effects](docs/notes/combat.md)

- [Player gun fires — FIXED (2026-10-30, session 4)](docs/notes/combat.md#player-gun-fires--fixed-2026-10-30-session-4)
- [Player damage, fire effects, native reload — WORKING (2026-10-30, session 4b; fresh-launch tested)](docs/notes/combat.md#player-damage-fire-effects-native-reload--working-2026-10-30-session-4b-fresh-launch-tested)
- [Recoil, bullet impacts, gore (2026-10-31)](docs/notes/combat.md#recoil-bullet-impacts-gore-2026-10-31)
- [Bot-on-bot damage, armour, aiming walk speed, your gunner's arc (2026-11-08, pvepatch.c + main.lua + rivals.lua)](docs/notes/combat.md#bot-on-bot-damage-armour-aiming-walk-speed-your-gunners-arc-2026-11-08-pvepatchc--mainlua--rivalslua)
- [Player shots: no hit zones on the mod's soldiers (issue 123; pvepatch.c pve_hit_capsule, hitzones.lua, ai.lua tuneBody)](docs/notes/combat.md#player-shots-no-hit-zones-on-the-mods-soldiers-issue-123-pvepatchc-pve_hit_capsule-hitzoneslua-ailua-tunebody)
- [Your shots at bots: armour, shotguns, meshes (2026-11-18; botdamage.lua, issue #123 follow up to the hit zones)](docs/notes/combat.md#your-shots-at-bots-armour-shotguns-meshes-2026-11-18-botdamagelua-issue-123-follow-up-to-the-hit-zones)
- [Bullet holes (2026-11-18; bulletholes.lua, docs/internals/BULLET_IMPACTS.md)](docs/notes/combat.md#bullet-holes-2026-11-18-bulletholeslua-docsinternalsbullet_impactsmd)

### [AI soldiers, station guards, civilians and cover](docs/notes/ai.md)

- [PvE AI — WORKS (mods/PvEDirector, 2026-10-30)](docs/notes/ai.md#pve-ai--works-modspvedirector-2026-10-30)
- [Shared AI brain, step 1-2 (2026-10-31): ai.lua](docs/notes/ai.md#shared-ai-brain-step-1-2-2026-10-31-ailua)
- [Bot leg animation vs speed (2026-10-31)](docs/notes/ai.md#bot-leg-animation-vs-speed-2026-10-31)
- [Cover and peeking, faster (2026-10-31, untested in game)](docs/notes/ai.md#cover-and-peeking-faster-2026-10-31-untested-in-game)
- [Factions, station garrisons, rushers (2026-11-01)](docs/notes/ai.md#factions-station-garrisons-rushers-2026-11-01)
- [Station defenders = the levels' own NPCs (2026-11-01)](docs/notes/ai.md#station-defenders--the-levels-own-npcs-2026-11-01)
- [8 defenders per station; space-map navmesh bug (2026-11-01)](docs/notes/ai.md#8-defenders-per-station-space-map-navmesh-bug-2026-11-01)
- [Busier stations (2026-11-01)](docs/notes/ai.md#busier-stations-2026-11-01)
- [AI tuning menu, aim variety, firing on the move (2026-11-06)](docs/notes/ai.md#ai-tuning-menu-aim-variety-firing-on-the-move-2026-11-06)
- [Difficulty presets (2026-11-06)](docs/notes/ai.md#difficulty-presets-2026-11-06)
- [Your own presets (2026-11-06)](docs/notes/ai.md#your-own-presets-2026-11-06)
- [Stutter, lighting, bot aim, kit looks (2026-11-06, written; NOT yet run in game)](docs/notes/ai.md#stutter-lighting-bot-aim-kit-looks-2026-11-06-written-not-yet-run-in-game)
- [Native bot kits, tested (2026-11-07, supersedes the donor notes above)](docs/notes/ai.md#native-bot-kits-tested-2026-11-07-supersedes-the-donor-notes-above)
- [Play areas replace the one-box ban (2026-11-07, later)](docs/notes/ai.md#play-areas-replace-the-one-box-ban-2026-11-07-later)
- [Station guards: own gear kept, bags and pockets rolled (2026-11-07, later)](docs/notes/ai.md#station-guards-own-gear-kept-bags-and-pockets-rolled-2026-11-07-later)
- [Cover map and cover-first fighting (2026-11-13)](docs/notes/ai.md#cover-map-and-cover-first-fighting-2026-11-13)
- [Gear follows your level (2026-11-13; rolls checked offline with lupa, in game 2026-11-15)](docs/notes/ai.md#gear-follows-your-level-2026-11-13-rolls-checked-offline-with-lupa-in-game-2026-11-15)
- [Station NPCs spread out; live-like spawn counts (2026-11-14)](docs/notes/ai.md#station-npcs-spread-out-live-like-spawn-counts-2026-11-14)
- [TODO: boarder corpse legs explode into spikes (seen 2026-11-14, not investigated)](docs/notes/ai.md#todo-boarder-corpse-legs-explode-into-spikes-seen-2026-11-14-not-investigated)
- [Station fights end too fast; AI legs too fast (2026-11-14; arrival stagger tested 2026-11-16)](docs/notes/ai.md#station-fights-end-too-fast-ai-legs-too-fast-2026-11-14-arrival-stagger-tested-2026-11-16)
- [Crews and guards by station size (2026-11-14; guard counts tested 2026-11-16)](docs/notes/ai.md#crews-and-guards-by-station-size-2026-11-14-guard-counts-tested-2026-11-16)
- [Asleep guards at stations you haven't entered (2026-11-14)](docs/notes/ai.md#asleep-guards-at-stations-you-havent-entered-2026-11-14)
- [Guards ignoring your fire while fighting through a wall (2026-11-14)](docs/notes/ai.md#guards-ignoring-your-fire-while-fighting-through-a-wall-2026-11-14)
- [Baked cover never used inside Rebel Base; soldiers out of sight backpedal (2026-11-14; tested 2026-11-16)](docs/notes/ai.md#baked-cover-never-used-inside-rebel-base-soldiers-out-of-sight-backpedal-2026-11-14-tested-2026-11-16)
- [Every baked cover spot "off limits": integer vs float cell keys (2026-11-14; tested 2026-11-16)](docs/notes/ai.md#every-baked-cover-spot-off-limits-integer-vs-float-cell-keys-2026-11-14-tested-2026-11-16)
- [Soldiers backpedalling instead of taking cover (2026-11-14)](docs/notes/ai.md#soldiers-backpedalling-instead-of-taking-cover-2026-11-14)
- [Cover a long walk away; melee soldiers swinging at nothing (2026-11-14)](docs/notes/ai.md#cover-a-long-walk-away-melee-soldiers-swinging-at-nothing-2026-11-14)
- [Bots animate at the display's rate (2026-11-17; main.lua trackTargets and animate)](docs/notes/ai.md#bots-animate-at-the-displays-rate-2026-11-17-mainlua-tracktargets-and-animate)
- [Civilians (issue 81, 2026-11-18; civilians.lua)](docs/notes/ai.md#civilians-issue-81-2026-11-18-civilianslua)

### [Rival crews and their ships](docs/notes/rivals.md)

- [Player-like rival bots — survey (2026-10-31)](docs/notes/rivals.md#player-like-rival-bots--survey-2026-10-31)
- [Rivals module (mods/PvEDirector/Scripts/rivals.lua) — first build, 2026-10-31](docs/notes/rivals.md#rivals-module-modspvedirectorscriptsrivalslua--first-build-2026-10-31)
- [Rival ships dock into berths (2026-10-31, user-confirmed)](docs/notes/rivals.md#rival-ships-dock-into-berths-2026-10-31-user-confirmed)
- [Rival ship combat (2026-10-31, rivals.lua)](docs/notes/rivals.md#rival-ship-combat-2026-10-31-rivalslua)
- [Event: the Red Baron in every raid (2026-11-16, #78; rivals.lua R.baron, F3 > Rival ships)](docs/notes/rivals.md#event-the-red-baron-in-every-raid-2026-11-16-78-rivalslua-rbaron-f3--rival-ships)
- [Rival hulls and turrets (2026-11-01, rivals.lua)](docs/notes/rivals.md#rival-hulls-and-turrets-2026-11-01-rivalslua)
- [Rival boarding and morale (2026-11-06, rivals.lua)](docs/notes/rivals.md#rival-boarding-and-morale-2026-11-06-rivalslua)
- [Player boarding and stealing rival ships (2026-11-06, rivals.lua; first build)](docs/notes/rivals.md#player-boarding-and-stealing-rival-ships-2026-11-06-rivalslua-first-build)
- [Rival interiors (2026-11-06, rivals.lua CFG designs `inside`)](docs/notes/rivals.md#rival-interiors-2026-11-06-rivalslua-cfg-designs-inside)
- [Keeping a stolen ship (2026-11-06)](docs/notes/rivals.md#keeping-a-stolen-ship-2026-11-06)
- [Rivals arrive through airlocks (2026-11-07, later)](docs/notes/rivals.md#rivals-arrive-through-airlocks-2026-11-07-later)
- [Pods, parked ships, the Mini Mine berth (2026-11-07, evening)](docs/notes/rivals.md#pods-parked-ships-the-mini-mine-berth-2026-11-07-evening)
- [Pod gun and ramming a rival (2026-11-08, ~13:00)](docs/notes/rivals.md#pod-gun-and-ramming-a-rival-2026-11-08-1300)
- [Ship gunnery: variable rival aim, crew gunner by level (2026-11-08, rivals.lua gunAim + crew.lua gunnery)](docs/notes/rivals.md#ship-gunnery-variable-rival-aim-crew-gunner-by-level-2026-11-08-rivalslua-gunaim--crewlua-gunnery)
- [Turret barrels: the gunner aims them, shells leave along them (2026-11-08, rivals.lua aimTurret + crew.lua)](docs/notes/rivals.md#turret-barrels-the-gunner-aims-them-shells-leave-along-them-2026-11-08-rivalslua-aimturret--crewlua)
- [Rivals scraping stations and docking inside hulls (2026-11-14; shipnav.lua, rivals.lua)](docs/notes/rivals.md#rivals-scraping-stations-and-docking-inside-hulls-2026-11-14-shipnavlua-rivalslua)
- [Pod breach input lock (2026-11-14, fix untested)](docs/notes/rivals.md#pod-breach-input-lock-2026-11-14-fix-untested)
- [Pod boarding rework (2026-11-14, tested)](docs/notes/rivals.md#pod-boarding-rework-2026-11-14-tested)
- [Rival crews dying in a heap at one airlock; rivals' edge over station guards (2026-11-14)](docs/notes/rivals.md#rival-crews-dying-in-a-heap-at-one-airlock-rivals-edge-over-station-guards-2026-11-14)
- [Pod breach into Fortress put you in a wall (2026-11-16, logic tested at the spot; rivals.lua podExitCheck)](docs/notes/rivals.md#pod-breach-into-fortress-put-you-in-a-wall-2026-11-16-logic-tested-at-the-spot-rivalslua-podexitcheck)
- [Pod breach prompt (issue 77, 2026-11-18; rivalcombat.lua playerBoarding)](docs/notes/rivals.md#pod-breach-prompt-issue-77-2026-11-18-rivalcombatlua-playerboarding)

### [Your ship, space and stations](docs/notes/space.md)

- [Flying the ship; interaction offline; per-update cost (2026-10-30)](docs/notes/space.md#flying-the-ship-interaction-offline-per-update-cost-2026-10-30)
- [Docking at a station (WORKING, 2026-10-30)](docs/notes/space.md#docking-at-a-station-working-2026-10-30)
- [Giant shapes in the space sky (2026-11-06)](docs/notes/space.md#giant-shapes-in-the-space-sky-2026-11-06)
- [Spawning your active ship (2026-11-06, replaces the in-raid swap idea)](docs/notes/space.md#spawning-your-active-ship-2026-11-06-replaces-the-in-raid-swap-idea)
- [Space_Solo_02 stations, Rebel Base lid, key card guard (2026-11-07, later)](docs/notes/space.md#space_solo_02-stations-rebel-base-lid-key-card-guard-2026-11-07-later)
- [Flying stutter and the minimap in new-map stations (2026-11-07, later)](docs/notes/space.md#flying-stutter-and-the-minimap-in-new-map-stations-2026-11-07-later)
- [Ship damage visuals / incapacitated state (2026-11-08, FIXED, see end of section)](docs/notes/space.md#ship-damage-visuals--incapacitated-state-2026-11-08-fixed-see-end-of-section)
- [Manning a turret yourself; crew gunner owns the turrets (2026-11-08, gunseat.lua + crew.lua)](docs/notes/space.md#manning-a-turret-yourself-crew-gunner-owns-the-turrets-2026-11-08-gunseatlua--crewlua)
- [Stray geometry floating in open space on Space_Solo_02 (user, 2026-11-14; airlocks of absent stations, fixed 2026-11-15)](docs/notes/space.md#stray-geometry-floating-in-open-space-on-space_solo_02-user-2026-11-14-airlocks-of-absent-stations-fixed-2026-11-15)
- [Ship stuck after undocking (2026-11-14)](docs/notes/space.md#ship-stuck-after-undocking-2026-11-14)
- [Stuck in a shaft after docking at Fortress by pod (2026-11-14)](docs/notes/space.md#stuck-in-a-shaft-after-docking-at-fortress-by-pod-2026-11-14)
- [Missing prompts, salvage, objective sounds (2026-11-16)](docs/notes/space.md#missing-prompts-salvage-objective-sounds-2026-11-16)
- [Salvage in the hold stayed behind a shut door (issue 134; main.lua relaySalvage)](docs/notes/space.md#salvage-in-the-hold-stayed-behind-a-shut-door-issue-134-mainlua-relaysalvage)
- [Purging salvage while docked is refused (space.lua guardPurgeWhileDocked)](docs/notes/space.md#purging-salvage-while-docked-is-refused-spacelua-guardpurgewhiledocked)
- [Level props: fans, reels, ambience and sparks start offline (2026-11-18, issue #143)](docs/notes/space.md#level-props-fans-reels-ambience-and-sparks-start-offline-2026-11-18-issue-143)
- [Blowtorch locks: the vault door could not be opened (2026-11-18; blowtorch.lua, BLOWTORCH.md; reported on Discord, no issue)](docs/notes/space.md#blowtorch-locks-the-vault-door-could-not-be-opened-2026-11-18-blowtorchlua-blowtorchmd-reported-on-discord-no-issue)
- [#143 leftovers: ship hum, pod hint, camera turrets, hold contracts (2026-11-18)](docs/notes/space.md#143-leftovers-ship-hum-pod-hint-camera-turrets-hold-contracts-2026-11-18)
- [Space object explosions and sounds (2026-11-18, issue #15)](docs/notes/space.md#space-object-explosions-and-sounds-2026-11-18-issue-15)

### [Your crew](docs/notes/crew.md)

- [Your crew: AI teammates (2026-11-07, night; mods/PvEDirector/Scripts/crew.lua)](docs/notes/crew.md#your-crew-ai-teammates-2026-11-07-night-modspvedirectorscriptscrewlua)
- [Hiring your crew, nametags (2026-11-07, late night; hire.lua, crew.lua)](docs/notes/crew.md#hiring-your-crew-nametags-2026-11-07-late-night-hirelua-crewlua)
- [Lobby crew hooks found (2026-11-07, 23:18; bridge/t_lobbychars.lua)](docs/notes/crew.md#lobby-crew-hooks-found-2026-11-07-2318-bridget_lobbycharslua)
- [Crew in the lobby: stands, slots, portraits, hiring page (2026-11-08, ~00:00; crewlobby.lua, hire.lua menu)](docs/notes/crew.md#crew-in-the-lobby-stands-slots-portraits-hiring-page-2026-11-08-0000-crewlobbylua-hirelua-menu)
- [Crew missing, boarding misses, wall spawn, stutter (2026-11-13; user report after the 11-09 runs)](docs/notes/crew.md#crew-missing-boarding-misses-wall-spawn-stutter-2026-11-13-user-report-after-the-11-09-runs)
- [Target switching, crew left behind at airlocks, stutter check (2026-11-13, evening; user report after a Navy Outpost raid)](docs/notes/crew.md#target-switching-crew-left-behind-at-airlocks-stutter-check-2026-11-13-evening-user-report-after-a-navy-outpost-raid)
- [Kill list, airlock crew, interiors from space, proportions (2026-11-13, ~20:30-20:55; user report)](docs/notes/crew.md#kill-list-airlock-crew-interiors-from-space-proportions-2026-11-13-2030-2055-user-report)
- [Crew worth their price (2026-11-13; hire.lua H.profile/H.maxHp, crew.lua, tuning.lua)](docs/notes/crew.md#crew-worth-their-price-2026-11-13-hirelua-hprofilehmaxhp-crewlua-tuninglua)
- [Crew gunner never shot stationary turrets (2026-11-16, tested; rivals.lua nodeTurretAlive)](docs/notes/crew.md#crew-gunner-never-shot-stationary-turrets-2026-11-16-tested-rivalslua-nodeturretalive)
- [Crew gunner reach, swing and click (issue 88; rivals.lua GUNNER_*, crew.lua ORDER_CONE)](docs/notes/crew.md#crew-gunner-reach-swing-and-click-issue-88-rivalslua-gunner_-crewlua-order_cone)

### [Missions, minimap and guild](docs/notes/missions.md)

- [Progression / missions — survey (2026-10-31)](docs/notes/missions.md#progression--missions--survey-2026-10-31)
- [Missions offline — WORKING (2026-10-31, mods/PvEDirector/Scripts/missions.lua)](docs/notes/missions.md#missions-offline--working-2026-10-31-modspvedirectorscriptsmissionslua)
- [Task minimap (2026-11-06, minimap.lua)](docs/notes/missions.md#task-minimap-2026-11-06-minimaplua)
- [Offline guild: guild page and guild shop (2026-11-16, tested; mods/PvEDirector/Scripts/guild.lua, issue #68)](docs/notes/missions.md#offline-guild-guild-page-and-guild-shop-2026-11-16-tested-modspvedirectorscriptsguildlua-issue-68)
- [Offline guild: editing it (2026-11-16, tested; guild.lua)](docs/notes/missions.md#offline-guild-editing-it-2026-11-16-tested-guildlua)

### [Looks, sound, menus and debug tools](docs/notes/presentation.md)

- [Raid loading screen (2026-11-06)](docs/notes/presentation.md#raid-loading-screen-2026-11-06)
- [Startup video re-cut (2026-11-06)](docs/notes/presentation.md#startup-video-re-cut-2026-11-06)
- [Startup video, second pass (2026-11-06, replaces the timing above)](docs/notes/presentation.md#startup-video-second-pass-2026-11-06-replaces-the-timing-above)
- [Startup video, third pass (2026-11-06, replaces the loop and levels above)](docs/notes/presentation.md#startup-video-third-pass-2026-11-06-replaces-the-loop-and-levels-above)
- [Startup video, fourth pass (2026-11-06, replaces the music levels above)](docs/notes/presentation.md#startup-video-fourth-pass-2026-11-06-replaces-the-music-levels-above)
- [Splash screen logo and credit (2026-11-06)](docs/notes/presentation.md#splash-screen-logo-and-credit-2026-11-06)
- [Footsteps (2026-11-06)](docs/notes/presentation.md#footsteps-2026-11-06)
- [Female outfits, voices, off-limits zone (2026-11-07)](docs/notes/presentation.md#female-outfits-voices-off-limits-zone-2026-11-07)
- [Women's versions of every outfit, player toggle (2026-11-07, later)](docs/notes/presentation.md#womens-versions-of-every-outfit-player-toggle-2026-11-07-later)
- [Debug menu (F9) and spawn counts in the AI menu (2026-11-07, later)](docs/notes/presentation.md#debug-menu-f9-and-spawn-counts-in-the-ai-menu-2026-11-07-later)
- [Seamless female body (2026-11-07, later)](docs/notes/presentation.md#seamless-female-body-2026-11-07-later)
- [F3/F9 in the lobby, borderless fullscreen (2026-11-09)](docs/notes/presentation.md#f3f9-in-the-lobby-borderless-fullscreen-2026-11-09)
- [Share of women (2026-11-13)](docs/notes/presentation.md#share-of-women-2026-11-13)
- [Plain wording (2026-11-13)](docs/notes/presentation.md#plain-wording-2026-11-13)
- [Your look and voice in raids (2026-11-16, tested; nakama_standin.py write_cosmetics, main.lua applyLoadout)](docs/notes/presentation.md#your-look-and-voice-in-raids-2026-11-16-tested-nakama_standinpy-write_cosmetics-mainlua-applyloadout)
- [F9 gun list: the rest of the guns (2026-11-17; debuggive.lua)](docs/notes/presentation.md#f9-gun-list-the-rest-of-the-guns-2026-11-17-debuggivelua)
- [F9 bottomless mags (2026-11-18; debuggive.lua, debugactions.lua, main.lua)](docs/notes/presentation.md#f9-bottomless-mags-2026-11-18-debuggivelua-debugactionslua-mainlua)
- [God mode: unlimited stamina (2026-11-18; debugactions.lua holdStamina, main.lua update)](docs/notes/presentation.md#god-mode-unlimited-stamina-2026-11-18-debugactionslua-holdstamina-mainlua-update)

### [Performance, stutter and crashes](docs/notes/performance.md)

- [Stability fixes (2026-10-30)](docs/notes/performance.md#stability-fixes-2026-10-30)
- [Dead-bot crash (FIXED 2026-10-31)](docs/notes/performance.md#dead-bot-crash-fixed-2026-10-31)
- [Stutter found: PGOS friends refresh; mid-flight freeze: pilot names ran out (2026-11-13, ~19:30, live in the user's raid)](docs/notes/performance.md#stutter-found-pgos-friends-refresh-mid-flight-freeze-pilot-names-ran-out-2026-11-13-1930-live-in-the-users-raid)
- [Frame drops to ~50 fps: Lua heap leak + GC stalls, FIXED (2026-11-13, ~20:00-20:25)](docs/notes/performance.md#frame-drops-to-50-fps-lua-heap-leak--gc-stalls-fixed-2026-11-13-2000-2025)
- [Director per-frame cost: ships off the helm, calm bots, fewer engine reads (2026-11-17, tested)](docs/notes/performance.md#director-per-frame-cost-ships-off-the-helm-calm-bots-fewer-engine-reads-2026-11-17-tested)
- [Build 4 quick wins: looting stutter, far animation, hot reload (2026-11-17)](docs/notes/performance.md#build-4-quick-wins-looting-stutter-far-animation-hot-reload-2026-11-17)
- [Parking far-off guards, a cap on bodies awake, fps in the status line (2026-11-17, tested)](docs/notes/performance.md#parking-far-off-guards-a-cap-on-bodies-awake-fps-in-the-status-line-2026-11-17-tested)
- [Director frame cost: perception, garbage collector, far animation, stray sweep (2026-11-14, tested)](docs/notes/performance.md#director-frame-cost-perception-garbage-collector-far-animation-stray-sweep-2026-11-14-tested)
- [Fight hitches and garbage: stray sweep, turret swing hook, per-frame aim (2026-11-14; tested 2026-11-16)](docs/notes/performance.md#fight-hitches-and-garbage-stray-sweep-turret-swing-hook-per-frame-aim-2026-11-14-tested-2026-11-16)
- [Mouse stutter in the menu, loadout and market (2026-11-17, tested; main.lua lobby tick, patchFriendsRefresh)](docs/notes/performance.md#mouse-stutter-in-the-menu-loadout-and-market-2026-11-17-tested-mainlua-lobby-tick-patchfriendsrefresh)
- [Menu hitches after a raid and on the title screen (2026-11-17; main.lua lobby tick and menu helper, mappick.lua, lobbylabel.lua)](docs/notes/performance.md#menu-hitches-after-a-raid-and-on-the-title-screen-2026-11-17-mainlua-lobby-tick-and-menu-helper-mappicklua-lobbylabellua)
- [Airlock crash in UE4SS: IsValid() on a freed object (issue 53, build 6; pvepatch.c pve_alive, main.lua valid)](docs/notes/performance.md#airlock-crash-in-ue4ss-isvalid-on-a-freed-object-issue-53-build-6-pvepatchc-pve_alive-mainlua-valid)
- [Crash on leaving a raid: the lobby world leaked through a rooted portrait (issue 133, builds 6-7; crewlobby.lua photoStep)](docs/notes/performance.md#crash-on-leaving-a-raid-the-lobby-world-leaked-through-a-rooted-portrait-issue-133-builds-6-7-crewlobbylua-photostep)

### [Launcher, releases, Linux and Steam Deck](docs/notes/launcher.md)

- [Trailer tooling (2026-11-01, trailer/)](docs/notes/launcher.md#trailer-tooling-2026-11-01-trailer)
- [Launcher and saves (2026-11-07)](docs/notes/launcher.md#launcher-and-saves-2026-11-07)
- [Public release build; no more hardcoded paths (2026-11-08, tools/release/)](docs/notes/launcher.md#public-release-build-no-more-hardcoded-paths-2026-11-08-toolsrelease)
- [Linux / Steam Deck via Proton (issue 127; scripts/pvemode.py, linux/)](docs/notes/launcher.md#linux--steam-deck-via-proton-issue-127-scriptspvemodepy-linux)
- [Linux launcher window and Deck controls (issue 127, 2026-11-18; launcher.pyw IS_WIN, pvemode.desktop_entry)](docs/notes/launcher.md#linux-launcher-window-and-deck-controls-issue-127-2026-11-18-launcherpyw-is_win-pvemodedesktop_entry)

### [Co-op multiplayer](docs/notes/coop.md)

- [Co-op multiplayer: first look (2026-11-07, evening)](docs/notes/coop.md#co-op-multiplayer-first-look-2026-11-07-evening)
- [Co-op host+join attempt (2026-11-07, late evening) — BLOCKED by a deeper second-instance quit](docs/notes/coop.md#co-op-hostjoin-attempt-2026-11-07-late-evening--blocked-by-a-deeper-second-instance-quit)
- [Co-op join: who drops, and what never fires (2026-11-15; tools/coop/coop_hooks.lua)](docs/notes/coop.md#co-op-join-who-drops-and-what-never-fires-2026-11-15-toolscoopcoop_hookslua)
- [Co-op join: the login never creates a player (2026-11-18; native/pvetrace.dll, tools/profile/dump_image.py)](docs/notes/coop.md#co-op-join-the-login-never-creates-a-player-2026-11-18-nativepvetracedll-toolsprofiledump_imagepy)
- [Correction: the server DOES create a PlayerState (2026-11-18; live GameMode probe)](docs/notes/coop.md#correction-the-server-does-create-a-playerstate-2026-11-18-live-gamemode-probe)
- [Client side: the GameInstance vtable is not where the bounce is decided (2026-11-18)](docs/notes/coop.md#client-side-the-gameinstance-vtable-is-not-where-the-bounce-is-decided-2026-11-18)
- [Night two: the probe grew teeth, and one address fact that explains the dead ends (2026-11-18/19)](docs/notes/coop.md#night-two-the-probe-grew-teeth-and-one-address-fact-that-explains-the-dead-ends-2026-11-1819)
- [The address puzzle is solved: UE4SS's tostring() is not the UObject (2026-11-19)](docs/notes/coop.md#the-address-puzzle-is-solved-ue4sss-tostring-is-not-the-uobject-2026-11-19)
- [Client PlayerController trace, with a real vtable this time (2026-11-19)](docs/notes/coop.md#client-playercontroller-trace-with-a-real-vtable-this-time-2026-11-19)
- [UNetDriver / PendingNetGame from Lua: reachable only while the join is live (2026-11-19)](docs/notes/coop.md#unetdriver--pendingnetgame-from-lua-reachable-only-while-the-join-is-live-2026-11-19)
- [One join window per client launch (2026-11-19)](docs/notes/coop.md#one-join-window-per-client-launch-2026-11-19)
- [Client RPC hooks fire; the connection is still unreachable from Lua (2026-11-19)](docs/notes/coop.md#client-rpc-hooks-fire-the-connection-is-still-unreachable-from-lua-2026-11-19)
- [Server side: the client goes silent, the server only cleans up (2026-11-19)](docs/notes/coop.md#server-side-the-client-goes-silent-the-server-only-cleans-up-2026-11-19)
- [Co-op join works: the host refused a PNAME that isn't Base64 (2026-11-19; native/vtprobe.c, PvEBridge `join`, #26)](docs/notes/coop.md#co-op-join-works-the-host-refused-a-pname-that-isnt-base64-2026-11-19-nativevtprobec-pvebridge-join-26)
