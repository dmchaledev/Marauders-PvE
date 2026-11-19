# Foundations: engine, UE4SS, tooling, code layout

Goals and ground rules, how the repository is laid out, UE4SS quirks, the native helpers, reading the exe, probing the
running game safely, and how main.lua and rivals.lua are split into modules.

Part of the project's research log: [NOTES.md](../../NOTES.md) lists every topic file and every section title.
Sections are in the order they were written; a later section can correct an earlier one, so read to the end of a topic
before trusting a finding. When a section says "see X", search [NOTES.md](../../NOTES.md) for that title to find which
file it is in.

## Contents

- [Goals (user's words, 2026-10-30)](#goals-users-words-2026-10-30)
- [Ground rules](#ground-rules)
- [Layout](#layout)
- [UE4SS quirks in this game](#ue4ss-quirks-in-this-game)
- [Pak key (not found yet; may not be needed)](#pak-key-not-found-yet-may-not-be-needed)
- [Native helper (native/pvenative.c, built by native/build.sh with WinLibs MinGW) — 2026-10-30](#native-helper-nativepvenativec-built-by-nativebuildsh-with-winlibs-mingw--2026-10-30)
- [Offline audit (2026-10-31)](#offline-audit-2026-10-31)
- [main.lua and its modules (refactor, 2026-11-17)](#mainlua-and-its-modules-refactor-2026-11-17)
- [Lua and launcher practices made into checks (2026-11-17)](#lua-and-launcher-practices-made-into-checks-2026-11-17)
- [rivals.lua and its modules (issue 149, 2026-11-17)](#rivalslua-and-its-modules-issue-149-2026-11-17)
- [Blueprint authority branches: bpbranch.py (issue 143, 2026-11-18; tools/offline-audit/bpbranch.py, kdis.py)](#blueprint-authority-branches-bpbranchpy-issue-143-2026-11-18-toolsoffline-auditbpbranchpy-kdispy)
- [Reading this exe (2026-11-18)](#reading-this-exe-2026-11-18)
- [Probing hazards that cost crashes (2026-11-18)](#probing-hazards-that-cost-crashes-2026-11-18)
- [Reading the bridge with the `lua` verb (2026-11-18)](#reading-the-bridge-with-the-lua-verb-2026-11-18)
- [Bridge chunks must be one line (2026-11-19)](#bridge-chunks-must-be-one-line-2026-11-19)

## Goals (user's words, 2026-10-30)
- Raids: PvE with bots (working, being polished: turning, patrols).
- **Space warfare + boarding with bots too**: the pre-raid/pre-station space phase (frigates in space, ship
  combat, boarding other ships) must work offline with bot crews. Relevant classes seen so far: ARaidFrigate,
  ARaidAIShipController, ARaidSpaceship(Inside), ARaidGame_Space, ARaidFrigateLevelStreamActor, drop pods
  (ARaidDropPodControl, Ship_DropPod_Pawn_C), frigate pawns (Ship_*Frigate01_Pawn_C), turrets, BotBehaviorShip BT,
  ARaidWorldProcManager.AIShipsToSpawn.

## Ground rules
- Offline mode only ever runs with mods; online mode restores stock files (`scripts/mode.ps1 online`). Never take a
  modded client into a live match. Easy Anti-Cheat is skipped by launching `RaidGame-Win64-Shipping.exe` directly.
- Offline project: working with Denuvo-protected code is fine (user, 2026-11-07).

## Layout
- `scripts/mode.ps1 offline|online|status` — installs/removes UE4SS + our mods, swaps `pgos_config.ini`.
- `scripts/launch-offline.ps1` — offline mode + start the game windowed.
- `scripts/send.sh "<cmd>" ...` — talk to the in-game PvEBridge mod (`bridge/cmd.txt` → `bridge/out.txt`).
- `mods/PvEBridge` — Lua bridge. Verbs: status, find <Class>, get <Class> <Prop..>, unwidget <WidgetClass>,
  spawn <ClassPath> [dist], dump/sdk/usmap/actors, anything else = console command.
- `config/` — UE4SS-settings.ini (engine override 4.27 needed for the scan to succeed; hot reload on, Ctrl+R) + mods.txt.
- `dumps/` — CXXHeaderDump, UE4SS_ObjectDump.txt, Mappings.usmap (taken in the main menu).
- `docs/internals/`: how the game works inside, read out of the running game: chains of calls with flowcharts, number
  tables, what is still unknown (index: `docs/README.md`). Start there before probing a system again; the research log
  with the reasoning stays in this file.
- `.github/workflows/check.yml` — CI on every push/PR: scripts/luacheck.py over every tracked .lua (Lua 5.4 via lupa, so
  the 200-locals limit too) and py_compile over every .py/.pyw. Needs no game files.

## UE4SS quirks in this game
- Engine version auto-detect fails → override in settings to **4.26** (NOT 4.27: UE4SS picks the ProcessEvent vtable
  slot by version; with 4.27 it calls slot 68, a stub returning 2, so every UFunction call from Lua silently did
  nothing and returned zeros). Real UObject::ProcessEvent = vtable slot 67 (offset 0x218), RVA 0x1c35330,
  prologue `40 55 56 57 41 54 41 55 41 56 41 57 48 81 EC F0 00 00 00 48 8D 6C 24 30`; ProcessInternal RVA 0x1c356e0.
- "unable to resolve JMP @ ...300483" is UE4SS failing to hook ULocalPlayer::Exec (harmless).
- `scripts/procmem.py` reads the live process (read-only) for this kind of check.
- `ExecuteInGameThread` never runs (ProcessEvent hook fails: "unable to resolve JMP"). Game-thread work is queued and
  drained from RegisterHook'd blueprint ReceiveTick functions (MainPlayerController_C in raids, MM_CoreMissions_C in menu).
- In-game console: F10 (ConsoleEnablerMod).

## Pak key (not found yet; may not be needed)
- Static exe scan for the `mov [reg+off], imm32` key pattern: nothing (Denuvo).
- Memory scan (`scripts/find_aes_mem.py`, 8-aligned windows in RW memory, 2.9 GB, 112M candidates): nothing.
- Plan B: list content at runtime through the AssetRegistry from Lua, load assets with StaticLoadObject.
  Note the pak has a .sig file (signing) — check whether extra unsigned paks (LogicMods) mount before relying on them.

## Native helper (native/pvenative.c, built by native/build.sh with WinLibs MinGW) — 2026-10-30
- Why not a UE4SS C++ mod: no MSVC installed, SDK needs a linked Epic/GitHub account and a matching UE4SS rebuild.
  Instead `package.loadlib(<dll>,"*")` from the bridge (`luaq`) loads a plain DLL whose thread polls
  bridge/native_cmd.txt -> native_out.txt (rebuilt copies: `build.sh 2` -> pvenative2.dll / native2_cmd.txt; a loaded
  DLL is locked). Commands: info, alloctest, dumpmap <addr>, merge <addr>, fill <addr>.
- Engine allocator: GMalloc = exe base + 0x58aee70, "binned2" (vtable[18] returns the name), Malloc = vtable[2], Free = [6].
  TMap<FString,FInventoryGridPair> layout verified (TSet: elements 32 B, inline bits, 1 inline hash bucket; HashSize=1
  chain works regardless of hash function).
- **CORRECTION of the earlier theory**: InventoryContainerSizes is NOT empty offline: the player's component holds 9
  defaults (Stash 10x15, PocketLeft 2x2, LootPocketLeft, Shop, Buy, Sell, Gift, unlock, scrap). "0 grid cells" came from
  never-built widget templates (WidgetTree.*). Missing keys PocketRight/LootCon/Lobby/RigSlot1-4 were merged in.
- Real finding: in an offline raid NO live SIGIS_HUDOverlay_C / MainOverlay exists. Creating it
  (WidgetBlueprintLibrary:Create(pc, /SIGISPlugin/Widgets/HUD/SIGIS_HUDOverlay.SIGIS_HUDOverlay_C, pc) + AddToViewport)
  works without a crash and gives live InventoryContainerWidgets; InitializeGrid then builds cells (call it once only,
  it appends). Needed for PocketRight/Lobby/LootCon.
- Still crashing (null read at 0x260, same getter): Server_EquipItem after Server_AddItem(..., ToCon="Equipment"). The item
  has no DraggableItemWidget because "Equipment" is not a container widget. Next try: add the item into a LIVE container
  ("Lobby"/"LootCon"/"PocketLeft") so a draggable exists, then equip; also check whether pressing Tab crashes with the HUD.

## Offline audit (2026-10-31)
Whole-game scan for code that only runs as a network client / via replication: see OFFLINE_AUDIT.md (prioritised list
of likely breakages: explosions, hit reacts, whizz, vault anim, ship system damage, turret manning, evac, contracts,
SIGIS add-item early-outs, gear meshes, IsServer-gated Blueprints incl. footsteps). Scripts + raw data:
tools/offline-audit/ (live read-only; name pool at RVA 0x58ceb40, GUObjectArray from UE4SS.log).
- Combat-feel fixes (same day, results in OFFLINE_AUDIT.md): explosions already work; pvepatch now 16 patches
  (+ instant-hit reacts 0x189b74c/0x189bbdf, vault/climb 0x180c648); director plays near-miss whizz and the broken-gun
  effect. Test scripts: bridge/t_wz.lua (whizz counter), t_wzshot.lua (fake bot near-miss), t_vault.lua, t_brk.lua,
  t_expl2.lua; `summon Proj40mm_C` spawns a grenade round (BeginDeferredActorSpawnFromClass fails from Lua).

## main.lua and its modules (refactor, 2026-11-17)
- Why: main.lua had 200 active locals in its chunk, Lua 5.4's limit, so new helpers went in as globals (addInteriorNav,
  relaySalvage for #134, godMode, PveResetRaid, PVE_patchFriends, PveMenuBusy...) or into the `Aux` table. Measured by
  appending locals until load() refuses: 200 before, 101 after.
- Moved verbatim (comments with their code) into modules with the usual shape (`local M = {}`, `M.init(ctx)`, `return M`):
  - `bots.lua`: sections 2-6 (KINDS, wake/arm/spawnBot, factions and foes, reapDead, parking, patrols, noises, cover,
    combatHints, updateBots, animate, trackTargets) and station garrisons (spawnGarrison, spawnQueued). The old
    `Aux.parked/openLog/botShot/advancePoint/isMelee/meleeHints/pathLen/longWay` are `M.*` there.
  - `playareas.lua`: where bots may go (sealed, offLimits) and the old `Aux.inBox/findAll/scan/mapPlayAreas/rescan`.
  - `loadout.lua`: ensureHud, applyLoadout, the donor-soldier gun, floor loot, extractNow, the extraction hooks and the
    back-to-menu step (`returnAfterExtract`, called where that block sat in update).
  - `launch.lua`: matchmaking (onStartMatchmaking, the captain button, launchMatch, its mm/launching/launchShip state)
    and the space-map loading veil (veilUntilAboard). onTick asks `Launch.busy()` and `Launch.fire()`.
  - `space.lua`: pod guns, docking hooks, level effects, key card, sun, the interior navmesh (addInteriorNav,
    startSpaceNav), relaySalvage and updateSpace (`Space.update`).
  - `debugactions.lua`: god mode and the F9 buttons (Debug.init).
- The per-raid table: resetRaid replaces `raid`, so every module keeps its own reference and main's `shareRaid()` hands
  the new table to each (`M.setRaid`) right after the reset. A new module that reads `raid` needs adding to that list.
  (The older modules still take a `raid = function() return raid end` getter; both work.)
- Kept in main.lua: CFG, valid/log/dist helpers, the patch DLL entry points, ragdoll settling, gc and the profiler,
  onTick, the land navmesh (startNav, navMesh, navReadyAt), footstep/friends patches, resetRaid, update (lobby stash
  rows, input on arrival, flag files), the gunfire/whizz/death hooks and the keys. `Aux` now only holds `due` (shared
  with the modules as `ctx.aux`) and `unlessTyping`.
- Globals made locals again: Out, GearScale, the menu helpers (Quit, InvKeys, LobbyLabel, InvQol), onTick's state
  (`tick.world/menu/menuSince/...`), resetRaid, patchFriendsRefresh, the mouse check, godMode, addInteriorNav,
  relaySalvage. Still globals on purpose: PveMapPick and PveGuild (lobbylabel.lua reads them), Hire, Crew, CrewLobby,
  Missions (other modules read them), PVE_PROF/PVE_ALLOC/PVE_GC (profiler, bridge/dir_eval.lua).
- Verified: luacheck on every file; a scan for names each module reads but doesn't declare (only the globals above);
  every line of the old main.lua is in the new files apart from the renamed call sites; main.lua and every module load
  under lupa with UE4SS stubbed, registering the same 27 hooks, key binds and loops and logging the same lines as before
  (only the order of hook registration differs).
- In game (2026-11-17, throwaway cheat save, the branch's Lua copied over the game's): login and lobby; lobby launch
  button -> matchmaking -> Space_Alpha, veil, loadout, floor loot, key card, play areas, space navmesh, aboard after 19 s;
  a rival boarded (bridge/rivals_board), took cover, peeked, switched to the crewmate, was killed; F9 extract -> main
  menu. Spaceport_01 land raid: navmesh, 8 soldiers, donor gun and ammo, god mode on/off, F9 spawn soldier, a fight with
  cover and a bot reload, F9 extract with 3 items. No Lua errors in UE4SS.log. Note: bridge/debug_cmd is only read in
  a raid (update returns early in the lobby), so its "testraid" does nothing from the menu, as before.

## Lua and launcher practices made into checks (2026-11-17)
- `scripts/luacheck.py` measures each file's headroom under Lua's 200-locals limit (as many extra top-level locals as
  still compile, put in front of the file) and fails CI under 20. It found **rivals.lua at exactly 200 (0 to spare)**:
  allowed as a named exception until #149 splits it. main.lua: 99 to spare after #146.
- main.lua `pveRoot(object)` replaces the raw `pve_root(address)`: it walks the object's outers and refuses (logged:
  `root: refused ... (a world owns it: Level ...)`) anything a World or Level owns, the #133 leak. Callers (crewlobby,
  female, loading, rivals, voice) pass the object. Checked with lupa stubs: a stand-owned render target refused, a game
  instance one and an asset rooted, nothing rooted without pvepatch.dll.
- Audit of raw `:IsValid()` calls: nearly all are on fresh lookups (StaticFindObject/FindFirstOf, class objects, CDOs,
  hook contexts). The exceptions were a game-held pointer, `turret.ControllerHere` (crew.lua twice, gunseat.lua), which
  can point at a freed controller: now `valid()`.
- Launcher (#147, PR #148): background threads go through `App.ui(fn)` and a 50 ms pump; grid layout with wrap widths in
  points; font fallback; dialogs are owned windows that grab only once visible; keyboard focus and Enter/Space on
  buttons; Tk option-database theme; `launcher/test_ui.py` (12 headless tests). Tk's font cache is per process on
  Windows: a scaling test must run in its own process or it leaks into the others.

## rivals.lua and its modules (issue 149, 2026-11-17)
- rivals.lua had all 200 of Lua's top-level locals (found by luacheck's headroom check). Its sections moved verbatim:
  `rivalcrews.lua` (Crews), `rivalships.lua` (Berths, Docking route, Ships), `rivalbodies.lua` (Bodies, Spreading
  out, Station defenders), `rivalcombat.lua` (Breaching pods, Ship combat, You boarding a rival's ship). rivals.lua
  keeps the header (CFG, helpers), World survey, Crew brain and Public: 60 locals now, 140 to spare.
- Sharing: rivals.lua builds a table H of the header's names and puts it at `package.loaded["rivalshared"]`; each
  module reads what it uses from it into its own locals at load, so moved code is unchanged. Modules load in
  dependency order (crews, ships, bodies, combat) and the functions a later module uses are added to H as each loads.
  `X` (main's context) and `S` (per-raid state) change at runtime, so they reach the modules through `M.bind(X, S)`,
  called by `shareState()` after `R.init` sets X, after a new raid's S, and in `R.reset`. Ships' `AIMED` table is reset
  per raid through `Ships.resetAimed()`.
- In rivals.lua, uses of moved names go through the module (`Ships.flyTo`, `Combat.engage`...): 152 call sites, found by
  scope analysis so locals of the same name were left alone. Note the Breaching pods section has its own
  `weighted(w)` (a map of weights), which shadows the header's `weighted(list)`; it stays inside rivalcombat.lua.
- Checked: luacheck (all 5 files 120+ spare); a scope-aware free-name scan (no name became a global; `package` is new
  and intended); every line of the old file is in the new ones, apart from the rewritten call sites and R.reset's
  shareState(); under lupa with UE4SS stubbed, old and new export the same 254 `R` keys, register the same 4 hooks,
  and run R.init / R.reset cleanly.

## Blueprint authority branches: bpbranch.py (issue 143, 2026-11-18; tools/offline-audit/bpbranch.py, kdis.py)
- kdis.py is importable now: `decode(code(func))` -> [(offset, text)]; the CLI is unchanged.
- bpbranch.py <out.json>: for each loaded Blueprint function, every `if not HasAuthority/IsServer/IsStandalone jump T`
  (and the Not_PreBool form) -> the side that never runs offline, walked through jumps, branches and push/pop, minus
  whatever the authority side also reaches; the calls there, flagged when they look visible. ~14 s for 988 classes.
  Results and triage: OFFLINE_AUDIT.md "Blueprint branches that never run offline". It found the pod breach timer (#77)
  by itself, and the same shape on every frigate pawn (ShipHealthCheck, 1 s: DamageEffects_ShipHull/Engine/Turret).
- ShipHealthCheck test (Space_Solo_01, your Starter hull cut to 25 %, timer started from the bridge, looked at from a
  pod 18 m off): no difference seen; the hull already trailed smoke before. Not shipped, and not needed: rivals.lua
  hullDamageFx (2026-11-14, "Rival hulls" above) already lights those emitters and calls DamageEffects_* itself.
- Gotcha: IsDedicatedServer is false offline (standalone), unlike IsServer; the first version of the scan had it the
  wrong way round.

## Reading this exe (2026-11-18)

- **The file is packed; only memory has code.** `.xtext`/`.xcode`/`.arch` are encrypted on disk:
  disassembling a known code RVA in the file gives nonsense (`and al,0x88`), the same RVA in the
  live process gives real code. All analysis must read the running process (or a dump of it).
- **`.data2` holds code too** - not just data. Small stubs like `ret 0` (0x7e0290, the shared empty
  override), `mov al,1; ret` (0x7e0320), `xor al,al; ret` (0x7e0330) live there, so "section name"
  does not tell you thunk vs body.
- **UFunction + 0xD8 is `Func`,** and it points at a `.data2` thunk (`jmp <abs>`) that jumps to the
  real implementation in `.xcode`. `HandleStartingNewPlayer`: UFunction -> 0x3588a80 -> **0xd7b8ab0**.
  UFunction objects are allocated 0xE0 apart, so +0xE0 is the *next* object's vtable, not a field.
  This converts "find a function in a 246 MB blob" into "read one pointer".
- **GameMode vtable map** (`ShootingRangeGameMode_C`, instance vtable RVA **0x4599ed8**, 420 slots):
  396 resolve; most are tiny `.data2` overrides. Only slots **0** (0xa0518f0) and **23** (0xc9f9b10)
  reach substantial `.xcode` code. `PreLogin`/`Login` are not identified yet; shape-matching by
  argument registers was inconclusive (a first pass gave a false positive at slot 96 because the
  scanner ran past the function's `ret` into the next function - bound the scan at `ret`/`int3`).
- **Tools fixed:** `tools/profile/refs.py` and `strfind.py` only scanned `.data2`/`.xcode` for
  references, so they found nothing on this build; both now include `.xtext` and `.arch`.
  `procmem` opens its process handle at import - reload it after the game restarts or reads fail at
  the old base. New: `tools/profile/dump_image.py` writes the live image to a PE (ImageBase patched
  to the runtime base) for Ghidra.

## Probing hazards that cost crashes (2026-11-18)

- **Do not dereference a fresh `UNetConnection`.** Reading `conn.State` / `conn.OwningActor` at the
  moment a client connects killed the host twice (crash dumps 15:16:09 and 15:18:56,
  `EXCEPTION_ACCESS_VIOLATION`, 37 UE4SS frames above the game's). `pcall` cannot catch it.
  Reading only array *lengths* (`ClientConnections:GetArrayNum()`, `GameState.PlayerArray:GetArrayNum()`)
  is safe and was enough for every measurement above.
- **Never assign a Lua table to a `TArray` UPROPERTY** (`gm.ConnectedPlayerIds = {...}` kills the
  game instantly). Filling such an array needs native code (`native/arrwrite.c` pattern: point the
  array's Data at a static block, set Num/Max).
- **A probe calling `FindFirstOf` at 1 Hz during a load kills or freezes the second client** (full
  object scan, 30-45 ms each). Re-run with the probe off before blaming the game.
- Harness: the host is shot by its own AI if left alone - `bridge/god.txt` makes it immune.
  `PvEBridge` goes permanently deaf after a world change (its LoopAsync stops after the first
  successful hook), and at the splash it only answers with PvEDirector enabled.

## Reading the bridge with the `lua` verb (2026-11-18)

A bridge line that is not a known verb is run as Lua and answered with `ran: <code>`, which hides
both the result and any error. The `lua <code>` verb is different: it runs the chunk on the game
thread and replies `= <return value>`. Use it for every query.

    bsend.sh bridge 'lua return #(FindAllOf("PlayerState") or {})'
    bsend.sh bridge 'lua local t=FindAllOf("PlayerState") or {} return #t'

`FindAllOf` and `FindFirstOf` work from there; `tostring(obj)` prints `UObject: 0x<address>`, which
is the object address, and the first qword at that address is its vtable - the cheap way to get a
class vtable in a process whose base you have not resolved.

Two probe bugs worth keeping: an empty `FString` is `Data=0 Num=0 Max=0`, so a filter that
requires `Num >= 1` never watches the error buffer it is meant to watch; and re-wrapping a vtable
whose slots still point at your own stubs fails the "does this look like a vtable" check until the
stubs are restored first.

## Bridge chunks must be one line (2026-11-19)

`bsend`/the probe inbox read a single line, so a Lua chunk containing newlines is truncated at the
first one and the reply is just the echoed code. Multi-statement chunks have to be joined with
spaces. Replies are `HH:MM:SS = <value>`; match `=\s*(.+)$`, and remember actor `tostring` prints
`AActor: 0x...`.
