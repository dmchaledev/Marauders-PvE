# Missions, minimap and guild

Progression, missions offline, the task minimap and the offline guild.

Part of the project's research log: [NOTES.md](../../NOTES.md) lists every topic file and every section title.
Sections are in the order they were written; a later section can correct an earlier one, so read to the end of a topic
before trusting a finding. When a section says "see X", search [NOTES.md](../../NOTES.md) for that title to find which
file it is in.

## Contents

- [Progression / missions — survey (2026-10-31)](#progression--missions--survey-2026-10-31)
- [Missions offline — WORKING (2026-10-31, mods/PvEDirector/Scripts/missions.lua)](#missions-offline--working-2026-10-31-modspvedirectorscriptsmissionslua)
- [Task minimap (2026-11-06, minimap.lua)](#task-minimap-2026-11-06-minimaplua)
- [Offline guild: guild page and guild shop (2026-11-16, tested; mods/PvEDirector/Scripts/guild.lua, issue #68)](#offline-guild-guild-page-and-guild-shop-2026-11-16-tested-modspvedirectorscriptsguildlua-issue-68)
- [Offline guild: editing it (2026-11-16, tested; guild.lua)](#offline-guild-editing-it-2026-11-16-tested-guildlua)

## Progression / missions — survey (2026-10-31)
- All on ASIGISPlayerController (client-side system): StartMission, IncrementMission, IncrementChapterMission,
  Client_CheckMissionEvent(FName, EContractType), GetAllMissionsForChapters("A") (54 rows), GetAllMissionsForRaid,
  GetMissionProgression, CollectMissionReward/CollectChapterMission, ApplyRewardsFromRaidMissions,
  ProcessedEndRaidMissionAndClear, AddXP, AddXpToFaction. Returned struct arrays come back as Lua tables of
  LocalUnrealParam: use `e:get()` (bridge/t_miss2.lua, output bridge/missions.txt).
- EContractType: Attack 0, Deliver 1, Kill 2, Destroy 3, Raid 4, Inspect 5, Guard 6 (hold an area), Test 7
  (kills with a weapon), None 8.
- Chapter A = the campaign, 53 steps (A0 Deliver 3 JunkScrap ... A52 Become Infamous): delivers (menu side), Kill
  (item "Human" = Marauders, "Raider Boss", none = any), Destroy (space mines, flak/radar/rocket turrets), Inspect
  (forklift, hidden stash), Guard (hold room/vault/medical/dock pod area/space gate/capital engine room for N s),
  weapon-kill counts. Rewards PlayerXPReward/CashReward; A17 gives FrigateFast_Ship. Storage: playerstats
  chapterprogressions "A-0-0", contracts "M2!M12!M5!M15!M11!M28-00-00" + contractstarttime (rolled by the client
  itself), xp, points — the client writes all of these.
- Offline in a raid: a player kill DOES call Client_CheckMissionEvent("AIRaider", 2). Contract actors exist on the
  maps (Spaceport: 12 Contract_Int_* inspect actors incl. RepoMan/HiddenStash, 7 Contract_Hold_* with a GuardArea
  box), but standing in a GuardArea (IsOverlappingActor true) fires nothing (audit #12: overlap code skipped as
  Authority). Calling Client_CheckMissionEvent by hand with row names / item names / actor class changed no
  progress, GetChapterMissionAmount stays 0 and pc:GetXP() is 0 in the raid: the raid-side controller seems to have
  NO mission state (live, the raid server must have handed it over at raid start). GetAllMissionsForRaid returned
  Spaceport_C2 / Merchant_A21 / Fortress_K28, which don't match the saved contract list.
- Next: disassemble Client_CheckMissionEvent / IncrementMission / StartMission and find where the active missions
  and chapter progress live (game instance? loaded from the masterstartfunction payload in the menu) and how the
  menu applies raid results (ProcessedEndRaidMissionAndClear / ApplyRewardsFromRaidMissions). Then: feed the state
  into the raid, emulate Guard/Inspect overlaps in the director, and check Destroy (RaidSubNodeActor:
  CheckMissionActor hook registered, not yet triggered).
- Spaceport_01 opened directly (`raid`) has no streaming sublevels; 12477 static meshes, only collision blockers
  hidden (MantleBarrier01 etc.). The user saw large void / unfinished (orange grid whitebox) areas; same package as
  the station streamed into the space maps. Unresolved whether live looked different there.

## Missions offline — WORKING (2026-10-31, mods/PvEDirector/Scripts/missions.lua)
- Where the state lives (game instance, survives travel): +0x1190 TArray<FMissionProgress {FName, int}> = this raid's
  active contracts and progress; +0x1160 chapter {FString "A", int stage +0x10, int progress +0x14}. Contract rows:
  gi.ContractTable (+0x23E0, 134 rows), chapter rows gi.ChapterMissionsTable (+0x2400). Row layout (FContract /
  FChapterMission): type +0x58, need +0x5C, item +0x60, ContractRequiredActorTags TArray<FName> +0x68. Dumps:
  bridge/contracts_table.txt, bridge/missions.txt (chapter A). Live readers in the session scratchpad: dtrows.py,
  prog.py, fname.py (name pool RVA 0x58ceb40, 4.26 FNameEntry header len = hdr >> 6).
- The SPACE MAP assigns 3 contracts per run, for stations present (e.g. Spaceport_C2, Merchant_A15, Spaceport_K12).
  Opening a raid map directly (bridge `raid`) gives none: test missions through Space_Solo_01.
- Client_CheckMissionEvent(tag, type) impl 0x9b68d0 (vtable +0xe20); chapter half 0x9b5bb0 runs first. Per active
  row: type must equal the event type and the tag must be in the row's actor tags. Kill/Destroy/Raid -> IncrementMission
  (0x9ca2c0) / IncrementChapterMission (0x9ca1a0). Test (weapon kills) also checks the equipped weapon (vcall +0x1040).
  Guard: 1 s repeating timer (chapter 0x9da150) that counts while bInChapterVolume (+0x980) / bInMissionVolume (+0x964).
  Inspect: sets CurrentTimedMission (+0x968) and a timer (contract 0x9da340) that counts while the "Use" key (F) is
  held, pawn.LastInteractionActor (+0x508) is set and within 400; the first tick without Use stops it.
- Offline gaps and fixes:
  * Contract actors' server half (overlap -> flags + event) is skipped: missions.lua does it. Hold areas: entering the
    GuardArea (IsOverlappingActor) sets both volume flags and sends the actor's Tags[1] (e.g. C2_WeaponIntel; NOT the
    class name) with type 6; leaving clears them. Read actor Tags with a.Tags:ForEach(e:get():ToString()).
  * Inspect objects are never offered by InteractionDetection (ShouldShowContractInteraction): right after each
    director InteractionDetection, missions.interact makes the inspect object within 350 that you look at (35 deg to
    start, 60 to keep, 1.5 s grace) your LastInteractionActor, and sends the type-5 event when Use is down and no
    inspect runs. No "F" prompt is shown for them yet.
  * Raid result: RaidPlayerController's ClientReturnToMainMenuWithTextReason override (0x1826900, vtable +0xa00) maps
    the reason text "ESCAPED"/"DEATH"/"DISCONNECT"/"TERMDISCONNECT" to gi.LastMatchResult (setter 0x8fb7c0) and runs
    the end-of-raid bookkeeping. The director's extraction used `open MainMenu` (result stayed LoggedIn=2, no
    rewards); it now calls pc:ClientReturnToMainMenuWithTextReason(FText("ESCAPED")).
  * Rival deaths send Client_CheckMissionEvent("Human", Kill) (rivals.lua bodiesAlive) for "Kill N Marauders".
- Verified (offline, Space_Solo_01): hold Fortress_A26 0->30 in 30 s; Spaceport_C2 30/30; inspect Spaceport_K12 5/5 via
  the module with F held; extraction -> chapterprogressions + xp written, Escapes/Matches stats, contracts cleared.
  Cash + faction XP for finished contracts were written once (19:25:57: cash +4500 = Spaceport_K10, factions
  0-0-25-0-0), about a minute after reaching the menu, together with the leaderboard posts: most likely when Play
  was pressed on the splash screen (same step that returns extracted loot). Not yet re-confirmed.
- Not verified: Destroy contracts (space mines / turrets; RaidSubNodeActor:CheckMissionActor), chapter steps in a raid
  (A0 is a menu Deliver; you need 3 JunkScrap), double counting of rival kills (native may also send AIRaider), the
  Use key if rebound (CFG.USE_KEY = "F"), death path (game returns to the menu by itself).
- Crash: reading a TArray<FName> inside a returned struct (FRaidMissionUI.ContractRequiredActorTags) from Lua crashed
  the game. Read row data from memory instead.
- Crash (2026-11-16, pod to the Mini Mine, contract Just Deserts): the contract actors were kept as UObjects from the
  once-a-raid scan; one was freed later, and the first IsValid on it (on arriving within 4000) read freed memory
  (AV in UObjectBase::GetInternalIndex under a Lua call, 2 pcalls deep). Same signature crash on 2026-11-15 21:28.
  Now each entry keeps its object path and missions.lua looks it up with StaticFindObject on every use. Not yet
  re-tested at the Mini Mine.

## Task minimap (2026-11-06, minimap.lua)
- Keys, all handled by UE4SS binds in main.lua: N shows or hides it (saved in config/minimap.txt), M switches small map / full overview, B follows the next task. `bridge/minimap_cmd` takes toggle, expand, next. REAL KEY PRESSES NOT TESTED: every check went through that file (the game window never had focus).
- Small map top left (the game's contract cards and gate timer fill the top right), heading-up. Overview centred, north-up (+X up), with every task listed. Widgets sit at viewport order -1, so inventory and Esc draw over them. pc.bShowMouseCursor is true during play here: useless for "a menu is open".
- Tasks: GetAllMissionsForRaid once, GetAllMissionsForChapters(gi.PrologueChapter.Chapter)[ChapterStage + 1], live progress in gi.ActiveMissions / PrologueChapter.Progress, then a "leave through a gate" task. pc:GetGameInstance() throws from Lua: use FindFirstOf("SIGIS_ExampleGameInstance_C"). GetCurrentChapterMission throws too.
- Places: contract actors (missions.lua, now with .level) and station airlocks grouped by level name. A level is present on this map if its first 5 letters match a Node_* class holding RaidDockingComponents (TAG_KEYS prison -> penal for RaidTag). Stations change per run: Node_PenalColony and Node_RebelBase sit at the same coordinates on different runs. Mini Mine and Merchant have no RaidUseableAirLockComponent.
- Stages (stage()): on foot in your ship -> helm or airlock; flying -> nearest dock of the station, with a bearing in words; in the right station -> navmesh route to the spot; wrong station -> back the way you came in (S.entry). Docked = home.CurrentDockingVolume (home.CurrentDockingVolume's owner names the node); ARaidFrigateStationDock.MyDockedShip stays null. The gate spawn time is RemainingTime - 1200.
- Routes: FindPathToLocationSynchronously, 1 ms for 18000 units. IsPartial is true for every contract object, because they stand off the navmesh: only count it if the route ends over 500 from the spot. ProjectPointToNavigation 8 us per call, and it only looks a short way up and down whatever extent you pass, so scanning from above the top floor finds nothing.
- Floor plans: flood fill over navmesh cells (100 units) from known spots, 2 ms per frame, 2-25 s per place, once. PNG only: ImportFileAsTexture2D returns nothing for BMP. Written by a small stored-deflate encoder in Lua, cached as assets/minimap/<level>.png + .txt (size). Your ship: ship_<interior class>.png, stored relative to the airlock. Floors merge, the highest wins, so a route can cross rooms on the map that are on another level ("up a level" in the text).
- Verified in game by bridge scripts (screens only): ship, flying, station, overview, gate markers, docked at the target, docked elsewhere, wrong station, hide and save, 90 FPS with the map open. Not verified: walking through a real airlock with the map (airlock Interact from Lua does nothing; stations were entered by teleport), AI frigate targets that fly around (place.hull), Destroy contracts (no marker unless a contract actor carries the tag), the first-raid overlap with the loading screen by eye.
- TESTING TRAP: a raid start takes the active ship out of the save (checkout) and only a gate puts it back. Closing the game mid-raid loses it. This test lost the Vanquisher; restored by putting that one inventory key back, stand-in stopped (backend/state.before-vanquisher-restore.json is the save without it). Back up backend/state.json before a raid test, and restore it after. bridge/mm_restart.sh, mm_launch.sh, mm_tour.sh do NOT do that for you.
- Land raids (the F9 test raid; 2026-11-15): locate() did `hull = valid(home) and home.SpaceshipToPairTo`, false with
  no ship, and valid(false) threw every frame ("minimap failed ... attempt to index a boolean value", ~24 lines/s in
  UE4SS.log; the minimap never drew there). Fixing only that line made survey() retry its 3 FindAllOf scans every 5 s
  all raid instead (land maps have no stations, so it finds 0 places; worst frame gap 87-94 ms vs 12-21 ms). M.tick now
  returns early off space maps.

## Offline guild: guild page and guild shop (2026-11-16, tested; mods/PvEDirector/Scripts/guild.lua, issue #68)
Guilds live on PGOS (membership, members, chat, hideouts) and Nakama (guild XP). Offline, PGOS never answers, so
SOCIAL > GUILD stayed an empty hall and the TRADE page's GUILD shopkeeper (First Mate Calico) stayed locked.
- Shop gate: SIGIS_InventoryWidget_C:Shopkeeper_CheckFactionGuildRankBlocker. For WhichFaction 4 (guild) it only checks
  that SIGIS_ExampleGameInstance_C:GetMyGuilds returns at least one entry in MyCurrentGuilds
  (TArray<PgosSDKCpp.ClientGroupItem>). Lua can grow it (`list[1] = { unread_count = 0 }`), then set
  `[1].group_brief.group_id/Name`. Then the shopkeeper opens. Buying (Guild Beret, $630) and selling go through the
  usual stand-in path. Side effect: the lobby's crew card label reads GUILD instead of FREEBOOTER.
- Page flow (Guild_Widget_C, /SIGISPlugin/Widgets/MainMenu/Guild_Widget):
  - GUILD_Widget_OPENED collapses its panels and calls gi:GetMyGuildList(onError, CheckOveralState).
  - The PGOS_MyGuildLists answer calls GetGuildInfo, then PGOS_MyCurrentGuild, which sets MyCurrentGuild_Info.
  - From there the page asks GetGuildMember, GetNakGuildInfo (GUILD_Get_NakamaGuild_Info) and GetGuildMembers.
  - PGOS_SuccessGetMembersList creates a Guild_Member_Row_SubWidget per member: GroupMemberInfo is set, then the row
    is added to the Owner, OFFICER or CREWMATE box.
- UE4SS 3.0.1 can't pass the PGOS answer structs: anything holding a TMap fails, with a function as the pcall error.
  So guild.lua sets the same widget fields and texts directly. NakamaGuildInfo {GuildXP, GuildUnlocks,
  numOfActiveServer} has no map, so GUILD_Get_NakamaGuild_Info and GetGuildProgressionStuff are called as they are
  (XP 500 = rank 5, 35/155).
- Rows: Create, fill GroupMemberInfo (nickname, player_info.display_name, is_owner/is_admin, joined_time in unix
  seconds, player_presence.Status 1 = Online), then AddChildToVerticalBox. Construct draws them. Rows with no GuildInfo
  show no PROFILE/MESSAGE/CREW INVITE buttons; those are collapsed anyway, since they're PGOS.
- Hidden, because they need PGOS or online servers: Border_GuildHideOut (hideout regions, START/JOIN),
  SizeBox_GuildChat, the leave button, and SizeBox_PermissionBasedStuff (the owner's edit panel: announcement,
  visibility, patch, tags, disband). The SUMMARY/PROGRESSION sub-tabs work as they are.
- Members: Haywire Hayley (captain), Lilykoi (officer), and 10-16 crew mates drawn at random per game start from the
  Discord member list, about 30% shown online. You are added too, with the stand-in save's display_name.
- Timing: the page counts as visible behind the login screen, so it is filled only after the game has fired
  GUILD_Widget_OPENED (pre-hook, re-registered when the UFunction moves). The guild entry is only set once the login
  widget is gone.
- Test harness gotcha (not the mod): pressing the login screen's PLAY before the stand-in has seen
  authenticate/getbuildinfo (a few seconds after the splash shows) crashed the game every time: a C++ exception, the
  same stack 4 times. The test helper now waits for getbuildinfo.
- Tested on fresh launches: the page fills on the first open and on reopening. Summary/Progression clicks work, the
  shopkeeper opens by mouse, the beret bought, and raids started fine (Space_Solo_01; Space_Delta with the module off
  for comparison). One raid load on Space_Delta exited silently with no dump and didn't repeat.
- kdis.py now decodes the delegate opcodes (0x5C, 0x5D, 0x61-0x63) and set/map/array literals (0x39, 0x3B, 0x3D,
  0x3F, 0x65).

## Offline guild: editing it (2026-11-16, tested; guild.lua)
You now captain the offline guild, and Haywire Hayley and Lilykoi are officers. The page's EDIT GUILD tab
(Btn_GuildTab_EditGuild, MM_GuildTab_EditGuild, SizeBox_ApperanceSubTabsDivide) is shown, MyCurrentGuild_AmIOwner is
set, and the tab's own handler shows SizeBox_PermissionBasedStuff.
- Each control's bound event runs its own body first: checks and warnings, then a PGOS request (SetGuildIcon,
  SetGroupTags, ...) that goes nowhere. A pre-hook then reads the panel, applies the value to the page, and writes
  config/guild.txt (key=value).
  - Announcement Confirm (event 16) and Clear Message (27): Txt_PGOS_MyGuild_AnnouncmentMessage, shown in
    Border_GuildAnnouncment above the tabs. Collapsed when empty.
  - Is Public checkbox (44): YES/NO.
  - Join Type combo (45): index 0-2 is Open To Anyone / Invite Only / Closed To All. The combo's FStrings from
    GetOptionAtIndex came back as garbage; DefaultOptions reads fine.
  - APPLY NEW PATCH DESIGN (35): Edited_Current_Patch_Design/PrimColour/SecColour, saved as "d-p-c" (the PGOS Icon
    format). Also written to the game instance's guild entry (group_brief.Icon).
  - APPLY NEW TAGS (event 4, the button named ..._PubliclyVisible_1): EditGuild_Tags holds the E_GuildTags names, e.g.
    "HelpingHand". They are shown spaced.
- Badges: Refresh_MyCurrentGuild_Patch(d, p, c) and Refresh_MyCurrentGuild_Edit_PatchLook(d, p, c) draw nothing until
  MyCurrentGuild_Patch_DMAT and MyCurrentGuild_Patch_Edit_DMAT are set. Initialise_Guild_My_Info sets them, but only
  on the PGOS path. guild.lua sets them from Border_TEMP_MyGuild_PatchLook_ and
  Border_TEMP_CurrentPatchLook_EditPatch with GetDynamicMaterial().
- Restoring the panel when the page fills: checkbox, combo index and announcement text are set back, plus the
  Edited_Current_Patch_* values. Tag buttons (Guild_GuildTag_SubWidget_C in WrapBox_GuildEditTags) get "Is Selected"
  and isTagSelected(true) when their label (txt_GuildTagName) minus spaces is a saved tag. GuildTagsActive_EditGuild and
  the "n / 5" text are updated too. LoadCorrectTagLook_ForEditGuild(TArray<FString>) didn't work: the Lua table
  arrived empty.
- Disband (Border_Permissions_OwnerOnly_Disband) stays hidden. Guild name and description have no controls on this
  panel and stay fixed.
- Tested with real clicks and typing: each control logged "guild: ... changed" and wrote config/guild.txt. The Summary
  showed the announcement, YES, OPEN TO ANYONE, the tags and the new badge. After a relaunch all of it came back,
  including the edit panel's controls (3 / 5 tags selected). Clear Message removed the banner.
