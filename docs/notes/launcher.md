# Launcher, releases, Linux and Steam Deck

The launcher and saves, building the public release, trailer tooling, Linux and the Steam Deck.

Part of the project's research log: [NOTES.md](../../NOTES.md) lists every topic file and every section title.
Sections are in the order they were written; a later section can correct an earlier one, so read to the end of a topic
before trusting a finding. When a section says "see X", search [NOTES.md](../../NOTES.md) for that title to find which
file it is in.

## Contents

- [Trailer tooling (2026-11-01, trailer/)](#trailer-tooling-2026-11-01-trailer)
- [Launcher and saves (2026-11-07)](#launcher-and-saves-2026-11-07)
- [Public release build; no more hardcoded paths (2026-11-08, tools/release/)](#public-release-build-no-more-hardcoded-paths-2026-11-08-toolsrelease)
- [Linux / Steam Deck via Proton (issue 127; scripts/pvemode.py, linux/)](#linux--steam-deck-via-proton-issue-127-scriptspvemodepy-linux)
- [Linux launcher window and Deck controls (issue 127, 2026-11-18; launcher.pyw IS_WIN, pvemode.desktop_entry)](#linux-launcher-window-and-deck-controls-issue-127-2026-11-18-launcherpyw-is_win-pvemodedesktop_entry)

## Trailer tooling (2026-11-01, trailer/)
- `bridge/cine.lua`: trailer camera (a CameraActor the controller views through, animated from the controller's
  ReceiveTick; HUD + widgets hidden). Shots: orbit, chase, duel (behind one ship looking past it at another), trail
  (follows the path a bot walked: stays out of walls in corridors), dolly, track. Ships are small (~300 units long):
  orbit radius 500-700 for your frigate. Helpers: bridge/t_pick.lua (ships), t_pair.lua (closest moving pair),
  t_bots.lua (station bodies), t_tocon.lua (walk up to a container).
- Recording: `trailer/setup.sh` after every map change (r.setres 1472x828w + window to the top-left, so the
  always-on-top Claude window doesn't cover it), then `trailer/rec.sh <name> <secs>` (ddagrab desktop duplication;
  gdigrab only sees black for this DirectX window). The crop drops the Razer overlay's FPS bar. Avoid computer-use
  while recording (its "Claude is using your computer" banner is captured); front.ps1 / key.ps1 / click.ps1 do focus
  and input instead (mouse clicks don't reach the menu: call the widget's BndEvt function from the bridge).
  Watch for Steam friend pop-ups in the bottom-right of takes.
- `trailer/make_trailer.py`: edit list, synthesized score (numpy), frame renderer -> marauders_offline_trailer.mp4.

## Launcher and saves (2026-11-07)
- launcher/launcher.pyw (tkinter, trailer style) + launcher/saves.py. Marauders Offline.lnk here and on the desktop. backend/saves/<id>/{state.json, meta.json, before-last-raid.json}. Play copies a save to backend/state.json (stand-in and scripts still use that path), backend/active_save.txt names it, and closing the game copies it back, stops the stand-in and goes to stock (backend/last_game.log keeps the UE4SS log). Started by launcher: cleanup waits until the game has been seen, or it kills the backend during boot (first version did: "connecting to backend" crash).
- New save: capture seed with stats, XP, factions, skills, cosmetics and stash reset, keeps Body01/Head01/voice gifts, adds a P08, ammo, bandages, 10,000 cash. Seed's contracts stay as they were. Cheat: state["cheat"], stand-in forces cash to 999999999 on every write; stash from assets/saves/items.json (tools/offline-audit/itemsizes.py; row+0x14 is u8 col,row).
- Double stash: config/stash_rows.txt (written on activate, per save). pve_stash_rows sets the InventoryContainerSizes TMap (32-byte elements at comp+0x128, size at +0x10); the grid widget has its own InventoryGridSize and builds at menu start, so main.lua rebuilds it (ClearChildren, InventorySlots:Empty, InitializeGrid) before items land. 59 items, 28 below row 15, all placed.
- Voice lines must not load during map travel: crash at bad RIP through UE4SS hook, in raid load. They now load only in the menu, 3 a frame, not while a match is pending. Lines not loaded are skipped.
- bridge/menu.sh waits for the splash before Play (fixed sleeps crash in nakama-cpp). rt.sh/zone_test.sh use backend/state.before-voice-model-work.json.
- Waist: width 0.885 at z108, 0.905 at z120, depth 0.86/0.9. Not looked at in game.

- Arms (2026-11-07): ANSUR II medians (ergoassessment.cam ANSUR II explorer), taken at equal height: biceps/forearm 0.92, wrist 0.95, neck 0.90, calf 1.03. make_female slims each arm around its bind-pose centreline (ARM_Z/ARM_Y), 0.88 at the shoulder to 0.97 at the hand; neck 0.9-0.96; calf 1.03. Checked on the lit lobby character, male vs female.
- Bust 8.3, waist width 0.91/0.925, depth 0.885/0.915 (user, 2026-11-07).
- PLAY preflight (2026-11-15): launch-offline.ps1's output used to be thrown away, so a wrong config/game_path.txt, a
  missing tools/ue4ss or Steam not running all showed as "The game didn't start" after START_TIMEOUT (90 s). launcher.pyw
  preflight() checks the game exe, tools/ue4ss (dwmapi.dll, UE4SS.dll, Mods) and steam.exe first; if the script still
  fails, the status line shows its first error line and the launcher tidies up at once.
- Update check (2026-11-16): the release zip now ships `version.txt` (`public-test-<build>`, written by
  build_release.py). launcher/update.py asks `api.github.com/repos/HaywireHayley/Marauders-PvE/releases/latest` (6 s
  timeout, background thread, fixed User-Agent, nothing about the player) and compares tags as (YYYYMMDD, .N; no suffix
  = 1). Newer -> a "! UPDATE TO BUILD ..." badge top right; same/older, offline, rate-limited or no version.txt (dev
  checkout, builds 1-3) -> nothing. Toggle "Check for new builds" -> config/update_check.txt (missing = on). UPDATE
  downloads the MaraudersOffline-*.zip asset to %TEMP%, checks it against the asset's `digest` (sha256 from the GitHub
  API; no digest -> no UPDATE button, only "What's new"), then writes the zip's files over the folder. Kept if they
  already exist: config/* except mods.txt and UE4SS-settings.ini (shipped, not player settings), bridge/*,
  backend/saves/*, backend/state*.json, cover/* (cover.lua appends the player's own points). Files the zip doesn't
  hold (saves, logs, loadout) aren't touched. Every replaced file is backed up first and restored if a write fails
  (tested with a read-only UE4SS.dll). Files removed from a later release stay behind (harmless so far). Builds 1-3
  have no update.py, so those players update by hand once.
- Launcher audit fixes (2026-11-16):
  - One launcher at a time: a named mutex (Local\MaraudersOfflineLauncher, single_instance() in launcher.pyw). Before,
    a second launcher opened between PLAY and the game appearing ran settle(): it filed state.json away before the
    raid and removed active_save.txt, so when the game closed the first launcher had nothing to put back, and the
    next activate() overwrote that raid. A second launch now brings the first window forward and exits. The updater's
    restart passes --after-update, which waits up to 15 s for the old launcher to exit.
  - Closing the launcher while the game runs asks first, and while it's saving it's refused. If it was closed anyway,
    the next start finishes the job: with the game still running it watches it as if PLAY had started it, otherwise
    it settles the save, keeps the log and runs mode.ps1 online, with PLAY off until that's done. Before, the game
    folder stayed in offline mode.
  - Save names that are Windows device names (con, prn, aux, nul, com0-9, lpt0-9) get "-save" on their folder:
    "Nul" made the folder but no files, and the new-save dialog closed with nothing made. Create errors now show
    in the dialog.
  - Copies into a save slot (settle, activate, undo, adopt) go through saves._copy (.tmp + os.replace), so a
    crash mid-copy can't cut a save off. A save whose meta.json or state.json can't be read is listed as DAMAGED
    (only Delete works) instead of silently vanishing from the list.
  - Settings boxes write through App.write_setting, which says so on the status line if the file can't be written.
  Tested outside the game: saves.py and the launcher with stubbed game/PowerShell (26 checks), and real launcher
  processes for the single-instance cases.
- Stand-in start and windowed size (2026-11-16, issue #75): launch-offline.ps1 started the stand-in with
  `Start-Process python -ArgumentList '-I', <path>`. Windows PowerShell joins -ArgumentList with plain spaces and no
  quotes, so with a space anywhere in the install path Python got a cut-off path and exited. Nothing checked, so the
  game sat on CONNECTING TO BACKEND forever. Reproduced on a folder named "with space"; re-extracting to a plain
  path "fixed" it, as the reporter found. Now scripts/launch-helpers.ps1 Start-Standin quotes the path, waits up to
  15 s for 127.0.0.1:7350 to accept a connection, and otherwise fails PLAY with a reason. The reason is the last line
  of backend/standin_err.log, where nakama_standin.py now writes a startup crash (port, state.json, no write access),
  or a timeout. Don't use Start-Process -Redirect* for it: that turns on handle inheritance, the stand-in keeps the
  launcher's stdout pipe, and the launcher's ps() call never returns. The stand-in now starts before mode.ps1 offline,
  so a failed start leaves the game stock.
  Windowed mode was a fixed -ResX=1600 -ResY=900, which ran off a 1366x768 screen. Get-WindowedSize uses 1600x900 when
  it fits, else the biggest 16:9 within 90% of the width and (height - 120) for the title bar and taskbar, in steps of 16,
  960x540 at least (1366x768 -> 1152x648). It reads the first video controller, so on two monitors it's sized for the
  first.
- New saves start as a new live account did (2026-11-16, issue #56). On the first login of an account with no
  social/created (the seed has none, so every fresh save), the game runs its new-player setup: it writes
  social/created + accouttype, adds 65,000 credits (statChangeArray TotalCash) and a 34-item kit (2 KlobbSMG, 3
  Mat49Rifle + 2 wooden stocks, 3 BrodieHelmet, M1FlakChest, 2 LeatherJerkinChest, 2 LightBag, SmallContainer,
  BasicSupplyDrop, 2 HuntingKnife, a P08, 9 x 32Ammo, 2 x 9mmAmmo, 7 BandageAid), and opens the Guide (its YouTube
  video can't load offline). The launcher used to add START_CASH 10,000 and its own P08 kit as well: the lobby showed
  10,000, then 75,000 after the first stash refresh. Now START_CASH = 0 and the launcher kit is gone (saves.py), so a
  normal save gets exactly the game's start; cheat saves are marked as set up (_set_up_already) so the kit doesn't land
  on their packed stash. Tested: fresh normal save 0 / 3 items -> after login 65,000 / 37 items, lobby shows 65,000
  straight away; fresh cheat save 999,999,999 / 32 items -> unchanged, no setup writes in server.log.
  The new-player Guide (Guide_Widget_C:FreshAccount_RunGuide; a popup on the game instance, not the lobby's embedded
  Guide_Widget) is closed by lobbylabel.lua with ForceCloseTheGuideWidget if it shows within 60 s of the session's
  first lobby (it opened ~15 s in). Tested on a fresh save: "lobby: closed the new-player guide", clean lobby.

## Public release build; no more hardcoded paths (2026-11-08, tools/release/)
- `python tools/release/build_release.py` -> release/MaraudersOffline/ + release/MaraudersOffline-<date>.zip (~88 MB).
  Allow-list: launcher, stand-in + backend/seed.json (the capture seed with Steam id/name/avatar/user id/social removed),
  PvEDirector, a release PvEBridge (tools/release/PvEBridge_main.lua: only loads pvenet.dll, no bridge/cmd.txt),
  pvenet.dll + pvepatch.dll, UE4SS minus dumper/profiler mods, art minus female/src and unused stills, mode.ps1,
  launch-offline.ps1, and install.ps1 / uninstall.ps1 / README.txt / Install.bat / Uninstall.bat. It fails if any
  shipped text file still has a dev path or the Steam name/id in it.
- Install.bat: checks the path is plain ASCII (Lua io.open), finds Python 3.9+ with tkinter (py, python, the usual
  per-user folder; offers winget), pip-installs Pillow, finds the game in every Steam library (libraryfolders.vdf; else a
  folder picker) -> config/game_path.txt, makes desktop + Start menu shortcuts to pythonw launcher.pyw.
- Paths, dev tree included: the Lua mods `require("pveproject")` (mode.ps1 offline writes Mods/PvEDirector|PvEBridge/
  Scripts/pveproject.lua = the project folder); mode.ps1, launch-offline.ps1 and launcher.pyw read config/game_path.txt,
  default still E:\...\PHtest; pvenet.dll / pvepatch.dll find the project from their own path (<project>\native\x.dll)
  and pvenet's "game's own modules" filter is now the exe's folder, not "\PHtest\". The launcher passes its interpreter
  to launch-offline.ps1 as PVE_PYTHON (a bare "python" can be the Store stub) and stops python%.exe stand-ins.
- Verified: DLL rebuilt and loaded by a / path finds bridge\ and capture\; release saves + stand-in serve "Marauder";
  installer detection finds Python and E:\...\PHtest; release mode.ps1 offline/online on a fake game folder restores it
  byte for byte. NOT verified: an actual game session on the new DLLs / pveproject.lua (the game was left in offline
  mode, so it wasn't switched for the test).
- Dev setup (2026-11-15): scripts/setup-dev.ps1 [-Research] does a dev checkout's setup: requirements.txt
  (requirements-research.txt with -Research), config/game_path.txt via Find-Game, UE4SS v3.0.1 into tools/ue4ss.
  UE4SS_v3.0.1.zip (GitHub release, 5,523,402 bytes) SHA-256 4B47D4BCEDDD2F561A4E395BFA00924CCFC945AF576A2D0C613E6537846C57EC;
  dwmapi.dll, UE4SS.dll and Mods/ sit at the zip's root. Find-Game now lives in scripts/find-game.ps1, dot-sourced by
  install.ps1 (build_release.py ships it next to it in scripts/).

## Linux / Steam Deck via Proton (issue 127; scripts/pvemode.py, linux/)
- Design (the issue's option B): Marauders' Steam launch option `"<project>/linux/marauders-offline.sh" %command%`
  runs `pvemode.py steam-run`, which does what the launcher's PLAY does: settle/activate the save (config/linux_save.txt
  or the last played), start the stand-in, switch the folder offline (same files as mode.ps1), then run Steam's command
  with RaidGame.exe (EAC bootstrapper) swapped for RaidGame-Win64-Shipping.exe plus -nosplash, and
  `WINEDLLOVERRIDES=dwmapi=n,b` so Wine loads UE4SS's proxy instead of its own dwmapi. On exit: stand-in stopped,
  folder back to stock, save settled. Steam supplies Proton, its prefix and steam_api.
- Unclean exits: offline() writes backup/offline_applied; every pvemode command (and steam-run first thing) puts the
  folder back when it's there and no game is running. SIGTERM/SIGINT/SIGHUP (Steam's stop) tidy up in a finally.
- Safety: `pvemode.py steam off` (config/linux_offline.txt) makes the same launch option exec Steam's command unchanged.
- pveproject.lua gets the Wine form of the project path (`Z:/home/...`): the Lua runs inside the game. pvenet.dll finds
  the project from its own module path, which Wine reports in the same form.
- Tested: scripts/test_pvemode.py on Windows and on Linux (WSL Ubuntu, Python 3.12), with a fake game folder and a fake
  Proton: play and tidy up, SIGTERM mid-game, switched off, unclean-exit recovery, libraryfolders.vdf with an SD-card
  library with a space in its path; linux/install.sh and the wrapper on a copy of the project.
- **Not tested: anything under real Proton.** Open questions in #127: does UE4SS 3.0.1 load with dwmapi=n,b, does
  pvenet's WinHTTP redirect work under Wine, does the Shipping exe start without EAC under Proton, where the prefix keeps
  Saved/ (crash reports, GameUserSettings.ini). Not done: a Linux GUI launcher (the Tk one is Windows-only), report.py
  in the prefix, a Steam Input layout.

## Linux launcher window and Deck controls (issue 127, 2026-11-18; launcher.pyw IS_WIN, pvemode.desktop_entry)
- The launcher runs on Linux. There it doesn't switch the folder or run the stand-in: Steam's launch option
  (pvemode.py steam-run) does. Its PLAY writes config/linux_save.txt, switches config/linux_offline.txt back on, and
  opens steam://rungameid/1789480 (app id from steamapps/appmanifest_1789480.acf). watch() then sees the game through
  pvemode.game_running (/proc cmdlines), and finish() waits for backup/offline_applied to go (steam-run's tidy-up),
  calling pvemode.recover() after 60 s if it's still there.
- linux_launch_option() reads every Steam user's userdata/*/config/localconfig.vdf: if Marauders' block (until its
  first "}") has no marauders-offline.sh, PLAY says to paste the launch option instead of starting the stock game. No
  config found = can't tell, PLAY goes ahead.
- Startup on Linux never settles a save (steam-run may be starting a game right then). It only recovers when the dirty
  marker is older than START_TIMEOUT (90 s) and no game runs.
- Also Linux-only: a flock in /tmp for the single instance, xdg-open for folders and steam:// links, the .ico through
  PIL + iconphoto, and no "Borderless fullscreen" box (launch-offline.ps1 applies it; on Linux the game's own video
  settings do).
- install.sh (pvemode install) adds ~/.local/share/applications/marauders-offline.desktop when Tk and Pillow import,
  else says which packages are missing.
- Deck controls: README table (back grips F6 / F3 / N / M, D-pad down B, View + D-pad K / J, right trackpad as
  mouse), set up by hand in Steam's layout editor. No .vdf layout file shipped: can't make or check one without a Deck.
- Tested: test_pvemode.py in WSL Ubuntu (15 tests, 2 new: desktop entry, launch-option check). The real launcher
  window in WSLg: opens, says why PLAY can't start with the Windows game path. Full PLAY cycle against a fake game and
  fake Steam (the dirty marker and a process named like the game for 6 s): "Steam is starting the game" -> "Saving..."
  -> "Saved", save written, launch option switch back on. Windows: launcher/test_ui.py 12/12.
  NOT tested: a real Steam / Proton / Deck, the window on a real desktop (WSLg wouldn't give a screenshot), Game Mode.
