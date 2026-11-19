# Looks, sound, menus and debug tools

Loading screens, the startup video, footsteps, outfits and voices, wording, the F9 debug menu, god mode.

Part of the project's research log: [NOTES.md](../../NOTES.md) lists every topic file and every section title.
Sections are in the order they were written; a later section can correct an earlier one, so read to the end of a topic
before trusting a finding. When a section says "see X", search [NOTES.md](../../NOTES.md) for that title to find which
file it is in.

## Contents

- [Raid loading screen (2026-11-06)](#raid-loading-screen-2026-11-06)
- [Startup video re-cut (2026-11-06)](#startup-video-re-cut-2026-11-06)
- [Startup video, second pass (2026-11-06, replaces the timing above)](#startup-video-second-pass-2026-11-06-replaces-the-timing-above)
- [Startup video, third pass (2026-11-06, replaces the loop and levels above)](#startup-video-third-pass-2026-11-06-replaces-the-loop-and-levels-above)
- [Startup video, fourth pass (2026-11-06, replaces the music levels above)](#startup-video-fourth-pass-2026-11-06-replaces-the-music-levels-above)
- [Splash screen logo and credit (2026-11-06)](#splash-screen-logo-and-credit-2026-11-06)
- [Footsteps (2026-11-06)](#footsteps-2026-11-06)
- [Female outfits, voices, off-limits zone (2026-11-07)](#female-outfits-voices-off-limits-zone-2026-11-07)
- [Women's versions of every outfit, player toggle (2026-11-07, later)](#womens-versions-of-every-outfit-player-toggle-2026-11-07-later)
- [Debug menu (F9) and spawn counts in the AI menu (2026-11-07, later)](#debug-menu-f9-and-spawn-counts-in-the-ai-menu-2026-11-07-later)
- [Seamless female body (2026-11-07, later)](#seamless-female-body-2026-11-07-later)
- [F3/F9 in the lobby, borderless fullscreen (2026-11-09)](#f3f9-in-the-lobby-borderless-fullscreen-2026-11-09)
- [Share of women (2026-11-13)](#share-of-women-2026-11-13)
- [Plain wording (2026-11-13)](#plain-wording-2026-11-13)
- [Your look and voice in raids (2026-11-16, tested; nakama_standin.py write_cosmetics, main.lua applyLoadout)](#your-look-and-voice-in-raids-2026-11-16-tested-nakama_standinpy-write_cosmetics-mainlua-applyloadout)
- [F9 gun list: the rest of the guns (2026-11-17; debuggive.lua)](#f9-gun-list-the-rest-of-the-guns-2026-11-17-debuggivelua)
- [F9 bottomless mags (2026-11-18; debuggive.lua, debugactions.lua, main.lua)](#f9-bottomless-mags-2026-11-18-debuggivelua-debugactionslua-mainlua)
- [God mode: unlimited stamina (2026-11-18; debugactions.lua holdStamina, main.lua update)](#god-mode-unlimited-stamina-2026-11-18-debugactionslua-holdstamina-mainlua-update)

## Raid loading screen (2026-11-06)
- Style from trailer/make_trailer.py: Bahnschrift, orange (255,138,36), tracked title with an orange ghost edge, rules, lower-left
  bar captions. Bahnschrift isn't in the game and Lua can't add a font, so all text is pre-rendered: trailer/make_loading.py ->
  assets/loading/ (backdrop, cap_world/match/ship/ready, travel). Runtime: KismetRenderingLibrary:ImportFileAsTexture2D(pc, path)
  + Image:SetBrushFromTexture. Re-run the script to change wording.
- loading.lua: full-screen UMG over the veil, shown from veilUntilAboard; stage and progress from what the load is really doing
  (main.lua loadProgress: streaming levels, match state, then the match clock over the 45 game second spawn wait). Fades out as
  the game fades in. Art scales to cover, so a window that isn't 16:9 crops it.
- The game's own travel screen is the AsyncLoadingScreen plugin, drawn on its own thread (Default__LoadingScreenSettings, picture
  /Game/LoadingScreens/Screen3 by soft path). Pointing Background.Images[1].AssetPathName at a runtime Transient texture works: paths
  resolve to objects in memory. Loading.arm (launchMatch only) does that, blanks LoadingText, moves the pistol away
  (TransformTranslation.X) and clears the Classic footer strip's tint; Loading.disarm restores all of it on the next world, so
  other travel (extraction, back to the menu) keeps the game's screen. Only via the lobby button: a bare `open` isn't armed.
- launchMatch waits 0.3 s before `open` so the screen draws. CRASH found by testing the real button: widgets shown in the menu die
  with that world and Loading.tick then read them on the new world's first frame (AV in UE4SS, every launch). Fix: Loading.reset right
  after `open`, and the screen stores its world's address; a tick from another world drops it untouched. Test launches through
  bridge/t_launch.lua (presses the lobby button), not `open`.
- A crash leaves the DLLs mapped briefly: launch-offline's copy can fail with "user-mapped section open"; wait and retry.

## Startup video re-cut (2026-11-06)
- The launch video is Content/Movies/LoadingScreen.mp4 (AsyncLoadingScreen StartupLoadingScreen, MoviePaths "LoadingScreen", skippable, 60.4 s).
  NOT IntroVideo01 (the menu's planet loop, played by Intro_MediaPlayer). Key art fades in 42.13-42.70 with the logo baked in.
- trailer/make_intro.py -> assets/intro/LoadingScreen.mp4: song starts at 17.13 s so its first big hit (25.27 s) lands on a hard cut at 42.4 s,
  with the trailer's flash and glitch; old logo buried by a gradient, trailer title + OFFLINE PvE on top. Same length, 1080p, H.264 Main.
  Measured: flash on 42.400, audio rise 42.40-42.45. Game reached the menu 61 s after launch, no crash. Audio by ear NOT checked.
- mode.ps1: offline copies our video in, online restores backup/LoadingScreen.mp4.original. The file contains the user's own copy of
  the song: this install only, don't share it.

## Startup video, second pass (2026-11-06, replaces the timing above)
- User wanted the song from the first frame, and the music was drowning the dialogue. The source's sound runs nearly unbroken 0-40 s and
  again 42-45 s, and the first cut faded it from 41 s (a mistake): now it's never touched; output minus source subtracts clean.
- No footage cut (17 s would lose dialogue). The song plays from t=0, its piano intro extended by one 16 s repeat: at 19.27 s it jumps
  back to 3.27 s (50 ms crossfade, 120 BPM, spectra ~0.90 alike; best of the beat-grid candidates). The band lands at 41.27, inside the
  source's near-silent gap, so the logo cut moved up to HIT 41.26 (the key art used to fade in at 42.13).
- Music level (only the song moves): -18 dB through the cinematic, -8 dB at the hit, -23 dB at 42-45 s, -11 dB over the studio logos.
  No scipy/whisper here: speech wasn't transcribed, only mapped by level and syllable-rate modulation.

## Startup video, third pass (2026-11-06, replaces the loop and levels above)
- Loop: phrase 9.64 s + 7.99 s, played 3 times (joins at 17.63 and 25.62 in the output), 350 ms equal-power crossfade, built sample-accurate
  in make_intro.py extended_song. The band lands at 41.25. Chosen by what the join does, not by waveform match: a high
  waveform correlation (6.98 / 7.993, 0.73) scored WORSE than the old join. Score: spectral change across the join against the piano's own
  (77th percentile, old 93rd), mean spectrum 1.5 s either side (54th, old 71st), level -0.2 dB. Blocks more than ~20 ms off the 2 s grid were
  rejected: they join smoothly but the rhythm stumbles. Scratch tools (search2/refine) not kept.
- Music: -18 dB under the cinematic, -3 dB for the whole logo (to 47.9 s, then down over 0.8 s), -11 dB over the studio logos. Source untouched.

## Startup video, fourth pass (2026-11-06, replaces the music levels above)
- The source audio is just mixed low: peaks -21.6 dB, flat ceiling throughout. SOURCE_GAIN_DB = 16 brings it to about -18 RMS, peaks -5.6 dB,
  no limiting. The logo stayed at MUSIC_LOGO -3 dB (song RMS about -17); MUSIC_UNDER_SPEECH rose with the source to 0.79 so the margin holds.
  Measured total: -19/-18 through the cinematic, -15 at the logo, -20 over the studio logos, output peak -2.6 dB, nothing above 0.94.
  Source over music: +11 dB median through the cinematic (min +6), -3 dB at 42.3-45 s, +2 dB over the studio logos.

## Splash screen logo and credit (2026-11-06)
- The screen after the intro is SIGIS_LoginWidget (live instance under "Main Menu", in the game instance). Logo: Border_Logo, brush is a sheen
  material, in SizeBox_9 (410x80), in VerticalBox_5 anchored bottom centre, so a taller box grows upward and the buttons stay put.
  Footer: TextBlock_59 under Border_288, which has no Blueprint variable; GetWidgetFromName errors from Lua, so it's found by object path.
- trailer/make_menu_logo.py -> assets/menu/logo.png (trailer title on transparency, cropped to the ink); splash.lua swaps the brush and text,
  from main.lua's update on the MainMenu world, retried each second until the widget exists. The game's own bytes aren't touched.
- trailer/grab.ps1 <file.png>: PrintWindow capture of the game window with UI, no focus needed. HighResShot and `shot showui` saved nothing here.
- Skipping the startup video (2026-11-15; config/skip_intro.txt, the launcher's "Skip the intro video", mode.ps1): the game
  plays LoadingScreen.mp4 (60.4 s) to the end before this screen, so launch -> splash was 69 s; a 1 s black clip
  (assets/loading/skip_intro.mp4) in its place makes it 16 s. `-NoLoadingScreen` on the command line changes nothing.
- CRASH that the long video hid: the splash is then up ~6 s before the game's backend login (the stand-in's
  POST /v2/account/authenticate/steam; afterwards SIGIS_ExampleGameInstance_C.NakamaPlayerID holds a 36-char id), and
  PLAY in that window (login widget MM_GenericSmallBtn01_1, event BndEvt__MM_GenericSmallBtn01_1_K2Node_
  ComponentBoundEvent_6_GenericSmallBtnPressed__DelegateSignature) dies with an access violation reading 0 in
  nakama-cpp.dll+0x7c2fc under exe+0x934799 (report in %LOCALAPPDATA%\RaidGame\Saved\Crashes). splash.lua gatePlay keeps
  PLAY Hidden (2, layout kept) until NakamaPlayerID is non-empty, checked from the director's tick 4x a second until the
  first login. Measured: PLAY visible at 12 s, hidden at 13 s, shown at 14 s with the login. A window under ~0.5 s remains
  between the widget appearing and the first check.

## Footsteps (2026-11-06)
- Silent for player and bots: every footstep event in rc_FPS_AnimBP / rc_AI_FPS_AnimBP (walk, sprint, jump, land, crouch) starts with
  `if IsServer: stop`, and offline is always the server. AnimNotifies fired fine (215 for bots, 9 for the player in one test).
- Fix: pvepatch `pve_bp_jump(UFunction, offset)` turns that JumpIfNot (0x07) into Jump (0x06), same size and target, checked against the
  surrounding bytes. main.lua FOOTSTEP_BRANCHES holds the offsets, applied once per world. Tools: tools/offline-audit/bpseq, bpwin, bpserver.
- Other IsServer sites in those ubergraphs (player 17357, 22810, 27791; bots 14316, 16650) are untouched. Player ones checked 2026-11-08:
  17357 montage check after a Delay, 22810 a RaidBot test (not a branch), 27791 landing camera shake. None is a sound.
- 2026-11-18 (#143): the "montage check" ones ARE a sound. `AnimNotify_ReturnedToIdle` / `_ReturnedToIdleRun` (fired when
  you stop walking / running) enter the ubergraph at 17347: `if IsServer: stop`, else (no montage playing) the crouch or
  walk step via `Force_*FootstepSound` -> the normal step path at 13545. So stopping was silent offline, for you and the
  bots (their copy: 14327). Patched both (player 17368, bots 14327: the JumpIfNot offsets; the notes' 17357/14316 are
  the IsServer calls before them), plus the landing camera shake (27802; your own camera only). 16650 in the bots' graph
  only stores IsServer into IsServerVersion: not a branch, left alone.
  Verified (Space_Alpha): kdis shows all three as plain jumps after a relaunch; firing AnimNotify_ReturnedToIdle and
  _ReturnedToIdleRun on your anim instance each produced a new Footstep_Metal_walk01_Cue AudioComponent. Not checked by
  ear; the landing shake not checked (needs a real fall). Counting footstep AudioComponents "attached to the player"
  missed them: count them anywhere, by address, before and after.
- 2026-11-08 "footsteps only sometimes": the player's PlayFootstepSound has its OWN gate (offset 1288: `if not IsServer -> sound`, else only
  the footprint decals), so your walk/sprint/crouch steps were silent while bots' (their copy has no gate) and the jump/land foley
  (JumpStartFoleySound/LandFoleySound, ungated) played. Patched the same way (FOOTSTEP_BRANCHES); the sound path's pop returns to the
  decal branch, as on a client. Verified in Spaceport: Footstep_Concrete/Metal_walk01 cues attached to the player's mesh while walking
  (bridge/t_fsplayer.lua). Not checked by ear.
- tools/offline-audit/kdis.py <UFunction hex> [from] [to]: Kismet bytecode disassembler (live, read-only) with real names, jumps and
  execution-flow push/pop. Mostly complete for 4.26 tokens; stops with "!! token" on one it doesn't know.
- Verified: Footstep_* cues on live AudioComponents (concrete, metal, thin metal, rubber, dirt land, jump). Not checked by ear. AudioComponents
  pile up to ~900 between garbage collections and drop back about once a minute (8 bots, ~14 steps/s). Harmless, but it scales with bots.
- CRASHES from test scripts, not the patch: RegisterHook on GameplayStatics:SpawnSoundAttached (AV marshalling), and a:GetOwner() on
  AudioComponents from a tick hook (null read, pcall can't catch). Don't hook sound functions; sample FindAllOf from the bridge, not a tick.
- A crash leaves dwmapi.dll mapped and CrashReportClient running: kill it and wait a few seconds before launching.

## Female outfits, voices, off-limits zone (2026-11-07)
- Pak key: not in Denuvo code. FAES tables are referenced by plain engine code (decrypt block 0x19fcb80, setup 0x19fdde0/0x19fe020), found as image-relative disp32, not rip-relative (tools/profile/rvaref.py). tools/profile/keysample.py read the schedule from a thread inside the routine during a raid load, read-only. backup/keys/pak.key, tools/offline-audit/data/paklist.txt (60657 files). Keep the key local.
- No female assets exist. tools/female/make_female.py copies cooked meshes out and moves every LOD's bind-pose vertices in place (FPositionVertexBuffer: 12, n, 12, n, floats). A-pose, front = +Y. Same topology, weights, UVs, materials. Normals aren't recomputed. Copies live in Meshes/BodieF, HeadF, AccessorieF (same name length, so the name table can be swapped in place). assets/female/list.txt: 41 Bodies + 1 Steam + 40 Heads + 24 vests/rigs = 106. WIDTH/DEPTH/THIGH/BUST_*/SEAT_* are the proportions, last tuned by the user.
- Our pak doesn't load (signature). Instead pve_loose_assets empties FPakPlatformFile.ExcludedNonPakExtensions (TSet at +0x60, Data.Num +0x68) and scripts/mode.ps1 copies the meshes as loose files; online removes them. UE4SS LoadAsset only sees the asset registry, so pve_load calls LoadAsset_Blocking 0x3172480 with a TSoftObjectPtr.
- GC: Lua tables are no GC roots. A preloaded cue was freed and SpawnSoundAtLocation crashed (call [null vtable+0x280] at 0x2efb9de). pve_root sets RootSet on FUObjectItem (chunks 0x58e7538, flags +8). Root anything loaded for later.
- rivals.lua: m.female (CFG.FEMALE 0.5) picks the HeadF/BodieF look; wearVest swaps the worn vest; top-up defenders roll it too. Placed bots stay as they are. Voices: voice.lua + voicelines.lua, 13 sets, one for life, lines from the menu one per frame. Top-ups have voices; placed bots don't.
- Verified: 106 assets built, load, skin and animate; 9 of 19 bots women; 208 lines loaded; female and male lines heard by AudioComponent sampling, not by ear; 4 kills with full corpses. Not looked at closely in good light; shading on reshaped areas keeps the old normals. Native hurt sounds still male if the game plays any on bots: unchecked. Corpses use body mesh from the pawn; not visually checked.
- Off limits: Spaceport basement around AINodeStart_2 (68268,23030,-186), walkable on the navmesh 107 m from an airlock, beside hidden stash and locked door contracts. main.lua OFF_LIMITS, checked in patrol, reachableNear, strafe, rival spawns, and adoption. 18 live bots, 10 samples, none inside. Only this zone is known; other stations may have similar ones. Space_Solo_02 often surveys no stations and rivals then extract at once: not new, not fixed.
- Issue #13 (2026-11-15): five Space_Solo_02 runs, none surveyed "none" (2, 1, 2, 3, 3 stations). The interiors are the
  same every run (Mini Mine, Penal Colony, Rebel Base loaded; Asteroid and Moon Base volumes empty); what changes per run
  is which space-side docking nodes exist (one run: only Node_PenalColony_01 + Node_MiniMine; another: Node_CapitalShip_01 +
  Node_PenalColony_01, with Asteroid/Mini Mine/Rebel Base interiors named but no nodes for them). So "none" needs a run
  whose nodes all lack a named interior and no AI frigate, or a survey that throws (pcall -> "station survey failed").
  Never seen in today's ~10 logs. survey now also logs "[rivals] survey: named interiors: ... | docking nodes: <class> ->
  <name or no name>", so the next "none" shows which side was missing.

## Women's versions of every outfit, player toggle (2026-11-07, later)
- assets/female/list.txt, 112 meshes (113 with the rebuilt Steam body counted by load test): all bodies, heads, vests, rigs and bags, plus the soldiers' one-piece Commando_Skel_01 and Security_Skel_01 (Meshes/ -> MesheF/). tools/female/classify.py lists every skeletal mesh; all 147 share RaiderChar01_Skeleton. Helmets aren't reshaped. Crewman and Traders are NPC models on other skeletons: not covered. Dev_Pirate body and head left out: the body's copy crashed the game on load (not investigated; unused in play).
- Bug fixed: renaming replaced the folder everywhere in the package, breaking Accessories/Mats and physics imports. Now only the package's own name is swapped.
- female.lua: version(mesh, on), dress(actor, on). All bot types go through it (rivals, top-ups, adopted placed bots, spawnBot soldiers) at CFG.FEMALE. Voice follows. F2 / bridge/female_toggle toggles your body, saved in config/female_player.txt; re-applied each update, because changing gear restores native meshes. Lobby re-dresses all MM_PlayerChar_C every 3 s (4 of them exist).
- bridge/t_loadall2.lua loads all with a crash trail, t_me, t_lobby, t_vestmat check the rest. Verified: player swap both ways, vest materials, 13 of 20 bots, corpses. Not verified: soldier outfits on a raid map (loaded only), how your own body looks in first person.

- Final proportions: shoulders width 0.82 at z 150 (0.91 at 135, 0.92 at 158). Locked in by the user 2026-11-07.
- Gear on the lobby character (2026-11-16, issue #29): putting gear on or taking it off on LOADOUT didn't change
  the lobby character until you switched tabs. A tab switch runs SIGIS_InventoryWidget_C OPENED_GearMenu,
  Switch_EquipmentState and RefreshMenuPlayerActor (x4), then MM_PlayerChar_C Refresh_PlayerLookActor /
  PGOS_OnChangedMyEquipment / NEW_PGOS_PlayerLookRefresh (x4, one per lobby character; they take a 104-byte look
  struct). Calling Force_RefreshPlayerLook, RefreshMenuPlayerActor or OPENED_GearMenu alone changed nothing;
  SIGIS_MainOverlay_C:CoreMM_Tab_Pressed(1) (LOADOUT's Which_CoreMenuState) on the page you're already on does it.
  lobbylabel.lua: while the LOADOUT tab isSelected, once a second, the equipped items (StashedItems whose
  MotherItemGUID is a plain slot name, not Stash / pockets / loot / shop / KeyCard / RigSlot*) are compared, and on a
  change it presses LOADOUT that way. Overlay, tab and inventory are kept as paths. Tested by dragging a Brodie
  helmet on and off: "lobby: gear changed, character redressed" each time and the helmet appeared / went at once.

## Debug menu (F9) and spawn counts in the AI menu (2026-11-07, later)
- debugmenu.lua: the old test keys are buttons now, F9 opens/closes (F3 AI menu; opening one closes the other). Removed keys: F4 crew attacks, F5 extract, F6 give gun, F7 test raid, F8 spawn soldier, F9 god mode. Kept: F2 body, F3, N/M/B. Buttons: god mode (label shows state; bridge/god.txt as before), extract now, open the space gates (UA_SpaceGateTrigger01_C:TriggerSpaceEvacReady), nearest crew attacks, spawn a soldier, give a soldier's gun, test raid on CFG.MAP. Each has when() and is greyed where it can't run. bridge/debug_cmd: an action id runs it, empty toggles the menu.
- tuning.lua Spawns tab (simplified at the user's request): rival crews (rivals.lua CFG.CREWS, 0 = one per free player slot, 11 on solo maps), crew size min/max (CFG.CREW_SIZE is now one range for every map: offline matchmaking always sends an empty configuration, so only Space_Solo maps are ever loaded; crew maps Space_Alpha..Delta and raider maps Space_Raider_01/02 never), stations per crew min/max, guards per station (MIN_DEFENDERS; a station with no guards of its own also gets this many soldiers, rivals passes the count to spawnGarrison, so main.lua GARRISON is only a fallback and has no slider). BOTS (land raids, debug test raid only) has no slider either. Ranges drawn with rivals.lua between(), which copes with min > max.
- Verified by bridge: both menus render (screens), god on/off, soldier spawned, gates, extract; CREWS 4 -> next raid "4 rival crews". Real clicks and keys not tested (the window never had focus).
- Crash once (12:03), ~10 s into a Space_Solo raid with no menu open, while rival hulls loaded: access violation through a UE4SS hook (UE4SS +0x555002 -> game +0x1c3574e -> junk). The next run passed that point. Cause unknown; watch for it.

## Seamless female body (2026-11-07, later)
- User: the body visibly switched to female after each menu click (the lobby pass ran every 3 s after the game's own re-dress). female.lua now post-hooks /Script/Engine.SkinnedMeshComponent:SetSkeletalMesh (native hook): when the owner is MM_PlayerChar_C or PlayerPawn_C, the mesh is replaced by M.version(mesh, playerOn()) inside the same call (re-entry guarded), and R_* fields are kept in step. Applies both ways: with the setting off it enforces the male version. The timed passes stay as a fallback.
- Verified (bridge t_lobbydress.lua, t_pawndress.lua): the lobby character's "PGOS RefreshCrewApperance" and a direct SetSkeletalMesh(male) both leave BodieF on; in a raid head, body, vest and bag stay female after setting the male meshes. Not watched by eye while clicking menus.

## F3/F9 in the lobby, borderless fullscreen (2026-11-09)
- F3/F9 did nothing in the lobby: they looked up FindFirstOf("MainPlayerController_C"), and the lobby's controller is
  MenuPlayerController_C (in a raid it could also be the last map's). Now F3/F6/F9 all use Hire.lastPc() (the ticking
  controller), each closes the other two, and Tuning/Debug tick from every ticker like the crew menu. Closing in the lobby
  gives the lobby its mouse UI back (menuClosed in main.lua); Z-order 5000/5010 so they draw over the lobby pages.
  Bridge-flag path (bridge/menu_toggle, debug_cmd) unchanged. Real key presses still NOT tested after this change.
- Launcher "Borderless fullscreen" box -> config/window_mode.txt (borderless|windowed). launch-offline.ps1: borderless
  writes FullscreenMode=1 (+ desktop resolution from Win32_VideoController) into %LOCALAPPDATA%/RaidGame/Saved/Config/
  WindowsNoEditor/GameUserSettings.ini and drops -windowed/-ResX/-ResY; windowed keeps the old 1600x900 args.
- F9 gun and ammo picker (2026-11-16, debuggive.lua; Debug.addActions appends its rows): Gun: <name> (click = next),
  Previous gun, Give me the <gun>; Ammo: <name> (click = next), Give me <stack> <ammo>. In a raid, on foot. Rows,
  kinds (0 long gun, 1 pistol) and magazines / stacks are from assets/saves/items.json (12 of 45 magazines I had
  typed from memory were wrong; Klobb and Sawed-off are type 1, so pistol slot). Both go through
  SIGISPlayerController:Server_AwsN_EquippedItemsReturned, the loadout path: one item string
  "<id>-<Row>-<Stack>-100-<Col>-<Row>-0-<Container>" registers the item, spawns the weapon, loads it and equips it,
  mid-raid too. Guns: first free of Prim, Sec (Pistol for type 1), read from StashedItems' MotherItemGUID; a second
  gun into a taken slot (tried by bridge) left the first in your hands with its item hidden behind the new one, so
  a full set is refused. Ammo: first free PocketLeft/PocketRight cell (ItemInSlot.Column/Row).
  Tested via bridge/debug_cmd: M45 36 -> Prim, Thompson 30 -> Sec, third gun "No free gun slot", SPP-1 4 -> Pistol,
  second pistol refused, 60 9mm and 60 .45 in separate left-pocket cells; the inventory screen showed all of it.

## Share of women (2026-11-13)
- Launcher slider "Female enemies and crew" (0-100 %, steps of 5, default 35) writes `config/female_share.txt` (a percent).
  `Rivals.femaleShare()` reads it into `Rivals.CFG.FEMALE` (default 0.35) at init and every 5 s from `R.update`; used for
  rivals, adopted/top-up station guards, director soldiers (main.lua spawnBot) and new crew recruits (hire.lua). People
  already made (hired crew, the saved recruit pool) keep who they are. Your own character stays the separate toggle.

## Plain wording (2026-11-13)
- Settings text is written for anyone: plain words, units named (cm, seconds, degrees), "1 = normal" style hints.
  Launcher and the F3 menu (now titled "Enemy and crew settings") were rewritten. F3 tabs renamed: Fighting -> Moving,
  Spawns -> How many, Crews -> Rival ships, My presets -> Saved setups; personalities show as Fearless/Reckless/... .
  Saved values are keyed on a tab's `id` (its old name), so config/ai_tuning.txt still loads.
- Fixed: Personalities rows used to share one id per setting (`Personalities:aggression`), so a saved value landed on
  every personality. Now `Personalities:<AI name>:<setting>`; the old id is still read (`stored`, `r.oldId`) from settings,
  presets and `set` commands, and the next save writes the new ids. Checked offline with lupa.

## Your look and voice in raids (2026-11-16, tested; nakama_standin.py write_cosmetics, main.lua applyLoadout)
Tester report: "no voices or cosmetics actually appear to change in raid". The lobby showed the chosen head, body and
voice (cosequipped), but raids always had Raider_Head_Skel_01, Raider_Body_Skel_01 and the English male voice.
- Online, the raid server gets them as it gets the loadout:
  SIGISPlayerController:Server_AwsN_EquippedplayerCosmeticsReturned(FString). Offline nobody calls it, so the
  controller's EquippedHead/Body/Voice stay "". The pawn's ActiveVoice stays "" too, and PlayEmoteVoice falls back
  to enM01 when GetInGameActiveVoice() is empty.
- Shape: a JSON array of {"key": "head"|"body"|"voice", "value": "<row>"}. Passing the stored string as it is
  ({"value":"20"}) put that whole string into EquippedHead. A {"collection",...} storage-list shape and a flat
  object did nothing.
- The call sets EquippedHead/Body/Voice and the pawn's ActiveVoice. It resolves the rows to meshes in the pawn's
  replicated R_FaceMesh / R_BodyMesh (head 20 = Hunter_Head_Red_Skel_01, body 48 = Raider_Body_RedWhite_Skel_01;
  R_HeadMesh stays null). Nothing replicates offline, so the character only changes after pawn:OnRep_SetHead(), which
  applies both.
- The stand-in writes backend/cosmetics.json (gitignored) next to loadout.json, on startup and every save. applyLoadout
  feeds it to the controller right after the loadout, then calls OnRep_SetHead, and logs "cosmetics: [...]".
- Tested: save set to head 20, body 48, voice frF01. The lobby showed the red Hunter head and the red/white body. On
  Space_Charlie, CharacterMesh0 = Hunter_Head_Red_Skel_01, CharacterBody0 = Raider_Body_RedWhite_Skel_01,
  ActiveVoice = frF01. A real F1 (Voice01) sent RunOnServerVoice with DT_VoiceSet_FrenchFemale01. Not watched in third
  person.

## F9 gun list: the rest of the guns (2026-11-17; debuggive.lua)
- The F9 picker only had the base guns, so the variants could not be given for testing. Added 13 rows: Terminator, Heavy Liberator, Heavy MG42, Heavy Thompson, Thompson Special, APS, Custom Mat 49, M712 Special, Sterling Special, Sterling (short), Viper Mk1, Mini Thumper, M1911 G.
- Kind (0 long gun, 1 pistol) and magazine size for each are checked against assets/saves/items.json (type and max), the same source as the rest of the list. Sterling (short), Mini Thumper and M1911 G are type 1, so they go in the pistol slot.
- Only the GUNS table changed. No row was removed or edited, and the give path is untouched. These rows were used from the F9 menu in game while testing guns against armoured bots.

## F9 bottomless mags (2026-11-18; debuggive.lua, debugactions.lua, main.lua)
- A toggle in the F9 menu, first of the gun rows: "Bottomless mags: ON / off". While it is on, every round a shot takes off the clip is put back, so no gun runs dry and nothing needs a reload. It is usable in a raid, on foot, like the gun picker; turning it on or off starts the count again from what the gun holds. It resets with the game (nothing is saved).
- Done in Lua with no game flags. bInfiniteClip and bInfiniteAmmo change how the clip reads, so code that watches the clip for shots (the damage code on the player to bot damage branch) never saw one, and finding the flags searched the world twice a second.
- How it works: for the player the loaded rounds are the StackAmount of the gun's own SIGIS item (found by UniqueItemGUID equal to gun.UUIDSIGIS, searched once per gun and again at most once a second while it is missing). The weapon's CurrentAmmoInClip only follows that stack, so putting the clip back alone changed nothing. Each frame, a clip or a stack lower than last frame's is set back to last frame's. One property read a frame, nothing searched.
- Order matters: main.lua calls it (`DebugActions.frame`, profiler section "mags") after the aim, cover and ragdoll sections, so anything that reads the clip for shots earlier in the frame has seen it drop before it is put back. A later change that reads the clip must run before this call.
- Logic lives in debuggive.lua (`G.frame` and the action); debugactions.lua exposes it as `M.frame`, which keeps main.lua's local count flat. Used while measuring armour (the armour test needs neither gun to run dry); the measurement itself is not part of this change.

## God mode: unlimited stamina (2026-11-18; debugactions.lua holdStamina, main.lua update)
- Problem: god mode (bridge/god.txt, the F9 button) only set `bCanBeDamaged = false` on the player's pawn. Sprinting and swinging
  still drained stamina, so a long test run kept stopping to wait for it to refill. An earlier test copy of main.lua held
  stamina, but that never reached the repo.
- Fix: `holdStamina(pawn)` in debugactions.lua, called from the main.lua update right after the immunity line. While god mode is on,
  four times a second (Aux.due), if the pawn's `Stamina` is below its `MaxStamina` it is set to `MaxStamina`. Both are properties of
  `PlayerPawn_C` (hud_dump.txt lists Stamina, MaxStamina, StaminaRegainRate). A pod or ship pawn has neither, so the guarded read
  gives nil and nothing happens there. The game log gets one line the first time it acts ("god mode: stamina held at its maximum").
- Left alone: the weapon values (StaminaADSModifier, StaminaRechargeRate) and the HUD stamina bar's own burn display.
