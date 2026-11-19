# Co-op multiplayer

Getting a second player into a raid: the investigation from first look to a working join, in order.

Part of the project's research log: [NOTES.md](../../NOTES.md) lists every topic file and every section title.
Sections are in the order they were written; a later section can correct an earlier one, so read to the end of a topic
before trusting a finding. When a section says "see X", search [NOTES.md](../../NOTES.md) for that title to find which
file it is in.

## Contents

- [Co-op multiplayer: first look (2026-11-07, evening)](#co-op-multiplayer-first-look-2026-11-07-evening)
- [Co-op host+join attempt (2026-11-07, late evening) — BLOCKED by a deeper second-instance quit](#co-op-hostjoin-attempt-2026-11-07-late-evening--blocked-by-a-deeper-second-instance-quit)
- [Co-op join: who drops, and what never fires (2026-11-15; tools/coop/coop_hooks.lua)](#co-op-join-who-drops-and-what-never-fires-2026-11-15-toolscoopcoop_hookslua)
- [Co-op join: the login never creates a player (2026-11-18; native/pvetrace.dll, tools/profile/dump_image.py)](#co-op-join-the-login-never-creates-a-player-2026-11-18-nativepvetracedll-toolsprofiledump_imagepy)
- [Correction: the server DOES create a PlayerState (2026-11-18; live GameMode probe)](#correction-the-server-does-create-a-playerstate-2026-11-18-live-gamemode-probe)
- [Client side: the GameInstance vtable is not where the bounce is decided (2026-11-18)](#client-side-the-gameinstance-vtable-is-not-where-the-bounce-is-decided-2026-11-18)
- [Night two: the probe grew teeth, and one address fact that explains the dead ends (2026-11-18/19)](#night-two-the-probe-grew-teeth-and-one-address-fact-that-explains-the-dead-ends-2026-11-1819)
- [The address puzzle is solved: UE4SS's tostring() is not the UObject (2026-11-19)](#the-address-puzzle-is-solved-ue4sss-tostring-is-not-the-uobject-2026-11-19)
- [Client PlayerController trace, with a real vtable this time (2026-11-19)](#client-playercontroller-trace-with-a-real-vtable-this-time-2026-11-19)
- [UNetDriver / PendingNetGame from Lua: reachable only while the join is live (2026-11-19)](#unetdriver--pendingnetgame-from-lua-reachable-only-while-the-join-is-live-2026-11-19)
- [One join window per client launch (2026-11-19)](#one-join-window-per-client-launch-2026-11-19)
- [Client RPC hooks fire; the connection is still unreachable from Lua (2026-11-19)](#client-rpc-hooks-fire-the-connection-is-still-unreachable-from-lua-2026-11-19)
- [Server side: the client goes silent, the server only cleans up (2026-11-19)](#server-side-the-client-goes-silent-the-server-only-cleans-up-2026-11-19)
- [Co-op join works: the host refused a PNAME that isn't Base64 (2026-11-19; native/vtprobe.c, PvEBridge `join`, #26)](#co-op-join-works-the-host-refused-a-pname-that-isnt-base64-2026-11-19-nativevtprobec-pvebridge-join-26)

## Co-op multiplayer: first look (2026-11-07, evening)
- Net setup (pak Config/DefaultEngine.ini): GameNetDriver = OnlineSubsystemUtils.IpNetDriver (plain UDP), bUseSteamNetworking=false, RaidReplicationGraph, NetServerMaxTickRate 60, timeouts 160/80 s, GameSession MaxPlayers 51. GlobalDefaultServerGameMode SpaceGameMode_C, ServerDefaultMap Space_Raider_02. So a join is "open <ip>:7777", no Steam/EOS relay.
- Listen server works: from the lobby, `open /Game/Maps/Space_Solo_01?listen?PID=...` loads the raid as usual (aboard, stations, rivals) and the process listens on UDP 0.0.0.0:7777.
- A SECOND COPY OF THE GAME ON THE SAME PC QUITS (exit code 0, ~10-15 s after start) when one is already running.
  CAUSE FOUND (2026-11-07, native/pvetrace.dll = IAT tracer injected by native/tracelaunch.exe): NOT Denuvo and NOT
  an OS mutex. The UE4 `"UnrealEngine4"` single-instance mutex does return ALREADY_EXISTS early in init, but the game
  keeps loading right past it (libcef/vivox/pgos load after) -> not the cause. The real exit is `PostQuitMessage(0)`
  on the Nakama thread, stack bottoming out in `nakama-cpp.dll` -> game request-exit path (exe+971c1b < exe+93c61a
  < ... < exe+9fafd0 < PostQuitMessage). It fires at a network-round-trip delay. So the LIVE Nakama backend
  (marauderea2...nakamacloud.io) enforces one realtime socket per account and boots the duplicate; the game treats
  that socket close as fatal. A single OFFLINE copy survives because its Nakama socket never reaches a live server
  (the stand-in is REST-only, no websocket), so there is nothing to boot it. Implication for co-op: two copies BOTH
  blocked from live Nakama (normal offline config, pvenet.dll offline flag / DNS-fail) should both survive on one PC.
  NOTE: a first pvetrace that patched ntdll syscall stubs got the process killed by Denuvo anti-tamper (exit -1);
  IAT patching of kernel32/user32 imports (what pvenet.dll does) is NOT detected. Only ever inject via IAT.
- <game folder>_client: hard-linked copy of the game (no extra space), dwmapi.dll removed (stock, no UE4SS). For a separate client install with its own UE4SS later. Hard links: mode.ps1 rewrites files in PHtest, which may or may not reach the copy (copy-over replaces the link).
- SAME-PC TWO-INSTANCE TEST PASSED (2026-11-07): with the Nakama block applied to BOTH copies (pvenet.dll injected
  via `native/tracelaunch.exe <dll> <exe> [args]`, bridge/offline_backend present so pvenet runs in offline mode),
  two RaidGame-Win64-Shipping.exe ran side by side for 30 s+ (pids 32148 + 33500, ~3.3 GB each), both past the old
  10-15 s death window. So co-op host+join can be tested on ONE PC; the second-PC requirement is lifted.
  Reusable: `tracelaunch.exe pvenet.dll <exe> <args>` starts an offline copy (Nakama blocked) WITHOUT UE4SS - useful
  for a client that must not run the full PvEBridge. These two copies have pvenet only (no UE4SS/PvEBridge), so they
  cannot be driven by console/bridge commands; to send `open`/console a copy still needs UE4SS or the bridge.
- Still unknown / NEXT for co-op: host+join. Host = an offline copy with UE4SS+PvEBridge issuing
  `open /Game/Maps/Space_Solo_01?listen?PID=...`; client = a second offline copy issuing `open 127.0.0.1:7777?PID=...`.
  Open: whether the game mode accepts a joiner (PreLogin URL options, GameLift session checks in a non-GameLift process).

## Co-op host+join attempt (2026-11-07, late evening) — BLOCKED by a deeper second-instance quit
- DONE - per-instance bridge: `mods/PvEBridge/Scripts/main.lua` now reads BRIDGE from env var `PVE_BRIDGE` (defaults
  to the single bridge/). `scripts/bsend.sh <dir> "<cmd>".."` drives a chosen bridge dir; `bridge2/` created (holds
  offline_backend). `native/tracelaunch.exe` now injects a `;`-separated list of DLLs, so a copy can get pvetrace +
  pvenet at once. Launch an instance with its own bridge:
  `PVE_BRIDGE=.../bridge2/ tracelaunch.exe "pvetrace.dll;pvenet.dll" <exe> <args>`.
- NEW PROBLEM: in full OFFLINE MODE (UE4SS + mods + pgos->localhost:1), a SECOND instance still quits (~4-18 s,
  timing varies with a network round-trip), even with live Nakama blocked by pvenet (redirected to the local REST
  stand-in). The FIRST instance survives indefinitely. Traced (pvetrace): B's exit is the same signature as the live
  case - `PostQuitMessage(0)` from `nakama-cpp.dll+5c641 -> exe+971c1b -> exe+93c61a -> <blueprint ProcessEvent
  chain, now with UE4SS.dll frames> -> exe+9fafd0 -> PostQuitMessage`. Deterministic: first instance NEVER calls it,
  second ALWAYS does.
- Levers TRIED and FAILED (all via pvetrace IAT hooks, env-gated):
  * PVE_SUPPRESS_QUIT: swallow PostQuitMessage from the quit site (exe+0x9fafd0). The call is suppressed but the
    process still exits seconds later with NO ExitProcess/TerminateProcess through our hooks -> the engine exit flag
    (GIsRequestingExit) was already set upstream; blocking the window message is too late.
  * PVE_FIRST_INSTANCE: spoof the `"UnrealEngine4"` single-instance mutex as freshly created (SetLastError(0) when it
    returns ALREADY_EXISTS). Confirmed firing ("SPOOFED FIRST") but the quit STILL happened -> the quit is NOT gated
    by UE4's IsFirstInstance. The mutex ALREADY_EXISTS is the only Win32-level difference between survivor and victim
    (diffed both traces), but it's a symptom of "being second", not the cause.
- The stand-in is pure REST (no websocket/status/match endpoint) and returns identical responses to both instances,
  so it is not the signal. The fatal trigger is nakama-cpp's realtime socket callback.
- CAUSE ISOLATED (2026-11-07, controlled A-vs-B traces): the trigger is **UE4SS core**, nothing else.
  * pgos is NOT it: offline mode with STOCK pgos_config (live URLs, pvenet blocks them) -> second still dies.
  * backend/account is NOT it: two copies in ONLINE FILE MODE + pvenet (no UE4SS) both survive 42 s, second has 0
    exits - even though both auth the same account to the stand-in. "Same account twice" is harmless.
  * our mods are NOT it: offline mode with EVERY mod disabled (deployed Mods/mods.txt all 0 except built-in Keybinds)
    -> bare UE4SS core -> second STILL dies (PostQuitMessage, same nakama->blueprint signature).
  So: with UE4SS present, the SECOND instance self-quits via the nakama-disconnect blueprint; without UE4SS neither
  does. UE4SS hooks ProcessEvent (its frames are in the quit chain); likely its per-UFunction overhead perturbs timing
  so the second copy's nakama realtime disconnect handler runs and quits (death time varies 4-18 s = a race).
- SOLVED (2026-11-07, later): the real single-instance guard is an exclusive lock file in %TEMP%
  (`%TEMP%\3BF2080B4AE836B4EC4CBB889BB045C2`, CreateFileW GENERIC_WRITE share=0). The second copy gets
  ERROR_SHARING_VIOLATION, retries once, then calls RequestExit (exe+0x1a70880) -> PostQuitMessage. FIX, no patching:
  launch the client with its own TEMP/TMP (`TMP=...\tmp2 TEMP=...\tmp2 PVE_BRIDGE=.../bridge2/ tracelaunch ...`).
  Verified: host + client both at the main menu with UE4SS, both bridges answering. (The "UE4SS is the cause" result
  above was a timing artefact; ignore it.)
- NEW BLOCKER: the host hangs (not responding) after `open /Game/Maps/Space_Solo_01?listen<RAID_OPTS>` from the main
  menu, even with no client running. UDP 7777 does open. Not yet understood; next session: try the listen open the way
  the earlier successful test did (bridge-loaded pvenet, no early injection, no pvetrace), and from the lobby rather than
  the main menu. scripts/quitsite.py + native/pvestacks.c are the diagnostic tools added.
- HOST HANG RESOLVED BY LAUNCH METHOD (2026-11-07, 21:00): plain `launch-offline.ps1` (bridge loads pvenet itself, no
  tracelaunch, no pvetrace), Play (bridge/t_play.lua), then from the LOBBY `open /Game/Maps/Space_Solo_01?listen<RAID_OPTS>`:
  host stays responsive, aboard after 13 s, rivals running, UDP 7777 listening. The earlier hang came with early
  injection / opening from the main menu. Client = plain Start-Process with env TEMP/TMP=MaraudersPvE\tmp2 and
  PVE_BRIDGE=.../bridge2/ (no tracelaunch needed; PvEBridge loads pvenet from bridge2/offline_backend).
- JOIN FAILS (client side). `open 127.0.0.1:7777?PID=offline2?PNAME=Marauder2?CREW=solo2?CPT=1?NUM=1?EOS=offline2?UPN=offline2?psid=2`:
  the handshake gets through: the host gets a NetConnection and, ~10 s later, a second MainPlayerController (no pawn,
  no PlayerState name) that stays until the connection times out. The client:
  * with PvEDirector on: loads for ~10 s, then is back at MainMenu with no NetDriver. No script-level cause: hooks
    (bridge/t_neterr.lua, t_kick.lua, t_leave.lua) on GameInstance HandleNetworkError/HandleTravelError,
    ClientWasKicked/ClientReturnToMainMenu(WithTextReason)/ClientTravel(Internal), OpenLevel, ExecuteConsoleCommand,
    QuitGame never fired (hooks do work: ExecuteConsoleCommand caught the join itself). So the engine dropped it
    internally (shipping build, no UE_LOG).
  * with PvEDirector off (deployed mods.txt only; host restarted the same way): the client freezes right after the
    join, main thread spinning in exe code (same rip exe+1c3cdc0 in two samples, CPU busy), indefinitely (>3 min).
  * joining from the client's LOBBY (pressed Play first, PvEDirector on): same as the first case, back at MainMenu
    ~20 s later. So a logged-in client doesn't help.
  * LAND RAID (2026-11-07, 21:25): host `open /Game/Maps/Raids/Spaceport_01?listen<RAID_OPTS>` from the lobby works
    (ShootingRangeGameMode_C, responsive, 7777 open). Client (PvEDirector on, UE4SS) joins -> freezes at once, the
    host never gets a second controller. Main thread spins at the SAME exe+1c3cdc0 as the space-map freeze; its
    stack alternates exe frames with UE4SS.dll+555002 / +554f22 (UE4SS's blueprint-VM hooks) under a net tick ->
    likely a blueprint loop that UE4SS's ProcessInternal/ProcessLocalScriptFunction hooks keep running.
  * Stock client without UE4SS (PHtest_client + tracelaunch pvenet.dll, URL `127.0.0.1:7777?PID=..` as first arg):
    the URL is ignored, the game sits on its own title screen (PLAY/EXIT). No way to drive it there.
  * UE4SS-settings HookProcessInternal=0 + HookProcessLocalScriptFunction=0 on the client: crashes ~9 s into startup
    (exit 0xC0000264), twice. So those hooks can't simply be switched off with our mods loaded.
  * CLIENT WITH ONLY PvEBridge (2026-11-07, 21:40; deployed mods.txt trimmed after the host started; host = full mods,
    Spaceport_01 listen): NO freeze. The client bounces back to MainMenu ~3 s after `open` (MainMenu reloads, new
    StationGameMode id), never loads Spaceport. Host: conns 0 -> 1, a second MainPlayerController with NO PlayerState
    (RaidGame pools controllers, so this does not mean the client got in), connection left until timeout.
  * THE FREEZE IS OUR TOOLING: with the diagnostic hook scripts (t_neterr/t_kick/t_leave) loaded on that same
    PvEBridge-only client, the next join froze at the same exe+1c3cdc0 spin. So Lua RegisterHook'd functions firing
    during the join (ours or PvEDirector's) cause the freeze; the real behaviour is the quick bounce.
  * Rejected during the handshake, in native code. Controller chain MainPlayerController_C -> RaidPlayerController ->
    SIGISPlayerController -> AGameLiftPlayerController (ServerAcceptPlayer/ServerRemovePlayer(PlayerSessionId));
    the exe carries the GameLift server SDK (AcceptPlayerSession). URL options the exe parses (UTF-16 strings near
    0x40998c8): PID UPN SHIP CREW CPT PNAME NUM EOS GUILD player_id player_battle_session_id code error (no `psid`).
    Game mode chain ShootingRangeGameMode_C -> RaidGame_Space -> RaidGameMode -> SIGISGameMode -> GameMode adds no
    script login functions: PreLogin/Login logic is all native. Tried, all bounce the same: CREW=solo1?CPT=0 (join the
    host's crew), host reopened with NUM=2, client NUM=1/2.
  * NATIVE PASS (2026-11-07, 21:55-22:11). Tools: native/pveudp.c (IAT sendto/recvfrom logger -> capture/udp-<pid>.log,
    optional per-path send stacks; decode with scripts/udpstr.py), native/pveeac.c (logs EOS anti-cheat SERVER calls via
    the exe's GetProcAddress import; pass-through), bridge/t_trace.lua (lean hooks: name + time only, never params ->
    no freeze), bridge/t_kick2.lua.
    - Not a PreLogin reject: the client sends a plain NMT_Login (URL options + Name=Marauder1 + net id `Hay-<hex>` from
      the NULL subsystem), gets its welcome, loads Spaceport's persistent level, joins, receives ClientSetHUD(MainHUD_C),
      and ~0.4 s later the HOST closes the connection: its keepalives (every ~0.2 s) stop at that moment. Client lands
      on MainMenu with options `?closed`. Other packets (both directions, except the login) are high-entropy:
      some packet transform; not decoded.
    - No kick RPC reaches the client (ClientWasKicked / ClientReturnToMainMenu* / Client_EACAction / ClientEACAction
      never fire), host never runs ServerChallenge/ServerAcceptPlayer as UFunctions. The close is flushed by the
      normal per-tick send path, so the deciding code isn't on the sendto stack.
    - EOS anti-cheat ruled out: EOSSDK is loaded but no EOS_AntiCheatServer_* function is ever looked up.
    - Options player_battle_session_id / player_id, CREW=solo1?CPT=0, NUM=2: no change.
    - Both copies have denuvo-anti-cheat-runtime.dll loaded, and SIGISPlayerController has
      ServerChallenge(TokenReturn, TokenReturn2): an anti-cheat challenge/response between host and joiner is a
      plausible remaining cause (unproven). NOT pursued: working around the game's anti-cheat is out of bounds (and
      the Denuvo anti-cheat components are never to be touched). Other unproven candidate: a native GameLift
      AcceptPlayerSession check in the host's login (server SDK statically linked; can't be IAT-hooked).
  Co-op status: host side works; joining is blocked by a native, host-side close right after login.
- (older) options for a driveable second instance (co-op client):
  (a) Fix with UE4SS present: identify the quit UFunction (C++ impl exe+0x9fafd0, a blueprint-callable reached via
      ProcessEvent from exe+971c1b nakama callback) and RegisterHook it in Lua to no-op / early-return. UE4SS is both
      the cause and the tool. Needs identifying the UFunction (log ProcessEvent around the quit, or hook candidates
      like a GameInstance OnDisconnect/ReturnToMainMenu/Quit).
  (b) Keep the client WITHOUT UE4SS (survives) and drive its join another way: a UE4 map URL on the command line
      (`RaidGame-Win64-Shipping.exe 127.0.0.1:7777?PID=..`) or a minimal injected helper calling open; host stays the
      FIRST instance with UE4SS+bridge (first instance never quits). Open: client needs a PID, normally from login.
  The listen server itself (`open ...?listen`) is already known to work for a single instance.

## Co-op join: who drops, and what never fires (2026-11-15; tools/coop/coop_hooks.lua)
Follow-up to "Co-op host+join attempt". Same setup as there: host = launch-offline.ps1, splash Play, then from the lobby
`open /Game/Maps/Raids/Spaceport_01?listen<RAID_OPTS>`; client = second exe with its own TEMP/TMP (tmp2) and
PVE_BRIDGE=bridge2/, deployed Mods/mods.txt PvEDirector 0 (PvEBridge only), `open 127.0.0.1:7777?PID=offline2...`.
Both copies ran tools/coop/coop_hooks.lua: logging-only hooks (name, time, object address; no params) on 21 UFunctions:
SIGISPlayerController ServerCheck / ServerChallenge / Server_SendEAC / OnAntiCheatCheck / ClientEACAction /
Client_EACMessage / Client_EACAction / Client_Loaded, GameLiftPlayerController ServerAcceptPlayer / ServerRemovePlayer,
RaidPlayerController ClientStartOnlineGame / ClientGameStarted / ClientDissconnectedFromServer, PlayerController
ServerNotifyLoadedWorld / ClientSetHUD / ClientRestart / ClientWasKicked / ClientReturnToMainMenuWithTextReason,
GameModeBase K2_PostLogin / K2_OnLogout, MainPlayerController_C ReceiveBeginPlay; plus Actor:ReceiveEndPlay logged
for PlayerController classes only. Two joins (21:05, 21:14), same result both times.
- The connection IS dropped about 3 s after the join (corrected later the same day). A first poll counted objects
  (FindAllOf IpConnection / MainPlayerController_C) and saw them stay for 30 s, which looked like the host keeping the
  joiner. Those are leftovers waiting for garbage collection: the host's live list, world.NetDriver.ClientConnections
  (GetArrayNum), went 0 -> 1 at the join and back to 0 about 3 s later. Count connections with that list, not objects.
- Client timeline (join 21:14:23): host spawns the joiner's MainPlayerController (ReceiveBeginPlay 21:14:27.2); client
  gets ClientSetHUD 21:14:28.8; client is back on MainMenu by ~21:14:30 (its menu re-login hits the stand-in's
  GET /v2/account at 21:14:30). The client's own ReceiveBeginPlay never fired, no ClientRestart, no ServerNotifyLoadedWorld.
- Never fired on either side, both joins: ServerChallenge, ServerCheck, OnAntiCheatCheck, Server_SendEAC, every
  Client_EAC*/ClientEACAction, ServerAcceptPlayer, ServerRemovePlayer, ClientWasKicked, ClientDissconnectedFromServer,
  ClientReturnToMainMenuWithTextReason. A host-side hook at a native RPC's exec thunk should fire on receipt even if
  its _Validate then fails (inferred, not verified). Whether a client-side hook fires when the client SENDS a Server
  RPC is not verified either.
- No backend traffic at the join: stand-in server.log has nothing between the join and the client's menu re-login.
  pvenet.log (needs a capture/ folder to exist, else it logs nothing) shows only the usual blocked lookups
  (api.gameanalytics.com every ~4 s from the exe, marauderea2...nakamacloud.io from nakama-cpp.dll), before and after.
- Gotcha: UE4SS 3.0.1 can't run a Lua hook for a function with an FText param: "Error executing hook pre-callback
  /Script/Engine.PlayerController:ClientReturnToMainMenuWithTextReason: [push_textproperty] Operation::GetParam is not
  supported" in UE4SS.log, and the Lua callback never runs. So a "never fired" for an FText RPC only holds if that error
  line is absent from UE4SS.log too (it was, for both joins). Earlier passes that hooked this RPC couldn't have seen it.
- Seen once, after the joiner crashed (below): ~17 s after the client died, the HOST called
  ClientReturnToMainMenuWithTextReason (the UE4SS error line above) and went back to its own MainMenu. That's the host
  ending its session on losing a player, not the join bounce.
- Crash, our tooling: a client-side RegisterLoadMapPreHook that read the URL (url:get().Map / .Op) killed the client
  during travel (0xe06d7363, a C++ exception inside UE4SS.dll frames, minidump in %LOCALAPPDATA%\RaidGame\Saved\Crashes).
  Don't read LoadMap params from Lua.
- Denuvo, passive OS view only: "Denuvo Anti-Cheat Update Service" (Manual start) is Running while the game is up, process
  denuvo-anti-cheat-update-service; EasyAntiCheat and EasyAntiCheat_EOS services Stopped. Nothing else looked at.

What this means for the candidates (desk research, same date):
- A, Denuvo anti-cheat challenge: no longer the best fit. The suspected path was SIGISPlayerController ServerChallenge
  (TokenReturn, TokenReturn2) failing on the host; no hook on either side ever saw it, and no kick arrives. Not
  ruled out: a check entirely inside the Denuvo runtime on the CLIENT that makes it leave (we don't and won't look there).
- B, GameLift accept: no sign of it. ServerAcceptPlayer never runs on the host and is never seen leaving the client.
- New lead, client side: the client leaves ~1-2 s after ClientSetHUD, before its controller's BeginPlay, without any
  kick RPC: the shape of an engine-level client network failure (UNetDriver/PendingNetGame error -> HandleDisconnect ->
  travel with `?closed`), e.g. a replication/package-map problem while the joiner's world starts, or game code on the
  client calling a disconnect natively. Desk research: `?closed` comes from UEngine::HandleDisconnect
  (https://forums.unrealengine.com/t/network-error-force-loads-entry-map-for-client-when-server-shuts-down/405257/11).
- Second session, same day (upstream master 92fde2d; native/pveudp.dll built with MinGW, -D_WIN32_WINNT=0x0602, loaded
  into both copies with package.loadlib from the bridge):
  * PvEDirector OFF on the host too (deployed mods.txt edited between mode.ps1 offline and the launch): same bounce.
    The director is not the cause.
  * 28 more client-side name-only hooks on everything that sounds like leaving: SIGIS_ExampleGameInstance_C
    Return_NakamaDisconnected / Return_Nakama_Error / Return_LostInternetConnection / ExitGame_ForceDisbandOrLeaveCrew /
    OnCanceled, SIGISGameInstance LoadMainMenu / BeenKickedFromLobby / CancelSearch, ...Nakama CaptainBackInMainMenu /
    AwsN_BeenKicked, ...PGOS CancelMatchmaking / DirectlyTravelToServer, GameLiftGameInstance QuitGame / ServerTravel,
    GameInstance HandleTravelError / HandleNetworkError, RaidPlayerController DeathToMainMenu, SIGISPlayerController
    HasLostConnection / TravelToMap / PGOSTravelToMap / OfficeTravelToMap / Client_ReturnPushMessage, PlayerController
    ClientReturnToMainMenu / ClientWasKicked. Only ClientSetHUD fired; no "Error executing hook" lines. Afterwards the
    client's world is MainMenu with no NetDriver.
  * UDP (both sides, same join): handshake and NMT_Login at 0-160 ms; host keepalives every ~200 ms while the client
    loads (the client sends nothing for 2.5 s); at ~2.6 s the client's first packet after loading, a few exchanges
    (ClientSetHUD arrives here), last client packets at ~2.70 s, last host packet at ~2.73 s, then nothing either way.
    No new send stack on either side at the end, so neither side's last packet came from a separate close path.
  * Not settled: which side ends it. Reading the client world's URL (.URL.Op) from the bridge errored.
- Out of bounds, unchanged: nothing that bypasses, patches, spoofs, emulates or hooks Denuvo anti-cheat/anti-tamper or
  answers a challenge; no modded client near a live match.
- Wire, third join (both captures merged on the shared GetTickCount clock): the last exchange is client 18 + 10 bytes,
  host 19 + 11 bytes within ~15 ms, then silence both ways. Who closes can't be read from the packets: after the
  handshake even the 12-byte keepalives look random (67027b5d5bb81ccde4bdd901, 67027b5d7c534de695f57301, ...), so a
  packet transform is on (encryption/obfuscation, not just bit-packing). Decrypting it is not pursued (it may belong to
  the anti-cheat protection; out of bounds). What's left, observation only: an engine-side signal on the client (which
  network failure, if any) or a client-side NotifyOnNewObject trace of what arrives in the final packets.

## Co-op join: the login never creates a player (2026-11-18; native/pvetrace.dll, tools/profile/dump_image.py)

**Superseded - see "Correction: the server DOES create a PlayerState" below.** The measurements
here were taken inside the ~3 s window before PostLogin, so "no PlayerState, the gate is in
PreLogin/Login" is wrong: the server does create the PlayerState, PreLogin and Login both pass,
and the client is what gives up. Kept because the probe hazards and the correction to the
CEF-parameter theory still hold.

The joining client's connection is accepted and dropped ~3 s later. Measured on the host with
array-length-only probes (10 Hz), reproduced many times:
- `world.NetDriver.ClientConnections` 0 -> 1 -> 0 in ~3 s; `GameState.PlayerArray` **stays 1**,
  so the server never creates a PlayerState for the joiner. Map load, the bare `PlayerController`
  the client spawns at +5 s, and the bounce to MainMenu are all consequences, not causes.
- `GameModeBase:HandleStartingNewPlayer` fires for the host's own entry every raid but **never**
  for a joiner (control is the same hook). `RestartPlayer` registers but never fires even for the
  local player, so a non-firing `RestartPlayer` proves nothing: UE4SS only sees ProcessEvent calls.
- Never fire either: `GameLiftPlayerController:ServerAcceptPlayer` / `ServerRemovePlayer`,
  every EAC/SIGIS RPC, `K2_OnLogout`, any kick RPC.
- Tried and did NOT change it: `player_battle_session_id=<the host's MatchSessionID>`, `player_id`,
  `UseDebugLogin=true` on the client's game instance, and filling `SIGISGameMode.ConnectedPlayerIds`
  (@gamemode+0x3D8, empty on a listen host, MaxPlayers 50) from native code before the join.
  The last one is "very likely not the gate", not disproven: UE4SS cannot stringify array elements,
  so the ids the engine sees were never verified.
- Next instrument: the login lives in native code with no UFunction wrapper. The vtable route is
  mapped (below); a trampoline hook on the candidate is what will confirm it, because the login
  rejection leaves no observable RPC.

**Correction to "Co-op host+join attempt" above:** the UTF-16 option strings at 0x40998c8 are NOT
join options the exe parses. They sit next to `...erController::HandleOnUrlChanged` with `?code=` and
`?error=` beside them, and nothing in the loaded image references them - no rip-relative reference in
`.xtext`/`.xcode`/`.arch` (2- and 3-byte forms) and no absolute pointer in any data section. They are
the CEF login page's result parameters. Experiments varying PID/psid/CREW/CPT/NUM could not have worked.

## Correction: the server DOES create a PlayerState (2026-11-18; live GameMode probe)

The section "Co-op join: the login never creates a player" is wrong on both of its conclusions,
and the measurements behind it were taken inside the ~3 s window, before PostLogin ever ran.

Instrument: a native DLL that patches the GameMode's **vtable entries** (not function prologues,
so no instruction is relocated) and logs each slot's first call with rcx/rdx/r8/r9 and any
plausible string among them. Loaded through a Lua mod's `package.loadlib`, because this UE4SS
build has no C++ mod support (`strings UE4SS.dll | grep StartMod` is empty) and bridge command
chunks are sandboxed. Slots used, all verified live:

- **slot 233 = PreLogin**, RVA **0x17E5320**. Logged with `rdx` = the full join options
  (`?PID=offline2?PNAME=Marauder2?...?Name=Marauder1?SplitscreenCount=1`) and `r8` = `127.0.0.1`,
  which is the `(Options, Address, UniqueNetId, ErrorMessage&)` signature.
- **slot 234 = Login**, RVA **0x30D0060**. Fires *after* PreLogin, so **PreLogin returns true**.
- Neither writes anything into any ErrorMessage argument (the candidates were watched for 6 s
  after each call), so **neither call rejects the join**.
- After Login the host walks the options string character by character (slots 237/257 show UTF-16
  fragments `Spli`/`eenC` from `SplitscreenCount=1`) and slot 240 receives `"Marauder1"`.

What the server actually holds afterwards, read through the bridge's `lua` verb:
`FindAllOf("PlayerState")` = **2** while `PlayerController` = 1. So the server created the joiner's
PlayerState, reached **PostLogin**, and destroyed the PlayerController when the client left.

**Therefore the drop is client-side:** the client loads the map, spawns a bare PlayerController,
and travels itself back to `/Game/Maps/MainMenu`. The login gate is not the server's PreLogin or
Login; it is whatever the client decides after it has the map. Next instrument: wrap the client's
own GameInstance/PlayerController vtable and find the slot that runs immediately before the travel.

String constants recovered from the dump, for the record: `"incompatible_unique_net_id"`
(PreLogin's uid-mismatch branch, not taken), `"Failed to spawn player controller, GameSession is
null"` and `"Failed to spawn player controller"` (Login; GameSession is non-null at gm+0x278),
`"SpectatorOnly=1"` (a post-login branch).

## Client side: the GameInstance vtable is not where the bounce is decided (2026-11-18)

Same probe, pointed at the client (VTH_DIR per instance, because both copies share one DLL). The
client's GameInstance vtable was found without resolving a base: bridge2's `lua` returns
`UObject: 0x...` for `FindFirstOf("GameInstance")`, and the first qword at that address is the
vtable - 245 slots wrapped, 173 of them executable.

Only **12** virtual calls ran during the join, and none is a travel: slots 192/124 are the console
`open` command itself (they receive the URL string), and the rest are ordinary engine plumbing. So
the decision to return to MainMenu happens on another object - the client's PlayerController or
the engine - not on the GameInstance.

Decompiling those 12 targets without a full analysis does not work: Ghidra bounded three of them
as 46-50 KB blobs (no analysis means no function boundaries), so the output is unusable. Any
further client-side work wants either the analysed project or a different measurement, not more
targeted decompiles.

Two process facts learned the hard way: `Get-Process ... Modules[].BaseAddress` returned the
HOST's base for both PIDs, so RVAs computed from it were nonsense - `VirtualQueryEx`'s
`AllocationBase` gave the real one (`0x7FFF0BCF0000` for that client, versus the host's
`0x7FF765060000`, so ASLR really does differ per instance). And the probe's own module-range
check reads 0 "in module" in the client while still finding 173 executable entries, so the gate
now trusts executable pages and a two-thirds ratio rather than my range arithmetic.

## Night two: the probe grew teeth, and one address fact that explains the dead ends (2026-11-18/19)

Reached with the same native vtable probe, now with four verbs on its command file:

- `obj=0x<address>` - wrap the vtable **of that object**; the deref happens in-process, so the
  caller needs no module base. Trusted: an address that came from an object's first qword is a
  vtable by construction, so the executable-ratio gate is skipped for this path.
- `vt=0x<address> [trust=1]` - wrap a caller-supplied address, gate on by default.
- `read=0x<address>:<hex bytes>` - log qwords from that address, page-checked first.
- `base=1` - log `GetModuleHandleA(NULL)` for the process.

**The address fact.** On a live listen host, `FindFirstOf("MainPlayerController_C")` gives an
object whose first qword is `0x7FFF0E596C80`, while `base=1` reports the module at
`0x7FF765060000`. Subtracting gives a 32 GB "RVA", so **that object's vtable is not at
`gbase + rva`**. The GameMode wrap that worked was measured the other way round - `gbase + 0x4599ED8`
came out 420/420 executable - so both statements are true and the two classes are not in the same
mapping. Until this is understood, do not derive a vtable address by adding an RVA to
`UE4SS.log`'s MainExe base for an arbitrary class; use `obj=` and let the process read its own
memory.

**Bridge reply parsing.** Replies are `HH:MM:SS = <value>`, so `line.startswith("=")` never
matches and every lookup silently reads as "not found". That one bug invalidated a whole round of
"the object does not exist" conclusions (the client PC, the class vtable). Match `=\s*(.+)$`.
`tostring()` of an actor prints `AActor: 0x...`, not `UObject: 0x...`.

**Where the join stands.** Unchanged from the correction above: the server accepts, creates the
PlayerState and reaches PostLogin; the client gives up ~3 s later. New this round: the client's
`GameInstance` and `GameEngine` vtables were wrapped and show only travel/URL plumbing, none of it
a decision to leave. Re-arming the wrap *after* the `open` command is required, since those slots
disarm on the first hit and the command itself consumes them.

**Not fixed.** No patch is in place. The next instrument is the client's PlayerController class
vtable armed before it connects, which needs the `obj=`/`base=` question above settled first.

## The address puzzle is solved: UE4SS's tostring() is not the UObject (2026-11-19)

`tostring(actor)` in this UE4SS build returns a **wrapper** object, not the UObject. Proof from one
live host, same process:

- `FindFirstOf("ShootingRangeGameMode_C")` and `FindFirstOf("MainPlayerController_C")` both
  stringify to distinct addresses, but **the first qword at both is the same value**
  (`0x7FFF0E766C80`), and `VirtualQueryEx` + `GetMappedFileNameW` put it in **UE4SS.dll**, not in
  the game. That is why every shape check reported "0 in module" and why `obj=` wraps of those
  addresses produced nonsense tables.
- `obj:GetAddress()` returns the real UObject. For the same PlayerController it gives a different
  address, whose first qword is `0x7FF769608738` - allocation base `0x7FF765060000`, file
  `RaidGame-Win64-Shipping.exe`. So the real class vtable is at **RVA 0x45A8738** and everything
  derived from `gbase + rva` was correct all along.

Rules that follow: use `GetAddress()` (or `obj=` with an address that came from `GetAddress`),
never `tostring()`, when a vtable is wanted. `GetClass()` stringifies as `UClass: 0x...` and is
fine for identity, not for addresses.

## Client PlayerController trace, with a real vtable this time (2026-11-19)

With `vt = client_base + 0x45A8738` (the class vtable, wrapped before connecting), one join logs
**78** virtual calls on the client's PlayerController, including a console command
`ENABLEALLSCREENMESSAGES` and a `"Maar..."` name string - and **not one travel call**. The client
does not decide to leave at the game layer; the give-up is beneath it (engine network failure).

Server side of the same join: `ps=3 pcs=2 pawns=1`. The joiner's PlayerController exists and its
`Pawn` is a pointer whose object is already invalid by the time it is inspected, i.e. the server
completed the join and then tore the pawn down when the client left. `SpectatorPawn` count is 0, so
"the joiner is made a spectator" is not supported by this evidence.

Open lead for next time: the client fails *after* `ClientSetHUD` and *before* its controller's
`BeginPlay`, with no game-level travel, so the failure is in the engine's pending-netgame/connection
path. That is below every vtable wrapped so far; the next instrument wants
`UNetDriver`/`UPendingNetGame` state (or the connection's close reason) rather than more game
classes.

## UNetDriver / PendingNetGame from Lua: reachable only while the join is live (2026-11-19)

Tried to read the engine's pending-netgame state from Lua, since the game-layer vtables showed no
travel and the failure must be below them.

- `FindFirstOf("NetDriver")` and `FindFirstOf("PendingNetGame")` both return objects **at the menu
  after a failed join**, so the objects survive the failure - but `:GetAddress()` on the
  PendingNetGame, on its `NetDriver` and on `NetDriver.ServerConnection` all return **0**. They are
  stale: the wrapper still resolves, the UObject behind it is gone. Any read taken after the
  fallback is meaningless, which is why an earlier "state" read looked plausible and said nothing.
- Property reads return `userdata` wrappers, not primitives: `p.bFailedToConnect` is a userdata
  whose `tostring` is `UObject: 0x...`, and `v:get()` returns a *function*. So this build does not
  let Lua read a bool or an enum property directly; state has to be read from memory at known
  offsets (the probe's `read=`), sampled during the live join window.
- Consequence for the next attempt: poll while the join is in flight (the client's bridge is alive
  until the world change), not afterwards, and read `UNetConnection::State` and
  `UPendingNetGame::bFailedToConnect` by offset rather than by property name.

## One join window per client launch (2026-11-19)

The client's bridge answers until the join's world change and then never again, so a launch gives
exactly **one** attempt at measuring. Polling from outside loses that attempt to a race: the
`open` command and the first poll compete for the same one-command-at-a-time inbox, and by the time
the poll is answered the client is already travelling.

What that means for the connection-state experiment: do not poll. Pre-arm a **hook**
(`RegisterHook` on a function that runs during connect) so the capture happens on the game thread
at the moment the object exists, and have it hand the address to the probe's `read=`. A fresh
client launch is required per attempt, so a failed run costs a full 50 s cycle.

Dead ends confirmed this round, in order: `PendingNetGame`/`NetDriver`/`ServerConnection`
`GetAddress()` is 0 after the fallback (stale wrappers); property reads return `userdata`, and
`v:get()` returns a function; polling the client's bridge during the join gets no reply at all.

## Client RPC hooks fire; the connection is still unreachable from Lua (2026-11-19)

A Lua mod that registers `RegisterHook` on `PlayerController:ClientRestart`, `ClientSetHUD`,
`ClientGotoState` and `ClientTravel` proves two things and closes one door:

- **The hooks fire on the client**, including `ClientRestart` - so the client does receive the
  restart RPC, it just never reaches `BeginPlay`. That is a sharper statement than "before BeginPlay".
- **`GetAddress()` on the connection is 0 even during connect.** Inside the hook, while the join is
  live, `PendingNetGame.NetDriver.ServerConnection:GetAddress()` returns 0, so the probe has nothing
  to read. The Lua route to `UNetConnection::State` is therefore closed in this UE4SS build, not
  merely awkward: every property wrapper either reads 0 or returns a function.

Getting the connection's pointer needs C++ (a mod DLL walking `UPendingNetGame`/`UNetDriver`
directly), not Lua. That is a bigger build than anything so far and is the honest next step.

Design note for whoever reuses the trick: the hook mod writes its probe command into
`bridge2/vth_cmd.txt` with `io`, which works from a mod's script (unlike a bridge chunk) and needs
no bridge round-trip. But both game instances load the same mod, so the hook log must be namespaced
per instance or it interleaves host and client lines - the run above muddied itself that way.

## Server side: the client goes silent, the server only cleans up (2026-11-19)

Server-side sampler: probe command `drv=0xADDR` walks `UNetDriver::ClientConnections` (offset
`0x90`, TArray) and byte-diffs each connection's first `0x200` bytes at 10 Hz. Offsets come from
the game's own reflection dump (884 headers, `sdk` verb):

| field | offset |
|---|---|
| `UPendingNetGame::NetDriver` | `0x30` |
| `UNetDriver::ServerConnection` | `0x88` |
| `UNetDriver::ClientConnections` | `0x90` |
| `UNetDriver::World` | `0x140` |
| `APlayerController::Player` | `0x298` |
| `APlayerController::NetConnection` | `0x418` |
| `UNetConnection::Driver` | `0x58` |
| `UNetConnection::LastReceiveTime` | `0x1D0` |

One join, 70 samples at 10 Hz:

- `ClientConnections` num: `0` (29 samples) -> **`1` (41 samples)** -> `0`. So a join connection
  exists server-side for about 4 s.
- `LastReceiveTime`: `85.371` -> `85.622` -> **`85.702`, then frozen for 39 samples (3.9 s)** while
  the connection was still in the array. The client's last packet arrives ~0.33 s after the
  connection is first observed, and then nothing.
- Byte diffs at the drop touch only `0x168..0x172` and `0x1D2..0x1F5`, which look like ack/hash
  counters. **Nothing in `0x00..0x168` changes**, so `UNetConnection::State` (not reflected) is
  either outside that range or not a plain byte - the earlier assumption that it sits just before
  `Children` (`0x48`) is unsupported by this data.

**What this settles:** the client stops sending and the server does not close the connection - it
lingers ~4 s and is then cleaned up. Together with #24 (traffic stops both ways with no close
packet) the initiator is the client's send path, not a server kick. That is a different conclusion
from "the server rejects the joiner", and it is the first time the drop has been located on the
wire with a timestamp rather than inferred.

**Also confirmed:** the client's `NetConnection` is 0 and it only ever holds `MenuPlayerController_C`
during `ClientSetHUD`, so it never materialises a controller for the join at all.

Next: widen the server dump past `0x200` to place `State`, and instrument the client's send path
(`UNetConnection::SendRawBunch`/`FlushNet`) to see whether the client stops sending because its own
connection object died or because it is waiting for something.

### Widening to 0x600: the server still ticks the connection while the client is silent (2026-11-19)

Second server-side run with the diff range widened from `0x200` to `0x600`. `UNetConnection::State`
still shows no `3 -> 1` transition, and no single byte in `0x00..0x600` behaves like a state enum.

What the widened dump did show, and it is worth more than the enum would have been: with
`LastReceiveTime` **frozen from the first sample** (`86.889` for the whole window), fields at
`0x1EA..0x1F5`, `0x1F8`, `0x248` and `0x480..0x48B` **kept changing every 100 ms**. Those look like
outgoing ack/timer/hash bookkeeping, which means the server is still actively ticking the
connection - it believes the connection is alive - while the client transmits nothing.

So the drop is not a close at all. Nobody sends a close: the server keeps an open, ticking
connection, and the client simply stops transmitting. That tightens the earlier reading ("the
client goes silent and the server only cleans up") into "the server never even notices anything is
wrong until the connection is eventually reaped".

Practical note on the sampler: the `State` hunt has now cost two runs. A cleaner way to place it is
to watch a value that must move - send one packet and diff - rather than looking for an enum that
may be bitfielded or living outside the dumped range.

### Client-side vtable scan: no coherent UNetConnection exists to sample (2026-11-19)

`scan=0xVT[:secs]` walks commit-private memory looking for objects whose first qword equals VT.
The vtable address is the class RVA `0x41A9050` (measured from a live server-side connection)
plus the client's own module base, which the probe reports via `base=1`.

Two 12-second scans spanning a join, on the client, found only:

- `obj=656ad0ddb0 cls=0 drv=7fff9a4c1836 lrt=0.000` - Class pointer is not a heap address, so not
  a UObject at all: a coincidental 8-byte match.
- `obj=1f4661b9d10 cls=1f45bdf8b00 drv=0 lrt=0.000` - plausible Class pointer, but `Driver` at
  `0x58` is 0 and `LastReceiveTime` never moves, so it is not a live connection.

So the client never holds a constructed `UNetConnection` anywhere in its private heap during the
join - which fits the rest of the evidence (no join PlayerController, `NetConnection` 0,
`PendingNetGame.NetDriver.ServerConnection:GetAddress()` 0). Either the object is never built, or
it exists for less than one scan pass and is freed.

Tell-tale detail worth remembering: a scan for a vtable is only as good as the vtable. A wrong
or truncated address yields plausible-looking hits, and the fields at `0x10`/`0x58` are what
separate a real object from a coincidence - so check `Driver` and `LastReceiveTime`, not just the
first qword.

**Better next step than more connection scanning:** scan for the *NetDriver* vtable instead (the
client definitely has a live NetDriver - `FindFirstOf("NetDriver")` resolves one) and read
`ServerConnection` at `0x88` from it. That reaches the connection through a pointer rather than by
hunting for it, and the driver object exists from boot.

### NetDriver route: found a driver, but the connection's layout does not match the dump (2026-11-19)

`ndscan=0xVT[:secs]` finds an object by vtable, takes `*(obj+0x88)` as `ServerConnection`, then
diff-samples that pointer at 10 Hz. This is the first route that does not need a race window: the
NetDriver exists from boot.

Measured on the host first, so the client can be armed with only its own module base:

- `FindFirstOf("NetDriver"):GetAddress()` works (unlike the pending-netgame wrappers).
- Host NetDriver vtable = `0x7ff769209428`, module base `0x7ff765060000` -> **RVA `0x41a9428`**
  (the connection class vtable sits 0x3d8 below it, at `0x41a9050`).

One client cycle:

- `NDHIT obj=f966a5db78 ServerConnection=f966a5dcb0` - a driver instance **was** found, and
  `+0x88` was non-null, which is what a client's driver should hold.
- But sampling that pointer gave `lrt` values like `5.7e300`, i.e. **garbage as a double**, and
  140 samples of churn at `0x18`, `0x60/0x61`, `0x70..0x87`, `0xf8`, `0x100`, `0x120..0x148`.

So one of two assumptions is wrong: either the object found is not the game's NetDriver (some other
class with that vtable is unlikely, but a *different driver* - demo/replication - is possible), or
`0x88` is not `ServerConnection` for the connection class on this build. The dump that gave the
offsets was generated from this same build, so the more likely error is the first: the scan hits the
first matching object in memory, which may not be the driver in use.

**Next:** before trusting `+0x88`, verify the object really is a `UNetDriver` - log `*(obj+0x10)`
(Class) and compare it against the Class pointer of the driver that `FindFirstOf` returns on the
host, and log `*(obj+0x190)` (NetDriverName, an FName) which should spell `GameNetDriver`.

### The NetDriver scan was finding its own stack; the dump offsets are right (2026-11-19, later)

Verified on a single offline instance, menu map opened with `?listen`, probe loaded from the bridge
with `lua package.loadlib("<repo>/native/vtprobe.dll","*")` (no loader mod needed: `package` is
reachable from a `lua` chunk, and `"*"` loads the DLL without calling an export).

- **At the main menu there is no NetDriver at all.** `FindAllOf` returns 0 for `NetDriver`,
  `IpNetDriver`, `DemoNetDriver`, `SteamNetDriver` and the beacon classes, and
  `FindFirstOf("NetDriver")` is nil. The earlier "the client has a live NetDriver from boot" was
  wrong (it was most likely read after a failed join, from a stale wrapper). A client's game driver
  only exists during the join.
- **A listen host holds exactly one**: `IpNetDriver_<n>`, `NetDriverName` = `GameNetDriver`, the
  same address as `World.NetDriver`. The `Default__IpNetDriver` CDO shares its vtable **and** its
  Class pointer; only the object flags at `+0x08` tell them apart (`0x40` instance vs `0x31` CDO).
- **`ndscan` on that host hit `0x19c7e0dbc8`, not the driver at `0x1c128338100`.** The "connection"
  it then sampled was `obj+0x138`, and the bytes changing there were the probe's own strings
  (`.../bridge/vth_cmd.txt`, `ndscan=0x...`, its log text). The scanner matches the copy of the
  vtable value on **its own thread's stack** and stops at the first hit. The client NDHIT in the
  section above had the same shape (`ServerConnection = obj + 0x138`, a low non-heap address), so
  that run measured the probe, not the game. The `lrt=5.7e300` garbage is explained; no layout
  mismatch exists.
- **The dump offsets hold on the real driver** (`read=` of `0x198` bytes): `+0x00` vtable
  (RVA `0x41a9428`), `+0x10` Class (= Lua `GetClass():GetAddress()`), `+0x88` ServerConnection = 0
  and `+0x90` ClientConnections empty (right for a server with nobody joined), `+0x140` World (=
  Lua's World address exactly), `+0x190` NetDriverName = FName index `0x2e8` (`GameNetDriver`).

Same suspicion applies to the earlier client connection scan ("no coherent UNetConnection"): its
low-address hit was very likely the same self-match and the heap hit with `Driver=0` looks like the
`IpConnection` CDO. Its conclusion still stands (nothing live was found), but it says nothing about
whether a scan *could* have found one.

**Not done:** the scanner was not fixed. `vtprobe.c` lived in a session scratch folder that has
since been cleared, so only the built `native/vtprobe.dll` (gitignored) remains. A rewritten scan
must accept a hit only if it lies in a heap region (not a thread stack: skip `MEM_PRIVATE` regions
that hold a TEB-listed stack, or simply skip the scanning thread's own stack range), has
`*(obj+0x10)` equal to the IpNetDriver UClass (read from Lua before joining), lacks the CDO flag
(`0x10`) at `+0x08`, and has `+0x190` = `0x2e8`. It must keep scanning past the first hit. Then
`+0x88` on the client during the join is the next real measurement.

## Co-op join works: the host refused a PNAME that isn't Base64 (2026-11-19; native/vtprobe.c, PvEBridge `join`, #26)

**Cause, measured end to end:** the host's GameMode `InitNewPlayer` override (exe RVA `0x98cba0`) reads the joiner's
`PNAME` option through `FBase64::Decode` (RVA `0x19e5db0`). `Marauder2` is not valid Base64 (9 characters), decodes to
nothing, and the function returns the error **`"PlayerNick is null"`**. Login fails, the host sends `NMT_Failure` with
that text, and the client closes. `PNAME=TWFyYXVkZXIy` (Base64 of `Marauder2`) joins: the client spawns its
`MainPlayerController_C` and `PlayerPawn_C` in the host's Spaceport_01, the host's bots replicate in (client pawn count
9 -> 33), and the connection stays Open (checked for over a minute, three joins, the last from a fresh client with no
probes). The host's own `PNAME=Marauder` passed all along only because 8 letters happen to be valid Base64.

The same function also requires a `PID` (`"PlayerID is null"`) and skips both checks only when the world type is
3/4 (PIE / editor preview, by the look of it). It parses `PID SHIP CREW CPT NUM EOS UPN PNAME psid`; only PNAME is
Base64-decoded.

How it was found (one session, all on the client unless said):
- **No NetDriver exists at the main menu** (`FindAllOf` 0 for every driver class). A listen host has exactly one,
  `IpNetDriver` named `GameNetDriver`. The old scan's "driver" was its own stack (section above).
- `NotifyOnNewObject("/Script/OnlineSubsystemUtils.IpNetDriver", cb)` from a bridge `lua` chunk fires on the game
  thread with the real object; `cb` writes `watch=0x<addr>` into the probe's command file. No scanning: a scan pass
  over a 5.6 GB heap takes ~10 s, longer than the join. `io` and `package.loadlib` are reachable from bridge chunks.
- **The client does build a UNetConnection** (vtable RVA `0x41a9050`, its `Driver` points back). The earlier "no
  coherent UNetConnection" was the broken scan.
- `+0x134` behaves as `UNetConnection::State`: the host's connection is 3 (Open); the client's stays 2 (Pending) until
  it closes (1). After the fix it goes 2 -> 3.
- **The "silence" was the client's map load.** The client's driver has `World=0` and its connection does not change
  at all for ~3.7 s (not even the per-tick field at `0x1f3`); the host's LastReceiveTime is frozen for the same time.
  "The server keeps ticking while the client is silent" (above) is this load, not a drop.
- With both instances logging on QueryPerformanceCounter (system-wide), 1 ms sampling: the client went to Closed in
  the same 2 ms as receiving a host packet; the host was still Open ~9 ms later and closed only on the client's close.
  So the host answered the Join without closing (UE4's join-failure path sends NMT_Failure and flushes) and the
  client closed.
- A hardware write-watch (DR0) on the client's `conn+0x134` caught the closing write with a clean unwind:
  `UWorld::Tick` -> `ReceivedRawPacket` (`"Packet failed PacketHandler processing."`) -> `UChannel::ReceivedRawBunch`
  -> control channel `ReceivedBunch` -> `NotifyControlMessage` NMT_Failure (`"NetworkErrors"`,
  `"GenericConnectionFailed"`) -> `UNetConnection::Close` (RVA `0x31ea2dc`). FStrings copied off the stack in the
  handler gave `"?failed"` and **`"PlayerNick is null"`**.
- An execute breakpoint on the host at `InitNewPlayer` captured the Options it received, PNAME included:
  `?PID=offline2?PNAME=Marauder2?CREW=solo2?...?Name=Marauder233?SplitscreenCount=1`, called from Login (RVA
  `0x30d0254`) <- SpawnPlayActor <- NMT_Join. The decode function's shape (decoded-size, decode returning bool,
  UTF-8 to TCHAR) is UE4's `FBase64::Decode(const FString&, FString&)`.

Setup that worked: host = `launch-offline.ps1`, bridge `raid Spaceport_01?listen`, `bridge/god.txt`. Client = same exe
with its own `TEMP`/`TMP`, `PVE_BRIDGE=<repo>/bridge2/` (holding `offline_backend`), deployed `Mods/mods.txt`
PvEDirector 0, then `bsend.sh bridge2 join`. Host and client had the same module base this time (`0x7FF765060000`).

**Not done / not tested:**
- The client ran with PvEDirector **off**, as in every earlier co-op run; earlier notes say its hooks froze a joining
  client. Co-op with the director on both sides is the next thing to try.
- Nothing played beyond spawning: no movement, combat, looting or extraction checked on the client, and no second
  PC. Both instances used the same stand-in account.
- Every player's displayed name reads `伸Хɯ` on both ends (host and joiner alike). It does not come from PNAME (a
  Base64 PNAME on the host changed nothing), so the name source is elsewhere; not chased. `RAID_OPTS` was left as is.
- No launcher or in-game co-op UI: joining is the bridge `join` verb only.

### Co-op with PvEDirector on both sides (2026-11-19, later; main.lua onTick)

Both instances with every mod on (the client too), host Spaceport_01 listen, client `join`: **no freeze**. The
earlier freeze came from diagnostic hook scripts, not the director. The client gets its controller and pawn, and all
16 of its `BotPawn_C` are replicated (`HasAuthority` false), so the client's director spawns no soldiers of its own.

**Bug found and fixed:** the host's director restarted the raid when the joiner arrived. A second batch of soldiers
(8 -> 16), floor loot placed again, the stash checked out again. Cause: the director ticks on
`MainPlayerController_C:ReceiveTick`, which on a host also fires for the joiner's server-side controller, and
`update()` keys the raid on `world@addr/pc@addr`, so every switch between the two controllers ran `resetRaid`. Fix: at
the top of `onTick`, a controller whose `IsLocalController()` is false is skipped (remembered per address, cleared per
world). Tested: host 6 bots before the join, 6 after, one `co-op: ignoring a joining player's controller` line, no
second spawn or floor-loot line, joiner has its pawn.

Telling the two instances apart in the log: both append to the same `UE4SS.log`. Raid lines carry the world address
(`navmesh generation started for World ...@<world>/<pc>`); match it against `FindFirstOf("MainPlayerController_C")
:GetWorld():GetAddress()` on each bridge.

**Still open:**
- The client's director still runs its arrival steps: navmesh, HUD, cosmetics, and `loadout: ... checked out of it`
  from the stand-in stash. Both instances use the same stand-in account here, so a joiner with real gear would take it
  out of the host's stash, and its extraction/death would write back to the same save. A joiner needs its own
  stand-in account (or its own stand-in), or the director should skip loadout/extraction when it is not the authority.
- Not played: moving, fighting, looting, extracting on the client; whether the host's bots target the joiner.

### A joiner with its own save (2026-11-19, later; scripts/launch-joiner.ps1)

`powershell -File scripts\launch-joiner.ps1 [-N 2] [-Name Marauder2]` after the host is up, then
`scripts/bsend.sh bridge2 join`. Player N gets:

- **its own stand-in**: `nakama_standin.py --port 7349+N --dir backend\joiners\<N> --name <Name>`. `--dir` moves
  every per-player file (state.json, loadout/cosmetics/checkout, ship files, gifts, coverage, server.log) into that
  folder; a new account there starts from the anonymous `seed.json` (never this PC's private capture) with a new user
  id and the given name. The old default (`backend\`, port 7350) is unchanged.
- **pvenet.dll pointed at it**: env `PVE_STANDIN_PORT` (pvenet.dll rebuilt, `gcc -shared -O2 -s ... -lws2_32`, same
  imports and size as before).
- **the director pointed at it**: `mods/PvEDirector/Scripts/pvebackend.lua` returns env `PVE_BACKEND` or
  `<project>/backend/`; main.lua (loadout, cosmetics, checkout, ship lost/gate), rivals.lua (ship stolen), hire.lua
  (crew save) and guild.lua (your name) use it.
- its own `bridge<N>\` (with the `offline_backend` flag copied in) and `tmp<N>\` as TEMP.

Tested in game (host Spaceport_01 listen, every mod on in both copies): the joiner logged in to its own stand-in on
7351, its raid start took **its own** equipped kit (flak vest, Brodie helmet, MAT-49, ammo) out of its own save, and
it spawned **holding the MAT-49**: the director's `Server_AwsN_EquippedItemsReturned` is a server RPC, so on a client
it asks the host, which equips the joiner. The host's stash was byte-identical before and after (33 items, same
hash), and the host's stand-in logged no request from the joiner. `tools/test_standin_flow.py` and
`test_standin_gaps.py` pass.

Not tested: the joiner extracting or dying (whether loot and losses land in its own save the way they do for the
host), a joiner on another PC (the scripts assume both copies on one machine), N > 2.
