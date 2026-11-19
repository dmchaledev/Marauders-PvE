# AI soldiers, station guards, civilians and cover

The shared AI brain, station garrisons, cover, AI tuning (F3), difficulty presets, bot kits, civilians.

Part of the project's research log: [NOTES.md](../../NOTES.md) lists every topic file and every section title.
Sections are in the order they were written; a later section can correct an earlier one, so read to the end of a topic
before trusting a finding. When a section says "see X", search [NOTES.md](../../NOTES.md) for that title to find which
file it is in.

## Contents

- [PvE AI — WORKS (mods/PvEDirector, 2026-10-30)](#pve-ai--works-modspvedirector-2026-10-30)
- [Shared AI brain, step 1-2 (2026-10-31): ai.lua](#shared-ai-brain-step-1-2-2026-10-31-ailua)
- [Bot leg animation vs speed (2026-10-31)](#bot-leg-animation-vs-speed-2026-10-31)
- [Cover and peeking, faster (2026-10-31, untested in game)](#cover-and-peeking-faster-2026-10-31-untested-in-game)
- [Factions, station garrisons, rushers (2026-11-01)](#factions-station-garrisons-rushers-2026-11-01)
- [Station defenders = the levels' own NPCs (2026-11-01)](#station-defenders--the-levels-own-npcs-2026-11-01)
- [8 defenders per station; space-map navmesh bug (2026-11-01)](#8-defenders-per-station-space-map-navmesh-bug-2026-11-01)
- [Busier stations (2026-11-01)](#busier-stations-2026-11-01)
- [AI tuning menu, aim variety, firing on the move (2026-11-06)](#ai-tuning-menu-aim-variety-firing-on-the-move-2026-11-06)
- [Difficulty presets (2026-11-06)](#difficulty-presets-2026-11-06)
- [Your own presets (2026-11-06)](#your-own-presets-2026-11-06)
- [Stutter, lighting, bot aim, kit looks (2026-11-06, written; NOT yet run in game)](#stutter-lighting-bot-aim-kit-looks-2026-11-06-written-not-yet-run-in-game)
- [Native bot kits, tested (2026-11-07, supersedes the donor notes above)](#native-bot-kits-tested-2026-11-07-supersedes-the-donor-notes-above)
- [Play areas replace the one-box ban (2026-11-07, later)](#play-areas-replace-the-one-box-ban-2026-11-07-later)
- [Station guards: own gear kept, bags and pockets rolled (2026-11-07, later)](#station-guards-own-gear-kept-bags-and-pockets-rolled-2026-11-07-later)
- [Cover map and cover-first fighting (2026-11-13)](#cover-map-and-cover-first-fighting-2026-11-13)
- [Gear follows your level (2026-11-13; rolls checked offline with lupa, in game 2026-11-15)](#gear-follows-your-level-2026-11-13-rolls-checked-offline-with-lupa-in-game-2026-11-15)
- [Station NPCs spread out; live-like spawn counts (2026-11-14)](#station-npcs-spread-out-live-like-spawn-counts-2026-11-14)
- [TODO: boarder corpse legs explode into spikes (seen 2026-11-14, not investigated)](#todo-boarder-corpse-legs-explode-into-spikes-seen-2026-11-14-not-investigated)
- [Station fights end too fast; AI legs too fast (2026-11-14; arrival stagger tested 2026-11-16)](#station-fights-end-too-fast-ai-legs-too-fast-2026-11-14-arrival-stagger-tested-2026-11-16)
- [Crews and guards by station size (2026-11-14; guard counts tested 2026-11-16)](#crews-and-guards-by-station-size-2026-11-14-guard-counts-tested-2026-11-16)
- [Asleep guards at stations you haven't entered (2026-11-14)](#asleep-guards-at-stations-you-havent-entered-2026-11-14)
- [Guards ignoring your fire while fighting through a wall (2026-11-14)](#guards-ignoring-your-fire-while-fighting-through-a-wall-2026-11-14)
- [Baked cover never used inside Rebel Base; soldiers out of sight backpedal (2026-11-14; tested 2026-11-16)](#baked-cover-never-used-inside-rebel-base-soldiers-out-of-sight-backpedal-2026-11-14-tested-2026-11-16)
- [Every baked cover spot "off limits": integer vs float cell keys (2026-11-14; tested 2026-11-16)](#every-baked-cover-spot-off-limits-integer-vs-float-cell-keys-2026-11-14-tested-2026-11-16)
- [Soldiers backpedalling instead of taking cover (2026-11-14)](#soldiers-backpedalling-instead-of-taking-cover-2026-11-14)
- [Cover a long walk away; melee soldiers swinging at nothing (2026-11-14)](#cover-a-long-walk-away-melee-soldiers-swinging-at-nothing-2026-11-14)
- [Bots animate at the display's rate (2026-11-17; main.lua trackTargets and animate)](#bots-animate-at-the-displays-rate-2026-11-17-mainlua-tracktargets-and-animate)
- [Civilians (issue 81, 2026-11-18; civilians.lua)](#civilians-issue-81-2026-11-18-civilianslua)

## PvE AI — WORKS (mods/PvEDirector, 2026-10-30)
Why bots did nothing, and the fix for each (all automated in PvEDirector):
1. **No navmesh in the shipped client.** Raid maps have only AbstractNavData; every AINodeStart names a stream level
   "SpaceportWhitebox" that isn't in the client pak (server-only content). Fix: set Default__RecastNavMesh
   RuntimeGeneration=2 (Dynamic), spawn a RecastNavMesh, spawn a NavMeshBoundsVolume and give it the
   CullDistanceVolume's BrushBodySetup + transform (runtime volumes have no brush; toggle scale to recompute bounds),
   then NavigationSystemV1:OnNavigationBoundsUpdated(vol). Builds the whole Spaceport in ~1 s.
   (Passing a non-NavMeshBounds volume to OnNavigationBoundsUpdated reads garbage SupportedAgents → nothing builds.)
2. **Bots spawn asleep**: CustomTimeDilation 0, movement tick off / interval 1 s, MovementMode None, mesh hidden,
   bActiveated false. Shortly after spawn the bot also **unpossesses itself and stops its BT**. Fix: wake all of
   that, keep the controller, re-possess + RunBehaviorTree(BotBehavior) + BB IsDeactivated=false whenever found detached.
3. **Stale PathFollowingComponent**: MoveTo fails/never moves until the controller re-possesses the awake pawn.
4. **Teams**: player and bots both team 0. Player PlayerState.TeamNumber=1, RaidAIController.TeamNumber=2.
5. **Perception** never reports the player (HasLosToEnemy stays false); the BT attacks as soon as BB "Enemy" is set.
   PvEDirector sets it when the bot hears (≤900) or sees (≤6000, 70° half-angle, LineOfSightTo) the player, or is hurt.
6. **Invisible shooting**: asleep, the skeletal mesh has tick off / interval 1 s / bNoSkeletonUpdate=true, so the bot
   never visibly turns or aims; and its gun was never equipped, so RaidAIController::ShootEnemy (called every frame
   while engaged) applies damage directly with no weapon effects and no ammo use. Fix: wake the mesh
   (tick on, interval 0, bNoSkeletonUpdate=false, VisibilityBasedAnimTickOption=1), bot:ServerEquipWeapon(CurrentWeapon)
   (afterwards Server/MultiSimulateWeaponFire run per shot), and ctrl:K2_SetFocus(player) on engage.
7. **No muzzle flash / gunshot audio** even after equipping: per AI shot only ServerMultiSimulateWeaponFire runs
   (fire anim + recoil); flash and sound are skipped for bots (weapon.MuzzlePSC stays none). Fix (PvEDirector hook
   on that function, bots only): GameplayStatics:SpawnEmitterAttached(w.MuzzleFX, w.Mesh1P, w.MuzzleAttachPoint, ...)
   and w:OnFiringSound(false, 30, 30, muzzleSocketLoc, w.FireSound). Confirmed in game by the user: both work.
   CurrentAmmoInClip stays 30 (AI may have infinite ammo by design).
8. **Turning**: the AI controller snaps rotation to its focal point every tick (body follows via
   bUseControllerRotationYaw). A per-frame SetControlRotation/K2_SetActorRotation override made it worse, and
   K2_ClearFocus left it facing a stale Move-priority focal point from the last patrol leg. Setting focus once on
   engage isn't enough either: something (a tree service on a timer) keeps replacing it with a slowly refreshed
   point, measured 100-1000 units behind a circling player (felt as "takes ages to turn"). LastKnownPlayerPosition
   is NOT that point. Fix: K2_SetFocus(player) every frame while the bot has LoS (K2_SetFocalPoint(lastSeen)
   without) → focal offset 0, body error 3-7 deg at 1.5-5 m (17 deg at 1.6 m).
   Also: mesh bEnableUpdateRateOptimizations (URO) was on → animation frames skipped, choppy. Turned off.
   Bot MaxWalkSpeed 220 and crouched 220 (player walks 280); director uses 220 patrolling, 380 fighting.
9. **Patrols**: the tree does nothing without an Enemy and ignores BB "destination". Idle bots get StopLogic and walk
   MoveToLocation legs to random reachable points within 1800 of their spawn, pausing 4-12 s.
10. **Combat movement / walking in place**: BB destination and CoverEQsResult stay at FLT_MAX and HasLosToEnemy stays
    false offline (cover EQS / LoS service find nothing), so the tree retried an empty move: crouch + walking in
    place. Director sets HasLosToEnemy (LineOfSightTo), and every 3-7 s a reachable destination (500 around the bot
    with sight, 400 around last-seen without) + issues a strafing MoveToLocation (bCanStrafe keeps focus) — the tree
    doesn't cancel it. Crouch toggling every ~2 s is the tree's own crouch-peek.
11. **Floating helmets**: helmet "Helemt", backpack "Backpc", "ChestSlot" are SkeletalMeshComponents attached to
    CharacterMesh0 with no master pose (set only when a bot activates normally) → rest pose, floating.
    Master pose alone wasn't enough: the gear components are asleep like the body (tick off, interval 1 s,
    bNoSkeletonUpdate) so their drawn pose never refreshed (bone data already matched the head). Fix: wake each
    gear component the same way, then SetMasterPoseComponent(body, true).
12. **Foot sliding / slow legs**: AI anim BP rc_AI_FPS_AnimBP (/Game/Characters/MainPlayer/) sets
    Standing_LegsPlayrate itself each update (1.1 walking, 0.65 aiming) and overwrites Lua writes; RegisterHook
    post-callbacks on its BlueprintUpdateAnimation never fire (pre only). So speed follows legs instead:
    MaxWalkSpeed = 200 x Standing_LegsPlayrate every frame (220 / 130). MaxWalkSpeedCrouched 220 → 132 and
    Crouching_Legs_Playrate (BP leaves it 0) = speed/132. Anim Speed var matches velocity exactly (no lag).
13. **Moonwalking**: fighting moves crawling at 23-38 u/s (blocked) → cancelled after 1 s below 60 u/s.
14. **Crouch-peeking**: capped at 2.5 s crouched, then forced standing (UnCrouch every frame) for 6 s.
    NavAgentProps.bCanCrouch can't be written from UE4SS Lua (nested struct write errors).
15. **Cover + leaning** (director section 6). Game cover (CoverGenerator plugin: ACoverGenerator, UCoverPoint with
    left/right lean flags, cover EQS tests) isn't placed offline; a spawned ACoverGenerator +
    OnNavigationGenerationFinished(navmesh) generates 0 points. Own search instead: 16 reachable spots within 900,
    500-3500 from the player; full cover = standing eye (floor+150) can't see the player but eye ±35 sideways can;
    low cover = crouched eye (+85) can't, standing can (penalised +500 so full cover wins). LoS probes are
    ctrl:LineOfSightTo(player, viewPoint, false). Cycle: move → hide 1.5-3 s → peek 1.5-3.5 s → ... new cover after
    8-15 s or when flanked (exposed at the hide eye). Lean = ARaidCharacter:ServerLean(1 left / 2 right / 0),
    GetLeanAmount -40/+40, head shifts 20-45 units. Leaning doesn't move the AI eye, so LoS while peeking is probed
    from the leaned head. The tree fires at BB Enemy regardless of sight and the controller at MyEnemy: hiding clears
    both (BB ClearValue + MyEnemy=nil), peeking restores; combat state lives in e.inCombat. Result: 0 shots from
    behind cover, ~13% of shots leaned out.
16. **Speed**: whole-body GlobalAnimRateScale 1.45 while moving (>30 u/s) and MaxWalkSpeed = 200 x legs rate x 1.45
    → walk ~320, aiming ~190 with matching legs. Tree "shuffle" input creeping <60 u/s with no move request →
    StopMovementImmediately. Crouch out of cover capped 1.2 s / 10 s cooldown; posture enforced every frame.
17. **Leaning is cosmetic for AI**: while leaned out with BB Enemy, MyEnemy, bCanSeePlayer, HasLosToEnemy all set,
    RaidAIController::ShootEnemy ran ~80x/s but barely fired — it traces from the real (unleaned) eye, still behind
    the wall. Fix: each full-cover spot gets a walkable firing point 60 to the side (K2_ProjectPointToNavigation,
    verified standing LoS); peeking strafes onto it (+ ServerLean for looks), hiding strafes back. Cover search goes
    900 then 2200 before ever fighting in the open; running to cover holds fire (Enemy + MyEnemy cleared), clears
    focus so it faces the path, anim x2.0 (~440). Real sprint (StartSprint, MaxSprintSpeed 550) doesn't engage for
    bots. Result over 30 s: 45 shots, 40 from firing points, 0 while running, 5 standing (low cover / no cover).
18. **Exposed runs**: a soldier in the player's sight only takes cover within 600, and abandons a cover run after
    1.5 s in sight; then 4 s of open fighting before it searches again. Open fighting = side-steps of 200-450 across
    the player's line of fire (walkable-projected) every 1-2 s, anim x2.2 (~290 at the aiming legs rate).
    30 s sample: 52 shots = 20 peeking, 15 strafing, 17 still (low-cover pop-ups, step ends).
19. **Sprint animation** (written, NOT yet tested after a restart): AI anim BP has no run cycle; slots are
    DefaultSlot / FullBodyCinematic / JumpLandAdd / hitReact. A dynamic montage of
    /Game/Characters/MainPlayer/Animations/00_BaseMovement/rc_Sprint_FW_New on FullBodyCinematic keeps playing
    (on DefaultSlot it was cut within 1 s). Director plays it while running to cover at 550, stops on arrival.
    Real sprint for bots: ServerSetRunning(true) sets IsRunning briefly; StartSprint doesn't engage.
20. **Player loadout**: player spawns offline with an empty Inventory. UE4SS World:SpawnActor returns nothing for
    weapon classes. WORKING: take a freshly spawned donor bot's ARaidWeapon → SetOwner/Instigator/MyPawn +
    OnRep_MyPawn → append to pawn.Inventory (`arr[n+1]=x` works) → pawn:ServerEquipWeapon(gun) → donor.CurrentWeapon
    = nil, donor.Inventory:Empty(), K2_DestroyActor. Director does this at raid start (CFG.GIVE_GUN) and on F6.
    Reload fails offline (no ammo items in the SIGIS inventory); cheat toggles had no visible effect. Stopgap:
    R sets CurrentAmmoInClip back to the magazine size (director + bridge). Real fix = ammo items via inventory.

## Shared AI brain, step 1-2 (2026-10-31): ai.lua
Engine checks (AI_DESIGN.md §4):
- Bot vs bot damage WORKS between awake, possessed bots on different TeamNumbers (BotPawnMilitary shooting another
  at ~7 m: 23 shots, 119 damage in 12 s). The earlier "sleeping NPC takes no damage" was the sleep.
- Accuracy: RaidBot.AIMissRate is the dial (defaults: BotPawn 0.85, Military 0.65; AIDifficulty 0.2 / 0.5,
  AiMissRange 2.25, AiMissRangeForAimedoff 1000). AIMissRate 0 did ~2x the damage per shot of 0.65-1.0 (noisy:
  guns differ per spawn). ShootEnemy (RVA 0x17eced0) itself only reads AIDifficulty (rand < it -> an extra vcall
  +0x7f0 with the enemy location); then fires via RVA 0x18192a0 / 0x1811890.
- Player shots run ServerMultiSimulateWeaponFire once per shot (same as bots) plus ServerTraceFireProjectile and
  ServerTraceMultiFireProjectile(Origin, ShootDir) (for near-miss suppression later). So one hook = all gunshots.
- Player state: pawn:IsHealing(), weapon:IsReloading() callable; ServerStartReload hook fires on reload.
- Not yet checked: ReloadAIWeapon animation, ShootAtLocation on a RaidAIController.
Built:
- mods/PvEDirector/Scripts/ai.lua: profiles (rival 1.0 / boss / guard 0.55 / soldier 0.3: spot-time multiplier,
  sight, cone, hearing, dispersion, reaction time, AIMissRate), 8 personalities with power-based picking
  (ramps), knowledge per enemy, gain-sight vision (distance curve x moving/crouch/peripheral/close/elevation/under
  fire/re-acquire/looking away), footstep + gunshot hearing with distance-based dispersion.
- main.lua: soldiers get profile by kind (BotPawn soldier, Guard/Military guard) and a personality; noticing is
  AI.perceive (gradual), reaction delay before first shot (e.holdUntil, released in trackTargets), noises at peace
  -> charge / freeze-watch-then-investigate-then-look-around (personality), every shot is AI.noise.
- rivals.lua: bodies get the "rival" profile; personality from kit power, kept per member (logged on materialize).
- Offline sim (lupa, scratchpad ai_sim.lua): spot times at 60 m standing: rival 1.0 s, guard 1.5, soldier 2.0;
  moving halves it; 50 deg off-centre 2.5-4 s.
- In game (Spaceport): loads, soldiers hear footsteps and log "(soldier/Rat) heard footsteps". Spotting not yet
  seen in game (test teleports put the player under the map; the start spot is inside the drop pod).
- Testing tip: don't teleport the player by navmesh projection on Spaceport, the navmesh reaches under the map.

## Bot leg animation vs speed (2026-10-31)
Per-frame log (bridge/t_legs.lua -> bridge/legs.txt; anim BP rc_AI_FPS_AnimBP_C reads Speed, Direction, IsAiming?,
Standing_LegsPlayrate 1.1/0.65) while watching the screen:
- RaidCharacterMovement.MaxMoveBackAndStrafeSpeed = 0.1 on bots (player 0.8): any sideways/backward move is capped
  at 10% (17 u/s aiming, 48 walking), and fighting bots strafe most of the time, with legs cycling at the full
  2.2x speed-up = shuffling on the spot. Now set per ai.lua profile (rival 0.8, boss 0.75, guard 0.65, soldier 0.6).
- The fixed GlobalAnimRateScale (1.45 / 2.2 when moving) also applied crouched (crouch speed 132 isn't raised) and
  the cover sprint montage (made for 550) played at 1.0 while the aim modifier held the bot to ~330.
- Fix (main.lua animate): GlobalAnimRateScale = actual speed / the cycle's natural speed (walk 200 x leg rate,
  crouch 132, sprint 550), clamped 0.6-2.4, smoothed; MOVE/STRAFE_ANIM_SCALE now only set the top walking speed.
  After: side-steps 103 u/s at 0.79x, crouch-walk 79 at 0.6x, side-runs 290 at 1.32x.
- Computer-use key presses (F8) don't reach the game's UE4SS key binds; use the bridge for test actions.

## Cover and peeking, faster (2026-10-31, untested in game)
- Smiley sprites: RaidBot's Billboard shows the AI debug state (sprite texture "AISTATE", RaidBot.SetDebugState).
  Hidden once per bot (it stays hidden through state changes): AI.tuneBody for director bots, the bridge `bot` verb.
- Peeking was slow: hide/peek only switched on the 0.5 s update, and the 60-unit step to the firing point was a
  pathed move under the bots' sideways cap (MaxMoveBackAndStrafeSpeed 0.6 x ~190). Now trackTargets switches
  phases every frame, and animate() gives the step PEEK_SPEED 450, PEEK_ACCEL 6000 and no sideways cap.
  HIDE {0.7,1.6} s, PEEK {0.9,1.8} s.
- More cover: searches every COVER_RETRY 1 s (was 2), 24 candidates within 11 m, runs for cover up to 12 m away in
  sight (was 6) for up to 3 s, OPEN_FIGHT 2 s (was 4), cover 3.5-40 m from the player. Shot while peeking: duck
  back at once; shot in the open: search for cover at once (e.hurtAt, HURT_DUCK_SECONDS).
- Crash (13:13, EXCEPTION_ACCESS_VIOLATION executing heap, in UE4SS's hook dispatch under a blueprint call):
  the Multi_Deathevent hook ragdolled/unpossessed the bot inside the death event. The hook now only queues the
  ragdoll for the next frame (onTick's `pending`). Since then: 3 kills by ApplyDamage and 1 by player gunfire
  (bridge/t_shootbot.lua) plus the user's play, no crash. Crash reports: %LOCALAPPDATA%/RaidGame/Saved/Crashes;
  scratchpad dmp.py lists the faulting address and the stack's return addresses (pip minidump).

## Factions, station garrisons, rushers (2026-11-01)
- Director AI is faction-based now (main.lua): factions = station soldiers ("station"), each rival crew
  ("crewN", team 10+N so bot damage applies between crews), and the player (team 1). Everyone is hostile to every
  other faction. Each bot keeps its foe as an ENTRY (PLAYER sentinel or another raid.bots entry; foeOf(e)), never a
  pawn, so a foe that died reads as gone (reapDead clears entry.bot). updateBots sizes up every hostile body within
  PERCEIVE_RANGE (7000) with AI.perceive (nearest first); spotted -> engage(e, pawn, entry); heard -> investigate;
  shot by someone unseen -> the nearest hostile. combatHints/trackTargets/peek use the bot's own foe.
  ai.lua: the "heard up to" noise marker is per enemy (k.heardUpTo), since a bot now checks several enemies per update.
- Rivals no longer know where you are: in a station each body searches a new area every 50-110 s, preferring spots
  far from the crew's last 6 searched areas; they find you, other crews and soldiers only by sight/sound.
  Verified (Spaceport): 3 crews inside, "Zed spotted salvage_sally at 7 m" -> salvage_sally killed; soldiers heard it.
- Station garrisons on space maps: stations streamed into a space map had NO soldiers (log "soldiers alive 0" all
  raid). The first time you enter a station (rivals.lua playerPlace), the director queues CFG.GARRISON (8) soldiers
  at its RaidAINodeStart nodes (else random reachable points) >= MIN_SPAWN_DIST from you, spawned ONE PER UPDATE
  (spawnQueued): 8 spawns + a rival materializing in one tick crashed the game once (EXCEPTION executing heap from
  UE4SS's hook dispatch under the ReceiveTick hook; same signature as the old death-hook crash).
- Ship targeting: you and rival ships are equal candidates (same chance per sighting, MAX_ON_SHIP 2 each). Shot by an
  unknown shooter -> the nearest ship in gun range (no longer "you if close").
- Rushers (RUSHERS 0.25 of crews, logged "(rusher)"): never start fights in space, fly straight to a station and
  dock; they fight back only when shot at. Verified: rushers were first to dock.
- The station's own GOAP raiders (GOAPNodeBot_Raider_C, team 1 = the PLAYER's team, not director-managed) were awake
  and moving in one run and one was being shot. Not handled: they're neither soldiers nor rivals.
- PROBE CRASH RULE: an unpossessed bot's Controller comes back as a wrapper around NULL; reading a field through it
  (c.MyEnemy, c.TeamNumber) crashes the game (AV 0x18 in UE4SS, pcall can't catch it). IsValid-check every object
  before reading fields (bridge/t_botfight.lua does).

## Station defenders = the levels' own NPCs (2026-11-01)
- Space_Solo_01 places 25 node bots across the station/AI-frigate sublevels: 22 GOAPNodeBot_Raider_C + 3
  GOAPNodeBot_Boss_C (asleep, unpossessed; the GOAP brain doesn't run offline). Navy Outpost has 7 of its own; the
  Fortress none (it gets spawned soldiers). These are presumably the live server's station NPCs.
- rivals.lua garrisonStation (first time you enter a station): placedDefenders(st) = those classes inside the
  station box, not already in raid.bots (rival bodies are the same class); adopted ONE PER UPDATE (adoptQueued):
  old controller UnPossess, b.AIControllerClass = BotPawnMilitary's (RaidAIController), b:SpawnDefaultController(),
  X.arm (wake/possess/team 2/tree), entry { placed = true, patrolRadius = POST_RADIUS 900, hand = CharacterBody0,
  mind profile boss/guard/soldier }. Their own gun is kept in the body mesh's hand (holdGun each update,
  keepDefendersArmed). Fewer than MIN_DEFENDERS (4) of its own -> X.garrison spawns the rest as BotPawn soldiers.
- Brain row: b.CachedPlayerController is a WEAK pointer (FWeakObjectPtr): read it with :Get() (calling IsValid on the
  weak pointer itself errors). The row came back empty on Navy Outpost, so all were profiled "soldier".
- Teams: player 3 (was 1, which the placed NPCs default to), soldiers/defenders 2, rival crews 10+.
- Verified (Navy Outpost): 7 defenders up with their own guns (Webley, Bren MkII, LongDouble, Sten, DeLisle) in hand,
  visible, patrolling; one spotted the player at 4 m and engaged, another at 10 m. Screenshot: body looks normal.

## 8 defenders per station; space-map navmesh bug (2026-11-01)
- MIN_DEFENDERS = 8. A station with some of its own placed NPCs is topped up with copies (topUpStep, one step per
  update, after its own are adopted): a GOAPNodeBot_Raider_C body with the head/body/helmet/chest/backpack meshes of
  one of the station's own (template DATA recorded at adoption: mesh assets, gun class, profile, health; never the
  pawn), its gun = `summon <the template's gun class>` handed over on a later update (like the bow guns), armed on
  the station side (team 2, faction "station"), patrolling POST_RADIUS around a spot. A station with none of its own
  (Fortress) gets 8 of the raid maps' soldier types (X.garrison). Verified: Navy Outpost 7 + 1 (LongDouble), Spaceport
  6 + 2 (1911s like its own).
- BUG FOUND: on space maps the director's navMesh() returned the RecastNavMesh actor startSpaceNav spawned
  (RecastNavMesh_<n>), which the navigation system doesn't use: every space-map nav query against it came back empty
  (rival body spawn spots, rivals' station searching, defender spots, and main.lua's reachableNear for soldiers'
  patrol/cover/strafe points on space maps). navMesh() now picks the registered RecastNavMesh-Common on space maps.
  (The runtime rebuild works on -Common: it's RuntimeGeneration 2.) Raid maps unchanged.
- stationPoint(st): random reachable point within 3000 of a station's entries / defenders' posts (st.posts). No box
  check: a station's box is one navmesh volume (the first holding an airlock) and can miss most of the station.

## Busier stations (2026-11-01)
- Solo raids felt empty inside: solo crews were 1 person, stations only took crews into free berths (Fortress has 1,
  Navy Outpost 4; full = crews flew elsewhere), and 8 defenders. Now: CREW_SIZE solo/raider 2-3, crew 3-4;
  DOCK_SECONDS 200-450; RUSHERS 0.4; MIN_DEFENDERS and main.lua GARRISON 14; with every berth taken a crew holds
  off the station BERTH_WAIT (10 s) and then "breaches in" (state docked, ship parked at its holding point, no berth;
  undock() copes with no berth). Verified (Spaceport, ~4 min in): 5 crews (14 rivals, 2 breached), 6 own + 8 copied
  defenders; 6 rivals and 12 defenders alive around you, fighting each other; 90 fps.

## AI tuning menu, aim variety, firing on the move (2026-11-06)
- F3 in a raid: tuning.lua, 121 settings in 10 tabs (Aim, Fighting, Cover, Senses, Rivals, Bosses, Guards, Soldiers,
  Personalities, Crews). Rows point at the live tables (main CFG, rivals CFG via R.CFG, ai.lua PROFILES/PERSONALITIES),
  read when bots decide, so changes apply at once. Defaults = the tables' starting values. Changed values only are saved in
  config/ai_tuning.txt (id=value; ids are "Tab:KEY" or "Tab:KEY.1" for one end of a range), loaded at mod start. Delete it
  to go back to defaults.
- Building UMG from Lua works. Host: Create() a DebugInfo_Widget_C (UserWidget itself is abstract; any Blueprint with a
  canvas root will do), root:ClearChildren(), StaticConstructObject(<UMG class>, host.WidgetTree), AddChildToCanvas /
  AddChild. Delegates can't be bound from Lua: the open menu polls Slider:GetValue and Button:IsPressed every frame.
  TextBlock:SetFont throws (a non-string error: pcall's message prints as "function: ..."); write t.Font.Size directly
  before the widget is built. `shot showui` captures UI, HighResShot doesn't. Panel height comes from the viewport.
  Tested through bridge/menu_toggle (empty = toggle; "tab N", "reset", "resetall", "set <id> <value>"), which
  stays in as a test hook, and Slider:SetValue. REAL MOUSE CLICKS AND THE F3 KEY HAVE NOT BEEN TRIED.
- AIMissRate measured properly (bridge/t_dmg2.lua + t_aimrun2.sh: every bot held at one value by `set`, all with a 5000
  health pool, total damage among bots per shot fired, 35-146 shots per value): 0.1 = 5.1 and 4.5, 0.45 = 5.7, 0.85 = 2.3,
  1.3 = 2.4, 2.5 = 2.7 and 1.3. The dial works below ~0.85 and is flat above it, so old soldier miss 0.85 sat at the
  flat end. Between 0.1 and 0.45 no change showed up in this data. Guns differ per bot, so it's a shape, not a precise curve.
- AI.aimFor (main.lua combatHints writes AIMissRate each 0.5 s update while fighting): profile miss x lifelong skill roll
  x streak x moving, target moving, just hit, range, and settle after gaining sight, capped at AIM_MISS_MAX 1.0. Bases
  lowered to rival .35, boss .4, guard .5, soldier .6 so modifiers stay in the live range. Bots are somewhat more accurate
  standing still than before and about the same moving. The native aim itself wasn't reversed: ShootEnemy (0x17eced0) only
  reads AIDifficulty; where AIMissRate is consumed wasn't found. Note the settled-ragdoll mark uses AiMissRange (+0xcd0),
  only on dead bots.
- Cover: every move to cover used to be a weapon-down sprint. Now COVER_SEEK_CHANCE / aggression decides whether to seek cover
  at all (COVER_HURT_CHANCE when just hit), else it fights in the open OPEN_FIGHT_SECONDS x holdGround; c.run rolled from
  SPRINT_EXPOSED_CHANCE / SPRINT_UNSEEN_CHANCE; not run = walks there with focus and enemy kept, so it fires on the way.
  aggression and holdGround existed but were unused until now. Top-up copies and rivals share all of this.
- Result, default settings, Navy Outpost, ~85 s, bots fighting each other too: 214 of 249 shots moving (86%); shots across miss
  bands 0.2-1.0 (old first tuning: 60 of 99 at the cap); 37 walk-and-fire vs 10 sprint cover moves; no errors.

## Difficulty presets (2026-11-06)
- tuning.lua PRESETS, a row of buttons in the F3 menu: Easy, Normal, Hard, Very Hard. They set competence only: every bot type's
  miss, reaction, spotTime, sight, hearing, dispersion (multipliers on the defaults) and part of the Aim tab (absolute values).
  Cover, sprint, strafing and personality settings are untouched at every level. Normal = the defaults exactly (a x1 row returns
  r.default; snapping to the slider step changed 11250 to 11300). Nothing extra is saved: the highlighted button comes from
  matching the current values, and a hand-tuned value shows as "Difficulty (custom)".
- Result (bridge/t_preset.sh + t_dmg2.lua, alternating in one live fight, Merchant, 17 s each, 99-184 shots a run, damage among
  bots per shot): Easy 3.05, 2.68, 1.79; Very Hard 5.23, 4.32, 3.20. Very Hard won every pair, ~1.7x. Hard wasn't measured
  on its own. This measures accuracy only, not reaction or senses, and not damage to the player.
- The menu_toggle commands other than `set` need the menu open: an early run of this test was silently at Normal. Check the logged
  miss values match the preset.

## Your own presets (2026-11-06)
- "My presets" tab in the F3 menu: name box, Save, then Load and Delete per preset (Delete asks for a second click). Saves EVERY
  setting, unlike the difficulty buttons. Stored in config/ai_presets.txt: "[name]" then id=value lines, only what differs
  from the defaults, so a new default in the code reaches anything a preset didn't change. Loading sets absent rows to the
  default. The same name updates that preset; a blank name becomes "My preset N"; [ ] and control characters are stripped.
  "(active)" comes from matching the current values, nothing extra is stored.
- Test commands (menu open): "save <name>", "load N", "delete N". Text box: EditableTextBox GetText():ToString() (checked).
  HorizontalBox:AddChildToHorizontalBox(w):SetPadding works; Button:SetIsEnabled greys it.
- Verified through those commands: save, auto-name, name cleaning, load restores tuning and difficulty, delete, survives a
  restart. NOT tried: actually typing in the box and clicking the buttons (including Delete's second click).

## Stutter, lighting, bot aim, kit looks (2026-11-06, written; NOT yet run in game)
Measured live in a Navy Outpost raid, with WoW in front for all of it, so frame numbers are only rough: p50 11 ms, 100-400 ms hitches several times a second. The render thread was busy and the game thread mostly waiting.
- Minimap think() ran FindAllOf + FindFirstOf twice per think (gates, game state, game instance), every second and on every ROUTE_MOVED step. Now cached; gates only scan once the timer is out, every GATE_RESCAN s.
- The only world light is Node_Background_06's DirectionalLight: intensity 10, movable, DynamicShadowDistance 650000. Hiding it live visibly darkened the Navy Outpost and the held gun (mean brightness 39 -> 35). There is no world skylight (the one SkyLightComponent lives in /Engine/Transient). main.lua updateSun keeps it on only while not on foot. Effect on frame time not measured: all tests ran with WoW in front.
- tools/profile/threadsample.py samples the busiest threads from outside. bridge/profile_on makes the director write scan counts and slow ticks to bridge/profile.txt.
- 2026-11-16: bridge/profile_on is looked for every 3 s (main.lua profiler), not only when the director starts, so it
  can be dropped in or taken out mid-raid ("profiler on (bridge/profile_on)" / "profiler off" in the log; off puts the
  plain FindAllOf/FindFirstOf back and clears PVE_PROF). bridge/dir_eval.lua runs while it's on. Tested in the lobby:
  "profiler on" 5 s after creating the flag, then dir_eval ran (used it to debug lobbylabel.lua, issue #55). Before,
  every look inside a running raid cost a quit and a relaunch.
- Shot probe (bridge/t_shots.lua, 80 shots): bots shooting while not bIsTargeting keep the gun level (shotgun gun -3 deg, bullets +19). bIsTargeting bots track it within ~5 deg and play the arms' montage (rc_Mat49_Aim_Shoot_Mon); from the hip the arms play nothing while the gun runs Mon_*_Shoot on its own mesh. trackTargets now sets ServerSetTargeting while fighting (not sprinting or hiding). Forcing it live raised hand_r 41-55 from 43-50 above the capsule; no shots landed in that test window.
- GlobalAnimRateScale (0.6-2.4, for the legs) also scaled the arms' montage while the gun's ran at 1.0; animate now counters it with Montage_SetPlayRate.
- anim.Bend: non-zero (2.8-8.5) only on three top-up copies, which sit lower (head 46-53 vs 64). A Lua write doesn't stick (the BP rewrites it each update). Cause unknown; check whether these still point low once aiming is forced.
- bridge/t_kit.lua: placed raiders' looks match their loot. Mismatches were top-ups (template gear, donor loot) and takeKit missing Beret/Cap/Vest/Rig rows. wearKit now shows the donor's piece only for armour in its loot. Rival gear no longer uses the catalog pool, so it's less varied. Assumes donors wear their loot: check on the first run. Donors' ammo can mismatch the gun (M1Para or 1911 with 762Ammo; placed raiders carry 32Ammo): not fixed.

## Native bot kits, tested (2026-11-07, supersedes the donor notes above)
- Rival and top-up bodies have no donors now. pve_roll_kit writes a bot's WeaponToSpawn/PistolToSpawn/HelmetToSpawn/ArmourToSpawn/BackPackToSpawn handles (table at +0, FName at +8; UE4SS can't write these) and calls the game's kit step 0x17cae70. That makes the items, sets the worn meshes and spawns the gun a moment later (GUN_WAIT 6 s). pve_add_item calls 0x17ee690(bot, row, stack, condition, 0xc) for ammo and meds. takeKit, wearKit and pve_take_loot are gone.
- mods/PvEDirector/Scripts/gear.lua: rows of SIGIS_ExampleItemData by type and price, plus every head and body mesh (tools/offline-audit/gearrows.txt, itemrows.py, fnames.py). TIERS are price ranges over it. Defenders use the mid tier, on the station's own head and outfit.
- bridge/t_allgear.lua: 57 of 57 guns arrived and 57 test bodies wore every helmet, rig and bag row with matching loot. 40 heads and 42 bodies loaded. Live: 5 kills, every body held everything the bot carried (4-7 items).
- Frames with WoW still in front: p50 23 ms, max 52 ms, no 100+ ms hitches in 8 s (was 100-400 ms several times a second). In the Navy hall view: p50 56 ms, max 96 ms. Director after the first minute: no tick over 25 ms in the last 40 s of the test. Fitting rival ships still scans about every 5 s during the first ~60 s of a raid (~100 ms). Not measured with the game in front.
- Aim: 140 of 142 shots were bIsTargeting (was mostly off). Skeletal poses freeze off screen, so gun pitch of unseen bots is meaningless, and the first-round shotgun reading may have been that too. Only 2 rendered shots: gun +19, bullet +34. Guns may fall short of the aim on steep angles. Montage rate and bolt sync not checked by eye; fullbright not rechecked on a ship interior.
- UE4SS.log is read by mm_launch.sh before the new run rewrites it, so Play fires too soon and crashes in nakama-cpp: sleep ~25 s after launching first. Heredocs with apostrophes break the Bash tool here; write scripts with Write.
- Stand-in now copies state.json to backend/state.before-last-raid.json at each raid start (full stash, including items bought just before). The 2026-11-06 23:09 raid was closed, not crashed (no crash dump): Vanquisher, PPSh and SackBag restored exactly; 3 x 10mmAmmo 60 and 3 x BandageAid 3 inferred from the write pattern in server.log; 40540596 and 25379686 unknown, not restored.

## Play areas replace the one-box ban (2026-11-07, later)
- The sample shots were at Z~980: the roof. The runtime navmesh covers roofs and shells on every station and the map marks nothing as out of bounds. bridge/t_nav.lua maps the navmesh against designer markers: everything at z 850+ has none.
- main.lua offLimits: on the four stations (and MiniMine), a point needs loot, a contract object, an AI node or an airlock within 1800 units and 260 up or down. Ships are exempt. The sealed basement stays ruled out by hand (SEALED), since it has its own AI node. Built once per raid (mapPlayAreas).
- Rival arrival points (st.entries) included roof spots: filtered after survey, plus guards in stationSpawnSpots and spawnGarrison.
- Verified on Spaceport only: 381 positions, z max 707, 6 outside (single readings at z 500-600). Navy, Merchant and Fortress use the same rule but weren't sampled. Legit floors with no marker nearby are avoided by bots too.
- Proportions: bust 9.5, waist width 0.85, depth 0.83.

## Station guards: own gear kept, bags and pockets rolled (2026-11-07, later)
- User: "keep their basic equipment, but roll what's in their bags and pockets". Placed guards (GOAPNodeBot_Raider/Boss) carry their level rows: worn items in their slot's container (MotherItemGUID Head, Prim, Pistol, Rig, Bag...), plus one LootToSpawn row in the bag (its id) or LootPocketLeft, usually one ammo stack and maybe a bandage.
- pvepatch pve_keep_worn(bot): compacts BotLootItems (+0xbf0) in place to the worn containers and lowers Num (never grows). Dropped item actors are left alone. bridge/keep_worn.txt, if present, gets "kept of total" lines.
- rivals.lua rollCarried (adopt and finishTopUp): reads the five *ToSpawn rows, keeps them, then pve_add_item adds ammo for each gun (1-3 stacks of 20-60 for the main one), 0-2 meds and CARRY_BAG 2-5 picks from gear.lua loot (type 3), boxes (type 20, 6%) and parts (type 15, 12%), weighted 1/sqrt(price), capped at max(1500, 1.5 x worn value), uncapped 5% of the time. No bag = one pocket slot (the game turns away the rest): one roll (50% ammo, 20% med, else loot/part), re-rolled up to 4 times until it lands.
- Verified (Mini Mine, Penal Colony): every guard and copy logs "carrying ..."; a killed guard's body held exactly its worn gear plus the rolled list (9 items). Guards whose gun isn't in gear.lua get no ammo (rare). The bag's grid can turn away the last picks; the log lists what was attempted.
- Once, on the first Penal Colony visit, 7 top-ups found no defender spot (0 points); not seen again in the next run. The message now also counts points rejected as off limits (play-area rule, which now covers RebelBase, PenalColony, Asteriod, MoonBase).

## Cover map and cover-first fighting (2026-11-13)
- Problem (user): too much strafing in the open; earlier cover attempts sprinted around exposed, and peeks were slow and
  predictable. Causes: random-point cover search (24 random navmesh points rarely sit behind anything), COVER_SEEK_CHANCE
  0.5 / aggression (half the decisions chose the open on purpose), long open-fight strafing, and a hold timer that made
  bots "move" to the spot they were already in (3-60 units away).
- cover.lua (new): bakes cells (1600 x 1600 x 400 floor band) of 100-unit navmesh grid points, each traced in 8
  directions at +100 (crouched eye) and +160 (standing eye) within 90 units: full / low / corner masks (corner = a
  step of 120 sideways is clear and sees 200 past). Visibility channel via LineTraceSingle (LineTraceSingleForObjects
  with an object-type table from Lua hits nothing). Pawn hits ignored. 2 ms per frame, ~47 us per trace; cells around
  you on foot (COVER_BAKE_RADIUS) and around fighting soldiers. Saved per map in cover/<map>.txt (empty cells never
  saved, re-baked after 60 s in case a sublevel wasn't loaded). Spaceport_01 around the spawn: ~2000 points.
- main.lua: findCover tries the 6 best baked spots facing the player (score = distance + low penalty + aggression
  pull towards/away from the player) through probeCover, then a few random points. probeCover tries lean-out steps
  PEEK_STEPS {60,100,140} (60 alone failed 1110 of 1126 baked spots: "no peek"). Seek chance = 0.95 ^ aggression
  (hurt 0.99), OPEN_FIGHT 1.5 s, strafes 100-250 every 2.5-4.5 s. No hold timer (user: no reason to leave cover that
  still works): a spot is left only when flanked or after COVER_BLIND_PEEKS (2) peeks in a row without sight of you,
  then only for a spot >= COVER_MOVE_MIN (300) away, else it stays. No sprinting under 300.
- Status line logs cover stats, fighting samples (hiding/peeking/moving/open in sight/open unseen) and why baked spots
  fail. Test: bridge/cv_test.sh [nobake] (FLANK=1 moves you to a new angle 12-20 m from the nearest soldier every
  12 s via t_flank.lua; t_provoke.lua starts the fight); bridge/cover_nobake = random search only.
- Results (Spaceport, 5 soldiers provoked, 90 s, flanking on): open in sight 12 of ~1100 fighting samples; 37 moves
  (15 angle lost, 10 flanked, 7 move ended short), 25 to baked spots. Random-only with the same new decisions: about the
  same open time, more "flanked" exits (10 of 21 vs 4 of 11 in the comparable run). Most of the open-fight cut comes
  from the decision changes; the bake makes picks reliable and faster. Not checked by eye in play.
- Open: 7 "move ended short" (baked spot maybe unreachable/other floor: filter by path?); minimap.lua:135 errors every
  frame on raid maps (valid(home) with home = false, pre-existing). Next steps from the plan: exposure-scored routes,
  cover-to-cover advancing (the "open unseen" approach samples), reactive peeks (read your aim, keep aim between peeks).

## Gear follows your level (2026-11-13; rolls checked offline with lupa, in game 2026-11-15)
- `gearscale.lua`: rivals (`newMember`), station top-up guards and crew kits (`hire.lua` `H.tier`) roll a gear grade
  0..1 = position in each price-sorted gear.lua list. Centre = 0.15 at player level 1 -> 0.80 at `LEVEL_MAX`; 70% of rolls
  land below it (up to 0.35 under), the rest above (squared, up to 0.25), 6% anywhere. Helmet/chest/bag chances rise
  with the grade. Offline at lvl 1 / 20 / 40: budget-mid-geared 93/5/2, 45/51/5, 2/43/55 %; avg gun $1.9k / $4.5k / $8.5k.
- Player level: only the menu controller knows it; main.lua reads `pc:GetPlayersLevel()` every 5 s in the menu and
  writes `config/player_level.txt` ("level max"); raids read that. Cap = last level `GetXPForLevel` still rises at,
  else 40. Default level 1 until the menu has been seen.
- Crew: + `KIT_BIAS` (0.05) per crew level; a promotion never lowers the grade (`r.kitG`). Pool recruits from before
  this get re-kitted once at load; hired crew keep their kit until promoted.
- Off switch: `Rivals.CFG.SCALE_GEAR = false` = old fixed TIERS odds. Raid-map soldiers/guards keep the game's own gear.
- Station top-up guards do NOT follow your level: `adopt` records each placed guard's kit rows (`wornRows`: Weapon/Pistol/
  Helmet/Armour/BackPackToSpawn) and its head + gear meshes before female.lua dresses it. A top-up copies one template
  guard's helmet/chest/bag/pistol rows and meshes (set again in `finishTopUp` once the kit has arrived) and takes a gun
  some guard of that station carries. Unreadable rows -> the old mid-tier roll.
- Level off by one, and level 0 dropped (2026-11-15, tested in game): the game counts from 0 (a new player's lobby
  shows "LVL 0"; GetXPForLevel(0) = 0, (1) = 525, (20) = 29070), so GetPlayersLevel() returned 0 for a new save and
  setLevel ignored it: a new save kept the previous save's level (and its geared enemies), and the dev tree kept the
  tracked config/player_level.txt "8 40". main.lua now passes GetPlayersLevel() + 1; player_level.txt is per-player
  (gitignored, no longer tracked). The XP table keeps rising past 200, so the cap stays LEVEL_MAX 40 (mod levels).
- Checked in game, rolls sampled inside the director (bridge/dir_eval.lua, 4000 GearScale.roll()):
  game LVL 0 -> "player level 1 of 40", centre 0.15: budget 92% / mid 5% / geared 2%, helmet 41%, chest 32%;
  game LVL 20 (XP 29080) -> level 21, centre 0.48: 41 / 52 / 6 %, helmet 59%, chest 54%. Live raid at level 21
  (GearScale.roll wrapped for 3.5 min): 5 new rivals rolled 0.48 0.19 0.35 0.66 0.61 (4 mid, 1 budget).
- F3 "Gear" tab (2026-11-15, after a tester asked for it to be switchable): "Gear follows your level" (Rivals.CFG.SCALE_GEAR,
  now 1/0 instead of true/false: a slider writes numbers, and 0 is true in Lua, so rivals.lua and main.lua's
  rivals_scale test `~= false and ~= 0`), "Typical gear at level 1 / at the top level" (gearscale CFG.TARGET[1]/[2]),
  "Share of people below the typical gear" (DOWN_SHARE) and "Chance of any gear at all" (OUTLIER). Read when a kit is
  rolled, so changes show from the next crews/recruits. Checked in game: the tab draws (169 settings), `set
  Gear:SCALE_GEAR 0` through bridge/menu_toggle -> the director reads 0 (gear no longer follows the level) and
  ai_tuning.txt saves "Gear:SCALE_GEAR=0"; back to 1 removes it. bridge/menu_toggle is only read in raids.

## Station NPCs spread out; live-like spawn counts (2026-11-14)
- User: station NPCs often got into one big fight at once and all died. Cause: every "random" station spot (stationPoint)
  is within 30 m of an airlock or a guard's post, so guards (POST_RADIUS 9 m around where the level put them), crews
  spawning in and crews picking an area to search all ended up in the same few rooms, within PERCEIVE_RANGE (70 m).
- rivals.lua spreadPoint: each station keeps a pool of walkable points (st.spots, up to SPREAD_POOL 160, SPREAD_GROW 4 per
  update) that creeps outward: each new point is searched for SPREAD_STEP 25 m around the earlier point furthest from the
  airlocks/posts (best of 3), kept within SPREAD_REACH 150 m of one. A pick scores SPREAD_TRIES 16 pooled points by distance
  to the nearest other living bot (and where it's headed), plus `visited`, and takes the best.
- Used for: top-up guard spawns (defenderSpot), crews already inside when you arrive (stationSpawnSpots), crews picking a
  new area every ROAM_SECONDS (crewmates excluded, c.searched avoided).
- roamGuards (every update in a garrisoned station): idle station-faction bots (adopted, top-ups, garrison soldiers; not
  crewmates) leave their posts within GUARD_FIRST_ROAM 10 s, then move to a new spread point every GUARD_ROAM 60-150 s,
  walking about within ROAM_PATROL 12 m of it. A bot is tied to the station it was near when first seen (e.roamSt).
- Spawn defaults lowered to a typical live solo raid (estimate, not measured): CREWS 0 (11) -> 5, CREW_SIZE 2-3 -> 1-4,
  MIN_DEFENDERS 14 -> 6 (the levels place 25 across Space_Solo_01's stations, Navy Outpost 7), SKIRMISH_MAX 6 -> 3,
  main.lua GARRISON fallback 14 -> 6. CREWS 0 still means every free slot.
- Not tested in game yet. Look for guards walking away from posts and fewer "spotted ... at N m" lines right after arrival.

## TODO: boarder corpse legs explode into spikes (seen 2026-11-14, not investigated)
A Rusty Mule boarder killed on your ship (Space_Alpha, MG42) lay with its legs/feet stretched into a fan of black spikes
(skinned mesh blowing up on the ragdoll). Torso, pack and helmet fine. Probably a rival kit's lower-body part on a body
it doesn't fit, or the ragdoll of a pod-spawned body; check rollKit leg pieces vs the female/male body. Bad for footage.

## Station fights end too fast; AI legs too fast (2026-11-14; arrival stagger tested 2026-11-16)
- Footage station_fight2.mkv, Moon Base: three rival crews (10) and 8 defenders appeared within 6 s of arriving; two
  crews came out of neighbouring airlocks (Moon_11, Moon_12) at the same moment and fought on the spot. Gunshots carried
  100 m, so every bot heard every fight and went to look. All 10 rivals were dead in two minutes.
- Fix: ARRIVAL_STAGGER (rivals.lua, 45 s): one crew through a station's airlocks at a time. BOT_GUNSHOT_SCALE
  (main.lua, 0.4): bots' own shots carry 40 m; the player's still carry the full GUNSHOT_RANGE.
- Legs: animate() sped the whole body up to 2.4x to match speed (strafing 2.2x, peek steps 450 = 3.4x of the aiming
  walk's 130). User: "very silly rapid leg movement". Now LEG_RATE_MAX = 1.6 caps the rate and holds top speed to
  match, so strafing and peeking are a bit slower. Both new settings are in the AI menu.
- Second cause (station_fight4, Rebel Base, CREWS 0 = 11 crews): three crews that had docked before you arrived all
  materialized in the same update you walked in, before the station's guards were adopted (spreadPoint only avoids
  bodies that exist), and 5 of 7 died within 9 s. Fix: MATERIALIZE_GAP (3 s): one crew at a time, and only once the
  adopt queue, top-ups and every earlier body are done.
- Blue gaps at corners in that footage line up with hitches (18 freezes of 4+ frames a minute with 11 crews, 3 with
  the default 5): after a freeze the view jumps and occlusion culling is a frame behind. Not fixed; fewer crews helps.
- Launch crash at Play (twice, same stack hash, null read): Play pressed before the login reached the stand-in.
  mm_launch.sh now waits for "rpc getbuildinfo" in backend/server.log instead of a fixed 12 s.

- Tested (Space_Alpha raid, Rebel Base, god mode, 2 min fight with its guards, 2026-11-16): three crews docked at Rebel Base came in through its airlocks at 22:49:03, 22:49:49 and 22:50:34,
  45-46 s apart; the later two waited 31 s and 41 s in the chamber. Leg speed was not watched on screen.

## Crews and guards by station size (2026-11-14; guard counts tested 2026-11-16)
- User: bigger stations should have more people, and fewer crews should go to the small ones. Station size = its
  navmesh box floor area, logged in "[rivals] stations:" (Space_Solo_01: ~4k to ~107k m2).
- chooseStation is a weighted pick: capacity = area / STATION_AREA_PER_CREW (15k m2, at least 1), weight =
  capacity x STATION_CROWD (0.35) ^ (crews docked/heading there / capacity).
- Guards: MIN_DEFENDERS is for a STATION_AREA_MID (35k m2) station; small ones get as few as half, big ones up to
  DEFENDERS_MAX_SCALE (1.5x). STATION_AREA_PER_CREW and STATION_CROWD are in the AI menu.

- Tested: Rebel Base (96k m2) got 8 of its own guards plus 1 = 9, the 1.5x cap on MIN_DEFENDERS 6. Fortress (48k m2,
  a tester's log the same day) got 7 + 1 = 8, about 6 x 48/35. All three crews of the run went to Rebel Base, the
  largest station; one run says little about the weighting.

## Asleep guards at stations you haven't entered (2026-11-14)

The soldiers that stand still with no AI controller, frozen until shot, are the placed guards of a station you haven't walked into yet. That's by design: garrisonStation takes a station's guards over the first time you enter it. On Space_Beta and Space_Delta the volume at about 61000,-5000 is the Asteroid Mine (LevelStreamingVolume_AsteriodWhitebox_1), not part of Moon Base. bridge/t_volnames.lua prints, for each navmesh volume, its streaming volume, its area, and its raiders with and without AI. A "join the station's wing" fix based on the wrong reading went into 21fab81 and was taken out again.
- Messed-up heads under helmets after entering a station (tester report, 2026-11-15): placed NPCs carry a hidden
  second head, DecalMesh_* (always Raider_Head_Skel_01, attached to CharacterMesh0), for blood decals. wake()'s
  `mesh:SetVisibility(true, true)` propagates to it, so every guard adopted on your first visit drew that head over
  its own; a helmet (LeatherCap, Civilian_Helmet...) showed it poking through. Seen live: adopted 10 of 10 with it
  visible, never-adopted 0. wake() now hides DecalMesh* after the propagation; after: 11 adopted, 0 visible.
- Bridge crash to avoid: reading `bot.Helemt.SkeletalMesh` on a bot without a helmet component crashed the game twice
  (AV in UE4SS, not catchable by pcall). Read gear through K2_GetComponentsByClass and check each object first.
- Women's heads (2026-11-16): the DecalMesh fix covers them as is. female.lua dress() swaps the decal head for its HeadF
  copy too, but SetSkeletalMesh leaves visibility alone, and wake() hides it by name whatever mesh it holds. headfit.lua
  (measured on the men's heads) is also safe for women: each HeadF head run through make_female.female_head against
  every helmet, with make_headfit's own test and limits, fits wherever the man's does (never worse; 0-20 more fits per
  helmet). Women share the men's list, so they're kept to the stricter one. Checked offline, not watched in game.
- Still seen after that fix (2026-11-16, user screenshot: skin showing through a woman's gas mask). Live, 3 of 12 awake
  bots (2 men, 1 woman) had the decal head visible again: something after wake() shows the body with propagation once
  more. wake() now also sets SetHiddenInGame(true) on it, which propagation doesn't touch. Checked through the bridge
  on one affected bot: after that, Mesh:SetVisibility(true, true) left it hidden. Not yet watched over a whole raid.
- Streaky "odd texture" on a head (2026-11-16, user screenshot: a woman in goggles and mask under a garrison cap). Not
  the female reshape: the man's version of the same head looked the same. The head was drawing Raider_01_Head_MIC
  (as a MaterialInstanceDynamic the bot made from its starting head) over Outlaw_Head_Skel_01, whose own material is
  Outlaw_Head_01_MIC: wrong textures on the new head's UVs. A spawned raider keeps that MID when rivals.lua or a
  station top-up puts another head on. female.lua's SetSkeletalMesh hook now rebuilds the MID from the new mesh's
  own material on raider bots (the old one had no parameters, so nothing is lost). Live: 1 of 15 bots was wrong,
  0 after; the screenshot showed the proper leather mask. The hook itself takes effect from the next launch.

## Guards ignoring your fire while fighting through a wall (2026-11-14)

In Penal Colony a guard kept shooting a rival through a wall while the player shot it. Mid-fight retargeting only looked at foes much closer than the current one (RETARGET_NEAR, RETARGET_RATIO), and only counted rivals and crewmates as "shooting at me", never the player. Now, in main.lua, a soldier that takes damage while its current foe is out of its line of sight turns on the nearest hostile it can see, within PERCEIVE_RANGE. Not tested in game yet.

Kill list check from the same raid: KILLS showed Commando, Commando, Prisoner. Both Commandos were stray guards adopted at 17:36:10, not rivals, so the names were right. A rival you kill is renamed "Marauder" (killstats.lua, logs "[kills] a rival's kill moved").

## Baked cover never used inside Rebel Base; soldiers out of sight backpedal (2026-11-14; tested 2026-11-16)

Watching the footage, the user saw a soldier slowly backstrafing that never went for cover. In the log, every cover pick
that raid was "random", and the baked-spot probe count stopped at 39 (all "no peek") after 18:49:15, so no baked spot
was even tried for the rest of the raid, with 6978 baked points on the map. From 18:51:36 to 18:52:16 the two fighting
soldiers spent every sample "open unseen": fighting a target their LineOfSightTo said they couldn't see.
- Likely why baked spots were dropped: findCover filters baked candidates with offLimits, and offLimits treats a point
  inside a station's box as off limits unless a play marker (loot spawner, contract object, AI node, airlock) is within
  18 m. mapPlayAreas scans for markers once, when the raid is ready, while you're still 430 m out; Rebel Base streams in
  later, so its loot and AI nodes may be missing. Random cover points skip offLimits, which is why those still worked.
  Not confirmed: check how many markers mapPlayAreas found per station box.
- Out of sight, probeCover can't find a spot either: it needs a step out that sees the target, and nothing nearby does.
  So the soldier fights in the open, walking to a random point within ADVANCE_RADIUS (400) of where it last saw its
  target while keeping its focus on the target. When that point is behind it, it's a slow walk backwards.
- The "no cover" and "chose not to" paths log nothing, which is why this was hard to see.
Fix (main.lua, untested in game):
- mapPlayAreas counts loot, contract and AI-node markers per station box and logs "play areas: markers per station
  box: ...". offLimits treats a box with none as unmapped and rules nothing out in it.
- Aux.rescan: the first time you're on foot inside a station box, the markers are scanned again, one class per frame,
  and the new map swapped in: "play areas: rescanned on boarding <station>: ...".
- Open fights are logged, per soldier at most every OPEN_LOG_SECONDS (10): "<bot> fighting in the open: <why>, in
  sight / target unseen (baked N, off N, out of range N, no peek N, random N, random no peek N, ...)". Reasons: chose not
  to look for cover, no cover found, nearest cover too far to run in sight. The status line adds "| open fights: ...".
- Out of sight, a soldier picks the nearest of 3 points around the last-seen spot and moves only if that's at least 1 m
  nearer than where it stands; otherwise it holds and watches.
To check: the per-box counts at raid start and after boarding, whether "cover probes of baked spots" keeps rising
inside the station, and "sprinting to baked ..." lines.
First test (Space_Solo_02, Penal Colony, 2026-11-14): at raid start Asteroid and Moon Base boxes had 0 markers (so the
problem is real); the rescan on boarding ran ("rescanned on boarding PenalColony"). 9 of 53 cover picks were baked
(none the raid before), but most searches still dropped every baked spot as off limits ("baked 40, off 40"). The floor
being fought on had no loot or AI node within 18 m on its level (nearest ~12 m higher), so offLimits ruled the whole
floor out though the soldiers stood on it. Fix: findCover only filters baked spots by offLimits when the soldier's own
spot passes it (untested). bridge/t_off.lua checks the rule on baked spots around the player.

- Tested (Space_Alpha raid, Rebel Base, god mode, 2 min fight with its guards, 2026-11-16): play areas found RebelBase 101 markers. Soldiers took baked cover ("firing on the way to baked
  lean-left cover 521 away", "baked low cover 109 away") as well as random cover. Fighting samples: hiding 39,
  peeking 37, moving 94, open in sight 10, open unseen 27.

## Every baked cover spot "off limits": integer vs float cell keys (2026-11-14; tested 2026-11-16)
After 12ffc4a soldiers in Rebel Base (Space_Alpha, 101 markers) still fought in the open: every cover search logged
"baked 40, off 40". bridge/t_off2.lua ran the same rule from the bridge on one of those soldiers: all 97 baked spots
near it passed. The difference was the play-area cell key: offLimits built it with //, which gives a float for a float
("26.0", the engine's marker and soldier positions) and an integer for an integer ("26", baked spots loaded from
cover/*.txt). Baked spots never found their markers. Both keys now use math.floor (an integer either way).

- Tested (Space_Alpha raid, Rebel Base, god mode, 2 min fight with its guards, 2026-11-16): cover searches logged "baked 40, ... off 6" and "baked 40, ... off 18", no longer all 40. Baked
  spots were picked and reached.

## Soldiers backpedalling instead of taking cover (2026-11-14)

In a Space_Beta fight a soldier mostly walked backwards away from the player and rarely reached cover. The log showed
"firing on the way to ... cover ~600-800 away" followed seconds later by "left cover (move ended 500-2278 short)", and
the fighting samples were mostly "moving" (335) against hiding 17. Two causes:

- Walking to cover keeps the focus on the enemy so it can shoot on the way. For a spot behind the soldier that's a
  backwards walk, and backwards is capped at the strafe factor (~0.6) on top of the aiming slowdown: a slow backpedal.
  Now a spot whose direction is more than ~107 degrees from the enemy (cosine below -COVER_BACK_RUN, 0.3) and farther
  than COVER_MOVE_MIN is run to, weapon down ("turning to run back to ... cover").
- Moves to cover ended early (the tree, or the stuck check's StopMovement) and the soldier dropped the spot and
  started over. Now the move is sent again up to COVER_MOVE_RETRIES (2) times while it still gains 100+ units
  ("move to cover ended N short: sent again", with "(stuck)" when the stuck check stopped it).

## Cover a long walk away; melee soldiers swinging at nothing (2026-11-14)

Cover on Space_Beta was still rare. One soldier was "sprinting to baked lean-right cover 611 away" and "move ended
2727 short" six seconds later: the spot was near in a straight line but the navmesh route went round through other
rooms, so he ran away from the fight. findCover now asks the navigation system for the walk's length
(FindPathToLocationSynchronously, about 1 ms) on the spot it picks, and skips it when the path is partial or longer
than COVER_PATH_STRETCH (1.8) x the straight line + COVER_PATH_SLACK (300). These show as "long way round" (baked)
and "random long way round" in the probe counts and "fighting in the open" lines.

Knife and truncheon soldiers (weapons under Weap_Knife_C; Penal Colony top-ups copy guards that carry them) got the
gunman's hints: cover and strafing, with an Enemy set, and the tree swings at its Enemy at any range. They walked
around swinging at the air. Aux.isMelee walks the held weapon's class chain (cached per weapon); Aux.meleeHints makes
them charge the target (or where it was last seen), running past MELEE_RUN (450), with no Enemy set (setEnemy returns
early) until within MELEE_REACH (230), and it lets go past MELEE_LET_GO (330).

## Bots animate at the display's rate (2026-11-17; main.lua trackTargets and animate)
- Before: animate() ran CFG.ANIM_HZ (30) times a second for a fighting or busy bot, ANIM_PEACE_HZ (15) for one at peace,
  and ANIM_SLOW_HZ (10) past ANIM_SLOW_FAR (4000) from the camera. On a 120 or 144 Hz display that is a fraction of the
  frame rate, so gait, posture and the leg rate stepped. (This replaces the rates in the 2026-11-14 performance notes above.)
- Now every bot, near or far, runs animate() CFG.ANIM_HZ_LOW (60) times a second, or CFG.ANIM_HZ_HIGH (120) while the
  game's smoothed frame rate is over CFG.ANIM_HI_FPS (120) plus 5; it drops back to 60 under 115, so it doesn't flip
  between the two. 120 is the ceiling. The frame rate is measured in trackTargets (the gap between its calls, smoothed).
- CFG.ANIM_BUDGET (14) caps the animate() calls in one frame. Bots over it wait for the next frame, and the next frame
  starts where this one stopped (raid.animFrom), so no bot starves and a crowd can't stall one frame. A bot's next time is
  on a grid of 1/hz (due + step, not now + step), so a rate close to the frame rate isn't halved by rounding up to a
  whole frame.
- animate(e, now): crouch is read once; the leg rate smoothing is by time (k = 1 minus 0.5 to the power of dt x 30, dt
  capped at 0.2 s), so it settles in about 0.1 s at any rate (it was a fixed half step per call, tuned for 30 Hz); the
  top speed is worked out in a local and written once at the end (it was up to four writes and two reads). The aim
  upkeep of a fighting bot runs at the same rate; one at peace keeps ANIM_PEACE_HZ.
- Removed from CFG: ANIM_SLOW_FAR, ANIM_SLOW_HZ, ANIM_HZ. The engine's own cheaper animation past ANIM_FAR (6000) is
  unchanged.
- Cost to watch: a call is about a dozen engine reads and writes. With every bot animating every frame the 2026-11-14
  profile showed about 1.2 ms a frame and 3 MB of garbage a second for 20 bots; the budget bounds it. The cost at 60
  and at 120 Hz in a full raid was not measured separately: bridge/profile_on puts the aim section in profile.txt.

## Civilians (issue 81, 2026-11-18; civilians.lua)
- Miners (Mini Mine, Asteroid Mine, Moon Base), prisoners (Penal Colony) and workers (Spaceport, Colony Cruiser, Navy
  Outpost): CFG.COUNT per matching station (F3 How many "Civilians at mines, ports and prisons", default 3, 0 = off),
  spawned when you first walk into the station (rivalbodies.lua garrisonStation -> R.onStation). Body: raider body
  with an empty kit (R.civilianBody: equipKit with no rows gives no gun and no armour) and 1-3 trade items in pockets.
- Kept out of raid.bots: no soldier, rival or crewmate targets or protects them. Woken with Bots.arm, then the
  behaviour tree is stopped every update; all movement is MoveToLocation from civilians.lua (space-map branch of
  main's update). States: work (wander WANDER around home), flee (you in sight within FEAR_RANGE, your gunfire within
  SHOT_RANGE in the last 3 s via the ServerMultiSimulateWeaponFire hook's raid.playerShotAt, or hurt: run to the
  farthest of 5 reachable points, Help line), cower (you within CORNER_RANGE while fleeing: stop, crouch, plead).
  Killed near you: station guards (no faction, not crew) within ALERT_RANGE get e.alert (they come for you).
- Pitfalls hit: spots taken at random across a station's box were all off limits (12 of 12 at Penal Colony): they
  start at the station's RaidAINodeStart nodes like a garrison (the nodes are gone once used: a second batch found
  none). The stray sweep and the placed-NPC spawn hook adopted civilians as armed defenders: R.civilianAt (by address,
  cleared in R.reset) keeps them out of both. The space-map update returns early: Civilians.update sits there.
- Verified (Space_Solo_02, Penal Colony, god mode): "3 prisoners", each unarmed with 1 pocket item, 200 hp,
  wandering; you 8 m away in sight -> flee (23 m off a few s later); you 2.5 m away -> cower; ApplyDamage from you ->
  "you killed a prisoner ...: 1 guard(s) come for you" and that guard "knows where the player is".
- Not verified: by eye (animations, crouch, voice), looting a civilian's body, mines and ports (only Penal Colony
  tested), fleeing from real gunfire.
