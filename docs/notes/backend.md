# Backend stand-in

What the live backend did and how `backend/nakama_standin.py` replaces it offline.

Part of the project's research log: [NOTES.md](../../NOTES.md) lists every topic file and every section title.
Sections are in the order they were written; a later section can correct an earlier one, so read to the end of a topic
before trusting a finding. When a section says "see X", search [NOTES.md](../../NOTES.md) for that title to find which
file it is in.

## Contents

- [Online backend (what offline mode must replace)](#online-backend-what-offline-mode-must-replace)
- [Backend capture (2026-10-30, session 5)](#backend-capture-2026-10-30-session-5)
- [Local Nakama stand-in — WORKING (2026-10-30, session 5)](#local-nakama-stand-in--working-2026-10-30-session-5)
- [French female voice free from the start (2026-11-16, tested; backend/nakama_standin.py)](#french-female-voice-free-from-the-start-2026-11-16-tested-backendnakama_standinpy)
- [Offline backend: coverage tally, tournaments, the gift box (issue 80, 2026-11-18; backend/nakama_standin.py)](#offline-backend-coverage-tally-tournaments-the-gift-box-issue-80-2026-11-18-backendnakama_standinpy)

## Online backend (what offline mode must replace)
- Game instance chain: UGameLiftGameInstance → USIGISGameInstancePGOS → ...Nakama → ...GraphQL → USIGISGameInstance
  → SIGIS_ExampleGameInstance_C.
- PGOS (Tencent): URLs in loose `Binaries/pgos_res/pgos_config.ini` (offline mode points them at 127.0.0.1:1).
- Nakama: `marauderea2.us-east1.nakamacloud.io` (hardcoded, still contacted in offline mode!).
- REST: `ApiUrl = https://1lv5atybp2.execute-api.eu-central-1.amazonaws.com/prod/` (GameInstance property).
- Also: Vivox (mtu1xp.api.vivox.com), Sentry crash ingest, AWS EC2 eu-west-1, Team17 t17service auth.
- In "offline" mode the menu still logs in to the live account (PlayerUserName = USER#S#<steamid>) and shows the real
  stash. TODO: in-process network shim to redirect these hosts to a local mock backend.

## Backend capture (2026-10-30, session 5)
- **native/pvenet.dll** (pvenet.c): read-only WinHTTP logger. PvEBridge loads it at mod start while
  `bridge/capture_on` exists. It rewrites WinHTTP import-table entries of modules under the game folder only
  (anti-cheat/Denuvo/other injected modules are skipped: the first build also hooked
  `denuvo-anti-cheat-update-service-launcher.dll`, which must never be touched) and wraps async status callbacks.
  Output: capture/winhttp-<time>.jsonl, one JSON per finished request (host, verb, path, headers with Authorization
  masked, bodies, status). capture/pvenet.log lists hooked modules. **capture/ contains live session tokens (auth
  response, vtoken): never share it.**
- WinHTTP users: nakama-cpp.dll (all Nakama REST), aws-cpp-sdk-core (GameLift/Lambda/Dynamo/Cognito), libcef
  (PGOS overlay web views), vivoxsdk, sentry. NOT the game exe (its own HTTP, e.g. ApiUrl REST/GraphQL, uses
  another stack: not captured yet) and NOT pgos_client.dll (own sockets + TLS).
- Nakama host marauderea2.us-east1.nakamacloud.io, REST v2. Menu load sequence (first capture, 14 requests):
  POST /v2/account/authenticate/steam?create=true&username=<steamid> → session; GET /v2/storage/public;
  GET /v2/account; RPC getbuildinfo {branch:"EA", steamid, needstoken} → {branch:{maintenence,version}, vtoken};
  POST /v2/storage (read social/created); RPC masterstartfunction (GET) → payload with cosequip, gifts, messages,
  playerstats (cash, chapterprogressions "A-0-0", contracts "M25!M15!M23!M18!M1!M40-00-00", contractstarttime,
  shiprotation, shipsleft, xp), prestige, raidertime, servertime; GET /v2/storage/inventory?user_id=<nakama id>
  → the stash; RPC getsteaminfo; GET /v2/storage/twitch; PUT /v2/storage cosequipped head/body (the game writes
  these itself on menu load).
- Stash item = storage object collection "inventory", key = item GUID, value
  `{"equip": false, "value": "<guid>-<Row>-<n>-<n>-<n>-<n>-<n>-<Container>"}` e.g. 13043956-BandageAid-3-1-2-6-0-Stash
  (fields after the row not decoded yet: likely stack, condition, grid column/row, rotation).
- Menu clicking capture (78 requests total). The backend is mostly a client-authoritative key-value store:
  - shops/contracts/quests/stats screens make NO requests: the client builds them from data it already has
    (masterstartfunction payload + its own data tables).
  - buy: client writes playerstats/cash (65000 → 57500 → 56695 → 57086) + a new inventory object, then RPC
    statChangeArray {"arrayIn":[{"stat":"TotalCash","amount":N}]} → payload = the account user record
    (metadata: Deaths, Looted, Matches, PirateGameRank, TotalCash, claimdate). sell: PUT /v2/storage/delete inventory.
  - moving an item in the stash: PUT inventory object with new col/row. Claiming gifts: delete "gifts" object +
    put "inventory". Cosmetics: PUT cosequipped head/body/voice (very chatty).
  - GET /v2/tournament (empty), GET /v2/account again, GET /v2/storage/public (regions, permMessage, titleNews...).
- Stash item value decoded: `<guid>-<Row>-<Stack>-<Condition>-<Col>-<Row>-<Rotated>-<Container>[-a!a!a!a!a!a!a]`
  (7 attachment slots on guns). A gun's Stack = loaded rounds (Mat49Rifle-36-60 = 36 rounds, condition 60), the
  same rule the client's fire path uses. equip=true items are the loadout; their Container is the slot
  (Prim, Head, Rig, PocketLeft...). A live raid presumably Server_AddItem's exactly these.
- scripts/capture_seed.py replays all captures (reads, then the client's writes/deletes) into
  capture/seed/account.json: account, storage collections, last reply of each RPC (getbuildinfo left out: tokens).
- Not capturable within the ground rules: matchmaking / raid / end-of-raid traffic (that would mean taking the
  modded client into a live match). Design those from the client code instead (SendEndMatchInfo, ExtractedLoot,
  DisconecttedLoot, AwsWs_StartSoloMatchMaking...).
- Next: stand-in Nakama server from the seed. Redirect idea: pvenet already wraps WinHttpConnect/OpenRequest, so
  it can point marauderea2.us-east1.nakamacloud.io at 127.0.0.1 and drop WINHTTP_FLAG_SECURE (plain HTTP to a
  local server, no certificate games, no hosts file).

## Local Nakama stand-in — WORKING (2026-10-30, session 5)
- **backend/nakama_standin.py** (Python stdlib, 127.0.0.1:7350): authenticate (Nakama-shaped unsigned JWT with
  uid/usn/exp: the client reads its user id from it), /v2/account, storage list (paged) / read / write / delete,
  RPCs masterstartfunction (built live from storage: playerstats, cosequipped, gifts + servertime),
  getbuildinfo (no maintenance, empty vtoken), getsteaminfo, statChangeArray (adds to account metadata);
  anything else answers {} / {"payload":"{}"} and is logged as UNKNOWN/UNHANDLED in backend/server.log.
  State: backend/state.json, built on first run from capture/seed/account.json (delete it to reset to the seed).
- **Switch:** `bridge/offline_backend` exists → launch-offline.ps1 starts the server (hidden python) if 7350 isn't
  listening, PvEBridge loads pvenet.dll, and pvenet's WinHttpConnect wrapper sends *.nakamacloud.io to
  127.0.0.1:7350 with WINHTTP_FLAG_SECURE dropped (cert/TLS WinHttpSetOption calls on those requests return TRUE
  without doing anything). Remove the file to go back to the live backend. `scripts/mode.ps1 online` removes UE4SS,
  so a stock launch never loads any of this.
- Verified: the menu's whole login sequence (12 requests, same order as live) served locally, 0 requests to the live
  Nakama host, stash moves saved to state.json. Sentry crash telemetry still goes to sentry.io (not redirected).
- Bridge hang (fixed 2026-10-30): after one game-thread `lua` job the PvEBridge LoopAsync thread never ran again
  (cmd.txt left unread) while the game kept rendering and ticking. Both threads shared the mod's Lua state; the
  async one stayed blocked on it. The bridge now reads and runs every command on the game thread (tick hooks,
  polled 4x/s, `luaq` = `lua`); LoopAsync only registers the hooks and then ends. bridge/heartbeat.txt is
  rewritten every 5 s while polling works. Commands wait during loading screens (no ticker then).
  PvEDirector still queues key-bind jobs from other threads (same pattern; fine so far).

- **What else the game reaches offline (2026-11-18).** Menu plus a Space_Alpha raid, capture_on, pvenet.log and the
  WinHTTP log. pvenet only blocked raw DNS lookups (getaddrinfo & co.); WinHTTP resolves inside winhttp.dll, so a
  WinHTTP host other than Nakama went **live**: sentry.dll posted a session envelope (`{"type":"session",
  "status":"abnormal"...}`, 314 bytes) to o293983.ingest.sentry.io and got 200. Fix: offline, pvenet sends every
  non-local WinHTTP host to the stand-in, others as `/_ext/<host>/<path>`; the stand-in answers `{}` and counts them in
  coverage.json under "other services". Verified: the envelope arrives as `/_ext/o293983.ingest.sentry.io/api/.../envelope/`,
  answered, counted. Blocked lookups (raw sockets, still blocked, nothing needs them so far): api.gameanalytics.com from
  the exe every ~8 s (analytics over its own TLS stack: redirecting it would need a fake certificate, not worth it), and
  marauderea2...nakamacloud.io from nakama-cpp.dll (the realtime socket: parties, matchmaker, notifications; the mod
  does matchmaking itself). Not seen this run: Vivox, EOS, the AWS GraphQL ApiUrl, the PGOS overlay (libcef). Those
  modules are hooked, so a lookup would show in pvenet.log; matchmaking through the lobby button wasn't exercised.
  pvenet.log only exists if a capture/ folder does.

## French female voice free from the start (2026-11-16, tested; backend/nakama_standin.py)
Issue #27. You can play as a woman from the first launch, but the cheapest female voice cost credits.
- DT_PlayerAppearance (row struct UnlockCosmeticData: ItemName, slot 0/1/2 = head/body/voice, UnlockRequirementStatName
  + Amount, UnlockCostAmount, PrestigeUnlock, ChapterUnlock) has these voice rows: enM01 0, frM01 3500, frF01 3500,
  plM01 4200, duM01/duF01 58000 (L_7), usaM01/usaF01 65000 (L_10), roM01 70000, huM01 76000, itF01 80000 (L_18),
  auM01 95000, itM01 115000, str01 prestige. Rows were read from memory with a scratch reader modelled on
  offline-audit/voicerows.py.
- SIGIS_InventoryWidget isThisCosmeticUnlocked (kdis) treats enM01, head "1" and body "6" as always free. Anything else
  must be in InventoryMenuWidget:GetUnlockedCosmetics (native 0x9f52e0). That reads
  SIGISPlayerController.UnlockedCustomisations (+0x8a0) plus the prestige unlocks.
- Storage format: playerstats/cosmeticsunlocked holds row names joined by "-" (seen after
  pc:SetPlayerUnlockCos(FName("frF01")) then "usaF01": "frF01-usaF01"). SetPlayerUnlockCos is the purchase. It also
  charges UnlockCostAmount (cash PUT plus statChangeArray). "!"-joined values are not parsed: the list stays empty.
- Fix: the stand-in's masterstartfunction adds FREE_COSMETICS ("frF01") to cosmeticsunlocked in what it sends. The
  save file is not changed. The game holds it in its list from then on, so a later purchase writes it back with the
  rest.
- Tested on a fresh boot with an empty cosmeticsunlocked: UnlockedCustomisations = {frF01}. Loadout > Appearance >
  Voice shows FRENCH 02 without a lock. Selecting it wrote only cosequipped/voice = frF01 (no cash write).
- Crashes while probing (don't repeat): calling InventoryMenuWidget:UnlockCosmetic("frF01") with a guessed signature,
  and appending to pc.UnlockedCustomisations from Lua (`a[#a+1] = "x"` on an FString TArray in UE4SS 3.0.1).
- Unlock all looks and voices (2026-11-16, issue #48, Hayley: a toggle): launcher checkbox -> config/unlock_all_looks.txt
  (on/off). The stand-in's with_free_cosmetics adds ALL_COSMETICS (every DT_PlayerAppearance row: heads/bodies 1-56,
  61-72, 84-90, 92-95 and the 14 voices; Pirate/Mod 57-60 left out, cost 1, likely dev placeholders) to what it sends
  at login, never to the save. Tested: on -> UnlockedCustomisations 93, Appearance > Voice all unlocked; off ->
  1 (frF01) and the save's cosmeticsunlocked still "". With everything unlocked nothing can be bought, so the game
  never writes the full list back into the save.

## Offline backend: coverage tally, tournaments, the gift box (issue 80, 2026-11-18; backend/nakama_standin.py)
- Writes were already crash-safe (state.json, loadout.json, cosmetics.json go through a .tmp + os.replace). Write
  coalescing NOT done: state.json is ~18 KB, and the launcher stops the stand-in by killing it, so a delayed write
  could lose a purchase. Not worth that risk for now.
- Coverage: the stand-in counts what nothing answers, by kind: "unknown rpcs", "unhandled endpoints" (ids replaced by
  <id>), "empty collections" (listed while empty: twitch on every login). backend/coverage.json, count + first/last
  time, added to across sessions, written by the 1 s watcher thread only when something new was counted. REPORT zips
  it. Seen so far: `guild_getinfo` (the guild page's Nakama half; guild.lua fills that widget itself, so answering it
  isn't needed), twitch empty, and GET /v2/tournament, which is now answered as "no tournaments" (the live list was
  empty in the capture too).
- Gifts work offline already: the lobby's GIFT tab (MainOverlay Btn_TEMP_MainBtn_Gift) lists the gifts collection
  sent in masterstartfunction. Claiming is the client's own delete gifts + put inventory (captured online), which the
  generic storage path handles. A gift is only an item row ({"value": "Mat49Rifle"}); the game picks the stack when it
  shows it: a gun with a full magazine, 9mmAmmo 30/60, BandageAid 1/3. Some showed the Twitch badge (which ones
  depends on the client, not the stand-in).
- backend/gifts_in.txt: item rows, one per line; the stand-in moves them into the gift box within a second (new
  5-digit keys, never one already in gifts or the stash). For the mod or the launcher to hand out rewards (#78's loot
  for harder raids). The client reads gifts at login, so they show from the next login.
- Tested in game (2026-11-18, throwaway save gifts-test, MainMenu): 2 x (Mat49Rifle, BandageAid, 9mmAmmo) queued
  through gifts_in.txt, all six shown in GIFTS. NOT tested: claiming a gift into the stash by dragging (no input
  from the bridge), whether ED_CheckForGiftsNow can make the lobby re-read gifts without a new login.
  tools/test_standin_gaps.py covers the tally, the tournament answer and the gift hand-off.
- Windows dev note: `pvemode.py steam-run` started the Shipping exe without its working directory, and Steam
  relaunched the stock game (folder already back to stock). It's meant for Linux, where Steam supplies the
  environment; on Windows use the launcher or launch-offline.ps1.
