# Your ship, space and stations

Flying, docking, turrets, ship damage, salvage, level props, space objects and map geometry.

Part of the project's research log: [NOTES.md](../../NOTES.md) lists every topic file and every section title.
Sections are in the order they were written; a later section can correct an earlier one, so read to the end of a topic
before trusting a finding. When a section says "see X", search [NOTES.md](../../NOTES.md) for that title to find which
file it is in.

## Contents

- [Flying the ship; interaction offline; per-update cost (2026-10-30)](#flying-the-ship-interaction-offline-per-update-cost-2026-10-30)
- [Docking at a station (WORKING, 2026-10-30)](#docking-at-a-station-working-2026-10-30)
- [Giant shapes in the space sky (2026-11-06)](#giant-shapes-in-the-space-sky-2026-11-06)
- [Spawning your active ship (2026-11-06, replaces the in-raid swap idea)](#spawning-your-active-ship-2026-11-06-replaces-the-in-raid-swap-idea)
- [Space_Solo_02 stations, Rebel Base lid, key card guard (2026-11-07, later)](#space_solo_02-stations-rebel-base-lid-key-card-guard-2026-11-07-later)
- [Flying stutter and the minimap in new-map stations (2026-11-07, later)](#flying-stutter-and-the-minimap-in-new-map-stations-2026-11-07-later)
- [Ship damage visuals / incapacitated state (2026-11-08, FIXED, see end of section)](#ship-damage-visuals--incapacitated-state-2026-11-08-fixed-see-end-of-section)
- [Manning a turret yourself; crew gunner owns the turrets (2026-11-08, gunseat.lua + crew.lua)](#manning-a-turret-yourself-crew-gunner-owns-the-turrets-2026-11-08-gunseatlua--crewlua)
- [Stray geometry floating in open space on Space_Solo_02 (user, 2026-11-14; airlocks of absent stations, fixed 2026-11-15)](#stray-geometry-floating-in-open-space-on-space_solo_02-user-2026-11-14-airlocks-of-absent-stations-fixed-2026-11-15)
- [Ship stuck after undocking (2026-11-14)](#ship-stuck-after-undocking-2026-11-14)
- [Stuck in a shaft after docking at Fortress by pod (2026-11-14)](#stuck-in-a-shaft-after-docking-at-fortress-by-pod-2026-11-14)
- [Missing prompts, salvage, objective sounds (2026-11-16)](#missing-prompts-salvage-objective-sounds-2026-11-16)
- [Salvage in the hold stayed behind a shut door (issue 134; main.lua relaySalvage)](#salvage-in-the-hold-stayed-behind-a-shut-door-issue-134-mainlua-relaysalvage)
- [Purging salvage while docked is refused (space.lua guardPurgeWhileDocked)](#purging-salvage-while-docked-is-refused-spacelua-guardpurgewhiledocked)
- [Level props: fans, reels, ambience and sparks start offline (2026-11-18, issue #143)](#level-props-fans-reels-ambience-and-sparks-start-offline-2026-11-18-issue-143)
- [Blowtorch locks: the vault door could not be opened (2026-11-18; blowtorch.lua, BLOWTORCH.md; reported on Discord, no issue)](#blowtorch-locks-the-vault-door-could-not-be-opened-2026-11-18-blowtorchlua-blowtorchmd-reported-on-discord-no-issue)
- [#143 leftovers: ship hum, pod hint, camera turrets, hold contracts (2026-11-18)](#143-leftovers-ship-hum-pod-hint-camera-turrets-hold-contracts-2026-11-18)
- [Space object explosions and sounds (2026-11-18, issue #15)](#space-object-explosions-and-sounds-2026-11-18-issue-15)

## Flying the ship; interaction offline; per-update cost (2026-10-30)
- F at the helm did nothing and no "F" prompts showed: SIGISCharacter::InteractionDetection (sets
  LastInteractionActor/Comp, which the native Use -> 0x8fdf80 needs, and drives the prompts) runs from a timer the
  server's player setup starts; offline nothing does. The director runs it 10x/s for the on-foot PlayerPawn_C.
  Then F at the helm hands the frigate (Ship_StarterFrigate01_Pawn_C, AI-possessed until then) to the player
  controller and F exits again - all native, nothing else needed.
- PERFORMANCE RULE: FindFirstOf/FindAllOf scan every UObject: 30-45 ms each in this game. The director did two per
  0.5 s update (player controller + PGOS overlay sweep) = an ~85 ms hitch twice a second (ship flight stuttered).
  Never call them per update/tick: take the controller from the ticker, world.AuthorityGameMode, pc.MyHUD, and cache
  per raid (navMesh(), gunItem()). The overlay sweep only runs in a map's first 30 s. Verified after: worst frame
  11 ms over 270 frames of flight (was 85-92 ms every 0.5 s).
- Space look: Space_Solo_01 streams every raid location (Spaceport_01, MerchantShip_01, Navy_Outpost_01,
  Fortress_01) and AI frigate interiors (Strike_/Fast_Frigate_01_Ai_Interior) as LevelStreamingAlwaysLoaded
  sublevels at their own coordinates (raids around +15k..+63k X; the flight area is negative X). Their
  ExponentialHeightFogs and Fortress's unbound PostProcessVolume apply world-wide and UE4 draws one height fog
  (first registered): one run looked fine, the next was pale blue "underwater" (Strike frigate interior fog,
  colour 0.64,0.91,1.0). The space map itself has no fog. Director: per space raid, collect sublevel fogs +
  unbound PPVs once (when ready), all off; switch on only the nearest sublevel's within LEVEL_EFFECT_RADIUS
  (40k) of the camera. Note: a sublevel actor's GetWorld() is the sublevel's own UWorld, not the space map's.

## Docking at a station (WORKING, 2026-10-30)
- Flow: RaidDockingComponent::FrigateDocking (authority; 0x17d33c0) sets pc.DockedVolume (+0xC60) and an unnamed
  docking flag (+0xC38), then ClientStartAbility(10 = FRIGATEDOCK) -> Ability_Frigate_BoardStation (moves the
  ship, fade to black, area name, NetworkSyncPoint OnSync). Client half: ClientFrigateDockingToStation (0x18264a0,
  clears +0xC60/+0xC38). Server half: RaidPlayerController::FrigateDockingToStation (0x182e990: uses
  DockingStationForDroppod or DockedVolume -> SpaceshipInside dock, then Docked()).
- Standalone: one controller, ability takes only the client branch, and the client clear wiped the server's
  DockedVolume -> "docking animation" then nothing. Director: pre/post hook on ClientFrigateDockingToStation keeps
  DockedVolume and calls FrigateDockingToStation. Verified: dock, airlock, on-foot station level, native AI there.
- Same server/client pattern likely for undocking (Ability_Frigate_ExitStation, FRIGATEUNDOCK/FRIGATEEXIT),
  drop pods (Ability_DropPod_*) and breaching: check ClientXxx resets of server state first.
- Interesting natives: ClientStartAbility(EInteractionAbilityTypes) on RaidPlayerController starts these.

## Giant shapes in the space sky (2026-11-06)
- Cause: raid interiors are always-loaded sublevels at their real coordinates, each wrapped in a black shell of thin Cube
  meshes (M_FullyBlack, ~200 m), plus fog cubes and large light panels. Their small props cull with distance, these big
  cubes don't, so from open space they hung in the sky as flat black plates, only when you faced that way. Seen on
  Spaceport from (-30000,22800,8000) and (25000,30000,9000). The runtime NavMeshBoundsVolumes were NOT it (vis=false).
- Fix (main.lua levelShells/updateLevelShells): every Cube with scale >= 10 inside a LevelStreamingVolume's box is hidden
  unless the camera is inside that box (+1500). SetVisibility only, collision stays. 53 pieces in 7 locations, collected
  once when the map is ready (walks all ~95k static meshes, ~3 s, under the veil). Verified: plates gone in both photos;
  Spaceport 19/19 visible inside, 0/19 outside. Whether windows look right from inside was not checked by eye.
- Left alone: ForceField_Mat sheets (Plane, ~120 x 160 m scale, Z 2106 and -23002 around the Spaceport exterior at
  X -88000) and 108 spline_blocker panels: a translucent barrier, probably also the 2 pale squares seen from
  (-30000,22800,8000) (not proven: spline components all report the same origin). The black box at the map origin
  (~20 m, no volume) doesn't render at range. Node_SpacePortWhitebox_01 (-90000,0,-5700) is the real station exterior.
- Tools: bridge/t_cubes (big meshes), t_view (a CameraActor view, no player move), t_ray (which meshes project onto a
  screen rectangle), t_shellvis, t_vols. The sky differs per run: compare geometry, not colours.

## Spawning your active ship (2026-11-06, replaces the in-raid swap idea)
- The travel URL takes ?SHIP=<FrigData row> (string at +0x409ad08, tools/offline-audit/strs.py). With it the game spawns that row's interior and hull itself. Without it, the Rustbucket. launchMatch reads the row from loadout.json and appends R.shipOption(row).
- Verified through the lobby button: Strike interior + hull, 1250 hull, cockpit deck, raid intro on screen, gate. bridge/rt3_test.sh <name> is the fresh launch path, rt4_test.sh the path from the lobby after a raid, sh_test.sh a bare open.
- Designs on the placeholder level have `stand`: launch on the stand-in row for its real interior, and R.ownHull replaces only the hull when loading finishes, from veilUntilAboard at raid.readyAt. Verified on a Heavy Raider: Capital interior, Ship_Frigate01 hull,
  950 hull, "hull is fitted" 1 s before "aboard". Bow gun fitted after. Turret and modules from the hangar are NOT applied to that hull.
- BUG found: on the FIRST raid after a game launch the interior has no name (ShipInfoItem not linked; on later raids it is) and extraction saves a made-up item: new id, new name, and the ?SHIP= row. A Heavy came back as FrigateCapitalShip_Ship "Helldiver".
  Why the first raid differs is unknown. Client_GetOutWithLootAndShip is what fires for a piloted ship; plain Client_GetOutWithLoot does not, so "extracted with" isn't logged and the mod's own menu return isn't used.
- Fix: stand-in remembers the ship at checkout (state ship_out) and settle_ship turns the next NEW ship item PUT into that exact item. Stolen ship: rivals.lua writes backend/ship_stolen.txt with the hull's row; the item keeps the game's id and name with that row.
  Death: hook Client_DiedCloseInv writes backend/ship_lost.txt, which clears ship_out.
- Verified in game: Heavy Raider from a fresh launch came back as 47943293 HeavyRaider_Ship Vanquisher, Capital interior, 950 hull (the game linked the item itself that time, so the first-raid bug is intermittent and was NOT reproduced). The bad item itself is covered by
  tools/test_settle_ship.py, using the real "Helldiver" write. Stolen Heavy Frigate saved as FrigateHeavy_Ship "The Leviathan" (ship_stolen path). Leviathan flown back in the next raid on the stand-in path, name shown. Death by ApplyDamage (Suicide isn't callable): back to the menu, ship gone, ship_out cleared.
- Leaving in a stolen ship loses the ship you came in: only the stolen one is saved. Several owned ships: which is active in loadout.json not checked. Hangar turrets and modules
  aren't applied to stand-in hulls. Nothing here was played by hand: helm, pods and gate were driven by scripts. Scratchpad tools setship.py, resetship.py need the stand-in stopped. Saves: backend/state.before-save-fix-test.json holds the pre-test save with the Vanquisher Strike.
- Quit then buy (fixed, verified in game by bridge/qb_test.sh): settle_ship now only acts when ship_out has gate=true. The mod hooks RaidPlayerController:Server_EnterEvacRaidVolume (no params) and LeaveEvacRaidVolume and writes backend/ship_gate.txt, 1 or 0.
  So a quit leaves ship_out unflagged and a ship bought afterwards is left alone. Client_GetOutWithLoot (on foot or by pod) now also clears ship_out: your ship stays behind.
  Verified: "ship in the gate: True" logged 1 s after the gate, Vanquisher back as 47943293. Then launch, `open MainMenu`, BuyShipFromShipShop(CorvetteScout_Ship): saved as 8989145 CorvetteScout_Ship "The Colossus", with ship_out still unflagged and untouched, cash written.
  The bought item's quantity field reads 0 where an extracted ship reads 1: that's the game's own write. LeaveEvacRaidVolume (gate=0) wasn't exercised.
- Test: bridge/qb_test.sh from a fresh launch (gate extraction, then launch, quit, BuyShipFromShipShop via t_buy.lua). Costs in-game cash and loses the ship on the quit: backend/state.before-quit-buy-test.json is the save to restore, stand-in stopped.

## Space_Solo_02 stations, Rebel Base lid, key card guard (2026-11-07, later)
- User report: big black cube in the sky at Rebel Base, rivals leaving/gone right at the start, poor loot at Rebel Base, locked out of own ship (captain's ID gone).
- Stations: Space_Solo_02's interiors (Rebel Base, Penal Colony, Mini Mine, Asteroid, Moon Base, Capital Ship) have no Navy/Spaceport airlock names and no anchors, so rivals.lua survey named none: "stations: none", every crew "nowhere to go" and extracted at once; with no station no garrison either, so the only enemies were the base's own native NPCs (native loot). Fix: unnamed nav volumes are named after the LevelStreamingVolume around them (CFG.VOLUME_NAMES) and matched to Node_* RaidDockingComponents by key5 (rebel, penal, minim, capit). Two nav volumes in one streaming volume: the bigger wins. No airlock (Mini Mine): entries are RaidAINodeStart spots. Verified: "Penal Colony (5 entries, 4 berths), Mini Mine (7, 1)" and on another run "Rebel Base (6 entries, 4 berths)"; crews head for them. Fights and loot there not watched.
- Docking on Solo_02: the space-side Node_RebelBase_01 / Node_PenalColony_01 sit near (-85000,0) with RaidDockingComponents; the interior's airlocks are StationAirlockDockingAreaAbility<Name>_N actors (RaidFrigateStationDock, in the persistent level) at the real interior. A docked ship shows in that dock's DockedShips (MyDockedShip stays null).
- Lid: Cube_4549 (Rebel_Base_01, scale 354x490x312, centre z 26140) sits above LevelStreamingVolume_RebelBase, so the shell pass skipped it. levelShells now falls back to matching a cube on the volume's floor plan (x, y). 24 pieces; lid hidden from the ship, verified by IsVisible only.
- Key card: row KEYCARD in container "KeyCard" (MotherItemGUID), Attachments "<captain>!<ship name>!<RaidSpaceshipInside.KeyCardUUID>!<type>". Docking and both airlock transfers keep it (tested at Rebel Base and Penal Colony by bridge: t_helmown, t_flydock, t_airuse, t_usecomp, t_stationuse). Station side: OpenBtn checks the card (dock PendingShipTransfer = your ship, door opens), InsideAirlockBtn transfers. What removed the user's card is NOT known (log shows nothing). main.lua guardKeyCard (every 2 s on space maps) remembers the card and re-adds it with Server_AddItem(KEYCARD, 1, cond, "KeyCard", 0,0, false, guid, 0, att, 0) when it's gone and the slot is empty; verified: removed by Server_RemoveItem, back 1 s later, and a re-added card opened the station side and transferred back. HangerEvent refusals (>= 3) are logged; the hook never fired in tests.
- Test crash: bridge-driven FrigateDockingToStation called again while docked, then OpenBtn twice: access violation in Blueprint code ~20 s later. Not seen in the clean sequence. Native Rebel Base guards still carry the game's own loot (adoption keeps it).
- Tools: bridge/t_rebel.lua (docks, volumes, cubes outside volumes), t_keycard*.lua, t_cardcon.lua, t_cardrestore.lua (+ _G.CARD_STEP="add"), t_cardadd.lua, t_dockstate.lua, t_hangerlog.lua. backend/state.before-rebel-test.json = save before these tests.

## Flying stutter and the minimap in new-map stations (2026-11-07, later)
- Measured on Space_Beta with bridge/profile_on (profile.txt now also counts gaps between frames, the whole game's hitches): every FindAllOf costs 40-50 ms on these maps. While flying, rivals.lua ran FindAllOf(InGame_BowGun_50Cal_C) to find guns it had summoned (about every second while crews launched) and FindAllOf(RaidCharacterTurrent) per ship fitted: pairs of them = the 100-159 ms freezes. Fixed: bow guns spawned with SpawnActor (CFG.GUN_PATH, GUNS_PER_STEP 2) and handed over directly; a hull's own turrets read from ARaidFrigate.SpawnedTurretArray. The PgosOverlay sweep now stops once the loading veil lifts on space maps. The key card guard keeps its inventory component (raid.cardInv). After: director never over 10 ms after boarding, no scans during the flight; frame gaps 0 at rest. Flying was tested by teleport steps (bridge/t_step.lua), which add their own ~50 ms gaps.
- The SetSkeletalMesh hook (seamless body) ran 0-3 times per 10 s: not a cost.
- Minimap: StationAirlockDockingAreaAbility<Station> airlocks are in the space map's own level, so survey() made a place of the space map itself ("Space Beta", and "Space_Solo_01" earlier) holding every station's airlocks: once through you were "in" it, so the guide said back to your ship and drew its (empty) floor plan. Those airlocks now join the place named in them (key5 + TAG_KEYS), else the nearest within LOOSE_AIRLOCK. Old plans moved to backup/minimap-old to rebuild. Distance text falls back to the straight line when the route has length 0 (airlock chambers are off the navmesh). Verified: in Asteroid Mine Large the guide gave the task's own step, map and overview drawn.
- TEST HAZARD: RegisterHook from a bridge command mid-raid crashed the game in UE4SS's hook dispatch (13:15), and GetAttachedActors with a Lua table out-param crashed it (13:09). Don't do either.

## Ship damage visuals / incapacitated state (2026-11-08, FIXED, see end of section)
- Measured in game (Space_Solo_01, Starter, bridge/t_shiphit.lua = real GameplayStatics:ApplyDamage on your hull; t_shipdmg.lua reads state):
  the server side works offline. Interior TotalShipHullHealth is a fraction (575 -> 425 = 0.739). At 0 hull the ship is NOT sunk:
  LifeSupportDestroyed turns on (interior and hull bLifeSupportDestroyed), i.e. the incapacitated state. Systems held only PrimGun=100.
- Nothing shows: the hull AnimBP's b_HullIsDamaged / f_isHullDamaged / b_*IsDamaged stay false at every hull level, and the interior
  BP's reactions (FrigateInside_*: ShipHullHealthChangeEvent, OnLifeSupportDestroyed, CriticalDamage_AmbientLighting,
  TakeDamage_MakeLightsOnShipFlicker, ShipHealthIsCompletelyDamaged, components P_Damage_LifeSupportComp/HelmGunComp/TurretComp,
  Audio_ShipAlarm, Audio_LifeSupportFlames_Part1, Widget_ShipOverallHealth) are only reached from RaidSpaceshipInside::OnRep_*
  (OFFLINE_AUDIT item 8), which nothing calls offline. Same bug class as OnRep_WeaponHasBroken (main.lua).
- Calling ins:OnRep_ShipHullHealthChange(old) and ins:OnRep_LifeSupportDestroyed(false) by hand runs without error, but the AnimBP flags
  stayed false and one screenshot pair showed no clear change; whether they light the interior was NOT confirmed (the component probe
  crashed the game, see below). The hull's BPI_ShipAnimations Frigate_Damage_* calls are likely made from another path (CheckFrigClientDamaged?).
- Fix plan: per update, for S.homeInside and each rival c.inside, remember TotalShipHullHealth and the 4 *Destroyed flags; on change call
  the matching OnRep_* with the old value, and call the hull AnimInstance's Frigate_Damage_Hull/Engine/Turret/HelmGun(bool) if still off.
- Probe hazard: reading ins[comp]:IsActive()/.Template on the interior crashed (AV 0x18 in UE4SS; pcall does not catch it). Check
  comp:IsValid() first. Also hit the known load crash (UE4SS +0x555046 -> game +0x1c3574e) once at raid load.
- FIX (rivals.lua damageFxStep, run each R.update): for S.homeInside and every crew's c.inside, remembers TotalShipHullHealth and the 4
  *Destroyed flags (first look starts from undamaged); on change calls OnRep_ShipHullHealthChange(old) / OnRep_*Destroyed(old), and
  calls Frigate_Damage_Hull/Engine/Turret/HelmGun(on) on the hull's and its CurrentWeapon's AnimInstance. Logs each system flip.
- Verified (Space_Solo_01, Starter, bridge/t_fxstate.lua = read-only component check with IsValid first): after 300 damage the AnimBP's
  b_HullIsDamaged turned true (was always false). At 0 hull (life support destroyed): Audio_ShipAlarm and P_Damage_TurretComp went
  active (were off at 48%). P_Damage_LifeSupportComp / Audio_LifeSupportFlames_Part1 were already active at 48% (baseline unknown).
  Screenshots showed only a subtle lighting change from the corridor. Engine/turret/helm-gun destruction and rival ships not tested.
- Rival hulls (2026-11-14): they still looked pristine when disabled. The hull pawn BPs (Ship_*Frigate01_Pawn_C) carry their own
  exterior emitters P_HullDamage01-04, P_EngineDamage, P_TurretDamage, P_HelmGunDamage and events DamageEffects_ShipHull(DamageAmount_Percent)
  / DamageEffects_Engine/Turret/HelmGun(TurnOn), also only reached from replication, and damageFxStep only covered ships with an interior.
  FIX: rivals.lua hullDamageFx runs on every crew's c.ship and your hull: one more P_HullDamage emitter lit per quarter of hull lost, all four
  plus engine/turret/helm-gun fires at 0 hull (or life support destroyed), a destroyed system lights its own fire. Activate(true) +
  SetVisibility after comp:IsValid(). Also calls DamageEffects_* (scale of DamageAmount_Percent unknown; we pass hull left 0-100).
  Verified (Space_Delta, Patrol Scout, bridge/t_hullfx.lua via ApplyDamage): 650 pristine, 450 -> 1 emitter, 250 -> 2, 0 -> all 7 on and
  "[rivals] hull fx: ... disabled" logged; screenshots show the wreck burning. Not moving at 0 hull is the game's own disabled state.
- Testing note: a bare `open <map>` from the menu has no PID and asserts "Couldn't spawn player: PlayerID is null" (or crashes in UE4SS
  at the splash). Start test raids with bridge/mm_launch.sh (waits for login, Play, lobby launch).

## Manning a turret yourself; crew gunner owns the turrets (2026-11-08, gunseat.lua + crew.lua)
- What works natively offline: F on a gunner seat (RaidUseable_TurretControl01; the camera turret seats too) moves your view to
  the turret's camera, which follows your mouse, and sets pawn.MYTurret + turret.ControllerHere = your controller. Missing:
  the turret never turns, the fire button reaches none of the turret's fire functions, F doesn't stand you up, and
  TurretControlUsing / OnRep_SetGunning (sitting anim) never happen (SendGunnerSeatOnRep is Role-gated, audit item 9). The
  native code reading MYTurret sits in Denuvo-moved code (no plain [reg+0x6c8] reads in the RaidGame range), so no patch.
- gunseat.lua (per frame on space maps, Gunseat.frame from main's frame block): when MYTurret appears it calls
  SendGunnerSeatOnRep(LastInteractionComp) + OnRep_SetGunning, marks the turret IsOccupied; each frame TurretLocalRot =
  camera direction relative to the hull (verified: barrel socket yaw = camera yaw); left mouse (IsInputKeyDown) fires the
  turret's own ServerFireProjectile along the camera from its barrel sockets at FireRate, magazine TotalAmmo, ReloadTime
  (AmmoLeft kept in step), and calls pc:ClientFiredTurret (what rivals hook as "you fired"); a fresh F press after 0.5 s
  stands you up (view back to the body, MYTurret/TurretControlUsing/ControllerHere cleared, TurnOffTheGunner).
  Bridge tests: bridge/gunseat_fire (exists = fire held), bridge/gunseat_leave (one F). Driver: gs_test.sh then gt_run.sh.
- Helm vs crew gunner: RaidFrigate::ServerFireFrigate_Implementation (0x183d160) fires SpawnedTurretArray[0] (vfunc +0x668)
  whenever that turret's ControllerHere (+0x2b0) is null, i.e. the pilot also works an unmanned turret. Online a gunner
  in the seat filled it; our crew gunner never did, so you and the gunner both fired it. crew.lua holdTurrets() puts your
  controller in ControllerHere of every turret the gunner works while it does (view unaffected, its direct
  ServerFireProjectile still fires), releaseTurrets() takes it back when you leave the helm, the gunner is down or the hull
  dies (not a turret you sit at yourself). With no gunner the pilot still fires the turret, as the game does solo.
- Verified (bridge only, no real input): pilot ServerFireFrigate fired the turret with ControllerHere null and not with it
  held (only rival turrets in the counts); released to nil after leaving the helm; seated at the gun turret, 6 shots in 4 s
  (ServerFireProjectile + NetMultiFire + ClientFiredTurret each 6), seat registered, occupied, barrel follows the camera; F
  test stood up cleanly. NOT verified: a real mouse click / real F at the seat, whether the body's own gun also fires on
  that click while seated, shells hitting a rival, the turret HUD (TurretFirstTimeOpen/RefreshTurretInfo called, nothing
  visible seen), camera-turret seats' shots.

## Stray geometry floating in open space on Space_Solo_02 (user, 2026-11-14; airlocks of absent stations, fixed 2026-11-15)
- Seen from the open middle of the map: long flat girder/hull-like pieces and a dark flat shape, in view from a ship.
  Possibly interior levels at the free interior slots (makeInterior) or station parts out of place; check what actors
  sit there before deciding. Keep it out of trailer shots meanwhile.
- 2026-11-15 (also "dark flat slabs near stations"), still not reproduced. On Space_Charlie the user saw none; there a
  probe found no stray visible meshes and your own ship interior (a level instance, no streaming volume) culls at
  100 m with one far-drawn Cube. Streaming volumes whose interior hiding collects 0 parts (interiors.lua): MoonBaseWhitebox
  and AsteriodWhitebox_1 on Space_Solo_02, NavyOutpost on Space_Alpha, Capital_Ai_Interior_2 on Space_Charlie.
  Those two Solo_02 stations are the likeliest source (their shell/far meshes are never hidden). Next: on Space_Solo_02,
  aim at a slab and list the largest visible meshes in view (material, level, owner, scale, draw distance).
- FOUND (2026-11-15, issue #9): the "0 parts" volumes are stations that aren't on this run's map, and their airlock
  chambers are what floats. Space_Solo_02 picks its stations per run; on a run without the Asteroid Mine its box held only
  36 meshes, all from the space map's own level: six StationAirlockDockingAreaAbility_AsteriodWhitebox2..10 actors
  (RaidFrigateStationDock), each with SM_MERGED_Airlock_01 (MI_Shuttle_Metal_Dark_01, drawn to 72 m), SM_Hangar_
  Computer_01 (100 m) and never-culled meshes. Seen on screen as a dark chamber in open space with more dark slabs
  beyond. interiors.lua leaves the space map's own meshes alone, so nothing hid them. Fix: collect counts each volume's
  meshes from other levels ("foreign"); a volume with none is a station that isn't here, and its RaidFrigateStationDock
  actors are hidden with collision off for the raid. Log: "... N airlocks of absent stations (AsteriodWhitebox_1 0, not
  here: 6 airlocks hidden, ...)". Verified: all six hidden, collision off; the spot shows empty space. Present stations
  keep their airlocks (they are the station's own exterior). Girder-like pieces from the report not separately seen.

## Ship stuck after undocking (2026-11-14)

After undocking from Penal Colony on Space_Beta, the player's ship took thrust (CurrentThrust 1) but didn't move. It wasn't disabled: bDocked was false, the controller was the player, and input wasn't ignored. Its CharacterMovement component had simply stopped ticking. Nothing in the mod turns that off, so it's the game's own docking. Turning the tick back on from the bridge freed the ship at once. rivals.lua's keepShipMoving now does this automatically: if you're flying, undocked, and the tick has been off for 2 s, it turns it back on and logs "your ship's movement had stopped ticking after undocking". This isn't tested on a fresh run yet.

The tuning menu also failed to open ("bad argument #2 to 'format' (number expected, got table)"). FLEE_HULL had become a per-crew range { 0.1, 0.25 }, but the menu row still treated it as a single number. It's now two rows, one for each end of the range.

## Stuck in a shaft after docking at Fortress by pod (2026-11-14)

Flying a pod into Fortress's docking arm put the player at the game's Pod_Spawner_Fortress6 (57354,119225,-914), inside
a sealed vertical shaft between two decks (rounded wall pieces from -1179 up to a lid at -745; no navmesh at that level;
floors at -1532 below). The body was also still parked for the flight: CharacterMovement not ticking, so "falling"
with no velocity. afterPod only ran after a pod brought you into a rival's ship. Fixed live from the bridge: moved
to the floor below and unparked the body (afterPod's steps).

playerBoarding now runs podExitCheck POD_EXIT_CHECK (1.5 s) after any other pod exit (not in the void, which
rescueFromVoid handles): no navmesh under your feet means a search downwards (then around) for floor and a move there
("out of the pod with no floor under you at ...: moved to the floor at ..."), and a parked body gets afterPod
("your body after the pod had ...: walking again").

Crew prices halved for testing how useful crew are: hire fee 500/1250/2500/4500/7500 and wage 150/300/500/800/1250 a raid
by level (were 1000/2500/5000/9000/15000 and 300/600/1000/1600/2500). hire.lua CFG.FEE / CFG.WAGE.

Faster into the lobby and raids (user report 2026-11-16): the PGOS social overlay scan runs every 1 s for a map's first
30 s (was every 10 s; it sat over the fresh lobby up to 10 s); test found it 5.5 s in. MM_SEARCH_SECONDS 4 -> 1, LOAD_TIME_DILATION
10 -> 20 (engine cap). Start to aboard went from ~22 s to ~18 s (Space_Charlie 18 s, Space_Beta 18 s); rivals launched normally.

Shotguns (user report 2026-11-16): the player's shotgun did nothing offline. FireWeapon (0x1884b80) handles guns with a
pellet count (+0x460 > 0) apart: when MyPawn is a RaidBot or RaidNodeBot (0x188f3a0) each pellet is traced and damaged on
the server (0x1895dc0), so soldiers, rival bodies (GOAPNodeBot) and crew should be fine; every other pawn, the player
included, goes to the multi-pellet client trace 0x18a1990, which traces the pellets, spawns their impacts (0x18a1c70) and
sends ServerTraceFireProjectiles, but starts `cmp byte [rcx+0xF0],3 ; jae return` (OFFLINE_AUDIT item 6). Offline the
player's pellets were never traced. Fix: pvepatch "Shotgun pellets trace RPC" NOPs that jae (0x18a19be), like the
single-shot "FireWeapon trace RPC". Found by static disassembly of the exe. Tested in game
2026-11-16 (bridge/t_sgive.lua hands a TrenchShotgun, bridge/t_sshoot.lua aims and fires): patch applied 21/21, one
shell at 4 m took a raider from 100 HP to dead (clip 30 to 29). Impact FX not checked by eye. Bot shotgun pellets get no impact FX (0x1895dc0
never calls 0x18a1c70); not fixed.

## Missing prompts, salvage, objective sounds (2026-11-16)
User report: interaction prompts (contracts, doors) missing; objective sounds repeat before an objective is done;
space salvaging doesn't work.
- **Hidden main HUD (fixed in main.lua ensureHud, needs a play-test)**: two SIGIS_HUDOverlay_C are in the viewport:
  the director's own (made early for the loadout, then Collapsed) and the game's "In Game Overlay Match". But
  MatchHUD_C.HUD_Widget (the HUD_Main_Widget every prompt goes to: Show_Interact_Prompt, SetAbleToDockPrompt, the
  frigate panel Border_FrigateHUD) still pointed at the one inside OUR collapsed overlay, so prompts were set on an
  invisible widget. ensureHud now also sets hud.HUD_Widget = hud.InGameOverlay.HUD_Main_Widget when it collapses ours
  (retries until that widget exists). Verified live by repointing it by hand: frigate panel and "KEY: SALVAGE" showed.
  Probably also the cause of the missing door prompts (doors tested earlier "had prompts" only because the probe read
  the hidden widget's state). Probes: bridge/t_hudp.lua (border parent chain), t_hudref.lua / t_hudref2.lua.
- **Salvage (fixed, pvepatch "Salvage scan timer a/b/c")**: RaidFrigate BeginPlay (0x1824550) only starts the looping
  salvage-scan timer (0x182e430: 1500-unit trace, wreck kept at frigate+0xD08, SalvageEvent -> CheckifAbleToDock ->
  HUD SetAbleToDockPrompt) on the non-Authority branch (0x18246a1). The three Authority exits now jump there.
  Salvage key = R (InputSettings action "Salvage"; key handler 0x1838f90 -> ServerOnSalvage 0x183d4c0 -> 0x185e800,
  spawns DefaultShipInsideSalvage in the interior). Verified in Space_Solo_01: R took a wreck aboard (SalvageFull,
  Industrial_InsideSalvage_01_C spawned in the hold). Not yet tested: looting it, unloading (0x182e990).
  OnSpaceSalvageChange (from OnRep_HasSpaceSavage) has no Blueprint implementation, so nothing lost there. **Wrong for
  FrigateInside_Starter_C**: it does implement it (door, lever panel), see issue 134 below.
- **Contract inspect prompt (pvepatch "Contract inspect prompt")**: ShouldShowContractInteraction (0x8fc9c0)
  `jae` at 0x8fc9f6 NOPed so InteractionDetection offers inspect objects. Patch applies (25/25 on a fresh launch);
  the on-screen prompt is not yet seen (also depended on the HUD fix above).
- **Objective sounds (NOT fixed)**: MainPlayerController_C OnUpDateMission / OnUpDateChapterMission play the
  Completed cue when progress == max; Inspect (type 5) plays the progress cue on every +1; native IncrementMission
  (0x9ca2c0) fires the event only when it increments. Suspects: (1) with two HUD overlays alive, a widget-played cue
  plays twice (both HUD_Main_Widget copies get mission updates); (2) missions.lua re-sending Client_CheckMissionEvent
  for inspects while Use is held; (3) both bInMissionVolume and bInChapterVolume set together. Probe
  bridge/t_mis.lua logs both events. CAUTION: hooking GameplayStatics:PlaySound2D/SpawnSound2D from Lua and then
  calling pc:OnUpDateMission crashed the game (AV inside UE4SS's hook; probe t_snd.lua, don't reuse as is).
- Bridge tips: globals set in a bridge command don't reach a dofile'd script; pass args with
  `pcall(loadfile("<absolute path>"), a, b)` (relative paths fail). Read widget `.Visibility` instead of calling
  GetVisibility (errors as "function: 0x..." on some instances).

## Salvage in the hold stayed behind a shut door (issue 134; main.lua relaySalvage)
- Report (Taki, build .6, confirmed live 17 Nov on master, Space_Solo_01, starter frigate): after R the hold's airlock
  stays shut, the lever panel reads "LOCKED / NO SALVAGE DETECTED", yet the lever offers "F" PURGE SALVAGE.
- Read live: the wreck's inside salvage (Industrial_InsideSalvage_01_C) spawns right at the interior's SalvageSpawn
  (child of SalvageComp tagged "Salvage", which 0x17d9dd0 looks up), not hidden; the interior's SalvageFull (+0x3c8),
  HadSpaceSalvageAlready and the frigate's SalvageFull (+0xc38) are all true, CurrentSalvageActor (+0x3d0) set.
- What's missing is FrigateInside_Starter_C's Blueprint OnSpaceSalvageChange (door open, panel), which only the native
  OnRep_HasSpaceSavage calls. Replication callbacks don't run on the authority, and offline the game is it.
  Calling `inside:OnRep_HasSpaceSavage()` by hand opened the door and the salvage could be looted.
- Fix: main.lua relaySalvage watches your interior's SalvageFull in updateSpace and calls OnRep_HasSpaceSavage on each
  change (pickup and purge). Same pattern likely behind #74 (salvage gone on docking): check the other OnRep_* there.
- Careful in bridge probes: calling methods on a possibly-null object wrapper inside pcall crashed the game in UE4SS
  (null read 0x18); check `o ~= nil and o:IsValid()` first.

## Purging salvage while docked is refused (space.lua guardPurgeWhileDocked)
- The original game never let you purge the hold's salvage while docked (the space door would open into the station).
  Offline nothing stopped it. Tester report: purge worked while docked.
- Read live: F on the purge object is SIGISCharacter::ServerInteractComp with the hold's component named "SalvageComp"
  (RaidUseableDockedSalvageComponent, the prompt) or "SalvageControlLever" (same class, the lever mesh). StartInteraction,
  ProcessInteraction and ServerInteract did not carry that press. A RegisterHook pre callback that calls `comp:set(nil)`
  cancels the interaction, so the press does nothing and the prompt stays on screen as in the original.
- Fix: hook ServerInteractComp once in Space.init. While the player's hold (raid.home) has is_Currently_Docked true and the
  component belongs to that hold and is one of the two names above, the press is cancelled. Undocked, purging is untouched.
- Feedback: the same thing a full inventory gives. The HUD overlay's HUD_Main_Widget_C (instance "In Game Overlay Match") has
  Txt_NotEnoughSpace; set its text, call hud:NoSpaceForItem() (plays Anim_NotEnoughSpace and the error sound), put the
  original text back after 4.5 s. Rate limited to one per second. Reached natively as SIGISInventoryComponent
  Client_NoSpaceInInventory -> SIGISHUD BP_NoSpaceForItem -> MatchHUD_C / HUD_Main_Widget_C NoSpaceForItem.
- Tried and dropped: switching the lever's collision off (the F prompt vanished; tester wanted it kept) and
  PlayerController:ClientMessage (text did not show). HUD_Message_SubWidget_C works but sits small in the top right
  with no sound.
- Also learned while testing salvage: a destroyed actor still passes IsValid and shows in FindAllOf until garbage
  collection (about every 60 s) and reads location 0 0 0, so check the location when watching wrecks.
  K2_TeleportTo returns false without an error when the destination overlaps geometry; use
  K2_SetActorLocationAndRotation(loc, rot, false, {}, true) and verify the new position.
  Salvage survived docking for menu spawned and level wrecks (issue 74 not reproduced there).
- Tested in game: docked press shows the warning and sound and does nothing, undocked purge works.

The whole chain (pickup, purge, docking, the Blueprint findings, the HUD refusal route and how it was dumped) has its own
reference with flowcharts: [docs/internals/SALVAGE_CHAIN.md](../internals/SALVAGE_CHAIN.md).

## Level props: fans, reels, ambience and sparks start offline (2026-11-18, issue #143)
- Cause (decompiled with tools/offline-audit/kdis.py): `MA_RotatingParent_Simple` / `_WithAmbience` start
  `K2_SetTimer(self, "LoopThisActor", Frequency, true)` from BeginPlay only `if not IsServer()`, and `_WithAmbience` also
  `Audio.FadeIn(1, 1, 0)` there when `ShouldPlaySound`. `Base_Broken_OneShots_Parent` does `PickARandomGoalNumber()` and
  `K2_SetTimer(self, "DoAnEvent", FrequencyOfCheck, true)` (every few checks: SpawnSoundAtLocation + particle burst) on
  the same side. Offline the game is the server, so none of it ran: fans and tape reels stood still and were silent.
  (The Simple one also starts in MainMenu, which is why lobby props turned.) `LoopThisActor` only turns the mesh while
  `WasRecentlyRendered(1)`, so running timers on unseen props costs next to nothing.
- Fix: `levelprops.lua` makes the same calls once per prop, 4 s and 30 s into a raid (one class per update: each is a
  FindAllOf), tracked by address in the per-raid table. The game runs the timers from then on.
- Verified (Space_Alpha): "level props: 44 started", `K2_IsTimerActive` true on 26/26 rotating, 17/17 ambience and 1/1
  broken props, 17 ambience Audio components playing, and a rendered fan's yaw going -30 -> -45 between two reads.
  Not checked by ear or eye in normal play; land raids and station interiors not checked.

## Blowtorch locks: the vault door could not be opened (2026-11-18; blowtorch.lua, BLOWTORCH.md; reported on Discord, no issue)
- Symptom: the vault door says "F requires blowtorch"; firing the torch at its three metal pieces (top, middle, bottom lock)
  changes nothing. The torch does hurt soldiers.
- Cause (decompiled with tools/offline-audit/kdis.py, live logs from a test raid): `Base_BlowTorch_C` only plays flame, light and
  sound; its damage is native (`RaidWeapon_Tool`). `Door_BlowTorch_C` has no damage code: three `RaidLockVolumeComponent` boxes
  (`RaidLockVolume_Top / _Middle / _Bottom`, native Health 300, hidden, about 14 x 7 x 11 cm either side of the middle, 60 cm
  apart in a column) and the event `LockDamaged(LockName, HealthPercent)`, which the native weapon code is meant to call. Offline
  nothing reaches the boxes: no health change, no `LockDamaged`. When a lock reaches 0 the door waits `Delay(10)`, scales the
  latch down (about 5 s), and after the last latch the vault door opens.
- Fix: `blowtorch.lua` (`frame(pc)` from the director's per-frame section). While the torch fires (`BurstCounter` above 0), every
  0.1 s, on each door near you the lock whose box middle is nearest your aim line (camera, up to 3 m, within 30 cm) loses
  50 health a second of 300, and the door is told with its own `LockDamaged(FName, share 0 to 1)`. When a door's three locks are at 0
  it sets `bIsUnlocked`, which the "F requires blowtorch" prompt checks. State is `raid.torch`, new each raid. The boxes are looked
  for every 10 s while firing only.
- Also: the Blowtorch is in the F9 gun list (`debuggive.lua`, 250 charge), so it can be spawned for testing.
- Mistakes on the way: testing points along the aim against the boxes burned all three locks at once (the box test counted the
  camera as inside all three), so the nearest line to the aim is used. The door takes the share as 0 to 1 (it stored 0.9667 for
  290 of 300). The latch's fall starting exactly 10 s after its lock hits 0 is the door's own Delay, not lag.
- Verified (the test copy of this logic, 2026-11-18): the three locks burned one at a time, only the aimed one glowing and falling;
  the latches fell 10 s after each lock reached 0; `Door_OpenClose01` finished about 1 s after the last latch (the vault door
  opened). blowtorch.lua itself: [fill in after the test run].
- Not done: explosive barrels and gas cans. Their Blueprint (`00_UA_Exploder_Base`) only takes damage from a flamethrower or fire
  grenade area (`ReceiveAnyDamage`), from explosion damage as a radial hit (`ReceiveRadialDamage`), or from `GenTakenDamage(Amount)`,
  which looks like what a gun's hit calls. A plain damage hit and an explosion-type hit sent to a gas can (10 health) and a barrel
  (42) changed nothing. It is not known that the real torch sets them off, so they are left alone; if it does, calling
  `GenTakenDamage` from the burn loop is the likely fix (separate change). The decompiled flow is drawn in BLOWTORCH.md.

## #143 leftovers: ship hum, pod hint, camera turrets, hold contracts (2026-11-18)
- Ship interiors: FrigateInside_Starter BeginPlay `if not IsServer jump 3976`; the client side is only
  `Audio_EngineAmbience.FadeIn(2, 1, 0)`. Verified silent offline (IsPlaying false in your Starter). levelprops.lua
  now fades it in per RaidSpaceshipInside (every 15 s, for interiors spawned later); verified IsPlaying true in your
  FrigateInside_Starter_C and a rival's FrigateInside_Fast_Ai_C. Not checked by ear.
- Pod hint: Base_RaidNode / Base_RaidMovementNode PopupWarning_CantEnterAsPod @20 and their ubergraphs @288 return
  early `if HasAuthority()`. The gate is `1C <FinalFunction HasAuthority> 16 07`, not the `68 <CallMath> 17 16 07`
  pve_bp_jump knew, so the first try logged "patched" and changed nothing (kdis showed it): pvepatch.c now also accepts
  a no-argument FinalFunction on self before the JumpIfNot. main.lua CLIENT_BRANCHES patches the four, retried every
  10 s (station classes load later). Verified: both decode as `jump`; calling PopupWarning_CantEnterAsPod on a node
  with your pawn made a new Popup01_Widget_C in the viewport. Not checked: a real pod flying into a docking area, and
  what PlayerIsInPodVisuals changes on screen.
- Camera turrets (Base_CameraTurret01, ship periscopes): authority side turns the barrel anim and plays the turning
  sound; the skipped side only turns SpringArmNewOne to the controller's view, which already follows the mouse offline
  (see "Manning a turret yourself"). No change.
- Base_Contract_Hold overlaps: covered by missions.lua (flags + Client_CheckMissionEvent); opening the gate too would
  start a second Guard timer. No change.

## Space object explosions and sounds (2026-11-18, issue #15)
- Symptom: turrets (flak, rocket, triple, radar dishes) and mines (small, nuclear) died or went off with no blast and no sound.
  Their damage and removal worked.
- Cause (decompiled with tools/offline-audit/kdis.py): `SubNodeActorTurret_C`'s OnDeathEvent (ubergraph offset 591) and
  `SubNodeActorMine_C`'s ubergraph build the blast (`Exploder Class`, spawned deferred then finished) and play the sound
  (`Destroyed_Sound`, `Sound_Explode`) only behind `if GetLocalRole() != 3`, the client half. Offline our role is 3. The mine's
  radial damage comes before the gate (offset 43; the `JumpIfNot` is at 221 to 459) and ran fine, which is why mines still hurt.
  The exploder Blueprints (`/Game/Blueprints/Exploders/`) have particles and a destructible but no audio: the sound is always the
  dying object's own.
- Not fixable with `pve_bp_jump`: the gate is `NotEqual_ByteByte(GetLocalRole, 3)`, not the `CallMath(self)` or no argument
  `FinalFunction` shapes it patches. `bpbranch.py` does not list `GetLocalRole` compares either, so this one never showed in its
  output (a search of dumped bytecode for `GetLocalRole` finds them).
- Fix: `spacefx.lua` (loaded from `Space.init`) hooks the native `RaidSubNodeActor_Turret:NetOnDeathEvent` (it fires offline; native
  hooks on OnDeathEvent, HealthChanged and OnRep_Health did not) and `Actor:K2_DestroyActor` for a `*NodeMine*` whose mesh is
  already hidden. Each reads `Exploder Class` and its sound off the actor, spawns the blast at its place and plays the sound with
  `SpawnSoundAtLocation` (`PlaySoundAtLocation` and `PlaySound2D` from a probe seemed silent). Once per actor, pcall everywhere. A
  first mine hook on `ApplyRadialDamageWithFalloff` was followed by a game crash on the nuclear mine, so it is not used.
- How it was tested: the F9 spawner and Log explosions showed no effect near a killed turret; kdis read the gate; then each effect
  was made by hand from the probe runner, one at a time with a countdown, asking the tester what they saw and heard (radar dish and
  flak turret: blast and sound; small and nuclear mine: blast and sound, no crash; the rocket turret had no live instance); then
  the real hooks were registered from a probe and every turret type was killed in play: all work, naval base turrets included.
  The mine hook through a real trigger is not separately reported yet.
- The test tools are in `tools/space_test/` (F9 rows: Start a space raid, the space object, exploder and salvage spawners, Kill, Poke,
  Log explosions, Log salvage; `install.py` puts them into a test copy). The full chain, class and property table, flowcharts, the
  probe and the order of the testing: [docs/internals/SPACE_OBJECT_DEATH.md](../internals/SPACE_OBJECT_DEATH.md).
- Open: mines through a real trigger in play; the rocket and triple turret by hand; a turret's hit sparks and a mine's
  `Sound_Triggered` were not checked for the same gate.
