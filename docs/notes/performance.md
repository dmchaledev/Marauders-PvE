# Performance, stutter and crashes

Frame cost of the director, stutter hunts, garbage collection, and crashes that were found and fixed.

Part of the project's research log: [NOTES.md](../../NOTES.md) lists every topic file and every section title.
Sections are in the order they were written; a later section can correct an earlier one, so read to the end of a topic
before trusting a finding. When a section says "see X", search [NOTES.md](../../NOTES.md) for that title to find which
file it is in.

## Contents

- [Stability fixes (2026-10-30)](#stability-fixes-2026-10-30)
- [Dead-bot crash (FIXED 2026-10-31)](#dead-bot-crash-fixed-2026-10-31)
- [Stutter found: PGOS friends refresh; mid-flight freeze: pilot names ran out (2026-11-13, ~19:30, live in the user's raid)](#stutter-found-pgos-friends-refresh-mid-flight-freeze-pilot-names-ran-out-2026-11-13-1930-live-in-the-users-raid)
- [Frame drops to ~50 fps: Lua heap leak + GC stalls, FIXED (2026-11-13, ~20:00-20:25)](#frame-drops-to-50-fps-lua-heap-leak--gc-stalls-fixed-2026-11-13-2000-2025)
- [Director per-frame cost: ships off the helm, calm bots, fewer engine reads (2026-11-17, tested)](#director-per-frame-cost-ships-off-the-helm-calm-bots-fewer-engine-reads-2026-11-17-tested)
- [Build 4 quick wins: looting stutter, far animation, hot reload (2026-11-17)](#build-4-quick-wins-looting-stutter-far-animation-hot-reload-2026-11-17)
- [Parking far-off guards, a cap on bodies awake, fps in the status line (2026-11-17, tested)](#parking-far-off-guards-a-cap-on-bodies-awake-fps-in-the-status-line-2026-11-17-tested)
- [Director frame cost: perception, garbage collector, far animation, stray sweep (2026-11-14, tested)](#director-frame-cost-perception-garbage-collector-far-animation-stray-sweep-2026-11-14-tested)
- [Fight hitches and garbage: stray sweep, turret swing hook, per-frame aim (2026-11-14; tested 2026-11-16)](#fight-hitches-and-garbage-stray-sweep-turret-swing-hook-per-frame-aim-2026-11-14-tested-2026-11-16)
- [Mouse stutter in the menu, loadout and market (2026-11-17, tested; main.lua lobby tick, patchFriendsRefresh)](#mouse-stutter-in-the-menu-loadout-and-market-2026-11-17-tested-mainlua-lobby-tick-patchfriendsrefresh)
- [Menu hitches after a raid and on the title screen (2026-11-17; main.lua lobby tick and menu helper, mappick.lua, lobbylabel.lua)](#menu-hitches-after-a-raid-and-on-the-title-screen-2026-11-17-mainlua-lobby-tick-and-menu-helper-mappicklua-lobbylabellua)
- [Airlock crash in UE4SS: IsValid() on a freed object (issue 53, build 6; pvepatch.c pve_alive, main.lua valid)](#airlock-crash-in-ue4ss-isvalid-on-a-freed-object-issue-53-build-6-pvepatchc-pve_alive-mainlua-valid)
- [Crash on leaving a raid: the lobby world leaked through a rooted portrait (issue 133, builds 6-7; crewlobby.lua photoStep)](#crash-on-leaving-a-raid-the-lobby-world-leaked-through-a-rooted-portrait-issue-133-builds-6-7-crewlobbylua-photostep)

## Stability fixes (2026-10-30)
- Raid -> same raid crashed: the director keyed its per-raid state on the world NAME, which is the same when the
  map loads again, so it validated the previous raid's freed soldiers (IsValid reads the object: access violation in
  UObjectBase::GetInternalIndex). Now keyed on name + world address + controller address, and the per-frame aim
  tracking only runs for the controller the state belongs to.
- A hang on raid load: a mod's print() blocked writing to the UE4SS debug console window (Output::send ->
  DebugConsoleDevice -> ucrtbase wait); console writes block while it is paused (text selected). ConsoleEnabled = 0
  in config/UE4SS-settings.ini; logs are in UE4SS.log.
- Crash reports: %LOCALAPPDATA%\RaidGame\Saved\Crashes\*\CrashContext.runtime-xml (PCallStack has module+offset;
  UE4SS offsets map to its exports, no PDB shipped). A crash leaves CrashReportClient holding the game folder's
  DLLs, so mode.ps1 can't copy until it is closed.
- Verified: 3 raid loads in a row, raid -> menu -> raid, all with the loadout and no crash.
- Next: real extraction points offline, loot pickup in raids, then contracts/quests.

## Dead-bot crash (FIXED 2026-10-31)
- Cause (from disassembling the stack in tools/ue4ss/UE4SS.dll): 0x87b9d0 is the metamethod dispatcher, 0x37f6f0
  the UObject `__index`, 0x380a50 the property lookup, and 0x4bdd90 is `IsA(UClass)` walking the SuperStruct chain
  (0x516440 = GetSuperStruct). So Lua read a property of a FREED UObject, and its garbage class chain ended at -1. It
  was a hooked ReceiveTick (the director's onTick), so it came from per-frame code. Not a TArray marshalling problem.
- The culprit: dead bots stayed in `raid.bots` forever, with e.fighting / e.cover frozen from their last fight. The
  per-frame peek/hide in trackTargets checked `valid(e.ctrl) and e.bot.Health`, with no valid(e.bot), so it kept
  reading the corpse pawn. The pawn is destroyed ~3.2 s after death (pve_bodies) and freed at the next GC (~60 s
  later), which explains the 1-10 min delay and the link to kills. Even `IsValid` reads the object's memory, so
  holding the reference at all is unsafe.
- Fix (main.lua `reapDead`, run first in trackTargets and updateBots): an entry whose bot is invalid or at Health
  <= 0 drops bot/ctrl/hand plus its fight state and leaves raid.bots while the pawn is still intact. Rivals' c.bodies
  keep the entry, but `valid(nil)` is false there, so bodiesAlive still reports the member killed. An invalid
  controller is swapped for the bot's current one. Line 896 now checks valid(e.bot) too.
- Rule: never keep a reference to an actor that can die or be destroyed past the frame you notice it. Drop it as
  soon as it is dead or invalid, before GC frees it.
- Verified: Spaceport raid (13:56-14:04) with 4 scripted kills of bots fighting from cover, ~3 crossfire deaths and a
  forced GC (KismetSystemLibrary:CollectGarbage) every 20-30 s. No crash and no Lua errors. The user ended the soak
  at ~8 min, satisfied. Not done: a repro on the unfixed code. Test tools: bridge/t_crash.lua (_G.CR_PHASE
  hurt/kill/gc) and bridge/soak.sh.

## Stutter found: PGOS friends refresh; mid-flight freeze: pilot names ran out (2026-11-13, ~19:30, live in the user's raid)
- First clean measurement (game in front, no WoW/Roblox, 10 GB RAM free, ~85 fps): 10-13 frame gaps of 50-100 ms per
  10 s while the director tick stayed under 5 ms on almost every frame. Not memory, not our per-frame Lua.
- Cause: a hitch every 1.00 s exactly (~70 ms). External sampling (scratch hitchcatch/walk scripts, same approach as
  tools/profile/threadsample.py plus dbghelp StackWalk64 on the suspended game thread): during each gap the game
  thread blocks in steamclient64 IPC under GAME+0x9590xx (ISteamFriends vtable +0x18/+0x20/+0x30/+0x38/+0x40 =
  GetFriendCount/ByIndex/PersonaState/PersonaName/GamePlayed, "%llu" ids) = native
  SIGISGameInstanceNakama::GetAdditionalSteamFriendsPGOS (thunk 0xa4b760), called from Blueprint
  PgosFriendsPanel_FriendsView_WBP_C:StartGetFriends -> GetSteamFriends. A hook counted StartGetFriends 8x in 8 s,
  no PGOS success/failure callbacks. Driver: native looping FTimerManager timer, rate 1.0 s (InternalSetTimer 0x348fba0,
  handle at panel+0x408, bound at 0x15aa446/0x15b40d0 to 0x15a50d0). Not a named timer (K2_IsTimerActive false).
  The overlay lives on hidden in raids (and the menu), so it hitched everywhere; cost scales with Steam friend count.
- Fix (UNTESTED in game): pvepatch.c `pve_bp_stub_return(UFunction)` turns the BP StartGetFriends stub
  (18 bytes: 46 <ExecuteUbergraph> 1d <1259> 16 04 0b 53) into an immediate Return (bytes checked first); main.lua
  `patchFriendsRefresh` applies it per world. Offline the friends panel only says "social service unavailable".
  Built as native/pvepatch.new.dll (the running game locks pvepatch.dll): rename it over pvepatch.dll with the game
  closed. Verify: profile.txt gaps over 50 ms should drop to ~0 at rest.
- Freeze at 19:38:59 (game Not Responding, one core spinning, memory flat): game thread inside the director's
  ReceiveTick hook in an endless Lua loop. rivals.lua newMember did `repeat name = pick(PILOTS) until not used[name]`;
  PILOTS has 52 names, and this raid had 11 crews + 5 skirmish pairs = 21 crews (~52 people + ship watches). The 6th
  skirmish (SKIRMISH_MAX 6) could never get a name. Fixed: pick from the free names, else a numbered name (Vex2).
- Also seen, not looked into: the director's Lua heap grew 58 MB -> 1.2 GB in 9 minutes of flying (profile.txt
  "lua heap"), ~100 MB/min, with few collections. Turret swing hook ~3500 calls/s. Worth a look before long raids.

## Frame drops to ~50 fps: Lua heap leak + GC stalls, FIXED (2026-11-13, ~20:00-20:25)
- User's raid (19:52, nothing else open, ~85 fps average): the drops were single frames of 190-430 ms, and every one
  lined up with a Lua garbage collection (7 of 9 windows with a collection had a >100 ms gap; 0 of 19 without one).
  The director's heap grew ~10 MB/s in fights to 1.7 GB, and stayed at 2.2 GB in the lobby afterwards.
- Cause: a UE4SS leak. Every UFunction call with an out-parameter (LineTraceSingle's hit result, navmesh projection,
  random reachable point, GetActorBounds, the SweepHitResult of K2_SetActorLocation...) takes a registry reference
  (luaL_ref) to the out table and never releases it: +1 registry slot per call, fresh or reused table, through a full
  collection (bridge/t_reftest3.lua). Cover baking traces thousands of times a second, so every hit result (11
  sub-tables) ever made stayed live; a census (bridge/t_census.lua) showed 484 -> 1503 of them under R/[n] in 2 min.
  Each GC cycle had to mark all of it.
- Fix: outref.lua. `Out.call(obj, "Method", ...)` notes the registry free-list head (registry[3] in Lua 5.4.4, lauxlib
  `freelist`) and length, makes the call, then releases (exactly as luaL_unref) only the new slots holding one of the
  call's table arguments. All ~30 out-param call sites go through it (main.lua uses a global `Out`: it's at the
  200-locals limit). Verified: registry stays at 58 slots, ~48k refs released in 2 min of fighting; live heap 2-3 MB flat
  (was 7 -> 75 MB in the same test, 2 GB in a long raid).
- GC is also driven from the frame now (main.lua `gc`): incremental pause 200, stepmul 400, plus up to 1 ms of
  collectgarbage("step") per frame (3 ms while the heap is over 2x live). Longest single GC step now 1-2 ms (was
  100-430 ms). bridge/gc_gen switches to generational mode (testing only, untested).
- Less garbage: cover.lua reuses its trace argument tables and looks up the engine objects once; animate() keeps each
  bot's Mesh/CharacterMovement on the entry (reapDead clears them); trackTargets reads the foe's location only when it
  sets LastKnownPlayerPosition; the turret swing hook allocates nothing past ctx:get() (UE4SS itself still makes ~1 KB
  per hook call, ~1.5 MB/s in space with ~45 turrets; now plain garbage, not a leak).
- Profiler (bridge/profile_on) now also writes: MB allocated in director ticks vs between them (hooks) and per section,
  GC cycles / live size after the last cycle / time spent stepping / longest step, registry size and refs released.
  bridge/dir_eval.lua (profiler on only): the director runs it once in its own Lua state, result in dir_eval.out.
- Tests: bridge/gc_test2.sh (Spaceport, 8 provoked, flanking), gc_test3.sh (same + census at start/end). WoW was in front
  for all of them (5-45 fps), so no frame-time numbers from these; memory/GC numbers don't depend on that.
  NOT yet seen: a clean-fps raid with the fix (profile.txt "frame gaps over 100 ms" should stay ~0).
- Save/crew restored from backend/state.before-gc-test.json / crew.before-gc-test.lua; folder left online.
- One call site was missed (found 2026-11-15): crew.lua C.tags called ProjectWorldLocationToWidgetPosition (out param
  ScreenPosition) directly, every frame per crewmate on screen. Through Out.call now. Checked in game through the
  bridge, 1,000 calls each way: direct +1,000 registry slots, Out.call +1 (1,000 released).

## Director per-frame cost: ships off the helm, calm bots, fewer engine reads (2026-11-17, tested)
- rivals.lua R.frame: on foot (S.onFoot, set in R.update: your character is the pawn, not the helm, a turret seat or a
  pod), glideShips, fireControl and swingAimed run CFG.SHIP_FRAME_HZ_FOOT (15) times a second with the real time
  since the last pass (glides go by the clock; gunnery and swing scale by dt, capped at 0.25 s). Pods and boarding
  still run every frame. At the helm: every frame, as before.
- main.lua trackTargets: bots at peace (not fighting, in cover, investigating or running) run animate() and their aim
  upkeep at CFG.ANIM_PEACE_HZ (15) instead of ANIM_HZ (30); a change of what they should be doing is still caught at
  once. The two per-frame loops after reapDead no longer re-check valid(bot) and Health (reapDead just did, and
  nothing is freed mid-frame): four engine calls per bot per frame fewer. Parked bots are skipped in both.
- updateBots reads each bot's location once per update (o.updAt) for the perception list, Aux.parked and its own
  loop; it used to read it three times (each read is a new table).
- Test: Space_Solo_01, Fortress, 14-16 guards and 8 crews, everyone's senses off (ai.lua PROFILES sight 1, hearing 0,
  from bridge/dir_eval.lua) so both runs are at peace; master's scripts vs this branch's, 120 s in the station.
  Per 10 s: rivals frame 554 -> 134 ms, aim 276 -> 233 ms, director total ~1000 -> ~550 ms, allocated 16.6 -> 11.3 MB.
  Frame rate unchanged on this PC (~76-80, not director-bound). Runs with fights aren't comparable: fights are
  random and fighting bots keep the full rate (cover alone went 34 -> 386 ms when 4 bots fought).
- Which stations have a docking node (and so a "station" in rivals' list) differs per run of the same map: test
  scripts should retry until the station they want is there.

## Build 4 quick wins: looting stutter, far animation, hot reload (2026-11-17)
- invkeys.lua menuWidget() ran FindAllOf("SIGIS_Exit_Widget_C") every 2 s while the inventory was open, until the pause
  menu had been opened once in that raid (44-101 ms each in bridge/profile.txt): a stutter while looting. Now it only
  looks once ExitMenu_Open's hook has run in this world (menuOpened, reset when the old world's widget is gone). The
  stuck-inventory check also needs the widget in the viewport (IsInViewport), not only flagged visible.
- Far animation (animDistance, ANIM_FAR): on by default; bridge/anim_far_off turns it off for testing (it used to need
  bridge/anim_far_on, so release never had it). In game: animSwitch counts in profile.txt, no errors, 14-16 bots.
- config/UE4SS-settings.ini EnableHotReloadSystem = 0: UE4SS 3.0.x reloads every mod on Ctrl+R, which is crouch +
  reload in a fight. Developers who want hot reload can set it back locally.

## Parking far-off guards, a cap on bodies awake, fps in the status line (2026-11-17, tested)
- Build 4 testers report 10-15 fps in raids. Found: every station you enter adds its guards (own NPCs adopted, plus
  top-ups to MIN_DEFENDERS) to raid.bots, and nothing ever put them back to sleep: updateBots even wakes any bot the
  game had put to sleep. After a few stations, dozens of guards far away kept their per-update AI, sized up every other
  body within PERCEIVE_RANGE (n^2), and ticked skeleton and movement every frame. Rival crews were fine (they go back to
  simulation 20 s after you leave).
- main.lua Aux.parked (main.lua and rivals.lua are both at Lua's 200-local limit, hence Aux / R fields): a guard or
  soldier at peace (not a rival, not your crew, not fighting, alerted or investigating) farther than CFG.PARK_RANGE
  (15000) from your on-foot character gets time dilation 0 (body and controller), movement and pose ticks off, and is
  skipped by updateBots, the perception candidate list and trackTargets' animate loop. Back within 85% of PARK_RANGE,
  or hurt, e.parked is cleared and updateBots' existing wake() branch (dilation < 1) brings it back.
- rivals.lua CFG.AWAKE_MAX (16), R.awakeCount(): a crew about to materialize in your station waits aboard (the same
  waitingRoom path as insideCap) while that many bodies are awake around you (parked and your crew don't count), and a
  station's top-ups stop at the cap ("N more guards wanted, room for M"). Both settings are in F3 > How many; 0 = off.
- The 10 s status line now has "parked N" and "fps N" (frames counted in onTick's aim step), so testers' last_game.log
  carries frame data without the profiler.
- Test (Space_Solo_01, MIN_DEFENDERS 14 and CREWS 8 set from bridge/dir_eval.lua, t.MaxFPS 0, god mode; teleport into
  Navy Outpost for 60 s, back aboard your ship for 120 s; master's scripts vs this branch's, same route):
  master 67-77 fps, director over 10 ms on 10-16 frames per 10 s; branch 89-96 fps, 0-3 frames over 10 ms, 12 of 14
  guards parked (the 2 still fighting stay awake). Back in Navy Outpost: parked 0, patrolling and fighting again, no
  Lua errors. Not measured: a slower PC, and a full raid of several stations (should gain more, as nothing piles up).
- Testing tips learned: splash PLAY doesn't always take its bound event from Lua (real click instead);
  Crew_LaunchToMatchBtn_SubWidget_C:BndEvt__Btn_Main_..._OnButtonPressedEvent__DelegateSignature() starts a raid from the
  bridge. A test raid appends to cover/<map>.txt (tracked): check it out again afterwards.

## Director frame cost: perception, garbage collector, far animation, stray sweep (2026-11-14, tested)

Follow-up to the Colony Cruiser numbers above (27 bots, ~20 fps with stutters):
- ai.lua AI.perceive: the target's velocity, facing, crouch and address are read once per body record (targetInfo), and
  the bot's own position and facing once per frame, instead of again for every check (each read is an engine call and
  garbage).
- main.lua gc.frame: incremental collection only starts once the heap is gc.START (1.25x) over the live size after the
  last cycle, instead of stepping every frame. The stepping went from ~2480 ms to ~360-500 ms per 10 s.
- main.lua trackTargets: bots that aren't fighting and are over ANIM_SLOW_FAR (4000) from the camera animate at
  ANIM_SLOW_HZ (10) instead of every frame. animate() reads crouch and targeting once.
- main.lua updateBots: the soldier's log name is built only when a line is logged.
- rivals.lua sweepStrays: one PLACED class per pass in rotation (~43 ms) instead of all of them (~100 ms).

Tested (Space_Alpha, Rebel Base, 8-11 bots, recording at the same time): 100-130 fps inside the station (88-92 at Moon
Base with 11 bots before, without recording); the user says it seemed good. Still there: a one-off hitch on entering a
station (worst frame 212 ms, the entry FindAllOf scans). Not yet tried with 20-27 bots.
- Station entry (issue #12, 2026-11-15; Space_Beta, teleported on foot into the Asteroid Mine, profiler on): the entry
  window had 9 FindAllOf (~480 ms): SIGISContractActor, SIGISLootSingleSpawner and RaidAINodeStart twice each (rivals.lua
  seedSpots and main.lua Aux.rescan scan the same classes within a second), RaidUseableAirLockComponent, and the two
  CFG.PLACED classes (placedDefenders). Worst director update 368 ms (rivals 286), interior show-all 148 ms.
  Now: Aux.findAll caches a class's FindAllOf for 3 s per world, used by Aux.scan and (as X.findAll) seedSpots; and
  placedDefenders takes the NodeBots spawn hook's list when it's on ("6 ... from the spawn hook"; the cross-check log
  had shown 6 = 6), FindAllOf only as the fallback. After: 4 scans (~195 ms), worst update 255 ms (rivals 177); same 6
  adopted, same 108 spread candidates, same marker counts. Left: the interior show-all (148-160 ms, I.frame shows
  every part at once by design: the airlock transfer covers it); when it lands in the same frame as the garrison update
  the frame is ~460 ms. Spreading the show over frames would trade that for a visible pop-in after a transfer.

## Fight hitches and garbage: stray sweep, turret swing hook, per-frame aim (2026-11-14; tested 2026-11-16)
Space_Solo_02 at Penal Colony and Moon Base, 17-21 bots. profile.txt showed a ~50 ms FindAllOf every stray sweep (a
steady hitch every few seconds). The Lua collector was stepping 0.5-2.4 s per 10 s, fed by the aim section (~31-34 MB per
10 s, 1.2-1.3 s of Lua) and by hook garbage between ticks (54-75 MB per 10 s, with ~50k turret swing hook calls).
- rivals.lua: placed NPCs come from a NotifyOnNewObject hook on /Script/RaidGame.RaidNodeBot (NodeBots, hookedPlaced).
  The stray sweep no longer calls FindAllOf; without the hook it falls back to the old one-class-per-sweep scan. The
  garrison sweep keeps its FindAllOf and logs "spawn hook knows N live placed NPC(s) in the box, FindAllOf found M
  unmanaged" as a cross-check.
- rivals.lua: the turret CameraRotation hooks come off after SWING_UNHOOK_AFTER (5) s with no turret aimed
  (swingHooksIdle, "turret swing hook(s) off"); aimTurret registers them again.
- main.lua: animate() and the aim upkeep (targeting pose, focus) run ANIM_HZ (30) times a second per bot instead of
  every frame; a change in what the bot should do applies at once. Hide/peek timing is still checked every frame.

- Tested (Space_Alpha raid, Rebel Base, god mode, 2 min fight with its guards, 2026-11-16, profile_on, 10 bots): frame gaps over 100 ms 0 in every 10 s window during the fight, worst 27-35 ms.
  GC stepping 56-82 ms per 10 s (was 0.5-2.4 s). Hook garbage 0.5 MB per 10 s (was 54-75 MB). Placed NPCs came from
  the spawn hook ("8 placed NPC(s) to adopt (from the spawn hook)"). Turret swing hook calls still ran at ~400 a
  second (was ~5000) with your own ship's turrets in the world.

## Mouse stutter in the menu, loadout and market (2026-11-17, tested; main.lua lobby tick, patchFriendsRefresh)
- bridge/profile.txt in the lobby: every 10 s window had exactly 10 frame gaps of 150 to 180 ms, one a second, while the
  frame rate between them was 120+. Raids had none. patchFriendsRefresh (the PGOS overlay's 1 s friends timer walking the
  Steam friends list, ~70 ms and up) was only applied from updateSpace, i.e. inside raids.
- Now the lobby tick applies it too, every 5 s while there is no raid (the stub is idempotent: the DLL checks the
  bytes), and logs "lobby: friends refresh stubbed" once. The overlay appears a few seconds after the menu, so the
  first seconds can still hitch.
- Tested by the reporter in the menu, loadout and market: no stutter.

## Menu hitches after a raid and on the title screen (2026-11-17; main.lua lobby tick and menu helper, mappick.lua, lobbylabel.lua)
- After a raid the menu hitched once a second again (150 ms). mappick.lua kept the widget paths of the old lobby
  (the START RAID label boxes, the map picker buttons) and looked each one up every check: a StaticFindObject of a path
  that no longer exists walks every object, ~15 ms apiece, ~10 paths. The list was not empty, so the new lobby's own
  widgets were never looked for either. Now lobbylabel.lua resets mappick's lists while a raid is on, and mappick's checks
  drop any path that has gone.
- The friends refresh stub keyed on `not raid.world`, which is only true until update() first runs in the menu; after a
  raid it never ran again. It now keys on the world: PveTickMenu is set once per world (its name has /Maps/MainMenu) and
  the stub is repeated every 5 s there, logged once per world, with a line if the function is not found.
- The title screen stuttered while the mouse moved: the voice lines (3 a frame) and other menu loads are 15 to 50 ms
  hitches. Voice.step now runs one a frame, and for the first 25 s of the menu only while the mouse is still for half a
  second (PveMenuBusy, APlayerController:GetMousePosition gives its numbers as out parameters that don't come back to Lua
  here, so it reads WidgetLayoutLibrary:GetMousePositionOnViewport, 5 microseconds). If the position can't be read nothing
  is held back, and a line says so. A raid started inside the 25 s still gets its voices.
- Log lines: "menu: mouse position read (x, y); ..." once per game start, "lobby: friends refresh stubbed" once per
  world.
- Checked: the title screen stutter was gone about 25 s in, when the startup loads finish. Not yet confirmed in game:
  the post raid hitch with the new mappick lists, and the mouse gating on the title screen.

## Airlock crash in UE4SS: IsValid() on a freed object (issue 53, build 6; pvepatch.c pve_alive, main.lua valid)
- Report (Taki, 17 Nov, public-test-20261117.6, Space_Beta): crash 1 s after `level effects: Asteriod_Mine_Large_01`, on
  going into the mine. `EXCEPTION_ACCESS_VIOLATION reading 0x1abccabc04c` in UE4SS: `+4baaaf` <- `+3b23fc` <- Lua
  (`+87a0d4`) <- lua_pcall <- UE4SS's ProcessEvent hook (`+555046`) under `RaidGame+1c3574e`, i.e. the director's tick.
  This is the first signature in #53; build 4's fix (#114) was the other one (Slate paint, `RaidGame+2bc825b`).
- UE4SS.dll disassembled: `+3b23c0` is a UObject method that takes the wrapper's pointer (`[ud+0x70]`), calls `+4baa20`
  (reads an int at a lazily resolved member offset from the object: InternalIndex) and looks it up in the object array:
  IsValid. So `o:IsValid()` dereferences the object; once the game has freed it and the allocator has given the page back
  (a station's contents streaming out), the check itself faults, and pcall can't catch an access violation.
- Fix: `pve_alive(address)` (pvepatch.c) reads InternalIndex only after VirtualQuery says the page is committed and
  readable, then checks the GUObjectArray item holds that pointer (+0, 24-byte items, NumElements at Objects+0x14) and
  isn't PendingKill (1<<29) or Unreachable (1<<28). It returns its result by pushing an integer onto the Lua stack (the
  first export that returns a value: pushInt). main.lua's valid() calls it before IsValid(); every module's X.valid is
  that. rivals.lua's `p.ship:IsValid()` (a kept reference) now goes through valid().
- Checked in game (menu): live controller 1, spawned actor 1, destroyed 0, after `obj gc` 0; Taki's fault address, 0,
  odd and pc+8 all 0 without a crash. 0.30 us per call, same as IsValid().
- Not covered: a direct `:IsValid()` or any other method on a kept reference elsewhere (shipnav/cover/killstats ones are
  CDOs or fresh reads). Not reproduced in a raid yet.

## Crash on leaving a raid: the lobby world leaked through a rooted portrait (issue 133, builds 6-7; crewlobby.lua photoStep)
- Reports (17 Nov, builds .6 and .7): pod extraction (Space_Delta), death (Space_Solo_01), Esc → quit to main menu
  (Space_Beta). All three have the same `PCallStackHash` 7952771C…, null read at 0x268 on the game thread.
- Static disassembly of the exe: `+30bca7b` is in UGameInstance::CreateGameModeForURL (references "GAME=",
  "LoadForAllGameModes"), reading `[WorldSettings + 0x268]` (DefaultGameMode) right after `World->GetWorldSettings(false,
  true)` (`+3502970`) returned null. The callers are UWorld::SetGameMode (`+350f8e0`, calling the game instance's virtual
  at +0x338) and UEngine::LoadMap. The UE4SS frame (`+554abd`) is UE4SS's LoadMap hook passing the call through: no Lua
  on the stack.
- Why WorldSettings was null: the main menu world loaded was the old one. d9a3ec1 rooted the crew portraits' render
  targets, made with `CreateRenderTarget2D(B.stand, …)`. That function makes its world context object the new object's
  outer, and a rooted object keeps its outer alive, so the photo stand, its level and the whole lobby world outlived the
  raid. Tearing a world down marks its actors for kill and the GC nulls UPROPERTY references to them (ULevel's
  WorldSettings among them). LoadMap then found the leaked package, and the shipping build has no stale-world check.
- Fix: the portraits are made inside the game instance (it lives for the session). Rule for anything passed to
  pve_root: its outer chain must not reach a world (assets, transient textures from ImportFileAsTexture2D and objects
  made inside the game instance are fine).
- Not checked in game yet.
