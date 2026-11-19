# Weapons, damage and hit effects

Player guns, damage to and from bots, hit zones, armour, recoil, bullet impacts and holes. Number tables are in
[DAMAGE_REFERENCE.md](../internals/DAMAGE_REFERENCE.md).

Part of the project's research log: [NOTES.md](../../NOTES.md) lists every topic file and every section title.
Sections are in the order they were written; a later section can correct an earlier one, so read to the end of a topic
before trusting a finding. When a section says "see X", search [NOTES.md](../../NOTES.md) for that title to find which
file it is in.

## Contents

- [Player gun fires — FIXED (2026-10-30, session 4)](#player-gun-fires--fixed-2026-10-30-session-4)
- [Player damage, fire effects, native reload — WORKING (2026-10-30, session 4b; fresh-launch tested)](#player-damage-fire-effects-native-reload--working-2026-10-30-session-4b-fresh-launch-tested)
- [Recoil, bullet impacts, gore (2026-10-31)](#recoil-bullet-impacts-gore-2026-10-31)
- [Bot-on-bot damage, armour, aiming walk speed, your gunner's arc (2026-11-08, pvepatch.c + main.lua + rivals.lua)](#bot-on-bot-damage-armour-aiming-walk-speed-your-gunners-arc-2026-11-08-pvepatchc--mainlua--rivalslua)
- [Player shots: no hit zones on the mod's soldiers (issue 123; pvepatch.c pve_hit_capsule, hitzones.lua, ai.lua tuneBody)](#player-shots-no-hit-zones-on-the-mods-soldiers-issue-123-pvepatchc-pve_hit_capsule-hitzoneslua-ailua-tunebody)
- [Your shots at bots: armour, shotguns, meshes (2026-11-18; botdamage.lua, issue #123 follow up to the hit zones)](#your-shots-at-bots-armour-shotguns-meshes-2026-11-18-botdamagelua-issue-123-follow-up-to-the-hit-zones)
- [Bullet holes (2026-11-18; bulletholes.lua, docs/internals/BULLET_IMPACTS.md)](#bullet-holes-2026-11-18-bulletholeslua-docsinternalsbullet_impactsmd)

## Player gun fires — FIXED (2026-10-30, session 4)
- Root cause (disassembled from live memory): ServerHandleFiring_Implementation (RVA 0x1896b70) = `if (AmmoInClip() > 0
  && CanFire()) HandleFiring+UseAmmo`. The ammo getter (RVA 0x18875a0): ShipGun → 100; infinite-ammo check → 999; if
  MyPawn's controller is a player controller and MyPawn.EquipmentComp exists → returns the **StackAmount of the SIGIS
  item whose UniqueItemGUID == weapon.UUIDSIGIS** (0 if no such item, or if its item type byte > 1); otherwise
  CurrentAmmoInClip. Bots take the last branch, the player the SIGIS one → 0 → never shot. CanFire (0x187aa60) was fine.
- Fix (PvEDirector `loadGun`): Server_AddItem a weapon row with the gun's UUIDSIGIS into container "Equipment", stack =
  magazine size; R refills both. Firing drains the item stack in step with CurrentAmmoInClip. Verified: 17 shots/1 s held.
- Tools: `pc:SimulateInputKey({KeyName=FName("LeftMouseButton")}, true/false)` presses the trigger from Lua (no
  window focus needed). Original native thunks survive UE4SS hooks in UClass NativeFunctionLookupTable (RaidWeapon
  class +0x220, entries {FName, fn}); `_Validate`/`_Implementation` are vtable +0x660/+0x668 for ServerHandleFiring.
  Capstone disassembly of live code works (scratch dis.py pattern: procmem.read + capstone).
- Weapon hidden fields: +0x6D0 bit 0x04 = bWantsToFire, +0x6DC = weapon state (1 firing); pawn +0x8D4 bit 0x04 = wants to fire.
- Not yet checked: bullet damage on bots from the player's gun (no Server* trace RPC fires for the player in standalone;
  the shot path is native). Test by shooting a soldier.

## Player damage, fire effects, native reload — WORKING (2026-10-30, session 4b; fresh-launch tested)
- **native/pvepatch.dll** (pvepatch.c, built with the build.sh gcc line), loaded by PvEDirector at mod load via
  package.loadlib. Patches 3 role checks in memory (original bytes verified first; report in bridge/patch_out.txt):
  1. FireWeapon (vtable +0x7d0, RVA 0x1884b80) @0x1885c1a `jae` → 6-byte NOP (66 0F 1F 44 00 00): trace guns now
     send ServerTraceFireProjectile even as Authority. Standalone RPCs run Local, so the game's own server half
     (lag compensation, hit areas, damage) runs with the client's real trace. Without it shots never hurt anything.
  2. same for projectile guns (ServerFireProjectile) @0x1885d63 `73 28` → `66 90`.
  3. SimulateWeaponFire (vtable +0x7c0, RVA 0x189a490) @0x189a4a3 `je return` → NOP: it skipped all cosmetics
     (muzzle flash, OnFiringSound, shake, fire anim) for Authority weapons = everything offline. Bots get the real
     effects too now, so the director's bot flash/sound hook is off when this patch reports applied.
  A Lua-side alternative (calling the Server* RPCs with hand-made args) never did damage. A role change can't
  work either: standalone absorbs server RPCs from non-Authority actors.
- Firing needs the SIGIS HUD overlay: UseAmmo (vtable +0x748) refreshes the item's widget; no overlay = crash
  (null getter 0x9f2e80). Director `ensureHud` creates SIGIS_HUDOverlay_C and sets MatchHUD_C.InGameOverlay.
- Gun item: director gives the gun a FRESH UUIDSIGIS + item in "Equipment" (the donor soldier owns an item under the
  gun's original id; it was found instead of creating one, then died with the donor → gun had no item, couldn't
  fire). `keepGunLoaded` re-creates it if it ever vanishes.
- Ammo: EBulletType → row: 0 12Gauge, 1 300, 2 32, 3 45, 4 9mm, 5 10mm, 6 762, 7 54R, 8 556, 9 40mm, 10 Flare,
  11 FlameFuel, 12 Dart (row AmmoType byte at +0x1C0, ItemType +0x8 = 18 for ammo; read from the
  SIGIS_ExampleItemData RowMap). Director puts START_MAGS (4) magazines in PocketLeft (stacks of 60). The native
  reload (R, or automatic when empty) pulls from them into the gun item; loot from bodies (LootCon) works too.
  The old R refill hack is gone.
- Verified from a clean launch: 3/3 patches, HUD created, M712 + 2 stacks 10mm, fire drains the gun item, R moved
  10 rounds pocket → gun, soldier 80 → 58 HP, Muzzle_Flash_Small spawned. Gunshot audio not confirmed by ear yet.
- Testing from the bridge: `pc:SimulateInputKey({KeyName=FName("LeftMouseButton"|"R")}, true/false)`; after a
  bridge `raid` load call WidgetBlueprintLibrary:SetInputMode_GameOnly(pc) first (cursor/UI mode eats the input).
  scripts/gbase.py reads the module base from UE4SS.log (it moves between launches).

## Recoil, bullet impacts, gore (2026-10-31)
- **Recoil (fixed, pvepatch "Weapon recoil ammo gate")**: gun configs are fine (Bren VerticalRecoil 2.25, H +-0.75).
  The per-tick recoil (0x189f890, ARaidWeapon) needs weapon +0x26c > 0, the client's copy of the clip count, which
  is only written when Role < Authority (0x188c27f in the fire loop, 0x189c100 in StartFire; don't un-gate those:
  they then call the Server* RPCs, which run locally standalone). NOP of that `jle` -> verified: one ADS shot raised
  the aim 2.2 deg. By design the aim kick (pawn vtable +0x748 pitch / +0x740 yaw) only applies while
  bIsTargeting (pawn +0x9e8, ADS); hip fire only gets the control-rig arm shake (rc_FPS_AnimBP Recoil_*, which
  worked all along, camera wobble ~0.1 deg). The base FireWeapon (0x1884b80, all Weapon_Master guns) never touches
  currentRecoil/currentBulletSpread (+0x84c/+0x854): those are only used by subclass FireWeapons 0x1885ee0/0x18868b0.
- **Bullet impacts (fixed, pvepatch "Bullet impact effects")**: FireWeapon calls the client hit simulation
  0x18a1c70, which starts `GetNetMode() == 3 (NM_Client)` else return: impact FX, hit reacts (OnProxyHitReact
  event via 0x18d4900) and the pooled impacts (RaidPlayerController.PooledImpactActors, 150, taken by 0x1832420)
  never ran offline. Verified: 9 shots into the floor = 9 pool actors in use with particle, sound and decal set.
  Projectile guns (TraceFireWeapon false) skip 0x18a1c70 (FireWeapon 0x1885b57 jumps to the projectile branch); their
  hits go RaidProjectile OnRealImpact/OnRealAnyHit -> 0x189bc80, same NM_Client gate: pvepatch "Projectile impact
  effects" (0x189bcbc). Every gun seen so far is a trace gun (Sten, M1 Para, MG42, Bren, 1911, M712).
  M712 verified 14:06 (13/13 patches): scoped shot raised aim ~2.5 deg, 3 shots = 3 pooled impacts, impact actors
  BasePoolHitEffect_C at the hit point with PS_BulletHit_Concrete, VfxComp active right after the shot. Their
  DecalComp is nil, so bullet-hole decals are unconfirmed. Not watched on screen (an overlay masked screenshots).
  Later found missing and added by the mod: see "Bullet holes (2026-11-18)" at the end.
- **Gore (as designed, not an offline bug)**: Mulit_Dismember_Implementation (0x180c4b0) only calls the BP
  DismemberEvent; BotPawn_C AddComponent's a BP_C_SimpleGoreSystem_C (SkeletalMesh = CharacterMesh0, e.g. bone
  lowerarm_l). Its bytecode (all 4 functions) spawns a BP_ChunkActor (generic static Mesh_Hand/Arm/Leg/Foot), blood
  emitters and a decal, and never calls HideBoneByName/BreakConstraint: the limb stays on the model. Fix idea: on
  DismemberEvent hide BrokenBone on the bot mesh, and on the death body's pose meshes after the director's body setup.
- Tools (scratchpad, rebuild if gone): scan.py (all instructions using a displacement), calls.py (numpy rel32
  callers), xref.py (vtable pointers), bpscan.py / bpfns.py (UFunctions a BP function's bytecode calls: Script
  TArray at UFunction +0x60, names via the object dump's [n:] FName indices), wpatch.py (test-write code bytes).
- Recurring crash, NOT caused by these probes (seen 3x, once with no test hooks): AV reading 0xffffffffffffffff in
  UE4SS (+0x4bddae <- +0x380bb0 <- +0x37f6fe <- +0x87b9d0, Lua call path) during/after fights, ~1-10 min into a raid.
  FIXED, see "Dead-bot crash" below.

## Bot-on-bot damage, armour, aiming walk speed, your gunner's arc (2026-11-08, pvepatch.c + main.lua + rivals.lua)
- Measured (bridge/t_bothit.lua = health drop between a bot's shots on its MyEnemy, t_phit.lua = the same on you with god
  mode off and 5000 hp): bots hit YOU for the gun's full damage (20 / 30 flat), bots hit BOTS for ~1/6 (Mac-10 24 -> 3.3
  x13 in a row, Grease Gun 25 -> 4.2 x12). Client_WeaponHit, PawnTakenDamage, ReceiveAny/PointDamage never fire offline.
- Why (disassembly, scratchpad vt.py / scan9f0.py): the character damage function 0x181a8a0 (health -= at 0x181baf4) first
  calls the game mode's ModifyDamage (vtable +0x940 = 0x17e1870), then armour. ModifyDamage zeroes a hit CanDealDamage
  (+0x950) refuses and x DamageSelfScale (0x4fc, 0.3) when the instigator controller's PlayerState == the victim pawn's.
  Bots have no PlayerState: bot on bot is null == null, so every bullet counted as self-damage.
- Armour (same function): per hit zone (hit capsule's AreaHitType +0x460), damage = clamp(damage - armour, 0, damage) for
  the equipped helmet (head, then x HeadDamageMulitplier 3.5 bots / 3.25 you) or chest piece (body); legs x
  LegDamageMulitplier 0.5, no armour. The armour amount is the item's ARaidArmourActor.ArmourDamageMitagation (+0x228;
  +0x22c concussion for blast damage, 0x181f570). FLAT, not a share: M1FlakVest 7, Helmet_Brodie 7 (CDO values). So 24 x
  0.3 = 7.2 minus a ~4 vest = 3.3. Applies to every shooter, bots included. EquipmentComp.EquipmentIDs reads empty on every
  pawn (the lookup 0x8fd2c0 goes by slot name elsewhere); TMap ForEach fails from Lua.
- Fix (pvepatch.c selfScaleFix, "Bot-on-bot self-damage scale @ +0x17e194a"): cmp rbx,rdi ; jne -> call to a stub near
  the game: same AND non-null PlayerState returns to the mulss, else skips it. Your own self-damage keeps 0.3.
  After (Space_Charlie, Colony Cruiser): a 30-damage gun at 0 m hit a soldier 19.0 x4 (30 - 11 armour), both crewmates
  died in the fight, soldiers 21 -> 19. The interim Lua x6 scaling (scaleBotHits) is gone: it scaled after armour.
- Armour health bonus removed: rival and crew bodies got BASE_HP + HELMET_HP 15 + CHEST_HP 45 ("armour isn't simulated on
  bots"), but their kit goes through the game's kit step (equipKit -> pve_roll_kit -> 0x17cae70) and the armour works.
  Measured with the patch on (bridge/t_vict.lua, hits between a bot's shots on its MyEnemy, Rebel Base): a 160 hp rival
  (helmet + chest bonus) took 14 from 24 x11, 11 / 21, 8 / 18 (chest ~10 a hit); a 115 hp one (helmet only) took 28 / 28
  x5 on the body. Now rivals' maxHp = BASE_HP 100, your crew 100 + HP_PER_LEVEL 10 per level above 1 (in game: level 3
  crew 120 hp, no errors). Rival bodies' 100 not seen in game (none near). A hand-made ApplyPointDamage on a hit capsule
  (bridge/t_ptdmg.lua) crashed the game (access violation 0x38, under UE4SS): don't use it as is.
- Aiming walk (t_fightmove.lua): the game runs an aiming bot at MaxWalkSpeed x 0.5 forward, x 0.5 x MaxMoveBackAndStrafeSpeed
  sideways (TargetingSpeedModifier reads 1.0 on bots, so it isn't that field). Fights were walked at 75-95 and strafed at
  114-143 (you walk 280). animate() now divides MaxWalkSpeed by AIM_SLOWDOWN 0.5 while targeting, standing, not running
  (crouch untouched); profile strafe caps up (rival .9, boss .85, guard .8, soldier .75). After: 226-343 moving, 257-309
  strafing, anim 1.4-2.2x.
- Your crew gunner's arc: rivals.lua GUNNER_ARC 120 deg either side of the nose (rivals stay TURRET_ARC 60); fireTurrets
  takes c.arc, R.gunnerFire passes it. F3 Ship guns "Your gunner's arc". bridge/t_turarc.lua: barrels follow a written
  Yaw_Delayed past their TurretMin/MaxYaw (60): rocket artillery reached 120 / 139 / -120 / -140. NOT seen in a helm fight.
- A launch from the menu by bridge (t_play + t_launch) right after the user's own raid crashed in UE4SS Lua during Space_Beta's
  load (EXCEPTION_ACCESS_VIOLATION 0xffff..., RaidGame+0x1a605d0 from a Lua call); the relaunch was fine. Cause not found.

- Gunner callouts (2026-11-16, issue #52): fireTurrets leaves the reason in c.held ("range" or "arc") when no turret
  of the hull can bear on the target at all (any turret in arc, reloading, swinging or pitching = nil). crew.lua
  heldCall: after HELD_SAY (3) s on the same target and reason, the gunner says it once: "<name>: the <target> is too
  far, close in" / "<name>: can't swing onto the <target>, turn us toward it". Tested on Space_Solo_01 at a flak node:
  11000 away facing it -> the range line; 5000 away facing away -> the arc line, each a few seconds after "engaging".
- Sniping station turrets (2026-11-16, issue #47, Hayley's option 2): CFG.TURRET_RANGE_STATION = 13500 (the node
  turrets' FireDistance). gunnerFire sets gun.reach for a target whose class has "NodeTurret" in its name, and
  fireTurrets uses max(type range, reach); ship-to-ship ranges (TURRET_TYPES) are unchanged, so rival duels behave as
  before. Tested on Space_Solo_01, starter hull 12000 from a Flak_NodeTurret facing it: "Noor: engaging the turret",
  150 -> 21 -> dying in ~15 s (the shells do carry that far). Two earlier test crashes (UE4SS, read of
  0xffffffffffffffff) were the bridge probe reading the turret after the gunner destroyed it: probe by path
  (StaticFindObject) and stop at bIsDying.

## Player shots: no hit zones on the mod's soldiers (issue 123; pvepatch.c pve_hit_capsule, hitzones.lua, ai.lua tuneBody)
- Reported: every STG44 hit on a BotPawn_C or BotPawnMilitary_C did a flat 34, helmet or not, head or not.
- Confirmed in game (Space_Solo_01): STG44 head shot on a helmeted BotPawnMilitary_C = 34.0; Mat 49, 10 hands-on hits
  anywhere on one = 22.0 each (the gun's flat damage).
- Cause: the damage function reads the hit capsule's AreaHitType (see "Bot-on-bot damage" above). PlayerPawn_C and the
  map's own node bots (GOAPNodeBot_Raider_C) have 17 RaidHitCapsuleComponents (head/neck 1, body 2, left arm 3, right arm 4,
  left leg 5, right leg 6). The pawns the mod spawns (BotPawn_C, BotPawnGuard_C, BotPawnMilitary_C: soldiers, guards,
  rivals, crew) have none, and their body mesh blocks channels 3 (Visibility) and 15, which the player's and node bots'
  meshes ignore so a trace reaches the capsules. So the bullet stops on the mesh with no zone: raw damage.
- Player capsules (measured): query only, object type Pawn, block only channels 3 and 9-15, attached to the mesh at the
  bone of the same name with an offset. Table (socket, area, radius, half height, rel. location, rel. rotation):
  head 1 10/14 (2.9,0.5,0) (90,-355,-695); neck_01 1 7/8.8 (6.1,-0.3,0) (90,0,0); spine_03 2 13/20 (18.8,-5.9,0.4) (0,10,0);
  spine_02 2 15.7/23.7 (9,-2.2,1.1) (39,91,93); pelvis 2 13/19.1 (-2.3,-1.1,0) (0,10,0); upperarm_r 4 6.5/16 (-16.2,0.3,-0.8)
  (81,-1,-6); lowerarm_r 4 5.7/16 (-14.5,-0.4,0.2) (86,-160,-163); Hand_R 4 4.9/7.9 (-6.2,0.7,1.6) (88,-24,-25);
  upperarm_l 3 6.5/16 (16.5,-0.3,0.6) (81,-1,-6); lowerarm_l 3 5.7/16 (15.1,0,-0.4) (85,-16,-15); hand_l 3 4.9/7.9
  (5.6,-0.6,-1.7) (88,-24,-22); thigh_r 6 8.8/23.1 (23.8,-0.2,-0.7) (90,-46,-54); calf_r 6 7.9/22.4 (21.5,2.4,0.1)
  (88,-171,-170); Foot_R 6 4.9/13.5 (6.7,-7,0.7) (86,82,166); thigh_l/calf_l/foot_l 5 as the right side with x negated
  (-24.1,0.4,0.6) (-21.6,-2.6,0.7) (-6.6,6.6,-0.4). BotPawn* meshes carry every bone named here.
  Mesh responses to channels 0-17: player 220022020222222022, node bot 220022020222222020, BotPawn* 220222020222222222.
- Fix: AI.tuneBody (every director bot passes through it once) calls hitzones.ensure, which calls pvepatch.dll's
  pve_hit_capsule once per capsule, then sets the body mesh to ignore channels 3 and 15. pve_hit_capsule does what the
  engine does for a component added at run time, all through ProcessEvent (vtable +0x218) with hand-built parameter blocks:
  AddComponentByClass deferred (Class @0, bManual @8, FTransform @0x10, bDeferred @0x40, return @0x48), SetupAttachment by
  writing AttachParent (+0xc0) and AttachSocketName (+0xc8), AreaHitType (+0x460, 1 byte), SetCapsuleSize and the
  collision setters, then FinishAddComponent (Component @0, bManual @8, FTransform @0x10) with the offset from the bone,
  which registers it; OnRegister attaches it to the socket. Layouts were read from the UFunctions' property chains in
  memory (UStruct.ChildProperties +0x50, FProperty.Next +0x20, Offset_Internal +0x4c, ElementSize +0x3c): UE4SS's
  ForEachProperty fails here. Bots that already have capsules (node bots) are left alone.
- Measured with the fix (Space_Solo_01, Mat 49 on a BotPawnMilitary_C): head 80.5 (23 x 3.5), body 23, legs 11.5 (x 0.5);
  the same gun on one without zones did 22 anywhere. STG44 body hits 34 on both. Bodies of zoned soldiers loot normally.
  Not yet seen through AI.tuneBody on a director soldier at a station (the tests called hitzones.ensure from the bridge).
- Why not from Lua (tried, failed): AddComponentByClass from Lua leaves the component unregistered (UActorComponent flags at
  +0x88 read 0; a registered one with physics reads 0x07), whatever bDeferredFinish says; FinishAddComponent from Lua
  registers it, but a capsule attached before that never follows its bone (the body stays where it was registered), and
  K2_DestroyComponent / AddComponentByClass(bManualAttachment false) from Lua crashed inside UE4SS twice.
- Testing traps: bots spawned with the bridge `bot` verb aren't the director's: it hides their mesh and unpossesses them
  (floating guns); loading a renamed test copy of pvepatch.dll re-points the bot-death hook to that copy, so no body can be
  looted until a restart; ShootingRangeGameMode (bridge `raid`, F9 test raid) applies no damage to bots at all; a FindAllOf
  every frame from a bridge hook took the game to 5 fps.
- More bridge notes: test in Space_Solo_01 (F9 "Give me the STG44"). An AI-controlled bot moved with K2_SetActorLocation is put back: UnPossess it
  first. SimulateInputKey fires only while the game window has focus, and setting CurrentAmmoInClip by hand left the gun
  refusing to fire (CurrentAmmo read -30). KismetSystemLibrary:LineTraceSingle's bool works from Lua (start the trace in
  front of the camera, the ignore list didn't seem to apply); its hit result doesn't come back.
- Not looked at: Liberator pellets doing no damage (the multi-pellet path, 0x18a1990).

## Your shots at bots: armour, shotguns, meshes (2026-11-18; botdamage.lua, issue #123 follow up to the hit zones)
- Every number below, and the full per piece tables (all 24 vests, all 30 helmets, damage per zone, base damage per gun, shotgun volleys, how it was measured, what is still unknown), is in docs/internals/DAMAGE_REFERENCE.md at the repo root. Update that file when a rating or a base damage changes.
- hitzones.lua gives a bot the player's capsules, so the game's damage function reads a zone. Three things were still missing on a bot, and botdamage.lua does them. main.lua requires it, passes it the raid's bots and calls `BotDamage.frame(ticker)` every frame after the aim section (profiler section "damage"). CFG.PLAYER_DAMAGE = false turns all of it off and leaves the game's flat damage.
- Armour. The function takes the victim's armour rating off each hit, flat, before the zone multiplier: ((shot damage minus armour) x projectiles) x limb multiplier. A bot has no armour items, only a helmet mesh (component "Helemt") and a vest mesh ("ChestSlot"), so every hit did the full damage. The game's own rifle damage cannot be changed from Lua, so a hit that did exactly a known gun's base damage times 4, 3.5 or 1 (tolerance 0.03) gets min(rating, base) x that multiplier handed back as health. Head is 3.5 on soldiers and raiders, 4.0 was seen on guards. A hit times 0.5 (a leg) is never refunded, see the zones below.
- Ratings were measured, not taken from guides (2026-11-18, test install). A raider dummy wearing ONE piece (dressed through the game's kit step, pve_roll_kit), 100000 health, 5 m ahead, shot with the STG44 (34 a hit) with the view locked on the part under test; only hits whose line trace met that zone counted, 5 per zone. Vest rating = 34 minus the torso damage; helmet rating = 34 minus the head damage divided by 3.5. Every set of 5 hits was identical and every rating came out a whole number. All 24 vests and 30 helmets in the item table were measured, and the table in botdamage.lua names each by the mesh it puts on (the row it comes from is the comment). A mesh that is not listed is matched by the longest listed name inside it, else counted as 0 and logged once. Vests: 13 (BAHeavyVest, Full Panzer chest and rig), 12 (Full Sherman, Heavy Pilot), 11 (Panzer, Sherman), 10 (CE Full Plate, Full Plate, Pilot Armour), 9 (CE Plate, Half Plate, Plate Rig), 8 (BA Flak, Mk3 Flak), 7 (M1 and M2 Flak), 6 (Leather Jerkin), 5 (Pouch Rig). Helmets run from 14 (Warden Riot) and 13 (Custom PSH) down to 3 (Cloth Cap). The community guide numbers this replaces were 9 for Panzer and 11 for Full Panzer (measured 11 and 13); Heavy Stahlhelm 12 and Security Helmet 7 matched. The raw test output (rows, hits, meshes) is the file armour_test.txt of the test install, not in the repo.
- Zones, measured the same way. A vest covers the torso and the arms (arm damage equalled torso damage for every vest). A helmet covers only the head. Nothing covers the legs: a leg hit did the same damage whatever was worn, so no armour is handed back for legs and pellets that hit a leg are not reduced. On these raider dummies a leg hit did 8.5 of 34 (x0.25), while the value dump lists LegDamageMulitplier 0.5 for BotPawn_C and the player pawn; ZONE in botdamage.lua still uses 0.5 for pellets and was not re-measured on soldiers. A bare head took 416.5 on every hit (34 x 3.5 x 3.5), so a head with no helmet seems to take the head multiplier twice, which makes an unarmoured headshot a one shot kill; a helmeted head takes it once (the only reading that gives whole ratings). An earlier run showed 119 (34 x 3.5) on some bare head hits; not explained.
- Base damage is per weapon class (BASE_DAMAGE), read off logged hits in testing, with a family match for variants of a gun (Thompson, Sterling, MG42, 1911, M712). A wrong or missing base means no refund, never a wrong one, because a refund needs the hit to be exactly base x a zone multiplier. A rifle or pistol with no base logs one line with its first hit. Shotguns, launchers, flares and melee are not refunded by this path. The F9 "Dump game values" run (192 rows, 2026-11-18) holds no damage, recoil, spread or pellet property for any gun, only fire rate, stamina, durability, ADS and ammo, so it cannot replace this table. Heavy MG42 and Heavy Thompson still use their base gun's number.
- Only a hit within 0.5 s of your gun's clip dropping is refunded, so damage from a crewmate or another bot is not. In the test logs 1278 of 1609 hits landed within 0.2 s of the shot.
- Not covered: a hit that killed the bot is not refunded (the death has run). Pistols and some SMGs lose damage with range, so a far hit is below base and gets no refund (SPP1: 32 at 127 to 616 cm, 22 at 1635 cm). The real fix is to read the hit zone from the damage function.
- Shotguns. Offline a shotgun's own pellets never reach the damage function (Liberator: 8 shots, 0 hits). Each shot (the clip dropping, up to 2 volleys a frame) fires 10 pellets of 18 from botdamage.lua: a line trace from 150 cm in front of the camera inside a cone, each hit dealt with GameplayStatics.ApplyDamage using the base DamageType class, with the armour taken off and the zone multiplier applied in the script (ApplyDamage carries no zone). The vest rating applies to the body and arms and the helmet to the head, as measured; legs get none. ApplyDamage was the one way of three that lowered health; point damage with and without a component both errored. A pellet that hits a mesh and not a capsule does 18 flat.
- Shotgun check, 2026-11-18: a Liberator fired at raider dummies 5 m away. The game's own part did 0.0 to them, so the pellets here are the only damage. On a bare torso a volley took 126 to 180 (7 to 10 pellets of 18), and in a Pouch Rig (rating 5) 91 to 130 (7 to 10 pellets of 13), so armour comes off each pellet as designed. The test's own per shot sums were mixed up with its health resets and are not used. The real pellet count and damage cannot be read this way; 10 x 18 is still the Guilds 1.0 notes.
- The cone half angles are guesses: Trench gun 2.0, Liberator 3.0, Sawed off 4.5, Jackhammer 3.0, Long double 1.5, Terminator 3.0, anything else 3.0 degrees. The weapon's own spread properties were looked for and not found. Not checked: if the game's own pellets ever do land now that bots have capsules, a shot would count twice.
- The throw. A volley throws the bots it hits: 900 cm/s base (x1.25 sawed off, x1.15 Terminator), scaled by the share of pellets that hit and falling to nothing at 1000 cm, over 14 steps 0.12 s apart. A ragdolled or dead bot gets the velocity on all bodies below the pelvis, a live one a nudge (30% sideways, 120 up, once). The numbers are a stand in: the exe has FireImpulse, DamageImpulse and bHasKnockback strings, but the properties read back empty.
- Meshes. A bot's helmet, vest and backpack are skeletal meshes of their own, and they block the weapon traces like the body does. hitzones.lua frees only the body mesh, on channels 3 and 15, so a bullet that met a helmet first, or a trace on another channel (projectile guns use 9 to 14), stopped on a mesh and did the flat damage: a guard in a Security helmet took 34 and 136 from the same shot. Once a bot has its capsules, every skeletal and static mesh on it ignores the channels the capsules block (3 and 9 to 15). Three bots a second at most; a bot that has no capsules after 5 looks is left alone.
- Raw findings, kept because they are odd. Bare head, STG44: 416.5 a hit, which is 34 x 3.5 x 3.5, so the head multiplier is applied twice when no helmet is worn (an earlier run mixed in 119, which is 34 x 3.5, never explained). A helmeted head applies it once, the only reading that gives whole number ratings. It may be deliberate (so an unarmoured headshot always kills) or a bug on our side. Bare leg: 8.5 of 34 on the raider dummies (x0.25), and every one of the 54 pieces left it at 8.5. Bare arm and bare torso: 34. Vest rating = 34 minus the torso damage (arm damage was identical); helmet rating = 34 minus the head damage divided by 3.5; arm and leg damage under a helmet matched the bare values.
- Rating tiers. Vests: 13 BAHeavyVest, FullPanzerChest, FullPanzerRig; 12 the Full Sherman pair and HeavyPilotArmourChest; 11 Panzer and Sherman chests and rigs; 10 CEFullPlate, FullPlateChest, PilotArmourChest; 9 CEPlate, HalfPlateChest, PlateRig; 8 BAFlakVest and the Mk3 flak pair; 7 M1 flak chest and rig, M2 flak chest; 6 LeatherJerkinChest; 5 PouchRig. Helmets run from 3 (Cloth Cap) to 14 (Warden Riot Helmet); the full list by mesh is in the VESTS and HELMETS tables of botdamage.lua and in docs/internals/DAMAGE_REFERENCE.md.
- How a bot's rating is found. The helmet is the skeletal mesh component named "Helemt" and the vest the one named "ChestSlot" (the game's own spelling). The mesh asset name is looked up in the exact tables, then by the longest listed name contained in it, else the piece is rated 0 and one line is logged. Some meshes carry a doubled name (Full_Plate_Skel_01_Full_Plate_Skel_01); the tables hold them as the game reports them. The result is cached per bot (e.armour).
- Health and head multipliers from the value dump: you 100 HP with head 3.25; BotPawn_C 80 HP, head 3.5; BotPawnMilitary_C 200 HP, head 3.5; guards 200 HP and head 4.0 (from logs, not the dump). Rival and crew bodies get 100 HP (crew plus 10 a level) from rivals.lua. The refund accepts 4, 3.5 and 1 as the multiplier because of the guards.
- What the value dump holds. The F9 dump of 192 rows is complete: fire rate, stamina, durability, ADS and ammo values per item, and attachment adjustments (all zero except two). It holds NO damage, recoil, spread or pellet property for any gun, which is why base damage comes from logged hits and the patch notes. The Terminator shotgun failed to spawn for the dump.
- The test method, so it can be repeated. An F9 test spawned a hidden GOAPNodeBot_Raider_C and dressed it with one item through pve_roll_kit(bot, itemTable, gun, pistol, helmet, armour, bag); 100000 health put back after every hit; hit capsules from hitzones.ensure; its AI and ticks off; the next dummy built 3 m to the side while the current one was shot, then swapped in. The view was locked onto the part under test (FindLookAtRotation and SetControlRotation, run before and after the game's frame, which removes recoil), only hits whose line trace met the wanted zone counted, 5 per zone, median kept. Every other AI was killed at the start and every 5 s. Bottomless mags were on and the STG44 was in slot 1, the Liberator in slot 2. A no shooting pass first read every piece's helmet and vest mesh off the dressed dummy. Each set of 5 hits came out identical. The test code lived only in a test install and is not in the repo.
- Still unknown: why a bare head takes the multiplier twice; the soldier's leg multiplier (0.5 in the dump, 0.25 on the raider dummies); the guard head multiplier from the dump; each shotgun's real pellet count, damage and spread (10 x 18 is from the Guilds 1.0 notes for all of them); range falloff for guns other than the SPP1; base damage of the Heavy MG42 and Heavy Thompson (they use their base gun's family number); explosions, fire and melee against armour. This code has not run in game on build 8 yet.
- Tested: the ratings, the zone coverage and the shotgun armour above were measured in game on a test install of an earlier build with the same logic as this file. This file is that logic without the test code, rebuilt on build 8's modules, and has passed scripts/luacheck.py and a stubbed load only. Not yet run in game on build 8: the first things to look at are a rifle hit on a helmeted soldier (the refund), shotguns counting twice, looting a body, and a helmet shot doing zone damage.
- Left out on purpose (a second pass): launchers and grenades (the 40mm shell explodes at the muzzle offline), mines, melee, shields, the blow torch, the fire extinguisher, and damage to the player from bots.

## Bullet holes (2026-11-18; bulletholes.lua, docs/internals/BULLET_IMPACTS.md)
- Symptom: shots at walls and floors gave particles and sound but no bullet hole (a few marks on metal and blood on a bot
  came from the game itself). The earlier note above ("DecalComp is nil, so bullet-hole decals are unconfirmed") was right:
  all 500 pooled impact actors (`RaidPlayerController.PooledImpactActors`, `BasePoolHitEffect_C`) have no decal component, and the
  Blueprint's ubergraph is empty (kdis), so the pool can never draw one. The decal materials exist and are loaded (38
  `BulletImpactDecal_<family><n>_MIC`: Concrete, MetalSolid, MetalThin, Wood, Snow, Glass_BulletProof, Sandbag, Wall, Brick, Water,
  Blood).
- Not hookable: a Lua hook on `RaidPoolImpactEffect:OnPoolActive` saw 0 activations (native calls it directly). The pool actors
  carry a `bInUse` flag, so the mod reads that.
- Fix: `bulletholes.lua`, called every frame from main.lua (`BulletHoles.frame`). Every 0.1 s it looks at the pool; an actor
  that just became in use, or moved while in use, is a new impact. Its rotation faces along the surface normal, so a 15 cm line
  trace each side of it along that direction gives the exact point and normal. `GameplayStatics:SpawnDecalAtLocation` then puts a
  decal of the matching family there (size is half extents, `{ 12, 5, 5 }`, rotated to face into the surface, random roll and
  variant, 60 s). Surface comes from the name of the actor's `EffectForHit` (`PS_BulletHit_<name>`): Concrete, MetalSolid, Tinplate
  (MetalThin), Wood, Glass, Snow. Ground, Water, Fabric and Blood get none. Holes are kept in a list and the oldest are destroyed
  past `MAX_HOLES`. F3, tab "Effects": `BULLET_HOLES`, `HOLE_SECONDS`, `MAX_HOLES`, `HOLE_SIZE`. F9 has a "Bullet holes" on or off button (debugactions.lua).
- First attempt traced from the camera to the impact point and rejected everything (bots' shots are off your view line); the
  actor's own forward vector fixed it. First decals were too big (half extents, not full size).
- How it was tested: the live tracer listed the pool and its properties; a probe watched the actors and logged surface, normal
  and rotation; then stamped decals while the tester shot walls, floors, metal, wood and glass with a rifle and a shotgun (concrete
  221, metal 70, wood 30, glass 31, no errors); then the module itself from a harness: no hitch on the first shot, a cap of 10
  left about 10 holes with the oldest gone.
- Open: Tinplate, snow and ground impacts (no map tried; the log names any surface that has no hole once); whether the game's own
  marks double up with ours on some surface (none reported); some shotgun gunshot sounds are silent from one spot (the weapon's
  own sound, not looked at); the F3 Effects tab and the main.lua wiring are only checked by luacheck until the next restart.
