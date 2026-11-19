# Troubleshooting

Common problems and what to do about them. If yours isn't here, press **REPORT** in the launcher and ask on the
[Discord](https://discord.gg/nfEW8tFJ3b) or in a [GitHub issue](https://github.com/HaywireHayley/Marauders-PvE/issues/new/choose).

- [The game didn't start](#the-game-didnt-start)
- [The launcher won't open](#the-launcher-wont-open)
- [Getting back to the online game](#getting-back-to-the-online-game)
- [The PC crashed or the game was killed mid-game](#the-pc-crashed-or-the-game-was-killed-mid-game)
- [Marauders updated and something stopped working](#marauders-updated-and-something-stopped-working)
- [I lost gear or want to go back](#i-lost-gear-or-want-to-go-back)
- [Too hard, too busy, too quiet](#too-hard-too-busy-too-quiet)
- [Linux and Steam Deck](#linux-and-steam-deck)
- [Reporting a bug](#reporting-a-bug)

## The game didn't start

- **Is Steam running?** Start Steam before pressing PLAY.
- **Did the game move?** If Marauders was moved or reinstalled, run `Install.bat` again: it finds the game again.
- **Where is the mod's folder?** It needs a plain path, such as `C:\Games\MaraudersOffline`: not inside Program Files,
  and no non-English letters anywhere in the path. Move the whole folder (your saves are inside it) and run
  `Install.bat` again.

## The launcher won't open

Run `Install.bat` again. It checks for Python 3.9 or newer (and offers to install it) and installs Pillow, which the
launcher needs.

## Getting back to the online game

Close the offline game, then launch Marauders from Steam as usual. The launcher puts every game file back to stock when
the game closes, so **keep the launcher open while you play**.

Don't start Marauders from Steam while the launcher is running an offline game.

## The PC crashed or the game was killed mid-game

The game folder may still be in offline mode. Before playing online, do one of these:

- open the launcher once and close it again, or
- run `Uninstall.bat` (it also removes the shortcuts; run `Install.bat` to get them back).

Either one puts the game folder back to stock. On Linux, the next PLAY does this for you before anything else.

## Marauders updated and something stopped working

The mod patches the game in memory and checks each patch before applying it. After a game update some patches may be
skipped instead of breaking the game. Open `backend\last_game.log` and search it for `SKIPPED`, then report it with
the REPORT zip.

To stop this happening, hold updates off: in Steam, right-click Marauders → **Properties → Updates** → **Only update
this game when I launch it**. The launcher starts the game without going through Steam, so playing offline won't
trigger an update.

## I lost gear or want to go back

- **Undo last raid** in the launcher puts the selected save back to the moment its last raid started: your ship and
  gear come back.
- **Copy** a save before trying something risky, and **Back up** to keep your saves in a zip (bring them back with
  **IMPORT**).
- Your saves live inside the mod's folder, so don't delete that folder to "reinstall". The launcher's orange **!**
  updates the mod and keeps your saves. If you set up a new copy instead, **IMPORT** brings saves in from the old one.

## Too hard, too busy, too quiet

Press **F3** in the lobby or in a raid. The **How many** tab sets rival crews per raid, people in each crew, guards at
each station, civilians, and ship battles; **Difficulty** at the top picks a preset. See
[the README](../README.md#too-hard-too-busy-or-too-quiet).

## Linux and Steam Deck

Linux support is experimental and not yet tested under real Proton. Please say how it went in
[#127](https://github.com/HaywireHayley/Marauders-PvE/issues/127).

- **No launcher window in my app menu:** the window needs Tk and Pillow in your Python (`python3-tk` and
  `python3-pil.imagetk` on Debian/Ubuntu; SteamOS doesn't have them). You don't need it: Steam's PLAY works without
  it, and `python3 scripts/pvemode.py saves` manages saves from a terminal.
- **Back to the online game:** clear the launch option in Steam, or run `python3 scripts/pvemode.py steam off`
  (`steam on` switches back).
- **Mod keys on a Deck:** they are keyboard keys; the [README](../README.md#linux--steam-deck-experimental) has a
  suggested Steam Input layout.

## Reporting a bug

1. Close the game.
2. In the launcher, press **REPORT**, then **MAKE REPORT**. It saves one zip to your Desktop with the logs from your
   last game, the crash report if the game crashed, and your build number. Your Windows user name, Steam ID and
   in-game name are taken out first.
3. [Open a bug report](https://github.com/HaywireHayley/Marauders-PvE/issues/new/choose) or post on the Discord with
   that zip and a line on what you were doing.

No launcher window (Linux)? Attach `backend/last_game.log` and `backend/server.log` from the mod's folder instead.
Those two aren't scrubbed like the REPORT zip, so look through them first if you're worried about your account ID.
