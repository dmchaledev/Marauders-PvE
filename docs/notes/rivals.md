# Rival crews and their ships

Rival crews: their ships, docking, ship combat, boarding (theirs and yours), pods, the Red Baron.

Part of the project's research log: [NOTES.md](../../NOTES.md) lists every topic file and every section title.
Sections are in the order they were written; a later section can correct an earlier one, so read to the end of a topic
before trusting a finding. When a section says "see X", search [NOTES.md](../../NOTES.md) for that title to find which
file it is in.

## Contents

- [Player-like rival bots — survey (2026-10-31)](#player-like-rival-bots--survey-2026-10-31)
- [Rivals module (mods/PvEDirector/Scripts/rivals.lua) — first build, 2026-10-31](#rivals-module-modspvedirectorscriptsrivalslua--first-build-2026-10-31)
- [Rival ships dock into berths (2026-10-31, user-confirmed)](#rival-ships-dock-into-berths-2026-10-31-user-confirmed)
- [Rival ship combat (2026-10-31, rivals.lua)](#rival-ship-combat-2026-10-31-rivalslua)
- [Event: the Red Baron in every raid (2026-11-16, #78; rivals.lua R.baron, F3 > Rival ships)](#event-the-red-baron-in-every-raid-2026-11-16-78-rivalslua-rbaron-f3--rival-ships)
- [Rival hulls and turrets (2026-11-01, rivals.lua)](#rival-hulls-and-turrets-2026-11-01-rivalslua)
- [Rival boarding and morale (2026-11-06, rivals.lua)](#rival-boarding-and-morale-2026-11-06-rivalslua)
- [Player boarding and stealing rival ships (2026-11-06, rivals.lua; first build)](#player-boarding-and-stealing-rival-ships-2026-11-06-rivalslua-first-build)
- [Rival interiors (2026-11-06, rivals.lua CFG designs `inside`)](#rival-interiors-2026-11-06-rivalslua-cfg-designs-inside)
- [Keeping a stolen ship (2026-11-06)](#keeping-a-stolen-ship-2026-11-06)
- [Rivals arrive through airlocks (2026-11-07, later)](#rivals-arrive-through-airlocks-2026-11-07-later)
- [Pods, parked ships, the Mini Mine berth (2026-11-07, evening)](#pods-parked-ships-the-mini-mine-berth-2026-11-07-evening)
- [Pod gun and ramming a rival (2026-11-08, ~13:00)](#pod-gun-and-ramming-a-rival-2026-11-08-1300)
- [Ship gunnery: variable rival aim, crew gunner by level (2026-11-08, rivals.lua gunAim + crew.lua gunnery)](#ship-gunnery-variable-rival-aim-crew-gunner-by-level-2026-11-08-rivalslua-gunaim--crewlua-gunnery)
- [Turret barrels: the gunner aims them, shells leave along them (2026-11-08, rivals.lua aimTurret + crew.lua)](#turret-barrels-the-gunner-aims-them-shells-leave-along-them-2026-11-08-rivalslua-aimturret--crewlua)
- [Rivals scraping stations and docking inside hulls (2026-11-14; shipnav.lua, rivals.lua)](#rivals-scraping-stations-and-docking-inside-hulls-2026-11-14-shipnavlua-rivalslua)
- [Pod breach input lock (2026-11-14, fix untested)](#pod-breach-input-lock-2026-11-14-fix-untested)
- [Pod boarding rework (2026-11-14, tested)](#pod-boarding-rework-2026-11-14-tested)
- [Rival crews dying in a heap at one airlock; rivals' edge over station guards (2026-11-14)](#rival-crews-dying-in-a-heap-at-one-airlock-rivals-edge-over-station-guards-2026-11-14)
- [Pod breach into Fortress put you in a wall (2026-11-16, logic tested at the spot; rivals.lua podExitCheck)](#pod-breach-into-fortress-put-you-in-a-wall-2026-11-16-logic-tested-at-the-spot-rivalslua-podexitcheck)
- [Pod breach prompt (issue 77, 2026-11-18; rivalcombat.lua playerBoarding)](#pod-breach-prompt-issue-77-2026-11-18-rivalcombatlua-playerboarding)

## Player-like rival bots — survey (2026-10-31)
Goal (user): "player" bots with random realistic loadouts, their own ship AI, who board you and enter stations
through airlocks like players, and are much more dangerous than the normal bots.
- Space_Solo_01 already runs, offline: 2 crewed AI frigates (Ship_FastFrigate01_Pawn_Ai_Child_C with
  AiFrigateController_Interceptor_C, Ship_RedBaron_StrikeFrigate01_Pawn_Ai_Child_C with AiFrigateController_RedBaron_C,
  ARaidAIShipController, tree /Game/Blueprints/Pawns/BotBehaviorShip = BotSearchEnemyLOS + BotShootEnemy + waits).
  They fly patrols (v 800/1200) on their own. Their interiors (FrigateInside_Fast_Ai_C / Strike_Ai_C) sit at the
  station coordinates with a captain (GOAPNodeBot_Boss_C). RaidFrigate.PlayerVersionOfAIFrig names the player class.
- 25 GOAP bots (GOAPNodeBot_Raider_C 100-250 hp, GOAPNodeBot_Boss_C 200-250) on stations and in AI ships, ASLEEP
  (dilation 0, unpossessed; GOAP_Controller_C kept in bot.CachedPlayerController). Loadouts are already random
  (Sten, M1 Para, PPSH, Bren MkII, Mat49, AC14, Johnson, GreaseGun, Liberator shotgun, China Lake, Webley/1911...).
  Controller AIActionsRowname = brain row (AverageRaiderSemi, EliteRaider ...); brains DefaultBrain_{Average, Elite,
  Rusher, Camper, Suppressor, Semi, Melee, Warden, Baron...}. Team 1 (= the player's team!).
- GOAP brain does NOT run offline: woken + possessed + StartActiveEvent + StartGOAPEvent + SetTargetEnemy(player)
  -> CurrentAction stays "", no movement. (A SpawnAIFromClass'd GOAPNodeBot_Raider_C gets a GOAP controller and
  200 hp but no gun and AIActionsRowname None: the proc manager applies MasterAILoadouts rows.)
- Navmesh: the space map has a baked static RecastNavMesh-Common (RuntimeGeneration 0) with 8 NavMeshBoundsVolumes
  covering the stations / AI ship interiors: bots there project onto navigation. The player's ship interior is
  spawned at runtime (~-110657,-244583) and has NO navmesh -> needs a runtime bounds volume (borrow an existing
  NavMeshBoundsVolume's brush, scale to FrigateInside.InSideComp extent 2550x3600x1250).
- Player ship interior: FrigateInside_Starter_C, 7 BreachTransforms (relative to the interior, e.g. -1444,-393,700),
  ShipDock*PlayerStart components. Breach API seen: RaidSpaceshipInside Breached/StartBreachedEvent/SealAirLock,
  RaidPlayerController ShipBreaching/ClientBeenBreached/NotifiyBreached, Ability_HumanBreachedIn.
- Stations: 11 StationAirlockDockingAreaAbility_C (ARaidFrigateStationDock) at Navy Outpost 1-6 / Spaceport 1-5;
  URaidUseableAirLockComponent StartTransferProcess/HangerDoTransfer.
- Waking a bot without the director's full wake() gives the floating helmet (gear master pose) and arms out of sync
  with the gun (user saw both). Always use the full wake.
- CRASH: a bridge script reusing an actor kept in a Lua global from an earlier command (_G.TBOT, probably dead or
  destroyed by then) crashed the game inside UE4SS (AV 0x18). Never keep actor references across commands/frames
  without re-finding them.

## Rivals module (mods/PvEDirector/Scripts/rivals.lua) — first build, 2026-10-31
- Population = the map's FrigInteriorSpawn slots - 1 (Space_Solo_01: 12 slots -> 11 crews; solo maps 1 per ship,
  crew maps 2-4). Ships: Ship_FastFrigate01_Pawn_Ai_Child_C / RedBaron Strike Ai_Child via SpawnAIFromClass at
  ShipSpawn points; flown with direct MoveToLocation (no pathfinding). The frigate's own AI keeps issuing patrol
  moves, so ours is re-issued whenever GetImmediateMoveDestination isn't ours (before that fix nothing docked).
- Stations found by survey: navmesh volumes named by station airlocks (Navy/Spaceport), anchors (Fortress, Merchant)
  and AI frigate interiors; space targets = Node_* RaidDockingComponents / the AI frigate pawn. Which stations and
  AI frigates exist varies per run.
- Bodies: GOAPNodeBot_Raider_C with AIControllerClass swapped to the soldier's RaidAIController (CDO write), gun from a
  BotPawnMilitary_C donor whose CDO WeaponTable picks the tier (AI/Security/Commando). Gun re-attached to
  CharacterBody0 (raider CharacterMesh0 is the head). Struct row-handle writes (WeaponToSpawn etc.) fail in UE4SS.
- Space maps: director now rebuilds the navmesh at runtime (fresh dynamic RecastNavMesh + a volume around your
  ship's interior), ~3-18 s; then Rivals.update + the soldier AI run.
- Verified in game: 11 crews launch, dock (Merchant), attack your ship, pull alongside and board (bodies at your
  breach points, StartBreachedEvent alarm, boarders engage). First build was far too aggressive (rolled every 0.5 s):
  now one decision per sighting, ~20% attack, max 2 attackers at once.
- Breaching pods (WORKING, verified 08:33): Ship_DropPod_Pawn_C spawned with an AI controller crashes ~0.5 s later:
  a timer (pod delayforLocalSPawnAbility, default 0.5; fn RVA 0xa0ae0a0) casts Controller (+0x258) to a player
  controller and calls vtable +0x6c0 on the result with no null check; with no controller it returns early. Writing
  the CDO's delay did NOT reach spawned pods (crashed again). Fix: SpawnAIFromClass, then UnPossess + destroy the
  controller in the same Lua call. Pods spawn hidden (show them) and are flown frame by frame from the director tick
  (Rivals.frame), aimed each frame at ship.Mesh:GetClosestPointOnCollision (frigate exteriors are small, ~1200 long).
  On contact: K2_AttachToComponent(ship.Mesh, KeepWorld), pod BP events DropPodisBreaching(true) /
  BreachingEffects_Part1_Movement(true) / ForceDropBoostingEffectForBreach(), ServerSetFrigateBreaching(ship,
  "DockAim") (impl RVA 0x183da40: stores ShipBreachingTo/socket, starts ability 9 only for a RaidPlayerController),
  then SpaceshipInside:StartBreachedEvent + pc:ClientBeenBreached (both safe). 2.5 s later the rider's body appears
  at a breach point. BreachCheck (RVA 0x18252c0) = trace from the pod's own "BreachAim" socket BreachingDistance
  (1250) forward hitting a RaidFrigate / breachable node; target ships only have a "DockAim" socket.
- Testing: touch bridge/rivals_provoke (or F4) = nearest crew attacks now (12000 out, pods after ~10 s).
- Tools: scratchpad dis.py / fn.py / ufn.py pattern = procmem.read + capstone; UFunction Func at +0xD8; *_Implementation
  via the object's vtable (thunk shows the offset).
- Boarders "friendly, gun lowered" (fixed): the donor's gun only went into the raider's Inventory; arm() equips
  CurrentWeapon, which was empty, so they never fired. rivals.lua holdGun() equips it (ServerEquipWeapon) and keeps it
  attached to CharacterBody0 (equipping attaches it to CharacterMesh0 = the head, where it's invisible); re-checked
  every update. Verified: MG42 boarder armed on arrival, shooting once in sight (counted via a hook on
  RaidWeapon:ServerMultiSimulateWeaponFire). A ship spawned this frame reads MainHullHealth 0 until it ticks.

## Rival ships dock into berths (2026-10-31, user-confirmed)
- Bug: docked rival ships just stopped within 2500 of a dock volume and floated outside the station (random
  heading, several crews piled on one dock).
- Berths: station nodes answer `ReturnAreaEntranceMoveToLocation(ship, dockComp, out FTransform, out cam, out boom)`
  (out FTransform DOES marshal from Lua). Navy Outpost / Spaceport return the berth the docking ability flies your
  ship to (inside the hangar bay, nose-in; ignore the pitch/roll, they belong to a marker mesh: yaw = quat yaw).
  Merchant and Fortress return zeros: there the berth is the docking volume itself along its long axis, nose toward
  the node. Fortress' two volumes overlap (one bay) -> deduped. AI-frigate "stations" get two berths alongside
  (ALONGSIDE 3000, follow the frigate). Survey found: Spaceport 6, Merchant 2, Fortress 1, AI frigate 2.
- rivals.lua: a crew reserves a free berth (stations with free berths preferred; all taken -> wait off the station
  BERTH_WAIT 45 s, then go elsewhere), flies to the approach point 3500 out, glides in (DOCK_GLIDE 7 s, smoothstep,
  in R.frame), is held there (actor AND controller rotation: the ship's AI controller keeps turning it otherwise),
  and glides back out (UNDOCK_GLIDE 5 s) before flying off. flyTo is ignored while gliding.
- Calling RaidDockingComponent:FrigateDocking(ship) / sweeping the player ship into a volume from the bridge did
  nothing (the real flow needs the helm/ability); not needed.
- Screenshots: an always-on-top window masks the game for computer-use; use the console `shot` (bridge) ->
  %LOCALAPPDATA%/RaidGame/Saved/Screenshots/WindowsNoEditor/. bridge/t_view.lua / t_view2.lua aim the player's ship
  (possessed via pc:Possess) as a camera.

## Rival ship combat (2026-10-31, rivals.lua)
- Why ships never fired: every frigate's DefaultInventoryClasses = InGame_BowGun_50Cal_C, never spawned offline
  (CurrentWeapon nil, also YOUR ship). And ARaidAIShipController::ShootEnemy (thunk 0x18dabc0 -> 0x17ed260) only fires
  if the pawn is a RaidFrigate with MyShipInside (+0xC90, a crewed interior: 0x1867230), hull > 0, BB Enemy a
  RaidCharacter with bShipAttackable (+0x54D), LoS, and the pawn's CurrentWeapon can fire. Rival ships have no
  interior, so their own ShootEnemy can never fire.
- Fix: `summon InGame_BowGun_50Cal_C` (console cheat, works) + SetOwner/Instigator/MyPawn/OnRep_MyPawn, append to
  ship.Inventory, ship:ServerEquipWeapon (armShips; your ship gets one too). Fired with gun:ServerStartFire/
  ServerStopFire from R.frame (fireControl): bursts while the target is within GUN_RANGE and GUN_CONE of the nose;
  the gun aims along the AI controller's view (K2_SetFocus target). Verified: rival vs rival 20-43 bursts per fight,
  ships sunk; your hull took hits (575 -> 540). Long range = many misses (GUN_RANGE now 6500).
- Swarming: the frigates' own behaviour tree (FindShipToAttack -> nearest ship, usually yours) steered every ship
  at you. Rival ships now get Controller.BrainComponent:StopLogic at spawn; rivals.lua alone decides targets/moves.
- Combat model: travelling crews size up every ship in sight (yours or another crew's) once per ATTACK_COOLDOWN,
  attack with aggression^2 x ATTACK_CHANCE (0.45), max MAX_ON_SHIP (2) attackers per target; shot at -> fight back
  (c.shotBy from fireControl, else you if close). Attack runs: fly at the target firing (nose slewed onto it at
  NOSE_TURN deg/s), overshoot 2500 past, swing out 5-7 km, repeat; break off after ENGAGE_MAX or when the target is
  gone; flee + extract below FLEE_HULL.
- Boarding (your ship only): decided per fight: BOARD_ONE 0.35 (crews of 2+, one member boards, ship keeps fighting),
  BOARD_ALL 0.08 (whole crew; solo crews' only chance). Boarders are a "party" (members flagged m.boarding, own
  materialize/dematerialize via a party table); pods take only them. Station visits leave boarders out. NOT yet
  seen in game (solo map = crews of 1 = 8% chance).
- Simulated clashes: two simulated crews docked at one station: SIM_CLASH_PER_MIN 0.25 that one loses a member.
- End of raid: GameState.RemainingTime (seconds; round 1500). Each crew heads out at EXTRACT_REMAINING (150-420 s
  left): flying crews extract, docked crews walk back to the airlock, undock and extract, boarders go back.
  Verified by setting RemainingTime from the bridge (300 -> flying crews left; 140 -> docked crew left and extracted).
- Stations: materialized rivals roam areas; hunters (0.25 + 0.5 x aggression per re-home) pick your area (logged
  "is hunting through your part of"). Not yet watched; rival bodies in one station don't fight each other (same team,
  director AI targets only you).
- Probe rule (crashed once): never touch an actor from FindAllOf without IsValid (destroyed ships are still listed).

## Event: the Red Baron in every raid (2026-11-16, #78; rivals.lua R.baron, F3 > Rival ships)
- Hayley on #78: event presets are welcome, guaranteed bosses first, reachable from the lobby, more loot when a preset
  makes raids harder. This is the first slice: one setting, BARON (0/1, off by default), in the F3 Rival ships tab. F3
  works in the lobby, and the value is saved with the other tuning (config/ai_tuning.txt, id Crews:BARON).
- The map's own Red Baron (Ship_RedBaron_StrikeFrigate01_Pawn_Ai_Child_C with AiFrigateController_RedBaron_C and a
  GOAPNodeBot_Boss_C captain) is rolled by the game per run and its GOAP brain doesn't run offline, so the guarantee is
  one of our crews: makeCrews turns crew 1 into the Baron's (at least one crew even with CREWS 0 / no slots).
  R.baron.make: the Strike Frigate design (no turret refit), a full crew (CREW_SIZE max), diehard, never a rusher,
  aggression 1, gunnery = GUN_SKILL max; captain "Red Baron" with the game's Baron_Head_Skel_01 / Baron_Body_Skel_01
  (headPath/bodyPath, as hired crew use), GearScale.spec(1) gear, helmet/chest/bag worn, 2x BASE_HP. He keeps the
  "rival" AI profile: ai.lua "boss" is weaker than "rival" (typeMod .75, miss .4).
- rivals.lua's main chunk is at exactly Lua's 200-local limit (adding even one top-level local fails scripts/luacheck.py),
  so the helpers are fields of R.baron. Check with luacheck before adding any local there.
- Tested in game (2026-11-16, Space_Solo_01, BARON set to 1 from bridge/dir_eval.lua, mod scripts from the branch laid
  over the offline copy): "solo map, 12 player slots: 5 rival crews"; "Red Baron's Strike Frigate (4) launched in a
  Strike Frigate (RocketArtillery): heading for Navy Outpost"; a Ship_RedBaron_StrikeFrigate01_Pawn_C in the world
  (bridge find); docked at Navy Outpost a minute later; no Lua errors. Not seen yet: the captain's Baron look in
  person, and a fight with him.
- Next (#78): event presets (config/event.txt or a lobby picker) bundling map + overrides, loot scaling for harder
  presets, other bosses.

## Rival hulls and turrets (2026-11-01, rivals.lua)
- The player ship designs live in DT_ShipInfo (26 rows: name, hull mesh, Turret01/02Type), DT_FrigateStats (speed,
  turn, armour, hull) and FrigData (interior prefab). The 26 designs are 6 base pawns (/Game/Blueprints/Ships/
  Ship_{Scout,Fast,,VIP,CapitalShip,RedBaron_Strike}Frigate01_Pawn) plus hull meshes in the same folders (same
  skeleton: SetSkeletalMesh keeps Soc_Turret01/02). All 6 fly under SpawnAIFromClass's plain AIController
  (MoveToLocation works) but have NO blackboard: setShipEnemy only sets focus for them.
- Turrets are separate actors (ARaidCharacterTurrent) attached to the hull mesh's Soc_Turret01/02 (scale 1.25). The
  hull blueprints spawn their own default turret (and 2 camera turrets); fitTurrets replaces the default one.
  Classes in this build (Ships_Extras/Turrets): SingleTurret01, Dual25mm01, 75mm_Turret01, RocketArtillery01 (12
  barrels), TorpedoLauncher (3). Triple/Flak/Howitzer/Nuclear/DualRockets have no class: mapped to the nearest.
- Firing without a gunner: turret:ServerFireProjectile(origin, dir, socketIndex) spawns its ProjectileConfig shell
  with its effects and explosion damage (verified: 75mm 120 + torpedo 300 took a Scout 650 -> 230). Projectile
  speeds (InitialSpeed): 25mm 18500, small shell 15500, missile 17500, 75mm 10000, torpedo 3500 (CFG.TURRET_TYPES;
  reading the CDO's ProjectileMovement from the director returned a UObject, not the number). FireRate/ReloadTime/
  TotalAmmo come from the turret. Turrets swing +-60 deg yaw, 0..15 pitch.
- Rivals: CFG.HULLS (weighted: scouts/interceptors common, heavies less, capital ships rare), 25% chance per turret
  slot of a refit with another type. Turrets fitted one ship per armShips pass; removed with the ship.
  Verified: 11 crews in 11 different designs, 58 turret shots in the first fights, crews extracting with hull damage.
- Lua checks: scripts/luacheck.py (the old lupa `load(...)` check never failed: load returns nil + message).
- Trailer capture: the lag was 30 fps CPU-encoded capture. rec.sh now records 60 fps with the AMD encoder at native
  size: the game holds 90 fps while recording. Never call FindFirstOf in a per-frame camera target function (19 fps).

## Rival boarding and morale (2026-11-06, rivals.lua)
- Rivals board each other: engage() rolls RIVAL_BOARD_ONE/ALL, real pods fly at the target (S.pods entries carry .ship). AI ships have no interior,
  so the fight is simulated (fightAboard: one kill per BOARD_ROUND, odds 0.5 + skill gap x BOARD_SKILL). Boarders who clear it keep the ship
  (captureShip: it keeps its name, the old ship is destroyed if nobody is left on it). Happens on its own: seen with no forcing, Slag vs Salt Witch etc.
- Diehards (DIEHARD 0.35): never flee, never "had enough", chase to SHIP_SIGHT x 4, ignore the raid clock while fighting. Others flee at a rolled
  10-25% hull (was a flat 30%); ENGAGE_MAX 80-160 s (was 50-110). Player boarding: BOARD_ONE 0.45, BOARD_ALL 0.15 (was 0.35, 0.08), BREACH_AFTER 20-55 s.
- Pods aim at the hull's side (podAim, POD_ALONG/POD_SIDE), not the closest point to the pod (which from behind was the engines), and vanish on impact
  (user: an embedded pod looked awkward; the rider still cuts through BREACH_DELAY later). Measured on the starter frigate: -164 to +156 ahead of centre, about 50 to the side. Not looked at on screen.
- Known gap: a parent ship that extracts mid-fight stops updating its party, so those boarders just stop; the victim carries on.
- Test triggers: bridge/rivals_clash (two crews, boarding), bridge/rivals_board (provoke + boarders). Provoked ships spawn 12000 +X of you and at the
  start spot park ~9000 out, likely on the nearby station; bridge/t_nudge.lua moves them into pod range. t_ships.lua lists distances.
- Player boarding a rival: NOT possible yet. Rival hulls have no MyShipInside, which breaching needs. The map has FrigInteriorSpawn slots and the
  game spawns interiors for AI frigates (AIFrigateInsideToSpawn), so the likely route is giving a rival's hull an interior. Stealing also needs
  pilot handover and what happens at extraction. Not attempted.

## Player boarding and stealing rival ships (2026-11-06, rivals.lua; first build)
- Spawning FrigateInside_Starter_C at a free RaidFrigateIntSpawn slot with World:SpawnActor brings its own streamed level AND spawns + pairs its own hull
  (plain AIController, hull.MyShipInside set). Space_Solo_01 has 12 slots; yours takes one. RaidUseableFrigateHelmComponent:Interact(pawn) on that interior
  possesses whatever SpaceshipToPairTo points at, a rival's hull included: pc.Pawn becomes it. OnUsed is a delegate, not callable.
- Flow: your pod (pawn.bADropPod) within PLAYER_BOARD_PREP of a flying rival -> makeInterior; next crew update pairInterior swaps the auto hull for the rival's
  and adds a nav volume (addInteriorNav); within PLAYER_BOARD_RANGE of its centre -> breachInto: Possess the on-foot pawn at the first breach point, destroy
  the pod. Inside (place "rival", S.aboard) the crew materializes as "boarding" bodies. Crew dead: state "derelict", ship stops. Helm: checkStolen sees
  pc.Pawn == c.ship and makes it S.playerShip / S.homeInside; the crew goes to "gone". Your old ship stays where it was. Max PLAYER_BOARD_MAX interiors a raid.
- Interiors by design: see "Rival interiors" below.
- Verified end to end (bridge/bd_test.sh, Lucky Strike): interior ready, breached, 2 armed bodies in the ship, helm, "you took". NOT verified: a pod launched by real F
  (the dock's Interact does nothing from the bridge; test pods are spawned beside the hull and possessed), a fight with those bodies, helm by real F (bridge
  calls Interact), extraction with a stolen ship, leftovers of the destroyed auto hull (its turrets), the SetControlRotation facing line (added after the last run).
- Crew still alive when you take the helm: they stay as bodies, but their kills no longer count (crew is "gone").
- FPS: 90 dropped to 5-15 about 40 s into a map, BEFORE any interior was spawned, and not tied to nav building (90 while building, 7 idle). Wow.exe was the foreground
  window and Roblox open, game window in the background, 4.9 GB RAM free. Likely that, not proven: measure with the game focused.

## Rival interiors (2026-11-06, rivals.lua CFG designs `inside`)
- /Game/Data/FrigData column 0x18 (tools/offline-audit/frigdata.py) gives each design its FrigateInside_* class. All 26 load and spawn, and each pairs its exact hull variant.
- LoadAsset on a cooked Blueprint needs "Path/Name.Name": the bare package path does nothing, silently (no "Asset loaded" line), and the class then appears as Name_C. loadClass uses that form.
  LoadClassAsset_Blocking with a soft path table crashed in Lua marshalling; don't use it. tools/offline-audit/fnames.py searches the whole FName pool, cooked asset names included.
- Real levels: Starter, Scout (all scout classes), Capital (all capital classes), Strike, plus Merchant and the _Ai ones. Every Interceptor, every Heavy and the VIP point at /Game/Maps/Main/ShipBlockOut:
  a grey roofless box open to space, seen on screen. So Interceptors use DefaultScout, Heavies use Capital, the Vulture uses Strike. LevelPath is what the level really is here (checked in StreamingLevels).
- Strike and VIP interiors have 0 BreachTransforms: entryPoints falls back to the ShipDock*PlayerStart components, solid floor at Z 2430 on Strike. Helm spots are NOT safe to stand at: on Fast and Strike the spot next to
  the helm has no floor and you fall into space. Whether the helm can be walked to on each interior by a real player is unchecked.
- Verified with full runs: Heavy Raider -> Capital interior, Strike Frigate -> Strike interior: breach, 3 armed bodies, helm, stolen. Scout family spawned and floor checked, not boarded. Fast_Frigate_01_Ai_Interior is a real level
  that only the map's own AI ship uses; it could serve Interceptors better if a way to stream it for a second ship turns up.
- Pods vanish on impact: 3 hits in the last session with riders aboard after, no crash. Not watched on screen.

## Keeping a stolen ship (2026-11-06)
- Works, by the game's own path: extracting at the gate while piloting a stolen hull goes through Client_GetOutWithLootAndShip, and the lobby (after the return to the menu) PUTs an inventory item:
  "47943293-StrikeFrigate_Ship-1-Vanquisher-0!0!0!0!0" equip true. The row is right for the hull stolen; the name is rolled by the game.
- The hangar lists it: MY SHIPS shows Vanquisher / Strike Frigate with the hull in the bay, its stats, and the green active bar with no click. Rustbucket is the "BACKUP SHIP". Slots 1/3. Reached with bridge/t_play.lua (splash Play) and
  t_tab2.lua (overlay Btn_TEMP_SubBtn_Hangar). PgosOverlay covers half the lobby after the 30 s sweep ends: t_tabs.lua hides it. InventoryMenuWidget.ActiveFrigate (+0x7B0) is null until the hangar page opens.
- A ship item with equip:true is in loadout.json, so it counts as gear: watch_checkout takes it out at raid start and only extraction writes it back (same id). Leaving a raid with `open MainMenu` or dying loses it. That is how the first test lost it;
  restored by hand (backend/state.before-ship-restore.json is the save without it). Round trip verified once: raid start took 47943293, gate, wrote 47943293 again, still in the save.
- The raid ignored it: Starter interior and hull both times, hangar opened or not, and the interior is named after the ship. Offline nothing reads the active ship when spawning you. It's independent of ActiveFrigate.

## Rivals arrive through airlocks (2026-11-07, later)
- Every station with RaidFrigateStationDock airlocks (StationAirlockDockingAreaAbility_*: Navy Outpost, Spaceport, Asteroid Mine, Penal Colony, Rebel Base, Moon Base, Colony Cruiser, Planet Killer) gets st.locks in survey(): chamber floor (InSideComp box), station-side button (OpenButton). Fortress, Merchant, Mini Mine have none: old arrival (pop in at an entry point).
- A docking crew takes c.lock = pickLock: berth i -> airlock i (sorted by name), skipping one your ship is docked at (DockedShips) or another docked crew holds. Docking while you're inside (FRESH_DOCK 25 s): bodies are built in that chamber (door closed, out of sight), crewArrival holds them (no rehome/patrol) for ARRIVAL_MIN 6 s and until armed (ARRIVAL_WAIT 12 s cap), then StartDoorEvent(true): the game's own hatch sequence (wheel, steam, opens in ~8 s; the passage unblocks at once, so they wait DOOR_OPENING 7 s), then walk to lockExit (past the button) and search as before. The door closes (StartDoorEvent(false)) ARRIVAL_CLOSE 10 s after, once nobody stands in the chamber. Leaving: they walk back to the same airlock.
- Verified: Asteroid Mine (2 of 2 and 3 of 3 in the chamber), Penal Colony (1 of 1), Navy Outpost on Space_Solo_01 (2 of 2); frames show DOCK-3C open and a rival stepping out. Open/close checked by eye from inside a chamber. bIsOpen stays false through StartDoorEvent; DoorMesh / bone reads don't show the animation (and GetBoneName/GetSocketLocation from Lua crashed the game once).
- Not done: a cue before the door (the hatch sequence itself is the warning: ~6 s cycle + 7 s opening); linking the ship's real dock to the airlock (the berth -> airlock map is a fixed assignment, not what the game would pick).
- Tools: bridge/t_lockprobe.lua (doors, chambers, paths; LOCK_OPEN/CLOSE), t_inchamber.lua, t_watchlock.lua, t_arrivals.lua. backend/state.before-airlock-test.json.

## Pods, parked ships, the Mini Mine berth (2026-11-07, evening)
- Black void after a pod breach (user): the pod hit a rival ship parked at the Mini Mine (state "docked"). playerBoarding only made interiors for flying crews, so the hull had no MyShipInside and the game left your on-foot body where it parks during a pod flight, at 0,0,0. Docked ships are boardable now. rescueFromVoid: on foot within VOID_NEAR (3000) of 0,0,0 for VOID_RESCUE (3 s) -> moved to your own ship's first entry point, with a message. (The user's stuck game was rescued by bridge/t_rescue.lua.)
- Guard on parked ships (user: no easy cheese): a docking crew gets c.watch = SHIP_WATCH 1-2 extra members (setWatch, newMember, crew team, rolled like the crew, kept for the raid). Boarding a docked ship materializes the living watch at breach spots other than yours (mode "boarding", alert). The docked branch no longer dematerializes boarding bodies (it did every update: the watch was rebuilt over and over). Verified: Stray Dog, 2 of the watch aboard, 26 and 30 m from you, team 20, armed; logged once.
- Grease Gun on the pod (user: the gun they carried): while pc.Pawn.bADropPod, main.lua hides the on-foot body's Inventory guns (SetActorHiddenInGame) and shows them again on foot. Verified hidden=true in the pod, false after.
- Ship flying into the Mini Mine rock: (1) its one berth was the 0.8 m RaidDocking00 marker 7 m under the real RaidDocking01 dock (dedupe kept the first): now the biggest volume of overlapping ones, and BreachVolume components are not berths (the biggest-volume rule had picked the Colony Cruiser's). (2) Crews waiting for a full station held at approach + c.id x 900 in X, + 1500 Z: now HOLD_OUT 2500 + spacing straight out along the approach lane. Verified: docked ship 5 m over RaidDocking01 at rest; three waiting ships 115-180 m out, drifting in open space. Each berth is logged at survey. The Mini Mine's position differs per run.
- Tools: bridge/t_podto.lua (POD_PHASE spawn/step/guns, POD_NEAR, POD_OFF), t_whereami.lua, t_bowguns.lua, t_shipsnear.lua, t_rescue.lua. Interiors cap PLAYER_BOARD_MAX 4 per raid; a pod's route can board another ship first (that's correct).

## Pod gun and ramming a rival (2026-11-08, ~13:00)
- User: their gun still showed on the pod (Pistol Training loadout), and ramming a rival with a pod never breached. Log: the Brass Monkey's
  interior loaded at 12:51:59, then about a minute of pod flight with no breach. breachInto needed the pod within PLAYER_BOARD_RANGE (1800)
  of the hull's CENTRE; the hull stopped the pod farther out. Now the pod also breaches within PLAYER_BOARD_TOUCH (600) of the hull's
  collision surface (rivals.lua hullGap, ship.Mesh:GetClosestPointOnCollision).
- Pod guns: main.lua hidePodGuns hides every RaidWeapon whose MyPawn is your body or that sits within 8 m of the pod, plus Inventory and
  CurrentWeapon. Hidden flags are re-applied every update (the old fix hid once), FindAllOf scans run at 0/1/4/10 s into the flight,
  and each gun hidden is logged once as "pod: hid <name> (carried|held|yours|on the pod)". Any pawn whose class name has "Pod" counts as a pod
  too (escape pods). NOT verified in game yet: copied into the game's Mods folder while the user was at the menu.
- Gun attachments on the pod (issue #18, 2026-11-15): a gun's attachments are actors of their own in its slots
  (RaidWeapon MuzzleSlot / SightSlot / LowerRailSlot / UpperRailSlot / MagSlot / StockSlot / SpecialSlot, e.g. a Mat49's
  Attach_Mat49_Wooden_Stock_C and Mat49_Default_Magazine_C), so SetActorHiddenInGame on the gun left them drawn. hide()
  now hides the slot actors too and keeps them in raid.podGuns, so the on-foot pass shows them again. Test save: a
  stash string with the stock in the 6th attachment slot (`<id>-Mat49Rifle-32-100-0-0-0-Prim-0!0!0!0!0!Mat49WoodenStock!0`)
  spawns the gun with StockSlot = Attach_Mat49_Wooden_Stock_C (so the 7 slots run Muzzle, Sight, LowerRail, UpperRail,
  Mag, Stock, Special, and a slot holds the attachment's row). Launched by InteractionDetection + ServerUse on
  RaidUseableComp_DropPod01: before, the hidden guns' StockSlot/MagSlot actors were still visible; after, all hidden
  (held, carried and the pod's own copy). Not seen: showing them again back on foot (the pod never landed in the test).

## Ship gunnery: variable rival aim, crew gunner by level (2026-11-08, rivals.lua gunAim + crew.lua gunnery)
- Before: every turret shot used a perfect lead and only the turret type's own spread, so every rival crew aimed the same,
  and your gunner's spread was rolled once at hire (a promotion never changed it).
- Now each rival crew rolls a gunnery skill (GUN_SKILL 0.3-0.9, logged in "engages ... gunnery 0.xx"). fireTurrets
  keeps their aim per target (c.aim): a new target starts off by GUN_FIRST_MISS deg (crack: 30%) with the lead misjudged
  by up to GUN_LEAD_ERROR; each volley walks GUN_SETTLE of it off (green: half); the target turning puts GUN_JINK deg per
  10 deg back; a green gunner drifts GUN_WANDER deg per volley; spread = type spread x TURRET_SPREAD x GUN_SPREAD_SKILL.
- Your gunner: crew.lua gunnery(m) = GUN_SKILL[1]..[2] (0.2 at level 1 to 0.9 at level 5, linear, read live so promotions
  count) - aimRoll x GUN_TALENT (lifelong, +/-0.1). Passed through R.gunnerFire(turrets, tgt, now, S.gun). hire.lua's old
  gunSpread is no longer rolled (old saves keep a harmless field).
- F3 menu: new "Ship guns" tab (all rivals.lua GUN_* above) and three rows on "Your crew". Tabs are now split evenly over
  two rows (14 tabs; the third row used to run into the Difficulty buttons). The difficulty presets don't touch ship guns.
- Defaults picked offline (scratchpad gunsim.py, frigate hit box ~900 x 540): at 7000 units a green gunner (0.0) lands ~12%
  of its first 3 volleys and ~24% after, mid (0.5) 31% / 70%, crack 83% / 100%; at 4000 roughly double for the poor ones.
  The old model hit ~100% at both ranges, so rivals are weaker at long range now unless set to high gunnery.
- Verified in game (bridge/gn_test.sh after gs_test.sh): no errors, crews logged gunnery 0.43-0.86, Nell (level 1) 0.14,
  169 turret shots in the raid, both menu tabs on screen. NOT measured in game: actual hit rates on your ship / rivals.

## Turret barrels: the gunner aims them, shells leave along them (2026-11-08, rivals.lua aimTurret + crew.lua)
- Bug: at the helm with a crew gunner your mouse still swung your hull's turret, and the gunner's shells flew at the
  target whatever way the barrel pointed. Rival turrets idled sideways (Yaw_Delayed -90) while firing ahead.
- What moves a barrel (probed with bridge/t_turaim, t_turforce, t_turall): NOT TurretLocalRot (writing it does nothing
  visible). Every frame the turret AnimBP's CameraRotation(worldRot, -80, 80, 10) event turns a world rotation into
  Yaw_Delayed (deg off the hull's nose) and NewPitch, which the bone reads. Your hull's turret gets the pilot's view
  there from the ship itself; rival turrets get GetTheRequiredrotation() (ControllerHere's view). Lua hooks on BP
  functions run AFTER the event (UE4SS: "both callbacks act as post"), so setting its param does nothing, and
  overwriting RotationFromCamera is too late; writing Yaw_Delayed / NewPitch in that hook does move the barrel, on all
  7 turret AnimBPs (LightTurret, Dual25mm, Flak, 75mm, Artillery, LargeTurret, TorpedoLauncher). Barrels showed
  pitch -15..+10 or more (anim clamp) whatever TurretMin/MaxPitch (0..15) says. The 75mm's barrel socket is turned
  90 deg in its own frame, so shot headings come from the commanded yaw/pitch, not the socket rotation.
- rivals.lua: AIMED (AnimBP address -> fireTurrets entry); swingBarrel (the hook) steps yaw/pitch toward
  wantYaw/wantPitch at TURRET_SWING x TurretYawSpeed/PitchSpeed (20/10) and writes them. fireTurrets runs every frame:
  sets want from the gunner's aim (gunAim errors included; TURRET_ARC, TURRET_PITCH), fires a loaded turret only when
  its barrel is within TURRET_ON_AIM deg, along the barrel (+ spread). Rival turrets registered when fitted (retried
  per second until the AnimBP exists), dropped with the ship; AIMED cleared per raid.
- crew.lua: holdTurrets also takes the barrels (R.aimTurrets on), releaseTurrets gives them back (off: the pilot aims
  and fires the first turret again, as solo); no target = R.restTurrets (nose). Tuning: "Turret traverse", "Fires
  within" on the Ship guns tab.
- Verified 17:10 (Starter, Nell gunner): at the helm view +45 -> barrel stayed 0. Provoked fight: 32 gunner shots,
  each within -1.9..+1.7 deg of the barrel's yaw (= spread), barrel at -30 on the target while the view sat at +45;
  175 turret shots in the raid, no errors, 84-90 FPS. NOT verified: barrel handed back on leaving the helm, targets
  below -15 deg (now never fired at), rival turret hits, the gunner seat (gunseat.lua still fires along the camera).

## Rivals scraping stations and docking inside hulls (2026-11-14; shipnav.lua, rivals.lua)
- Seen live (asteroid-field raid): a ScoutFrigate rival flew into a station, dragged along its underside, turned, slid into
  its berth and then showed above it. Probably Widowmaker at the Capital Ship (docked 01:29:04 in that run, no stuck or
  lifted lines in the log).
- Cause 1, the scraping: shipnav's obstacle sweeps never hit anything. `SphereTraceSingleForObjects` with an object-type
  list from Lua returns false every time, even through a BlockAll rock (the enum array doesn't get through; cover.lua had
  found this for line traces). The status line always read "detours 0". `ActorsToIgnore` arrays don't get through either:
  only the world-context actor is skipped (bIgnoreSelf). Checked with dir_eval probes: by channel (Visibility, 0) the same
  sweeps hit rocks, the Rebel Base, the Capital Ship node and its turrets, and other ships.
  Fix (shipnav.lua `blocked`): `SphereTraceSingle` on CFG.TRACE_CHANNEL 0, ship as world context; a hit on an actor in the
  ignore list (target, turrets, gun) counts as clear; a sweep that starts touching something counts as blocked only when
  heading into it, so a ship along a hull can still be steered off.
- Cause 2, no idea of the station: the move goes straight to the berth's approach point. rivals.lua `dockRoute`: each
  station berth keeps its node's bounds (`b.hull`: owner GetActorBounds plus the berth; an AI frigate's live bounds).
  A docking ship flies to the lane's entry (out along the approach lane to where it leaves the bounds + HULL_MARGIN 2000),
  going round the bounds' corners/edges/faces when the way is blocked (straight out the nearest face first when it's
  inside them), and only heads for the approach point once it's on the lane (within LANE_WIDTH 1500 of its line, past
  BERTH_APPROACH / 2). The glide in starts only within DOCK_ARRIVE of the approach point AND DOCK_LANE 900 of the lane's
  line, never beside or under the station. Checked offline (lupa, rivals.lua's own functions): from 12 points around
  each of Rebel Base berths 1 and 3, the Capital Ship and the Mini Mine every ship docked without entering the bounds;
  from under the hull it leaves through the nearest face first.
- Cause 3, sitting in the hull: nodes with no berth transform (Capital Ship, Mini Mine, Merchant, Fortress) dock at the
  volume's middle. The Capital Ship's is 1.3 m off the hull's side, beside a rocket turret: a sphere of 500 there
  penetrates the node by about 290, so a ScoutFrigate (bounds 737 x 737 x 600) sat half inside the hull and stuck out of
  its top. A sweep from the docked Bad Penny's middle started inside the Capital Ship node. `clearOfHull` (survey, volume
  berths only) moves the berth sideways along the hit normal, in steps, till a BERTH_CLEAR 500 sphere fits (at most
  BERTH_CLEAR_MAX 3000; height kept; stops at a ship or a floor or roof). Once it's pushed back the way it came (wedged
  between hull and turret), it moves straight out along the lane. Dry run on the live map: the Capital Ship berth moved
  from -101564,17395 to -102132,18815 (15 m out along its lane), its other dock 724, Mini Mine 0. Game berths (ReturnAreaEntranceMoveToLocation: Rebel Base, Spaceport) are
  kept: they put your ship in docking clamps that any sphere overlaps (Rebel Base berth 1: 684 deep, normal straight up).
  Pushing those out would lift ships above their berths.
- The glide and the hold agree: both use berthPose's `at`. Three moored ships measured 0 from it (one 28, under the
  hold's 30 tolerance), with zero velocity and the actor, capsule and mesh all at one point. No Z offset between them;
  station nodes don't move.
- Another way to see a ship jump up: shipnav lifts a ship stuck 3 times 2500 away (up-weighted) when it's NUDGE_FAR
  25000 from your ship, but a trailer camera can be right there. Now it must be that far from your ship and from the
  camera (`S.watchers`: your ship, PlayerCameraManager location).
- In game (01:48-01:51, hot-swapped into the running director, S kept): two leaving ScoutFrigates were sent back in.
  Bad Penny went to the Capital Ship from far out along its lane, never inside the bounds, and the glide started on
  the lane. Moored at the moved berth: 0-1 off in Z, sitting in open space between the station's turret towers, nose to
  the hull. Brass Monkey came at the Rebel Base from behind, took a waypoint round the station, came onto the lane,
  glided in and sat centred in the docking tunnel (dz 0). The steering line went from "detours 0" to "detours 32"
  in 3 minutes. Stucks went on (mostly Grey Mare and Iron Gull, as before the swap: Red Herring was stuck 41 times
  before): not looked into.
- The game process vanished at about 01:51:10, when the raid timer ran out: the log just stops, there's no crash
  report, and the hot-swapped code and two test crews held back from extracting were live. Cause unknown; watch the
  end of the next raid with this code installed.
- Hot-swap tool (scratch, not in the repo): load the new rivals.lua/shipnav.lua with loadfile in dir_eval,
  debug.upvaluejoin every non-function upvalue to the old module's cell (S, X, Nav, CFG...), add new CFG keys to the
  old table (the tuning menu keeps a reference to it), and copy the new functions into the module table.

## Pod breach input lock (2026-11-14, fix untested)
- After a pod breach into the Rusty Mule you could pitch and shoot but not turn or walk. ResetIgnoreInputFlags,
  EnableInput, SetInputMode_GameOnly and SetCinematicMode(false) from the bridge gave back pitch and fire only.
- breachInto now logs which flight-state fields your body still has after the pod ("breach: your body after the pod: ...")
  and clears IsFlyingShip, HelmControlUsing, TurretControlUsing and MYTurret, then resets input and walking mode.
  Check the log line on the next breach to see which one it was.
- Do NOT run bridge/t_props.lua props() on the player pawn or its CharacterMovement: reading every property crashed
  the game outright (05:13:26, no UE4SS error). Read named fields only.

## Pod boarding rework (2026-11-14, tested)
- Tested in game: after a pod, your body is fixed by afterPod (log "your body after the pod had yaw=false tick=false
  grav=0.0: walking again"); the old teleport breach and the void rescue both left you able to walk and look.
- PLAYER_BOARD_GAME = true: the game's own breach (F prompt near a hull, or ramming) does the boarding; the mod only
  preloads and pairs the interior as your pod heads for a ship. The old proximity teleport fired the moment a pod
  launched beside a ship pulled alongside. Not yet seen working on a rival: the one try hit a wreck (no interior) and
  the void rescue sent the user home.
- Wrecks (hull shot to 0, crew dead with it) are state "wreck" and boardable while the hull actor exists (hullThere).
  Ships whose crew is wiped out are "derelict" and boardable with or without an interior already in.
- Void wait: the camera looks at the hull you hit (or your own ship) instead of the dark, and the check runs every
  frame. Untested.
- Confirmed in game 05:50: pod + the game's breach into the Long Odds with its interior preloaded; no void, no void
  camera needed, walking and looking fine. User: "it worked perfectly".
- Fixed 2026-11-15 (issue #11): the status line said "you: in space" while the user was inside the Long Odds.
  playerPlace() returns "rival" there, and the status line only knew "ship", a station table, or else "in space". It
  now says "you: aboard the <ship name>" (S.aboard.shipName). Checked by running the expression in lupa for all five
  cases; not re-seen in game (needs a pod boarding of a rival).
- TODO: "no breach point joins up with the inside: boarders come in nearer the middle" fired for the Long Odds.

## Rival crews dying in a heap at one airlock; rivals' edge over station guards (2026-11-14)

Walking into Penal Colony with four crews docked there: the director spawned all of them (8 guard top-ups too) within
ten seconds, each 1-6 m from guards and from each other, and 14 rivals died in about 20 s by one airlock door. Causes:

- A station's spread pool (the walkable points spawns and roaming pick from) starts as a few points by the airlocks and
  grew 4 per update, so on arrival every "far from everyone" pick was in the same few rooms.
- Guard top-ups spawned but not yet armed (S.pendingDefenders) and rival bodies still being built weren't counted as
  "everyone", and crews didn't wait for the top-ups to finish.
- Nothing kept a spawn away from a body that already stood near the best spot.
- Freshly docked crews used the airlock tied to their berth, so successive crews came through the same door.

Fixes (rivals.lua):
- Crews already inside wait until the pool holds SPAWN_POOL_READY (60) points, grown SPAWN_POOL_BURST (16) a update;
  top-ups grow it the same way before picking.
- spreadPoint counts bodies being built and pending top-ups; a crew spawns only SPAWN_CLEAR (20 m) from everyone,
  waiting up to SPAWN_WAIT_MAX (20 s), then takes the best spot and logs
  "[rivals] <crew>: no clear spot in <station> after 20 s, spawning N m from the nearest body".
- Crews don't materialize while top-ups are still arming.
- pickLock: the free airlock used longest ago, not the berth's own.
- STATION_AREA_PER_CREW 15000 -> 25000: big stations count as busy sooner, so crews spread over more of the map.
- The pool grown outward from the airlocks clustered anyway (Asteroid Mine: 112 of its 160 points within 5 m of
  another, the first test's 30 m clearance found 1 of 160), so it's now seeded first from the level's own markers
  (loot spawners, AI start nodes, contract actors) inside the station, spread 208 x 168 m there, and pooled points keep
  SPREAD_GAP (6 m) apart. Look for "[rivals] <station>: spread pool seeded with N points (M candidates)".
- Too many crews in one place: Colony Cruiser (30k m2) is the only station on its map, so 11 crews docked there; walking
  in, all of them spawned inside at once, every one fell back to 10-16 m from someone, and 23 rivals died in about three
  minutes, mostly shooting each other at 2-13 m (guards got about 4). Now at most insideCap crews walk a station at once,
  one per INSIDE_AREA_PER_CREW (10,000 m2, at least INSIDE_MIN 2); the rest wait aboard ("[rivals] <crew> waits aboard:
  <station> already holds N crews") and, as a place frees, come in through the airlock furthest from everyone (their
  berth's chamber if they have one, else the station entry furthest from any body). Waiting crews still undock on time.

Rivals' edge (main.lua CFG, ai.lua perceive's new spotMul): against station guards and soldiers only, never against each
other, you or your crew. A guard aiming at a rival misses EDGE_GUARD_MISS (1.6x) more and spots one EDGE_GUARD_SPOT
(1.8x) slower; a rival aiming at a guard misses EDGE_RIVAL_MISS (0.7x) as much.

Docked ships hidden (rivals.lua showShip, run from glideShips): ships held in a berth showed wedged into the airlock
frame, and breached-in crews' ships (no free berth) idled in a clump at their hold points while Colony Cruiser flew on.
A docked ship and its turrets are now hidden with collision off from the end of the glide in until it glides out,
leaves, or you're aboard it. Trade-off: you can no longer see a docked rival ship to pod-breach it and raid its watch.

Tested (2026-11-14, Moon Base, 3 crews): pool seeded with 36 points (69 candidates); no "no clear spot" fallbacks; the
two late crews came in through different airlocks (Moon_7, Moon_8); docked ships read bHidden. The cap didn't trigger
there (Moon Base allows 10); the "waits aboard" path is untested in game.

Performance: on Colony Cruiser with 27 bots inside the director ran over 5 ms on 416 of 433 frames in 10 s (aim 1.2 s,
update 1.1 s, cover 0.9 s and 64 MB allocated, single FindAllOf calls ~55 ms); the user saw ~20 fps with stutters. With
~20 bots at Moon Base it's 64-80 fps, still over 5 ms on a third of frames. Per-bot aim and cover cost is the next thing
to cut.

Also seen this session: the load crash at RaidGame+0x1a605d0 (UE4SS hook dispatch, see 2026-11-09) again, once, loading
Space_Charlie after a bridge launch; the relaunch was fine.

## Pod breach into Fortress put you in a wall (2026-11-16, logic tested at the spot; rivals.lua podExitCheck)
Tester report with log (build 3, Space_Alpha): "out of the pod with no floor under you at 60356,114798,-1038: moved
to the floor at 60230,114665,-1203", inside a wall.
- At that spot the pod leaves you above a round hatch. The room below has its floor at -1626 (SM_Floor_400x3278,
  navmesh at -1623 straight under you). podExitCheck searched the navmesh 300, 600, ... below with a +-200 box, so it
  found -1203 first, 180 to the side. A trace from the exit to that point hits SM_WallRoundedCorner, and the point
  itself is on SM_Wall_Hole_9.
- Now: trace straight down first (Visibility channel, your body ignored, up to 1500) and land on the navmesh at the
  hit, or on the hit point itself when no navmesh is built there yet (it's built around you as you arrive; right
  after a teleport there was none). Any other candidate must be in sight from where you came out (a trace to it, 60
  above its floor, hits nothing). The helpers are R.Ground (trace / below / inSight): rivals.lua is at Lua's 200-locals
  limit, so they're on the module table.
- Tested in a Space_Alpha raid through bridge/dir_eval.lua, at the reporter's coordinates: below = -1626, nav =
  60356,114798,-1623, in sight = true. The old pick (60230,114665,-1203) is not in sight (rejected). Not tested: a
  real pod flight into Fortress with the new code.

## Pod breach prompt (issue 77, 2026-11-18; rivalcombat.lua playerBoarding)
- Cause: Ship_DropPod_Pawn_C's BeginPlay (ubergraph 10670: `if not HasAuthority() jump 7935`) starts its looping
  0.1 s timer `K2_SetTimer(self, 'Timed_BreachCheck', 0.1, true)` (at 8781) only on the non-authority branch.
  Timed_BreachCheck = BreachCheck() -> SetAbleToBreach(it) -> MatchHUD.HUD_Widget.SetUIAbleToPodBreach(bool), which shows
  HUD_Main_Widget's Border_isAbleToBreach ("... BREACH BOOST READY ..."). Offline we're the authority, so the border
  stayed Collapsed while BreachCheck was true. F (and ramming) still breached, since they call BreachCheck themselves.
  Same pattern as the salvage scan timer (#134 / pvepatch) and issue #143.
- Fix: playerBoarding (every frame while you're in a pod) starts the same timer once per pod through
  KismetSystemLibrary:K2_SetTimer(pod, "Timed_BreachCheck", 0.1, true, 0, 0); the game runs it from there.
- Tested in game (2026-11-18, Space_Solo_01, gifts-test save, pod from RaidUseableComp_DropPod01 via
  pawn:ServerInteractComp): pod parked 1200 off your own hull, nose on it: BreachCheck true, border 1 -> 4 within a
  tick, "BREACH BOOST READY" on screen (screenshot); moved to open space: false, border back to 1. No errors. NOT
  tested: a real flight onto a rival hull with a real F press, the escape pod after your ship dies.
- Bridge: pawn:ServerInteractComp(comp) (with pawn.LastInteractionComp = comp) uses a seat, pod bay etc. like F does.
