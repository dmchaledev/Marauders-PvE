# Your crew

Hired AI teammates: hiring, the lobby, following you, gunnery, price and levels.

Part of the project's research log: [NOTES.md](../../NOTES.md) lists every topic file and every section title.
Sections are in the order they were written; a later section can correct an earlier one, so read to the end of a topic
before trusting a finding. When a section says "see X", search [NOTES.md](../../NOTES.md) for that title to find which
file it is in.

## Contents

- [Your crew: AI teammates (2026-11-07, night; mods/PvEDirector/Scripts/crew.lua)](#your-crew-ai-teammates-2026-11-07-night-modspvedirectorscriptscrewlua)
- [Hiring your crew, nametags (2026-11-07, late night; hire.lua, crew.lua)](#hiring-your-crew-nametags-2026-11-07-late-night-hirelua-crewlua)
- [Lobby crew hooks found (2026-11-07, 23:18; bridge/t_lobbychars.lua)](#lobby-crew-hooks-found-2026-11-07-2318-bridget_lobbycharslua)
- [Crew in the lobby: stands, slots, portraits, hiring page (2026-11-08, ~00:00; crewlobby.lua, hire.lua menu)](#crew-in-the-lobby-stands-slots-portraits-hiring-page-2026-11-08-0000-crewlobbylua-hirelua-menu)
- [Crew missing, boarding misses, wall spawn, stutter (2026-11-13; user report after the 11-09 runs)](#crew-missing-boarding-misses-wall-spawn-stutter-2026-11-13-user-report-after-the-11-09-runs)
- [Target switching, crew left behind at airlocks, stutter check (2026-11-13, evening; user report after a Navy Outpost raid)](#target-switching-crew-left-behind-at-airlocks-stutter-check-2026-11-13-evening-user-report-after-a-navy-outpost-raid)
- [Kill list, airlock crew, interiors from space, proportions (2026-11-13, ~20:30-20:55; user report)](#kill-list-airlock-crew-interiors-from-space-proportions-2026-11-13-2030-2055-user-report)
- [Crew worth their price (2026-11-13; hire.lua H.profile/H.maxHp, crew.lua, tuning.lua)](#crew-worth-their-price-2026-11-13-hirelua-hprofilehmaxhp-crewlua-tuninglua)
- [Crew gunner never shot stationary turrets (2026-11-16, tested; rivals.lua nodeTurretAlive)](#crew-gunner-never-shot-stationary-turrets-2026-11-16-tested-rivalslua-nodeturretalive)
- [Crew gunner reach, swing and click (issue 88; rivals.lua GUNNER_*, crew.lua ORDER_CONE)](#crew-gunner-reach-swing-and-click-issue-88-rivalslua-gunner_-crewlua-order_cone)

## Your crew: AI teammates (2026-11-07, night; mods/PvEDirector/Scripts/crew.lua)
Co-op joining is blocked (see above), so teammates are AI stand-ins.
- Roster (CFG.SIZE, default 2, F3 menu tab "Your crew", 0-3): rival-style people (rivals.newMember) kept for the game session.
  Same names every raid, kit re-rolled each raid. The dead are replaced by new recruits at the next raid.
- Bodies: rivals.startBody/finishBody, then TeamNumber = PLAYER_TEAM (3) and faction "player", so neither side can hurt the
  other, and every other faction fights them. e.rival is cleared, so they never count as rival kills. e.follow replaces patrol/investigate in
  main.lua updateBots; e.followRun makes animate() sprint. Spawn SPAWN_DELAY s after you're on foot somewhere with
  navmesh (space: playerPlace ~= nil; land raids always); farther than REJOIN (5000: you docked/breached) -> teleported
  near you; fights farther than LEASH from you are dropped. defend(): every 0.5 s a crewmate not fighting goes for the
  nearest bot whose foe is you (boarders only ever target you). gearCatalog works without rivals' S (land raids).
- Gunner (first crewmate, CFG.GUNNER): while you fly (pc.Pawn == your hull) there's no body. Crew.frame (per frame) fires
  your hull's own turrets (rivals.shipTurrets = SpawnedTurretArray, non-camera) through fireTurrets at rivals.hostileShips():
  crews attacking you, or the ship you just fired at (inYourSights). Reaction GUN_REACT, spread x GUN_SPREAD (rolled once per gunner). Counts as you firing (playerFired).
- Verified 22:28 (bridge/cr_test.sh): 2 crewmates spawned aboard 3 s after the raid started, following. At the helm: "Teague mans 1 turret(s)",
  "engaging the Long Odds", turret shots. First run: Fennec ignored 2 boarders for 30 s+ (follow dropped the heard noise) -> defend() added.
- Second run: defend() fired, but the crewmate sat at TeamNumber 2. updateBots' re-arm calls arm(), which sets BOT_TEAM.
  It now keeps the team of any entry with a faction, which fixes rival bodies too. crew.lua also re-asserts the team every update
  and logs it. A crewmate fighting out of sight gets e.lastSeen refreshed from the foe every 2 s (combatHints closes in on it).
- Third run (22:41): crewmate on team 3 took a boarder 160 -> 33 hp in 40 s. Crew names are now their own list (a crewmate
  and a boarder were both "Grub"); that change has only been syntax-checked.
- Not yet seen: crewmates on screen, land raids, docking at a station with them, a crewmate's death, a real F at the helm
  (bridge t_helmown's second call doesn't take you out of the helm).

- Pod breach (2026-11-08): your crew comes through your hole with you. rivals.lua breachInto records S.breach (R.lastBreach:
  spot, time, ship, breachSpots of the interior) and now picks the first breach point with navmesh around it. crew.lua keys on
  that breach (not on "you were nowhere": a short pod flight can start and end between two crew updates, and then they stayed
  on your ship): bodies removed and rebuilt on the floor where you landed (breach points sit ~5 m up the hull wall; the
  navmesh nearest the hole itself was the deck above yours), first 1.5 s after you, the rest 1.2 s apart, "Your crew follows
  you into the X". Old catch-up teleport needed navmesh around you and left them 458 m away on your ship at a Capital interior.
- Verified (bridge/bp_test.sh <screens> [design]; t_bpod flies a pod in from 60 m with your body parked at 0,0,0, t_podin
  brings it to the hull, t_crewpos/t_breachpts/t_navship probe): Black Tallow, Nell and Hollis 2-3 m from you on your floor
  4 s after the breach, then both went for the defender fighting you. Facing into the ship on screen. Not seen: a real F
  pod launch, a Capital interior with the fix (prep picked scouts). Test launches pay wages: the stand-in keeps state in
  memory, so restore state.json/crew.lua with it stopped.

- You and your crew walk through each other (2026-11-16, issue #62): passThrough() in crew.lua, called when a body
  is finished, sets PrimitiveComponent:IgnoreActorWhenMoving both ways (crewmate capsule ignores your on-foot pawn,
  your capsule ignores the crewmate). Enemies still collide with both; shots are separate traces. Tested on
  Space_Solo_01 aboard the ship with bridge/t_walk.lua (sweep the player 300 units forward, Noor placed 150 ahead):
  Noor out of the way 197 (a wall), ignore turned off 62 (stopped at Noor), with the fix 197 (through Noor to the
  wall).
- e.stuckAt meant two things (2026-11-16): crew.lua kept the crewmate's stuck position in it (cutOff), main.lua's
  cover code the time a soldier's move stalled. A crewmate in a cover fight made main.lua:1480 do arithmetic on a
  position: "update failed: main.lua:1479: attempt to perform arithmetic on a table value (field 'stuckAt')", which
  ended that whole update() pass (seen 3 times in a player's log, 16 Nov, Space_Beta). crew.lua's is e.stuckPos now.

## Hiring your crew, nametags (2026-11-07, late night; hire.lua, crew.lua)
Replaces the free random crew above: crewmates are now hired, persistent and optional.
- hire.lua: pool of 8 recruits, each a set person: name (by sex), voice set (voicelines key), head + body mesh paths (gear.lua),
  personality, level 1-5, lifelong aimRoll and turret spread. Saved in backend/crew.lua (`return {...}`, delete for a fresh pool;
  one file for every save slot). Crew max 3. Hire fee 1000/2500/5000/9000/15000 and wage 300/600/1000/1600/2500 a raid by
  level, both through the controller's own GetCash/TakeCash (the game then PUTs playerstats/cash itself: verified in
  server.log). Wages are paid in launchMatch; a crewmate you can't pay stays home. Each launch records D.raid = paid ids. Back in the lobby
  (Hire.lobby, every MainMenu update) they get +1 raid (promotion at 3/7/12/20), and 2 pool recruits are swapped for new ones.
  Death in a raid (crew.lua bodyOf) -> Hire.died: removed for good, kept in D.fallen. A raid killed by quitting still counts as survived.
- Level = AI profile between ai.lua's soldier (1) and rival (4), extrapolated at 5 (miss 0.6 -> 0.35 -> 0.27), kit tier
  budget/mid/geared, +10 hp a level. Set as e.mind.profile after rivals.finishBody (which now takes m.headPath/bodyPath).
- Optional: no hires = no crew; "Crew comes on raids" ON/OFF; per crewmate Comes along / Stays home; pick the gunner.
- F6 menu (lobby and raid; changes only in the lobby). The lobby's director tick runs on the MM_CoreMissions widget: the
  controller comes from GameplayStatics.GetPlayerController (GetCash on the widget failed; the menu couldn't be created).
  A raid's controller reads 0 cash. The PGOS overlay covers viewport widgets even at Z 5000: opening the menu hides it.
  bridge/crew_cmd takes "menu", "list", "hire N|name", "dismiss", "bring", "gunner", "toggle".
- Nametags (crew.lua C.tags, every raid frame): TextBlock + health bar per crewmate in a DebugInfo_Widget host at Z -2,
  placed by WidgetLayoutLibrary.ProjectWorldLocationToWidgetPosition, fading past 15 m, hidden past 60 m.
  TextBlock:SetColorAndOpacity({SpecifiedColor=...}) left the text dark; writing ColorAndOpacity.SpecifiedColor fields works.
- Verified (bridge/hr_test.sh, 23:01-23:05): hired 2 then 1 (4th refused: full), cash 19591 -> 14491 written to the backend,
  wages paid, the saved crew came back after a game restart with their raid counted, 3 crewmates in the raid, green nametags
  on screen; lobby menu above the PGOS overlay (23:10). Test save restored and backend/crew.lua deleted afterwards. Not yet seen: a promotion or a death in game (simulated offline with lupa: scratchpad hire_sim.lua), clicking
  the menu's buttons with the real mouse.

## Lobby crew hooks found (2026-11-07, 23:18; bridge/t_lobbychars.lua)
- The hangar has 4 character stands, MM_PlayerChar_C: id 0 = you (isPlayer, at -328,-118,-13) and ids 1-3 inactive beside
  you (-438,-274 / -216,-399 / -172,-248). They're the live crew's stands: full rigs (SkelMesh_Head/Body/BodyArmour/Helmet/Bag,
  weapons + attachments), GetSetPlayerItem(mesh comp, item row, ...), `members` TArray<FPlayerInfo>.
- 5 MM_GuildChar_C elsewhere (-2900,-500,-397: the guild hall).
- Crew slot widgets Crew_member_MM_Widget_C Slot01-04 (two sets): Img_CrewMembAvatar, Txt_CrewMembName, Btn_InviteToCrew (the "+"),
  Btn_ViewProfile, isSlotFull; Update_CrewSlot/Clear_CrewSlot take FPlayerInfo/FClientPartyInfo structs (not tried).
- CRASH: the first probe called GetVisibility on every Crew_member_MM_Widget_C FindAllOf returned, the class default object
  included -> game crashed (UE4CC report). Skip Default__ objects; read properties only.

## Crew in the lobby: stands, slots, portraits, hiring page (2026-11-08, ~00:00; crewlobby.lua, hire.lua menu)
- Hired crew stand on the hangar's crew stands (MM_PlayerChar_C CharID 1-3) in their own look and kit; the crew slots
  (Crew_member_MM_Widget_C Slot02-04 under /Engine/Transient) show "Name  Lv N" and a portrait; "+" opens HIRE, a filled slot
  opens YOUR CREW. The hiring page is a left panel in lobby colours with the lobby's font (copied from a slot's TextBlock);
  clicking a recruit row puts them on a free stand, right-hand first. F6 still opens it.
- Each recruit has a fixed kit (hire.lua giveKit: rivals.rollKit on their level's tier, re-rolled on promotion); crew.lua uses
  the same kit in raids (fresh ammo/meds). Not yet run in a raid since this change.
- Dressing: head/body by mesh path; helmet/armour/bag/gun rows -> meshes learned once from a hidden donor raider dressed by
  pve_roll_kit, saved in config/crew_meshes.lua. Refresh_PlayerLookActor/GetSetPlayerItem can't be called with a look from Lua
  (struct with FStrings fails; names-only "succeeds" and does nothing). Cached paths can have odd object names
  (M1_Helmet_Skel_01.M1_Helmet_Skel_01_M1_Helmet_Skel_01); LoadAsset of that full path works.
- FREEZE (fixed): K2_DestroyActor on a donor raider (SpawnActor'd, no controller) hangs the game thread forever (found by a
  flushed per-call trace: capture/crewlobby_trace.txt). Donors are now hidden and kept, never destroyed. An earlier hang
  before Play was my own bridge probe (t_ufuncs.lua StaticFindObject on 24 paths while assets were loading).
- The lobby's own crew refresh after Play hides the stands, empties their gear slots and puts "+" back: crewlobby re-checks
  every 0.5 s (hidden, wearing() per part, slot border visible) and re-dresses.
- Portraits: photo booth = our own MM_PlayerChar_C 3000 under the floor, two point lights, SceneCapture2D with
  PrimitiveRenderMode show-only (ShowOnlyActorComponents) and fixed exposure, 256px RGBA8 render targets (FinalColorLDR);
  the face is on the stand's RIGHT side (mesh +Y; -forward gave profiles), camera aimed along the head bone's +Y. All 8 recruits + crew filled within ~30 s on a fresh lobby.
- Kill switch: config/crewlobby_off containing "all" (or "stands"/"slots") turns the lobby part off, read every 2 s.
- Tests: bridge/lb_test.sh (hire two, preview, tabs), lb2_test.sh (saved crew after restart).
- Slot clicks (2026-11-08): the user's real "+" clicks didn't open HIRE: polling Btn_InviteToCrew:IsPressed misses quick clicks and
  only watches the slot set findSlots kept (there are two). crewlobby now hooks the slot's own events
  (Btn_InviteToCrew ..._4_OnButtonPressedEvent, Btn_ShowHideOptions ..._6_OnButtonClickedEvent) and maps the widget's name
  (Crew_member_Slot0N) to the slot; polling stays as a fallback.
  The lobby only SHOWS Slot01-03 (Slot04 is collapsed, vis=1), and the "+" you see first is Slot01: the crew used Slot02-04, so
  the visible "+" was never watched and a 3rd crewmate landed in the hidden slot. Crew now fills Slot01-03.
  Verified by the user clicking "+" in game (2026-11-08): HIRE opens. Their first launch-offline run that night came up
  without UE4SS (stock folder, "+" opened the real social menu); the second launch was fine. Cause not looked into.

## Crew missing, boarding misses, wall spawn, stutter (2026-11-13; user report after the 11-09 runs)
- Crew "never showed up": not a bug in spawning. Save had $166, wages were 1000 + 600: payWages left both at home, and its
  ClientMessage went to the lobby controller a moment before travel, so nobody ever saw it. Now hire.lua keeps the unpaid
  list (H.unpaidNote) and crew.lua says it 6 s into the raid: "Nell and Hollis stayed home: wages of $1,600 unpaid (you
  have $166)". Seen in the log of both test raids. The rule itself (no pay, no crew) is unchanged.
- Boarding misses (11-09 log: three interiors loaded during one pod flight, then "That hull had no way in"):
  playerBoarding ran every 0.5 s from update and gave EVERY ship within 150 m an interior, up to PLAYER_BOARD_MAX 4 a
  raid; after that nothing was boardable, and a pod could reach a hull between two looks or before its interior was in,
  so the game's own impact left you at 0,0,0. Now: per frame (R.frame) while pc.Pawn.bADropPod; only the ship the pod flies
  at (PLAYER_BOARD_AIM 25 deg within PLAYER_BOARD_PREP 16000, or anything within PLAYER_BOARD_CLOSE 4000), one interior
  loading at a time, max 6; free interior slots listed once a raid. The pod's last nearest hull is remembered (S.podShip):
  if you end up in the void within VOID_BOARD_RECENT of that, rescueFromVoid boards THAT ship (loading its interior if
  needed, VOID_BOARD_WAIT 12 s) instead of sending you home.
- Wall spawn: breachInto put you AT the breach transform, which is in the hull wall ~5 m up. Now breachLanding: navmesh
  floor by a breach point that joins up with the inside (joined), else floor at the dock starts; with no navmesh yet and
  the pod at the hull (PLAYER_BOARD_FORCE 250) or from the void after 2 s, the ShipDockOnePlayerStart spot. The home rescue
  uses the same landing.
- Verified (bridge/bx_test.sh <screens>, t_voidhit.lua, t_onfloor.lua; t_podto now keeps its hull in _G.POD_HULL): pod
  stepped at a hull -> boarded the Crow's Due (Capital interior), standing on floor in a room, walking mode; void after an
  "impact" 2500 from the Widowmaker -> out inside it 6 s later, on navmesh, in front of the cockpit door. BOTH came in at
  the dock start ("navmesh isn't ready"): the breach fires the moment the interior is paired, before its navmesh builds, so
  the breach-point floor path (breachLanding's first branch) has NOT been seen in game. Not seen: a real F pod flight.
- Stutter: not the director (ticks over 25 ms: 0-4 per 10 s, none at rest) while frame gaps over 200 ms came 8-19 times
  per 10 s. Measured during the test: 31.6 GB RAM, 0.48 GB free, commit 57.1 of 58.2 GB, 100-1900 pages/s; the game had
  15 GB private but 7.8 GB resident, WoW 12.7 GB private. The machine was paging. Likely what "most runs, not all" was
  (WoW open or not); NOT confirmed on the user's own runs. Small director costs removed anyway: addInteriorNav's two
  scans (~90 ms per interior) are cached per raid. bridge/profile_on + profile.txt is the way to check a real run.
- release/ rebuilt with these changes: MaraudersOffline-20261113.zip (322 files, 88 MB; the 20261108 zip is still beside it). Save restored from backend/state.before-board-fix-test.json after the tests.

## Target switching, crew left behind at airlocks, stutter check (2026-11-13, evening; user report after a Navy Outpost raid)
- Ignoring the enemy beside you: main.lua updateBots only perceived while NOT fighting, so a bot locked on a far foe never
  looked again (a crewmate and a soldier side by side, each shooting someone across the room). Now, while fighting, every
  RETARGET_EVERY 1 s a bot switches to a hostile within RETARGET_NEAR 15 m and under RETARGET_RATIO 0.5 x the current
  foe's distance that is in its line of sight or fighting it ("X turns on Y at 6 m (was fighting someone 16 m off)").
  Applies to everyone (soldiers, rivals, your crew). Seen in game: a soldier turned on Sputnik at 6 m from a foe 16 m off.
- Crew stuck behind airlock doors: airlock chambers are off the navmesh, so a follower can't path through one at all;
  the old catch-up only fired past REJOIN 50 m. crew.lua cutOff: a follower more than STUCK_SLACK 4 m past their follow
  distance who hasn't moved STUCK_MOVE 1.5 m for STUCK_SECONDS 4 s is brought to you out of your sight (or after
  STUCK_SEEN_SECONDS 12 s regardless). Both catch-ups wait while YOU stand in a chamber (rivals.lua R.inAirlock, the
  chamber box turned by its yaw; lock entries now keep box), because the floor nearest you could be either side of the
  doors. Verified (bridge/st_test2.sh + t_crewto.lua + t_meaway.lua): crewmate put in Navy Outpost's chamber, you 26 m
  away -> "Tova was left behind 28 m back (4 s without getting anywhere): catching up", 4 m from you after. Not seen: a
  real docking cycle with the crew (expect them to appear behind you a few seconds after you step out).
- Stutter: bridge/st_test.sh (profiler on). Director stays small in a raid (a few ticks over 10 ms per 10 s, no object
  scans after the load), but the run is NOT a clean measurement: WoW was started mid-test (17:35, foreground, ~85% GPU)
  and fps fell to 4-10. The user's own raid (17:24-17:31) had Roblox started at 17:27 and 14 GB free RAM (no paging this
  time). Lobby: PgosOverlay_BP_C + MM_PlayerChar_C FindAllOf ~20 ms each, 6-8 per 10 s (lobby only). Next: a profiled
  raid with no other game open, or have the user turn on bridge/profile_on for one of their own raids.
- Save restored from backend/state.before-stutter-test.json / crew.before-stutter-test.lua (test hires Vera and Tova
  died/were hired only in the tests). Game folder left online.
- Stutter, second look (same evening; user: it happens with no other game open, Navy Outpost was a station both times,
  worst while flying). bridge/st_test3.sh (aboard 30 s, helm 60 s, then a station). WoW still open, so most windows ran
  at 5-25 fps; the one window the game had the machine (17:51:05, 89 fps, at the helm with the gunner firing) had NO
  gaps over 100 ms (worst 64) and the director never over 10 ms (rivals.frame ~0.8 ms/frame with the gunner).
  The profiler now also writes: Lua heap range and garbage collections, per-section ms + max (aim, minimap,
  rivalsFrame, gunseat, crewFrame, tags, update, rivalsUpdate), the turret swing hook's call count, the time of each
  gap over 100 ms within the window, and where you were (pawn class = on foot / flying, rivals.where, nearest station
  + distance, fps). Seen: swing hook ~45 calls a frame (every turret of the 7 hooked AnimBP classes in the world calls
  CameraRotation each frame; only AIMED ones do work), Lua heap 90-200 MB with a collection every ~20-30 s. Neither
  showed as a hitch in the clean window. bridge/profile_on left ON for the user's next raid (profile.txt);
  the test run's output is in bridge/profile.test-17-51.txt.
- crew.lua cutOff: only for followers within REJOIN, logs "caught up" only when rejoin found a spot (it spammed the
  line with you at 0,0,0 after a test teleport), and waits the full STUCK time again after a failed try.
- Stutter, third look (same evening, "keep testing"; stopped by the user, who will report when they see it again).
  WoW held ~90% of the GPU through every run, so frame numbers are not usable. Found:
  - Game-thread sampling (tools/profile/threadsample.py, now also prints "active" samples and UE4SS hot spots;
    tools/profile/threadcpu.py = per-thread CPU over a window): under WoW the game thread waits ~85% of the time.
    Of its active samples, UE4SS is on the stack in ~40-45%, with or without the turret swing hook
    (bridge/no_swing_hook skips registering it, test only): the hook is not what costs.
  - Flying with no station visited there was only 1 bot (garrisons spawn when you walk in), so the
    distant-bot animation idea was not testable: wake() sets every bot AlwaysTickPose + URO off. main.lua
    animDistance puts bots past ANIM_FAR 60 m from the camera back on OnlyTickMontagesWhenNotRendered + URO; it is
    OFF unless bridge/anim_far_on exists (not tested with a garrison alive).
  - Test hooks added: bridge/autofly ("<station name>" or "x y z": flies your hull there by AddMovementInput, every
    frame, facing it; untested: both runs' maps had no Navy Outpost in the survey); bridge/map_pin pins the map.
    Space_Solo_01 surveyed only Merchant x2 + Spaceport in one run; Navy Outpost was found in an earlier random map.
  - profile.txt now lists wakes, animSwitch, bots count. bridge/profile_on is ON for the user's next raids.

## Kill list, airlock crew, interiors from space, proportions (2026-11-13, ~20:30-20:55; user report)
- Kill list: the end screen lists your kills from PlayerState.InMatchStats ({StatName, StatAmmount}, +0x410), named by
  BFL_UI_Functionality:Translate_K_ForKillList (kdis): K_AIRaider Raider, K_AICommando Commando, K_AISAS SAS Operative,
  K_AISASCaptain, K_AICommandoMajor, K_AISecurity, K_AIPrisoner, K_AIMiner, K_AIBaron "Red Baron", K_AIMarine, K_AIWarden,
  K_AIRaiderBoss, K_AIBandit, K_AISASMajor, K_AIUACommander; K_Human = "Marauder", the only isPlayerKill (counts for
  AddKillToLeaderBoard). Rivals wear soldier bodies, so they were filed as guards. New killstats.lua: rivals.lua calls
  rivalDied() at a rival's death, update() (end of R.update) moves each new K_* addition to K_Human (pending 3 s; a
  rival killed by your crew files nothing and expires). UE4SS can rename/recount an element but not append (arr[n+1]
  and whole-array assignment both fail): pvepatch `pve_array_grow(TArray addr, elem size)` adds a zeroed element in the
  spare room (Num < Max; first allocation is Max 4), never reallocates. Verified: rename path, increment path, grow path
  (K_AISAS=2, K_AIRaider=1, K_Human=1), and the end screen showed "#4 Marauder". Calling Translate_K_ForKillList from
  the bridge at the splash crashed the game (out params of a BP library function): read bytecode with kdis instead.
- Crew vanishing in the airlock transfer: crew.lua put bodies away whenever rivals.where() was nil, and a station's
  airlock chamber can lie outside its navmesh box (+MATERIALIZE_MARGIN), so mid-transfer they were removed and rebuilt
  3+ s later somewhere near you. Now: playerPlace counts a station's chamber as that station; crew keep their bodies for
  TRANSIT_GRACE 15 s while "nowhere" on foot; standing in a station chamber with a follower > LOCK_BRING 15 m off (still
  aboard), they're put in the chamber behind you (ship side, clamped to the turned box) and walk out with you; arriving
  back aboard your ship, anyone > 15 m off rejoins at once. NOT tested in game (needs hired crew + a real docking cycle).
- Floating geometry: hiding the black shells (2026-11-06) left the interiors themselves exposed. Each interior has a few
  hundred meshes that never cull (CachedMaxDrawDistance 0) and up to ~9000 drawn past 100 m (rest cull at <= 100 m).
  New interiors.lua replaces main.lua's levelShells: per LevelStreamingVolume, shell cubes + the interior level's
  visible meshes with draw distance 0 or > 10000 (not the space map's own level). Camera inside (+1500): all shown at
  once (~67 ms for Navy Outpost's 8.6k, covered by the transfer); outside: hidden 1000 per frame. Space_Solo_01: 53
  shell pieces + 21302 meshes. Verified: from 300 m off Navy Outpost and Fortress only asteroids; camera inside Navy
  28203 visible, back out 20077. Not looked at: the interior by eye right after an airlock transfer.
- Female proportions (user): bust 8.3 -> 7.5, waist width 0.91/0.925 -> 0.93/0.94, depth 0.885/0.915 -> 0.905/0.93,
  seat 3.8 -> 4.5. 113 meshes rebuilt. Not looked at in game.
- native/pvepatch.dll rebuilt (old one: pvepatch.before-kills.dll). Save restored from state.before-kills-test.json; the
  test stand-in stopped; folder left online.

## Crew worth their price (2026-11-13; hire.lua H.profile/H.maxHp, crew.lua, tuning.lua)
- User: even the lowest-level crewmate should fight quite a bit better than enemy AI and have a good deal more health.
  Before: level 1 = the station soldier profile (the weakest enemy), level 4 = rival, 100 + 10 hp a level.
- Now H.profile(level) starts from the LIVE rival profile (difficulty preset and tuning included, so crew stay ahead on
  Very Hard too) and applies hire CFG.EDGE, level 1 -> level 5: miss x0.65 -> x0.4, reaction x0.65 -> x0.35, spot time
  x0.75 -> x0.45, hearing error x0.75 -> x0.45, sight x1.1 -> x1.3, hearing x1.15 -> x1.4, field of view +5 -> +15 deg,
  strafe >= 0.95. Health H.maxHp = BASE_HP 200 + HP_PER_LEVEL 25 a level (300 at 5); rivals/soldiers 100.
- Normal difficulty, offline (lupa): rival miss 0.35, reaction 0.15-0.35; crew L1 miss 0.23, reaction 0.10-0.23, 200 hp;
  L5 miss 0.14, reaction 0.05-0.12, 300 hp. The profile is taken when the body spawns (a preset change mid-raid applies
  to the next body). F3 "Your crew" tab: health at level 1 / per level, and aim/reaction/spotting edge at levels 1 and 5.
- Not yet seen in game: whether Health above 100 survives the game's own healing/med use on a bot (an earlier run showed
  a crewmate at 160 hp, so values over 100 do stick).

## Crew gunner never shot stationary turrets (2026-11-16, tested; rivals.lua nodeTurretAlive)
Issue #40. nodeTurretAlive tested `t.bIsDying == 0`, but UE4SS returns bIsDying as a Lua boolean, and `false == 0` is
false. So every RaidSubNodeActor_Turret counted as dead: hostileShips never listed the ones aiming at you, and
pickShip (left-click orders) never offered them. It now treats only `true` or a non-zero number as dying.
- Before (Space_Solo_01, gunner Noor level 1, hull parked 11000 and then 5000 from a flak node that was aiming at the
  hull, CurrentAimingActor = your ship): no "engaging" call, and the flak's health stayed at 150 while the hull went
  575 -> 495.
- After (Space_Charlie): "Noor: engaging the turret" 1 s after parking 5000 away. Four MovingFlak nodes killed the
  hull in about 18 s, and all shots were held by arc: SetControlRotation doesn't turn the hull, and the starter has
  one front turret (GUNNER_ARC 120).
- After, Space_Solo_01, hull set to face the flak 6000 away (hull health topped up each second): flak 150 -> 110 -> 22
  -> -21 (bIsDying true) within about 12 s, then "Noor: engaging the Widowmaker" (a crew attacking you), so a dying
  turret is dropped.
- Test path: hire with bridge/crew_cmd "hire 1" in the lobby, then pc:Possess(Ship_StarterFrigate01_Pawn_C) from the
  bridge; F at the helm from the bridge didn't take. Node turrets' FireDistance is 13500, beyond every hull turret's
  range (6000-9500, TURRET_TYPES), so between those distances they can hit you and you can't hit back.

## Crew gunner reach, swing and click (issue 88; rivals.lua GUNNER_*, crew.lua ORDER_CONE)
- Reports: a level 3 and a level 4 gunner "only kept shooting ahead and not turning the turret", clicking a target didn't
  make them attack it, nothing to answer a stationary turret with. Hayley: mainly radius/range.
- What limited them: each turret type's crew range (60-95 m), GUNNER_ARC 120 deg, and the barrels' pitch (-15..10 deg)
  with TURRET_PITCH_SLACK 6: a target a little above or below was held ("pitch"), one past the arc or range was "arc" /
  "range", and an ordered ship out of range just got "too far, close in".
- Shells don't run out of range: every ship turret's shell (ProjSmallShell, Proj25mm, Proj75mmShell, ProjSmallMissile,
  ProjTorpedo) has InitialLifeSpan 0 (probed from the CDOs). The turrets' own limits: yaw +-60, pitch 0..15.
- Now for your gunner only (gunnerFire passes them to fireTurrets; rival crews unchanged): GUNNER_RANGE 1.75 x the type's
  range, GUNNER_ARC 170, GUNNER_PITCH_SLACK 30 (past the barrel's tilt the shell keeps the true pitch instead of the
  barrel's). A click picks the ship nearest your view within ORDER_CONE 25 deg (was 15). Both new settings are on the
  F3 "Ship guns" tab.
- In a fight (Pavel, level 2, gunnery 0.46, Starter Frigate): "engaging the Lucky Strike" a second after it attacked,
  held only for range at first (57% of checks while it closed), then firing (reload 99% of held checks), and it was a
  wreck 38 s later. A click on a stationary turret 103 m off (well below the ship) got "ordered onto turret", but your
  hull was disabled a second later, so nothing fired (right: the gunner stands down with the hull).
- Then: GUNNER_PITCH_SLACK 30 -> 45 (a turret below you as you pass over is 40-60 deg down), and the gunner now says when
  height is what stops them ("can't get the guns on the ..., too far above or below us"); before, a pitch hold was silent.
- Not done: a second gunner (only one crewmate is the gunner; they already work every turret on the hull).
