# Inventory, stash and loot

The SIGIS inventory, equipping, the stash grid, containers, bodies and loot windows.

Part of the project's research log: [NOTES.md](../../NOTES.md) lists every topic file and every section title.
Sections are in the order they were written; a later section can correct an earlier one, so read to the end of a topic
before trusting a finding. When a section says "see X", search [NOTES.md](../../NOTES.md) for that title to find which
file it is in.

## Contents

- [Inventory / loot system (SIGIS plugin) — findings](#inventory--loot-system-sigis-plugin--findings)
- [Offline inventory/equip findings — 2026-10-30 (session 3)](#offline-inventoryequip-findings--2026-10-30-session-3)
- [Container loot (WORKING, 2026-10-31)](#container-loot-working-2026-10-31)
- [Enemy bodies (WORKING, user-confirmed 2026-10-31)](#enemy-bodies-working-user-confirmed-2026-10-31)
- [Bot corpses: empty loot, frozen ragdolls (2026-11-06)](#bot-corpses-empty-loot-frozen-ragdolls-2026-11-06)
- [Typed stash size, ambient ship fights (2026-11-07, evening)](#typed-stash-size-ambient-ship-fights-2026-11-07-evening)
- [Stash capped at 25 rows: the game's grid wraps past 256 cells (2026-11-14)](#stash-capped-at-25-rows-the-games-grid-wraps-past-256-cells-2026-11-14)
- [Stuck in a loot window after rotating an item (2026-11-16, tested; invkeys.lua)](#stuck-in-a-loot-window-after-rotating-an-item-2026-11-16-tested-invkeyslua)

## Inventory / loot system (SIGIS plugin) — findings
- Items = rows of /SIGISPlugin/ExampleBlueprints/SIGIS_ExampleItemData (row struct
  FInventoryDatASIGISInventoryItemStruct: ItemType, size, stack, ItemBP class, AmmoType, container info...).
  Live item instances = ASIGISInventoryItem actors (UniqueItemGUID, ItemData row name, StackAmount, Condition,
  MotherItemGUID = container, BackEndID). ~326 exist in a Spaceport raid (container loot + bot loot).
- Row names seen: weapons StenSMG, Mat49Rifle, M45CarlSMG, DP28Rifle, MG42Rifle, BrenMk2Rifle, KrasaRifle,
  DaewooK1Rifle, Mac10Rifle, M50ReisingRifle, SterlingRifle_Short, M712Pistol, P08Pistol, 1911Pistol; ammo 9mmAmmo,
  45Ammo, 762Ammo, 556Ammo, 54RAmmo, 32Ammo, 12GaugeAmmo, 40mmAmmo; armour M1Helmet, SecurityHelmet, PilotHelmet,
  M1FlakChest, FullPlateChest, PanzerChest, LeatherJerkinChest; rigs/bags ShermanRig, LightBag, SackBag, MedicBag;
  meds BandageAid, SmallFirstAid, Morphine, Aspirin; plus valuables/crafting scrap.
- Loot tables: /Game/Data/Loot/AILoot/{AIBagTable, AILootTable, AIWeaponTable, CommandoLootTable,
  CommandoWeaponTable, SecurityLootTable, SecurityWeaponTable}.
- The player's USIGISInventoryComponent is on MainPlayerController (object name "Inventory"; look it up with
  FindFirstOf("SIGISInventoryComponent") — pc.Inventory is NOT a property). USIGISEquipmentComponent is on each
  pawn (player + bots). EEquipmentSlot: Head0 Chest1 Legs2 Rig3 Prim4 Sec5 Pistol6 Melee7 Bag8 ...
- `inv:Server_AddItem(FName(row), stack, cond, "Equipment", {Column=0,Row=0}, false, guid, 0, "", maxDur)` creates
  an item actor with that GUID (works). Equipping it crashes IN GAME CODE (null read at +0x260) both via
  inv:Server_EquipItem(guid, 4) and via the pawn equipment component's ServerEquipItemToSlot(guid, 4). Likely the
  same missing object as the inventory-screen crash (UI/backend-side). Crash RVA 0x9f2e80 in the exe.
- **Why equipping / the inventory screen crash**: crash RVA 0x9f2e80 is a getter `mov rax,[rcx+0x260]; ret`
  called on null; its neighbour returns +0x2D8. UDraggableItemWidget has ItemCanvas @0x260 and Item @0x2D8 →
  equipping looks up the item's inventory-screen icon widget, which doesn't exist offline. In a raid the
  inventory UI exists (2 InventoryMenuWidget, 32 InventoryContainerWidget, 35 EquipmentSlotWidget) but every
  container has 0 grid cells and there are 0 DraggableItemWidgets. Container IDs: PocketLeft, PocketRight, Stash,
  LootCon, LootPocketLeft, Lobby, Gift, scrap, Shop, RigSlot1-4. InitializeGrid() builds 0 cells even after writing
  InventoryGridSize → it reads sizes from USIGISInventoryComponent.InventoryContainerSizes (TMap<FString,
  FInventoryGridPair>), which the server fills from the backend loadout at raid start. Offline: empty.
- **Gun given via donor still won't fire for the player**: trigger input arrives (PlayerPawn_C:Shooting_Shaking
  fires), but no ServerFireProjectile / no ammo use; magazine attached (Bren_Default_Magazine_C, MagAmmoAmount 20),
  clip 30, reserve 0, not broken. Suspect the player fire path requires the weapon to be equipped in SIGIS
  (EquipmentIDs / HasPrimaryEquipped) — blocked by the same missing container/UI data.
- UE4SS crashers to avoid: out TArray params (DataTableFunctionLibrary:GetDataTableRowNames), reading fields
  inside nested structs (bot.WeaponToSpawn.RowName) and possibly :GetArrayNum().
- Verified: after the open-fight spell, bots re-seek cover ~4-5 s later (log 10:02:30 → 10:02:35).
- **Known issue: opening the inventory in an offline raid locks the controls and later crashes the game**
  (inventory comes from the online backend; PID=offline1 has none). Needs the local stand-in backend.
- Test immunity: bridge/god.txt present → director keeps the player un-damageable across raids; F9 toggles.
  (Toggling damage back on between tests kept killing the user mid-test — leave it on while testing.)
- Bot classes: BotPawn_C (80 hp), BotPawnGuard_C (200 hp), BotPawnMilitary_C; BT /Game/Blueprints/Pawns/BotBehavior,
  blackboard keys Enemy, NeedAmmo, destination, SelfActor, HasLosToEnemy, LookAtDist, bInCover, CoverEQsResult, IsDeactivated.
- masterNodeBot_C (GOAP) refuses SpawnAIFromClass (returns none) — probably needs a RaidWorldNode; not used yet.
- Without an enemy the bots hold their node (no patrol). Two bots killed the player in ~20 s; death → main menu.
- Keys (director): F7 start offline Spaceport raid, F8 spawn a soldier 15 m ahead. Status line every 10 s in UE4SS.log.
- UE4SS Lua gotchas: pass real objects for UObject params (nil breaks); FTransform params don't marshal; GetActorBounds
  needs all 4 args; a failed property read returns a bare function as the error. Never call AssetRegistry from the
  LoopAsync thread (crashed the game), and don't run Lua work there at all (see the bridge hang below). Hide the PGOS overlay (SetVisibility 1) — RemoveFromParent crashed the next travel.

- Esc and lean with the inventory open (2026-11-16, issues #60/#61; invkeys.lua). There's no "inventory open" flag:
  between open and closed only pc.bShowMouseCursor / bEnableClickEvents / bEnableMouseOverEvents change (property diff
  of controller, pawn and both SIGIS_HUDOverlay_C). It counts as open when the cursor is shown with neither the pause
  menu (SIGIS_Exit_Widget_C IsInViewport and IsVisible; its .Visibility reads 4 even when closed) nor F3/F6/F9 up.
  Esc = MainPlayerController_C InpActEvt_InGameMenu_K2Node_InputActionEvent_3: it opened the pause menu behind the
  inventory. UE4SS runs the "pre" callback of this input event after the event's Blueprint body (a probe at the
  first press, nothing open, already saw the menu up and the cursor on), so the hook reads the previous frame's
  state; the tick then calls CloseTheMenu once the menu is up, and SIGISPlayerController:CloseInventory on the
  frame after (inside the key press it didn't stick). The hook is re-registered when the UFunction's address changes:
  the controller Blueprint is loaded again for each raid map, and a hook placed in the lobby never fired in the raid.
  Lean: RaidCharacter.Lean (0/1/2) is zeroed with RaidCharacter:ZeroLean while the inventory is open.
  Tested with real keys (Space_Solo_02): Tab+Esc -> inventory closed, no menu; Esc -> menu; Esc -> closed; Tab+hold Q
  -> Lean 0; hold Q with nothing open -> Lean 1.

## Offline inventory/equip findings — 2026-10-30 (session 3)
- Tab did nothing because the HUD actor (MatchHUD_C, ASIGISHUD) has InGameOverlay == nil offline. Fix: `hud.InGameOverlay = _G.PVE_HUD`
  (our created SIGIS_HUDOverlay_C). Tab then only blurs + shows the cursor; the menu stays Collapsed until
  `overlay:ShowInventoryMenu(0)` is called (then the Loadout screen shows; slots all empty placeholders).
- DraggableItemWidgets ARE created once the overlay is wired (Server_AddItem with the correct signature:
  `inv:Server_AddItem(FName(row),1,100,"Lobby",{Column=c,Row=r},false,guid,0,"",100)`); they sit at 0,0 size 100x30 in the Lobby canvas.
  Earlier adds (before the HUD was wired) never got widgets.
- Bridge usage: `send.sh 'lua <code>'` — verb and code in ONE argument; code must `return` a value (bridge tostring()s it).
- Equip chain runs: Server_EquipItem -> equipment comp ServerEquipItemToSlot -> Client_EquipItemToSlot (all on PlayerPawn_C),
  but pawn:EquipActorItem is never reached and CurrentWeapon stays the donor MG42 (no crash now).
- Donor MG42 has UUIDSIGIS=99841675, RepSlotIn=4, clip 30, reserve 0/-1, lastFireTime 0 (never fired). Registering an item with that
  GUID (MG42Rifle) and equipping it changed nothing.
- Firing: real LMB clicks run PlayerPawn_C:Shooting_Shaking (58 hits) but NEVER ARaidWeapon:ServerStartFire/ServerFireProjectile; a manual
  w:ServerStartFire() also does nothing visible. Mouse input is bound natively (no UFunction to hook); the gate is native code.
  Cursor is off and no menu open during these tests, so it is not an input-mode problem.

## Container loot (WORKING, 2026-10-31)
- Spaceport has ~206 loot actors (ASIGISBaseActor subclasses: SIGIS_Container_*, LootableCon_*, InteractionType 2),
  filled client-side at load (~300 ASIGISInventoryItem in ItemsInContainer). F -> Interact -> Server_StartLooting
  (impl 0x99eff0; returns early if CurrentActorLooting == this actor) -> Client_OpenInventory + Client_BatchAddLootItems.
- Bug: the client loot handlers (Client_AddLootItem 0x97e560, _Struct 0x97e360, _ItemsStruct 0x97e730,
  Client_BatchAddLootItems 0x97f2e0) skip creating the client's item copy when GetNetMode()==Standalone (0x316ebe0),
  so LootsItems stayed empty and the grid showed nothing. pvepatch.dll now NOPs those 4 jne (7/7 patches).
- Moving loot: Server_MoveItem(guid, "PocketLeft", {Column,Row}, ESlotType Normal 0, from Loot 3, 0) works.
- Clicks blocked (fixed): the game now builds its own SIGIS HUD overlay ("In Game Overlay Match") with the local
  backend, after the director already made one; ours sat on top and swallowed every click (loot grid, Esc menu).
  Director collapses its own overlay once the HUD's InGameOverlay is a different one.
- Testing tip: never SetInputMode_GameOnly / UIOnly from the bridge while the user plays (mouse stays captured,
  no clicks or no game input). Original native thunks: scratchpad nft.py (UClass +0x220 table by FName index).
- Floor loot (WORKING, user-confirmed 2026-11-01): main.lua spawnFloorLoot triggers every ASIGISLootSingleSpawner
  once the raid is ready (raid maps: spawns a SIGISResourceManager with gi.DefaultDropItem; space maps have their own
  ResourceManagerBP). TriggerSpawn (0x9b2380) takes a free pooled pickup (+0x488 in-use flag), moves it onto the
  spawner, rolls the loot table and sets the item. Space_Solo_01: 105 of 141 spawners place an item (the rest roll
  "null"). Pickups stay bIsActive=false offline; that doesn't matter: F picks them up into the inventory and the
  pickup goes back to the pool (it jumps ~64k units away, which looks like a bug in probes but isn't).
  Probe: bridge/t_floor.lua.

## Enemy bodies (WORKING, user-confirmed 2026-10-31)
- Bodies vanished: ARaidBot's death (vtable +0xcc0 = 0x17edf20) spawns DefaultDeathBody (SIGIS_ExampleDeathActor_C),
  moves the bot's loot into it, hides the pawn and sets a 0.2 s lifespan. The call that gives the container its mesh
  and pose (0x17ee028 -> 0x7e0290) is a stripped server function (`ret 0`), so the container stayed bHidden with
  no mesh: invisible but holding the loot.
- The player's death (0x1842800) uses the intact setup ASIGISDeathActor 0x8fac80(death, body mesh, pose comp, head
  mesh, body comp) + 0x8fac00(death, chest, helmet, bag, FString* badge). 0x8fac80 ends in OnRep_SetBoth's
  implementation 0x8f18f0: with a live pose component (R_BodPose has a mesh) it takes 0x8ef3c0, which needs
  R_HeadMesh AND R_BodyMesh non-null, sets both SIGISPoseMesh components and CopyPoseFromSkeletalComponent; else the
  client path applies BoneTransforms. A NULL head mesh made it do nothing: the container's default Raider head/body
  meshes stood in A-pose, bone hitboxes at the origin, so F found nothing.
- Fix (pvepatch.c): the stub call goes to botBody, which only queues the bot; three patches keep the dead pawn
  visible with no lifespan. The director ragdolls it on Multi_Deathevent (fires for bots offline) and calls the DLL's
  exported pve_bodies every frame (a lua_CFunction that ignores L: UE4SS exports no Lua C API). 3 s after the death
  it runs the setup with the bot mesh as both body and head, empties HeadPose, does the gear, then hides the pawn and
  gives it the original 0.2 s. pve_bodies_reset on every new world; queued entries older than 8 s are dropped.
  The jump stub is re-pointed if a renamed copy of the DLL is loaded later (live testing: pvepatch_test*.dll).
- A bot killed without the ragdoll fell through the floor once its pose was taken (seen in testing).
- Swap flicker + slow loot (fixed 2026-10-31): the game shows the body (un-hides SIGIS_ExampleDeathActor) only when
  the pawn is destroyed, so hiding the pawn first left ~20 frames (0.2 s) with no body drawn. And the setup itself
  runs from a 2.8 s timer (0x1819d00 SetTimer -> vcall thunk 0x17f94ec -> 0x17edf20; found with a stack capture in
  botBody: FTimerManager::Tick 0x34975b0), meant for the server's death animation; plus our 3 s = lootable 5.8 s
  after the kill. Now: pvepatch "Bot death: body after 1.0 s" (rate constant -> the 1.0 at 0x4043cb0, as the other
  death path 0x1806760 uses), BODY_DELAY_MS 400, pose -> show the body the next frame (the pose mesh's first frame is
  a few units off) -> hide the ragdoll 35 ms later. Measured (bridge/t_swap.lua, per-frame trace): body shown at
  1.39-1.42 s with the pelvis identical to the ragdoll's, ragdoll hidden 4 frames later, no frame without a body;
  bridge/t_lootable.lua: the interaction trace targets the body at 1.41 s. Not watched on screen.
- Smiley faces above bots: RaidCharacter's Billboard component (editor sprite) is visible in game. AI.tuneBody
  hides it (SetHiddenInGame).

## Bot corpses: empty loot, frozen ragdolls (2026-11-06)
- Empty bodies: the death routines only copy bot.BotLootItems (+0xbf0) into the body's ItemsInContainer. Placed raiders
  get theirs from level-set rows (LootToSpawn etc: generator 0x17cae70; soldiers roll tables in 0x17caba0, both through
  the add-item helper 0x17ee360(bot, row FName, stack, condition)). A raider spawned at runtime has no rows, so every
  rival and top-up copy had n=0 and an empty corpse. The loot UI itself was fine (slots come from the item type; the
  0,0 grid position on body items is normal).
- Fix (rivals.lua takeKit): a BotPawnMilitary donor's BotLootItems is a full kit whose gun item's GUID matches its gun.
  Rivals already used a donor for the gun, top-up copies now do too (they no longer `summon` the template's gun class,
  so they carry CFG.DEFENDER_WEAPONS guns instead of the station's). Armour the body isn't shown wearing is dropped.
  Result: no empty bots on any team; 15 kills, every body held all its items through forced GCs.
- NEVER grow a TArray from Lua. UE4SS's __newindex grows only when index >= Max, by one element, and stores past the
  buffer: writes 1..4 into an empty array gave num 1,1,2,3 with write 3 at index 2 of a 2-slot allocation. The heap
  overflow crashed the game with unrelated stacks seconds later (physics task, null read in a worker). Writes below Num
  are safe. Existing `Inventory[n + 1] = gun` only survives on an empty array, or in slack without bumping Num.
- pve_take_loot(donor, body, keep) swaps the two array headers, then trims Num. It reads its integer arguments straight
  from the Lua stack (lua_State.top +0x10, .ci +0x20, slots 16 bytes, tag at +8), with tag and count checks, since
  UE4SS exports no Lua API. Tested with UE4SS as in tools/ue4ss; a mismatch does nothing and logs "loot not handed over".
- Frozen ragdolls: GOAPNodeBot_* (all raiders) die through 0x17ee0a0, not 0x17edf20. The "Enemy bodies" work above only
  covered soldiers. 0x17ee0a0 posed the corpse on the 1.0 s timer, mid-collapse, and set the 0.2 s lifespan. Raider Mesh
  is only a head/mask; the body component is +0xce0. pvepatch now queues that call too and skips its gear step and
  lifespan (patch_out: 19/19 plus the two body hooks).
- Settling: main.lua settleRagdolls samples 6 bones every 0.1 s; 0.4 s under 3 units per sample (not before 1.2 s, at
  most 7 s) writes SETTLED_MARK into the dead bot's AiMissRange (+0xcd0), which pve_bodies polls; it also poses by
  itself 7 s after the setup call. Bodies appear 2.2-7.1 s after the kill (typically 4-5), so looting waits for that.
- Probes: bridge/t_lootsurvey, t_lootwho, t_who2 (loot per bot), t_lootkill, t_killall (soak), t_bodyitems (BI_LOOT runs
  the real Server_StartLooting), t_rag (bone trace), t_donor, t_arr (TArray growth).
- Testing: echo on > bridge/god.txt before a run (or the player dies to vacuum/fire and the raid ends). Teleports with
  t_gostation can land outside; bridge/t_near.lua lands next to a raider, so inside its station. Stay out of the user's
  way: never run trailer/front.ps1 for a capture, use the console's `HighResShot 1`
  (%LOCALAPPDATA%/RaidGame/Saved/Screenshots/WindowsNoEditor), which needs no focus.

## Typed stash size, ambient ship fights (2026-11-07, evening)
- Stash: the old "Double stash size" switch only wrote meta.double_stash; activate() wrote config/stash_rows.txt (30) and the mod resized the Stash container in the menu; switching off was refused with items in rows 16-30. Now the new-save dialog takes a row count (saves.STASH_MIN 10 .. STASH_MAX 100, width stays the game's 10), stored as meta.stash_rows and fixed for the save's life (no switch; set_double_stash removed). saves.stash_rows(meta) reads old saves (double_stash -> 30, else 15). The details panel shows "Stash N items, 10 x R". Verified: dialog and panel captured (test_launcher.py); a 100-row save logged "stash grid: 100 rows" in the lobby. The 100-row grid wasn't looked at on screen.
- Ambient fights (rivals.lua SKIRMISH_*): while you fly your ship, every SKIRMISH_EVERY 70-150 s (first after 20-45 s, max 6 per raid, one at a time) two extra crews (newCrew, ambient, diehard, no boarding) spawn SKIRMISH_AHEAD 140-260 m ahead (any way if you're still), clear of stations, berths and ships, and engage each other. Hull x SKIRMISH_HULL 1.5 (guns only take ~6-7 hull/s each: x3 ran past 5 minutes; x1 with boarding ended in ~20 s). The winner extracts ("won their fight"). They ignore you unless provoked: hit while you fired in the last PROVOKE_SECONDS 4 (OnClientFiredTurret, RaidWeapon ServerStartFire/BurstStartFireEvent on your ship's gun), within 1.5 x GUN_RANGE, and nearest your aim line within PROVOKE_CONE 20 deg (with only a cone both dogfighters turned on you). Spawns tab: per raid and seconds apart.
- Verified: fights spawned 166-254 m away; one ran to "went down" + "won their fight" without touching you; faked fire (bridge/rivals_fired) + 80 hull off one ship with your view on it: only that one "engages your ship (provoked)". NOT verified: the real firing hooks (needs real input), the final x1.5 duration, how a fight looks on screen (the follow camera never framed one). bridge/rivals_skirmish starts one now; t_hitnear.lua, t_faceskirm.lua, t_shipsnear.lua (hull).
- One launch crashed in UE4SS's startup scan (0xe06d7363), before any mod ran; the retry was fine.
- Launcher freeze (user: New save did nothing, then nothing could be clicked or closed): the borderless Dialog (overrideredirect + transient) opened UNDER the main window (wm stackorder: dialog, then "."), and its grab_set blocked every click while it was out of sight. Dialog.show now sets -topmost, lifts, then positions (positioning before -topmost put it at 0,0), and Escape always closes it. Applies to every launcher dialog (new save, rename, confirmations). Verified with a real screen capture (PIL ImageGrab): dialog on top, centred; Escape releases the grab; 5 rows refused with the message; 42 rows creates the save. test_launcher.py's PrintWindow capture can't catch this kind of bug: it draws hidden windows too. The two stuck launcher processes were killed.

## Stash capped at 25 rows: the game's grid wraps past 256 cells (2026-11-14)

On a 50-row save, the green drop highlights never lined up, and once (17:45, while the menu was being driven from the bridge) a bag-to-stash drag left copies showing in the bag although the save had the items in the stash. The stash grid widget positions its slots with a byte index. Of the 500 slots, the first 244 sat on rows 25 to 49, on top of the right ones, and rows 0 to 24 had no slot widgets under them. bridge/t_slotmap.lua maps slot index to grid cell. Re-placing the slots from Lua didn't stick: the game re-placed them with the same wrap. Highlights and the space checks look slots up by cell index, so no layout works past 256 cells. Item drops themselves land right, because they come from the mouse position.

Fix: 25 rows at most (250 cells). launcher/saves.py STASH_MAX = 25, and stash_rows() caps saves made when up to 100 was allowed. main.lua caps config/stash_rows.txt at STASH_ROWS_MAX and logs "stash: N rows asked for". Live check after shrinking to 25: 250 slots, none out of place, 26 items kept. A save with items below row 25 would need them moved up first. None of the current saves have any (the lowest is row 21).
- Prestige stash upgrades: DT_PrestigeUnlockInfo rows i1 to i4 (InventorySpace, costs 1 to 4 prestige) each have StashSizeIncrease 0x2: 2 rows, 8 for all four. Owned unlocks are in SIGISPlayerController.PrestigeUnlocks (FStrings). On a 25-row save they would push the stash to 33 rows, past the wrap. main.lua now counts them: rows = min(save rows + 2 x owned, STASH_ROWS_MAX). It rewrites the component size every 2 s in the menu and rebuilds the grid widget when its height differs. It logs "stash: N rows (save S, B prestige upgrade(s))", plus ", capped from X" when it caps. Saves without config/stash_rows.txt are left to the game: 15 + 8 = 23 fits. Buying an upgrade isn't tested yet (no prestige on the test save). It's unknown whether the game adds the rows to the current size or recomputes 15 + 2n; the absolute rewrite covers both.

## Stuck in a loot window after rotating an item (2026-11-16, tested; invkeys.lua)
Tester report: with Use rebound to R (also Rotate's key), rotating an item in a container left the loot window drawn
over the game, while the game took mouse and keys again ("could move and shoot but couldn't see"). Reproduced with
default keys: in an open loot window, pressing Use (F) opens the pause menu (SIGIS_Exit_Widget_C:ExitMenu_Open fires
with no InGameMenu input action). Closing that menu leaves In Game Overlay Match's InventoryMenu (SIGIS_HUDWidget_C)
visible (visibility 4) with bShowMouseCursor false. This is the game's own behaviour; no mod code opens the menu.
- invkeys.lua now also hooks ExitMenu_Open (pre, re-hooked when the class reloads). If the inventory was open on the
  previous frame, it does what Esc does: the menu is closed, then the inventory on the next frame. So Use in a loot
  window closes it.
- Safety net: if InventoryMenu is visible with the cursor off, no pause menu and no mod menu, for 0.5 s,
  pc:CloseInventory() runs (visibility goes to 1). It logs "inventory was drawn without the cursor; closed it".
- Tested on Space_Charlie at a station crate (SIGIS_Container_Common5_2), with real key presses.
  - Before: F opened the crate, F again brought up the pause menu, and Resume left the window drawn with the cursor
    off.
  - After: F again closes the window and the "F Search" prompt is back.
  - Tab open/close and Esc in the inventory work as before. Esc outside the inventory still opens the pause menu.
  - Forcing InventoryMenu visible with the cursor off got it closed within 0.5 s, with the log line. The net never
    fired on its own.
