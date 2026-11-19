# Raid flow: matchmaking, loadout, extraction, conditions

Getting into a raid and out of it again: matchmaking, loadout from the stash, loading, the space gate, raid length,
raid conditions, quitting.

Part of the project's research log: [NOTES.md](../../NOTES.md) lists every topic file and every section title.
Sections are in the order they were written; a later section can correct an earlier one, so read to the end of a topic
before trusting a finding. When a section says "see X", search [NOTES.md](../../NOTES.md) for that title to find which
file it is in.

## Contents

- [Raids offline — WORKS (first test)](#raids-offline--works-first-test)
- [Raid loadout from the stash (WORKING, 2026-10-30)](#raid-loadout-from-the-stash-working-2026-10-30)
- [End of raid: extraction and death (WORKING, 2026-10-30)](#end-of-raid-extraction-and-death-working-2026-10-30)
- [Start Matchmaking -> space raid in your ship (WORKING, 2026-10-30)](#start-matchmaking---space-raid-in-your-ship-working-2026-10-30)
- [Space gate extraction (WORKING, 2026-11-06)](#space-gate-extraction-working-2026-11-06)
- [Faster space raid loads (2026-11-06)](#faster-space-raid-loads-2026-11-06)
- [Map variety (2026-11-07, later)](#map-variety-2026-11-07-later)
- [No captain's key card at raid start (2026-11-16, tested; main.lua guardKeyCard)](#no-captains-key-card-at-raid-start-2026-11-16-tested-mainlua-guardkeycard)
- [Quit Game in the pause menu (2026-11-16, tested in a raid; mods/PvEDirector/Scripts/quit.lua)](#quit-game-in-the-pause-menu-2026-11-16-tested-in-a-raid-modspvedirectorscriptsquitlua)
- [Raid length from the launcher (issue 159, 2026-11-18; raidtime.lua, launcher "Raid length")](#raid-length-from-the-launcher-issue-159-2026-11-18-raidtimelua-launcher-raid-length)
- [Raid conditions (issue 78, 2026-11-18; conditions.lua, config/raid_conditions.txt)](#raid-conditions-issue-78-2026-11-18-conditionslua-configraid_conditionstxt)
- [Space gate time (2026-11-18; raidtime.lua, docs/internals/SPACE_GATE.md)](#space-gate-time-2026-11-18-raidtimelua-docsinternalsspace_gatemd)
- [Minefield raid condition (2026-11-19, no issue)](#minefield-raid-condition-2026-11-19-no-issue)

## Raids offline — WORKS (first test)
- `open /Game/Maps/Raids/Spaceport_01?PID=x?PNAME=x?CREW=x?CPT=1?NUM=1?EOS=x?UPN=x?psid=1` from the menu loads the map
  standalone with a player pawn (PlayerPawn_C, MainPlayerController_C). Without PID the engine asserts
  "Couldn't spawn player: PlayerID is null". URL options read by the raid code: PID CREW CPT NUM EOS UPN PNAME psid.
- Default game mode in that case is ShootingRangeGameMode_C (no AI spawned). Real raid modes: ARaidGame_Space,
  ARaidGame_FreeForAll, ARaidGame_TeamDeathMatch (C++); BP subclasses unknown until the pak is listed.
- Maps: /Game/Maps/Raids/{Asteriod_Mine_01, MoonBase_01, Navy_Outpost_01, Penal_Colony_01, Spaceport_01}.
- AI: ARaidBot / ARaidNodeBot pawns (BotPawn_C, BotPawnGuard_C, BotPawnMilitary_C), ARaidGOAPController
  (GOAP_Controller_C, /Game/AI/Actions/*), AISPAWNTYPE {Player, AINormal, AIGuard, AIMilitary}, frigate AI
  (ARaidAIShipController), ARaidDebugAIGymSpawner, node system (/Game/Blueprints/NodeSystem).

- With UE4SS on 4.26 the player really stands at ~(59161, 24577, 300) on Spaceport (camera inside pod/helmet).
- AI spawns: `AIBlueprintHelperLibrary:SpawnAIFromClass(pc, BotPawnMilitary_C, BotBehavior, loc, rot, true, pc)` →
  BotPawnMilitary_C possessed by RaidAIController. It stands still (speed 0) — needs team/target/node setup (phase 3).
  Pass real objects for every UObject param (nil → UE4SS error); FTransform params don't marshal (use FVector/FRotator
  APIs). FString return values come back garbled; numbers/objects are fine.
- Map has 14 AINodeStart_C (AI spawn nodes) + RaidTeamStart_3. URaidCheatManager has SpawnBot/ForceMatchStart/
  ToggleInfiniteAmmo etc. (SpawnBot did nothing in ShootingRange mode).

## Raid loadout from the stash (WORKING, 2026-10-30)
- Live flow: the raid server calls SIGISPlayerController::Client_GetEquippedItems; the client reads its equip=true
  inventory from Nakama and answers Server_AwsN_EquippedItemsReturned(FString) (thunk 0xa778f0, _Validate vtable
  +0xf18, _Implementation +0xf20 = 0x9d4470 -> 0x9b2a20). Offline Client_GetEquippedItems does nothing (no request).
- The string is a JSON array of storage objects: `[{"value":{"equip":true,"value":"<id>-<Row>-<Stack>-<Cond>-..."}}]`
  (value is read as an object, then its "value" string; items containing "_Ship" are skipped; an empty string takes
  another path). The game registers each item under its stash id, spawns the weapon actor (row ItemBP), loads the
  gun's stack as its magazine and equips it on a fresh pawn.
- The stand-in writes backend/loadout.json in that shape (startup + every save). The director feeds it to that
  function once the SIGIS HUD overlay exists, while bridge/offline_backend exists; the donor gun is only a fallback.
- Verified: Mat49 (stash id 56548551, 36 rounds) equipped, fires, drains its own item (36 -> 26); 32 ammo in the
  left pocket; helmet + vest registered. Not verified: helmet/vest visible on the character.
- Your armour works (2026-11-16, bridge/t_parm.lua = your hp drop per bot shot at 5000 hp; M1FlakChest cond 40 in the
  loadout, Space_Solo_01 Fortress and Space_Delta Navy Outpost): 1911 (28) hit you for 21, Bren (36) for 29, both
  less 7 = the vest's value; a few hits did half of that (legs, armour first). Body hits wear the vest ~2 condition
  each (40 -> 0 in ~20-23 hits, read off its SIGISInventoryItem.Condition), then hits do the full 28 / 36. The
  game's own wear, nothing in the mod. No head hits landed, so the helmet is untested in game.
- Don't pass nil for a UObject parameter (pc:GetItemArmourValue(nil) crashed the game).
- Gear back from raids that end without extraction or death (2026-11-16, issue #49, Hayley's option 2): the stand-in
  keeps what a raid took out of the stash as state.raid_out {items, ended}. ship_lost.txt (death, or out on foot /
  by pod) and ship_gate.txt = 1 (into a space gate) mark it ended; = 0 (back out of the gate) unmarks it. If it isn't
  ended, return_unfinished_raid() puts the items back (same keys, still equipped) when the stand-in starts, at the
  next login (/v2/account/authenticate), or when the next raid starts: QUIT GAME, Alt+F4, a crash or leaving through
  the menu. Loot picked up in that raid is lost. The raid QUIT GAME warning says so now.
  Tested: equipped Stahlhelm + 1911 by drag -> raid start "took ['99255929', '68933336']" -> QuitGame mid-raid -> next
  login "raid ended without an extraction or death (login): [...] back in the stash", both still equipped on the
  Loadout screen. Death (ApplyDamage on your pawn) -> "ship lost", raid_out ended -> next login returned nothing.
  Editing equip flags into state.json by hand didn't reach the raid: the game's first lobby load re-saves the stash.

## End of raid: extraction and death (WORKING, 2026-10-30)
- Extraction: the raid server calls SIGISInventoryComponent::Client_GetOutWithLoot (thunk 0xa62f20, impl vtable
  +0x708 = 0x980950): on the local client it copies every carried item except KeyCard/GuildBadge rows into
  SIGISGameInstanceNakama.ExtractedLoot (+0x1110), which survives travel. The lobby, after Play on the splash
  screen (the main menu alone writes nothing), PUTs those to Nakama inventory and empties the array.
- The live server must also take the equipped items out of the stash at raid start (otherwise extraction
  duplicates them; seen once, cleaned up). Offline: the director writes the ids it loaded to backend/checkout.txt and
  the stand-in removes them (watch_checkout). Death then loses them, as live.
- The director hooks Client_GetOutWithLoot and opens the main menu EXTRACT_SECONDS (3) later; F5 extracts on the
  spot. Not checked yet: whether the maps' own extraction points call it offline.
- Death: the game goes back to the menu by itself and writes stats (statChangeArray, playerstats xp), nothing to
  the inventory. After every raid it also POSTs /v2/leaderboard/<TotalCash|TotalPres|TotalSP|TotalXP|TotalStash>
  {"score"}; the stand-in stores them in state.json "leaderboards".
- Lua tables passed as TArray<FString> parameters crash (pc:Client_RemoveEquippedItems({...}): game read
  0xffffffffffffffff). Don't pass arrays from Lua.
- Verified 2026-10-30: raid start checked 4 items out; extract -> menu after 3 s -> Play -> 4 items back (Mat49 with
  its remaining 25 rounds); death -> menu, gear gone, stats written. The stash was restored from a backup
  (backend/state.before-death-test.json) after the death test.

## Start Matchmaking -> space raid in your ship (WORKING, 2026-10-30)
- The lobby's START MATCHMAKING is the crew captain's launch button (Crew_LaunchToMatchBtn_SubWidget_Captain on
  SIGIS_MenuMain; you captain a crew of one). It sits on top of the solo button (MM_LaunchToMatchMain_SoloPlay,
  whose press -> SIGIS_MenuMain.LaunchGameSolo -> SIGISGameInstanceGraphQL::AwsWs_StartMatchMaking over the game's
  own AWS websocket). The captain path goes through PGOS crews. Both are dead offline: the lobby searches forever.
- Director: with bridge/offline_backend, the captain button's press (hooked from update() once the menu widget
  class is loaded) or AwsWs_StartMatchMaking starts a 4 s "search", then `open /Game/Maps/Space_Solo_0N` + the raid
  options. Second press during the search cancels. Crew/raider configurations would pick the crew/raider maps.
- Space maps (SpaceGameMode_C, RaidGame_Space, ISASpaceGameMode) need nothing extra: after the 15 s warmup the
  game mode spawns the starter frigate (FrigateInside_Starter_C inside, Ship_StarterFrigate01_Pawn_C outside, from
  /Game/Data/FrigData) and the player pawn in its cockpit; the "Space gate arrives in" timer runs. No backend calls.
  Until then you'd see open space, so the director holds the camera black (SetManualCameraFade) until pawn + ship
  + streaming levels are in, then fades in. Space maps get the loadout/checkout and extraction, no soldiers/navmesh.
- In-ship RPCs for later (RaidPlayerController): ServerDeploySpaceRaid, ServerDeployShipFromHanger, ServerLandFrigate,
  ShipDockingToStation, ShipBreaching, EvacRaid, LeaveSpaceRaidVolume.
- Hooking gotchas found on the way: hooking hundreds of Blueprint functions at once corrupts UE4SS's function map
  (FMallocBinned2 "unrecognized block" / AV at 0x70) - hook a handful. Inside a hook callback the bridge's `reply`
  isn't visible (it's only in the command's environment): log to a file or capture reply in a local first.
  Calling widget functions (GetVisibility...) on non-widget objects crashes. PostMessage clicks don't reach the
  game (UE reads the real cursor). Hovered widgets: UserWidget:IsHovered() from a menu tick hook.
- 2026-11-16 (issue #55): offline the button reads START RAID (lobbylabel.lua). The label is TextBlock_31 of
  Crew_LaunchToMatchBtn_SubWidget_C (Captain and Crewmember copies), with no variable of its own;
  UWidgetTree::FindWidget isn't callable from Lua, so it's found as StaticFindObject("<button path>.WidgetTree.TextBlock_31").
  Paths are kept, not objects, and looked up again each second. It's set again whenever it
  differs (in case the game rewrites it). Text_CoreState (CANCEL MATCHMAKING, shown for the 1 s "search") is left alone. Tested: "lobby: launch
  button relabelled START RAID (2)" at boot; a raid starts from it as before.
- Lobby QUIT tab (2026-11-16, issue #50): quit.lua adds a tab of the top bar's own kind (MM_CoreMM_TabBtns_C,
  WidthToUse/HeightToUse from SOCIAL, Which_CoreMenuState 99 so the bar never selects it) to HorizontalBox_Core_MM_Tabs
  after SOCIAL; it lays itself out. Same click-twice confirm ("SURE?"), then QuitGame. A button added to the
  overlay's MainCanvas didn't show (CanvasPanelSlot:SetAnchors with a Lua table was ignored, the position landed off
  screen), and probing that canvas crashed the game: calling a method on a null UObject wrapper (a root canvas's
  .Slot) is an access violation inside UE4SS that pcall can't catch, so check IsValid() before every call there.
- quit.lua keeps both menus' widgets as object paths now, not objects (the pause menu's were held across raids and
  checked with IsValid each frame after a map change). hire.lua H.reset() also clears the tick controller
  (H.lastPc): quit.lua and invkeys.lua ask for it before the frame's H.tick, so on a new world's first frame they got
  the old world's controller. (tickPc was declared below H.reset; moved up so the reset clears the real local.)
- Tested: lobby "QUIT tab added", one click -> SURE?, two clicks -> "Quit Game from the lobby", the game exited, no
  crash reporter; same boot through a raid: pause menu QUIT GAME -> CLICK AGAIN TO QUIT -> quit.
- Choosing the map (2026-11-16, issue #54; mappick.lua): the lobby's REGION picker (Crew_MatchmakingTypeSelect_Widget,
  WrapBox_RegionList) holds six SIGIS_MatchmakingRegion_Subwidget_C, region 1..5 and 0 (USA WEST, USA SOUTH, EU
  CENTRAL, ASIA NORTH, ASIA SOUTH, USA EAST) -> SOLO 1, SOLO 2, ALPHA, BETA, CHARLIE, DELTA, plus a RANDOM button of
  the same class (region 99) added to the WrapBox. Findings: the game re-creates the six each time the picker opens
  (the old ones stay valid, hidden), so new ones are caught with NotifyOnNewObject and dressed on the next frame;
  it disables "bad ping" regions and offline every ping is 999, so only two were clickable (Btn_MatchmakingSetting /
  widget SetIsEnabled(true)); the ping row "(999ms)" is a HorizontalBox around Txt_PingValue (collapsed); a click on
  the region already selected doesn't fire, hence the RANDOM button; the choice is stored in
  SIGISGameInstancePGOS.ActiveMMRegion, whose default 0 can't mean "untouched", so the click is read from a hook on
  the button's own BndEvt ... OnButtonPressedEvent instead. RANDOM closes the picker itself
  (Crew_MatchmakingTypeSelect_Widget_C:FORCE_CLOSE_MatchmakingAndRegionSelect: the game's buttons close it through a
  delegate their parent binds). The box (SIGIS_MenuMain Txt_PGOS_Matchmaking_WhichRegion and _CrewMember) and the
  settings widgets' copies show the pick or RANDOM MAP. onStartMatchmaking uses PveMapPick.map() before map_pin.
  Lua pitfall hit: `(a == b) and nil or c` is always c. Tested: ALPHA picked -> raid on Space_Alpha; remembered over
  a restart ([ CHARLIE ], box CHARLIE); RANDOM -> picker closed, box RANDOM MAP, config/raid_map.txt removed; BETA ->
  raid on Space_Beta.
  Details (2026-11-16, later): each button shows "solo map" / "crew map" in its ping row (its "(" and "ms)"
  emptied) and a hover tooltip, UMG's own (UserWidget:SetToolTipText, set once per button address): the map, its kind
  and the stations seen there (from the "[rivals] stations:" log lines and the NOTES survey); RANDOM's says it picks
  any of the six. Checked: tooltip shown on hover over CHARLIE, three lines.

## Space gate extraction (WORKING, 2026-11-06)
- Flow: at 300 s (gm.TimeTillEvacSpawn, RemainingTime 1200) the game mode spawns EscapeZoneSpaceGate_C (SpaceEvacToSpawn, a
  RaidPlanetEvac) at both EvacSpawnPoint_C; gs.EvacSpawned true, pc.ClientEvactriggered. All of that already ran offline.
  Calling it early: the stations' UA_SpaceGateTrigger01_C consoles call SIGISGenericActor::TriggerSpaceEvacReady
  (0x9a1720 -> game mode vtable +0x920); `t:TriggerSpaceEvacReady()` from Lua saves the 5 minute wait in tests.
- The gate's Blueprint, on overlap: cast to RaidCharacter, GetController, cast to RaidPlayerController,
  EnterEvacRaidVolume (impl 0x182c210). So only a character a player controls counts: an unpiloted ship does nothing.
- The bug: EnterEvacRaidVolume stops at `cmp Role,3 ; je return` (0x182c23e). Only a client went on to EvacRaid +
  Server_EnterEvacRaidVolume. pvepatch "Space gate extraction" NOPs it (20/20). The server half (0x183e160) is intact.
- Verified with an item in the pocket: pod into the gate -> Client_GetOutWithLoot -> "extracted with 1 item(s)", item
  written to the backend inventory. Piloted ship into the gate -> Client_GetOutWithLootAndShip, item and xp written, menu.
  (Two test bandages, pve-test-*, are in the stand-in's stash.) Gate entry was by teleport, with no jump cinematic
  checked, and whether the ship itself is kept was not checked.
- Pods: DropPodHatch_C (ARaidFrigateShuttleControl). Launching from the bridge is NOT the real path: hatch:OnUsed(pawn)
  leaves pc.DroppodLevelLauncher (+0xc58) null, and the pod starts near 0,0,0 or at garbage coordinates (seen 1.5e16, 6.6e34)
  and a second use in the same raid did nothing. SimulateInputKey F did nothing unfocused, ServerUse needs
  LastInteractionActor on the same frame. Launched by real F in play, pods reached the gate (the user did), so this
  looks like the shortcut's fault, but that isn't proven. On launch the on-foot pawn parks hidden at 0,0,0 with its gun.
- "Massive uzi on the pod" (user report): NOT reproduced. Ruled out: equipCarried (on foot only), pod weapon (none, no gun
  components, 5 skeletal comps only), held rifle (stays hidden on the parked pawn), summoned InGame_BowGun_50Cal actors
  (they stay at the player's spot, assigned to ships, and don't render there). Note the bow guns aren't moved to their
  ships at all. Test scripts: bridge/t_pod, t_podgate, t_pilot, t_shipgate, t_armme, t_gunwhere, t_evachooks(2), t_evacstate.

## Faster space raid loads (2026-11-06)
- Timeline of `open Space_Solo_01` (bridge/loadsample.ps1, t_loadstate.lua): real work (disk, CPU) done in ~20 s. WaitingToStart,
  then InProgress, then 45 game seconds with 0 MB read and no ship or pawn, then both appear at once: 65-66 s open to aboard, and
  the same on every run. Not the backend (silent in that gap), not a Blueprint delay (no float constant in the game mode or map),
  not a constant in any of the 284 SetTimer calls (0x348fba0), not gm:RestartPlayer (runs, does nothing early), not
  RaidWorldProcManager::TimedSpawning (0x18befa0, one shot). The timer itself was NOT found.
- Fix (main.lua veilUntilAboard): the wait is game-time, so SetGlobalTimeDilation(CFG.LOAD_TIME_DILATION = 10) for the whole black
  veil, back to 1 when pawn + ship + streaming are ready, and on giving up at VEIL_MAX. A new map starts at 1 anyway. Same
  simulated seconds, less real time. Rivals only start once the player exists, so they aren't ahead.
- Result: open to aboard 17-20 s (3 loads, "aboard after 8-9 s"), was ~66. Arrival vs. normal speed (2 loads each, bridge/t_arrive.lua):
  raiders 13, 13 vs 16, 13; item actors 1052, 1036 vs 1041, 1040; hull 575, hp 100, time dilation back to 1.00, no ship at bad
  coordinates. Raid clock on arrival ~1440 vs ~1448: up to 0.5 s of update lag x 10, so ~8 s more of the 1500 s gone.
  Played after a fast load: rivals launch/dock/attack, Fortress garrison, fights, gate extraction with item and xp saved. Not seen on
  screen by a person. A station's own defenders weren't checked after a fast load (the Fortress has none).
- Raid maps opened directly aren't touched: the veil only runs on space maps.
- Missing health at raid start (tester report, 2026-11-15): the pawn spawned while the load still ran at 20x, since
  veilUntilAboard only looks every UPDATE_SECONDS (10 game seconds at 20x). It arrived with Health 97 or 85 and
  totalTallyHealthBurn 3 or 15 (burned: the bar's white segments stay short), set between two frames with no
  ReceiveAnyDamage, so the landing in big physics steps. At LOAD_TIME_DILATION 1: Health 100, burn 0, but ~50 s slower.
  Fix: onTick (per frame) sets the speed back to 1 from CFG.SPAWN_SLOW_AT (40) match seconds, or as soon as a pawn
  exists. Two raids after the fix: 100 HP, burn 0, aboard after 13 s and 15 s.

## Map variety (2026-11-07, later)
- Offline matchmaking always got an empty configuration, so only Space_Solo_01/02. main.lua CFG.MAP_POOL now holds both solo and all four crew maps (Space_Alpha, Beta, Charlie, Delta); bridge/map_pin (a map name) forces one for tests. bridge/maps_test.sh loads each map in $MAPS and writes bridge/maps_test.txt.
- Tested (bridge only): every crew map gets you aboard in 10-12 s with the key card, stations found, 11 crews, launches heading for stations. Seen: Alpha Rebel Base + Spaceport; Beta Asteroid Mine, Penal Colony, Capital Ship; Charlie Mini Mine, Colony Cruiser (some runs); Delta FastFrigate, Navy Outpost, Merchant. Charlie also has Planet Killer airlocks but no docking node in the runs seen.
- Charlie has two identical nav volumes in the Mini Mine: the duplicate check now keeps the first of equal ones. VOLUME_NAMES colon / plane, play-area STATIONS ColonyCruiser / PlanetKiller.
- Space_Raider_01/02 (the game's raider mode) shut the game down shortly after "match found" (no crash report): left out of the pool, not investigated.
- Crew sizes use one range for every map (Spawns tab); live crew maps had crews of 3-4.

## No captain's key card at raid start (2026-11-16, tested; main.lua guardKeyCard)
Issue #33. Reproduced on Space_Beta with the test save's empty loadout: the player's inventory had no items and no
KEYCARD 35 s after boarding, and guardKeyCard logged nothing, because it only puts back a card it has seen.
- SIGISInventoryComponent:Server_ReadyforKeyCard (no params, server RPC) makes the card. Called by bridge, KEYCARD
  appeared in the KeyCard slot a second later, Attachments "<captain>!USS Oberon!75312034!FrigateStarter_Ship" (the
  interior's KeyCardUUID). A second call doesn't add another card (still 1).
- guardKeyCard now calls it when no card has turned up 6 s after boarding (CARD.GRACE, at most CARD.ASKS = 3 tries,
  every CARD.CHECK = 2 s). The card it gets is then remembered and guarded as before. CARD is a table because main.lua
  is at the 200-locals limit.
- Tested on a fresh launch, empty loadout: "none 6s after boarding; asked the game for one (1)" at +6 s, then
  "key card: Vanquisher!16368391!FrigateStarter_Ship" at +8 s; 1 card. Not tested: using this card at a station airlock
  (it is the game's own card, the same kind the 2026-11-07 tests used), and which normal-start step fails to ask with
  an empty loadout.

## Quit Game in the pause menu (2026-11-16, tested in a raid; mods/PvEDirector/Scripts/quit.lua)
Testers had no way to quit from inside the game and force-closed it. SIGIS_Exit_Widget_C (Esc in a raid) has Resume,
Guide, Report Abuse, Settings and Main Menu. Its EXIT button belongs to the "are you sure?" panel behind Main Menu and
leaves the raid. Its REPORT BUG button is collapsed and opens a web page.
- A QUIT GAME button is added under Main Menu the first time each menu opens: a new MM_GenericSmallBtn01 (Main Menu's
  class) in a new SizeBox, appended to VerticalBox_161. The button gets Main Menu's designer variables (WidthOverride
  200, HeightOverride 35, b_TexOnlyVersion, fill material, opacities, sounds), then PreConstruct(false) again. The slot
  gets Main Menu's padding (top 10) and centre alignment. Struct copies need a plain Lua table: passing `from.Padding`
  failed silently. Border_MainMenuOptions sits in a canvas with a fixed size (290 x 341.6), so it grows by one row
  (+50) with SetSize.
- The hook on ExitMenu_Open must be a pre-callback. Its post-callback never ran (counted pre 1, post 0). The widgets
  already exist in pre.
- Clicks: UMG delegates can't be bound from Lua, so Btn_Main:IsPressed() is polled from the director's tick while the
  menu is visible, and a release counts as a click. The first click relabels the button "CLICK AGAIN TO QUIT" for 4 s.
  In a raid it also sends a ClientMessage saying the gear you brought in counts as lost. That message is not seen
  behind the menu; Alt+F4 loses it the same way. A second click within 4 s calls
  KismetSystemLibrary:QuitGame(pc, pc, Quit, false).
- Tested on Space_Solo_01 with real mouse clicks. The button looks like the others. Click 1 armed it, and it was back
  to QUIT GAME after 4 s. Clicks 1 and 2, 1 s apart, logged "quit: Quit Game from the pause menu" and the process
  exited with no crash reporter. Synthetic clicks need a real mouse move over the button (SetCursorPos alone isn't
  hovered by Slate).
- The lobby has no Esc menu: MenuPlayerController's InGameMenu action opens nothing. SIGIS_MainOverlay_C has an
  MM_SecondaryOptionsBtn_Exit, but it is inside Border_BottomBar_Old, which is collapsed. That's a possible follow-up.

## Raid length from the launcher (issue 159, 2026-11-18; raidtime.lua, launcher "Raid length")
- The raid's countdown: RaidGameState.RemainingTime (seconds) and bTimerPaused; RaidGameMode (gs.AuthorityGameMode,
  also for the SpaceGameMode_C subclass) RoundTime 1500 (25 min), WarmupTime 15, GameOverideTime 0,
  TimeTillEvacSpawn 300 (space gate). GameState.ElapsedTime doesn't match the round (128 vs 175 s gone), don't use it.
- During the warmup RemainingTime holds the warmup's 15 s countdown, and the round then restarts it from RoundTime.
  Writing RemainingTime or pausing in the warmup is wrong: a length came out wrong, and a pause would hold the warmup.
- raidtime.lua: config/raid_length.txt = minutes (5-240) | "default" | "none". Sets gm.RoundTime at once; once
  RemainingTime > WarmupTime + 1 the round is running: "none" sets bTimerPaused; a raid first seen already running
  gets the time gone carried onto the new length. Once per raid (raid.lengthSet).
- Launcher: a "Raid length" slider (25 min default, 15, 30, 45, 60, 90, 120, no limit). Both sliders are one row now
  (label, slider, value): with the new one the settings column clipped at 150 % scaling.
- Tested in game (Space_Solo_01, relaunched each time): 60 -> "raid length: 60 min", 3541 s left a minute in, RoundTime
  3600; 15 -> 883 s left at the round start, RoundTime 900; none -> paused at 1488 s and still 1488 ten seconds later,
  raid started normally. Hand-written RemainingTime 2700 counted down (2693 after 7 s). launcher/test_ui.py 12/12.
  NOT tested: a land map, what happens when a set length runs out (#159 noted one process exit at timer end), whether
  the space gate's arrival depends on the round time.

## Raid conditions (issue 78, 2026-11-18; conditions.lua, config/raid_conditions.txt)
- A condition is a named set-up applied while a raid map is loaded: F3 settings by their ai_tuning.txt id
  (`Crews:BARON`, `Spawns:CREWS`...), `ships` (rival crews guaranteed in those hulls, boss-like: diehard, aggression 1,
  no rushing; rivalcrews.lua makeCrews sets `c.hullRow`, rivalships.lua honours it), `map` (wins over the lobby pick,
  launch.lua), `loot` (multiplies rivals CFG CARRY_BAG, MEDS max, CARRY_CAP_MIN/SHARE and CARRY_JACKPOT: bodies'
  carried loot, rivalbodies.lua rollCarried; floor and container loot are the game's and unchanged).
- Applied in onTick on a new non-menu world, restored on the menu world. Original values are kept per table slot;
  tuning.lua's save() asks `X.base` so F3 never saves a condition's value as yours.
- Picked from the launcher ("Raid conditions" row: click cycles, right-click back, status line says what it does) or
  the lobby's REGION picker: an eighth button (region 98) cycles. The game ignores a click on the region it holds as
  chosen, so after a conditions click mappick.lua puts SIGISGameInstancePGOS.ActiveMMRegion back to the last region
  clicked (or the picked map's). The pick is config/raid_condition.txt.
- Verified in game (Space_Charlie via START RAID, "Baron's last stand"): log "raid conditions: Baron's last stand (3
  settings, loot x2, ships CapitalDreadnought_Ship, map Space_Charlie)"; the lobby button's matchmaking chose
  Space_Charlie; five crews launched incl. "Red Baron's Strike Frigate" and a Dreadnought; in the raid BARON=1,
  CARRY_BAG 4-10 (2-5), CARRY_CAP_MIN 3000, JACKPOT 0.1, ATTACK_CHANCE 1, RUSHERS 0; back in the menu all back to the
  user's values and config/ai_tuning.txt unchanged. "Hunted" on a later launch: 4 settings, loot x1.5, map from the
  lobby pick. Launcher: test_ui.py passes; the row fits at 150 % after Cash and XP share a line.
- Not verified: the lobby picker button with a real mouse (the picker couldn't be opened from code: its widget stays
  collapsed), including the ActiveMMRegion reset; loot on a killed body by eye; Linux launcher.
- The bridge mod has its own Lua state: probe the director's globals (Conditions...) with bridge/profile_on plus
  bridge/dir_eval.lua, not `send.sh "lua ..."`.

## Space gate time (2026-11-18; raidtime.lua, docs/internals/SPACE_GATE.md)
- Request (Discord, ChurchOfHusk_Enjoyer): choose when the space gate arrives (instant, 5, 10, 15 minutes), because the custom
  raid length also moved the gate's countdown. Launcher: "Space gate" slider under "Raid length" (default, instant, 5, 10, 15),
  config/gate_time.txt (default, instant, or minutes up to 240).
- Cause: the real gate comes TimeTillEvacSpawn (300 s) into the raid whatever the raid's length, but the HUD's "Spacegate
  arrives in" counts to the last 20 minutes of the raid (fixed 20), so a 60 minute raid said about 40 minutes and the gate came
  at 5. The two agree only in the stock 25 minute raid.
- Fix: raidtime.lua writes gm.TimeTillEvacSpawn in the warmup (a write in the raid does nothing; measured), and M.frame writes
  the countdown text every frame as TimeTillEvacSpawn minus the time gone, on the two live text blocks named
  Txt_SpacegateTimeArriveIn (the third, under /SIGISPlugin/, is the unused template). The HUD rewrites its text about once a
  second and its functions never reach a Lua hook, so a per frame write is the way. Found once, never searched for again.
- Verified (Space raid, length 60, gate 10): log "space gate: set to arrive 600 s"; EvacSpawned false at 585 s, true at 600 s;
  countdown read 06:23 at 229 s, 00:09 at 591 s, no flicker (live test from a probe).
- Not verified: the countdown as the mod's own code from launch (the first launch with it is the next test), instant, 15
  minutes, a raid shorter than the gate time, no limit raids, the launcher slider on screen (no Tk on the test machine).
- A game crash happened while live tests of the text scan were running; the log shows no error and the cause is not proven.

## Minefield raid condition (2026-11-19, no issue)
- `mines = N` in a raid condition (conditions.lua M.mines) has minefield.lua copy each space mine the map placed
  (RaidSubNodeActor classes with `NodeMine` in the name: Small_NodeMine_C, Nuclear_NodeMine_C) N - 1 times, scattered
  up to 90 m around it (at least 15 m away), with `world:SpawnActor(mine:GetClass(), at, rot)`. Once per world, 8 s
  into the space map, looking for up to 90 s; at most 400 copies. Shipped condition: [Minefield], mines = 20, loot 1.25.
- Verified: Space_Alpha, twice: "14 mines on the map, 266 more spawned", then "20 mines, 380 more" (the cap).
- Not verified: the copies seen, triggered or exploding in play. Another tool was driving the same game install during
  the test (opening Spaceport_01 on every bridge load and restarting the game), so whether the game stays up with 400
  extra mines is unknown. Test this first: a raid with Minefield picked, fly around a field for a few minutes.
