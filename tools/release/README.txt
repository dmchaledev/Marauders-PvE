MARAUDERS OFFLINE  -  PvE public test
=====================================

Single-player Marauders against AI: soldiers on the stations, rival crews in their own ships, and a crew of your own to
hire. Everything runs on your PC. Nothing talks to the live Marauders servers.

Marauders is being developed by a small team from the UK. Offline PvE is a fan mod and is not affiliated with the
original developer or publisher. You need your own copy of Marauders on Steam.

Heads up: this mod is vibe coded with Claude Code. Some of it may not be fully efficient or make complete sense. That's
where your contributions come in: see CONTRIBUTING.md on the mod's GitHub page, or come and talk about it on the
Discord: https://discord.gg/nfEW8tFJ3b


WHAT YOU NEED
-------------
  - Windows 10 or 11
  - Marauders installed through Steam, and Steam running when you play
  - Python 3.9 or newer  (Install.bat offers to install it for you with winget)


INSTALL
-------
  1. Unzip this folder somewhere permanent with a plain path, e.g.  C:\Games\MaraudersOffline
     (not Program Files, and no non-English letters in the path). Your saves live inside it.
  2. Double-click Install.bat. It finds Python and the game, installs Pillow for the launcher, and puts a
     "Marauders Offline" shortcut on your desktop and in the Start menu.

Install.bat doesn't touch the game folder. That only happens while you play (see "Is my online game safe?").


PLAYING
-------
  Start "Marauders Offline", make a save (NEW SAVE), pick it and press PLAY. When you close the game the launcher saves
  and tidies up. Keep the launcher open while you play.

  Saves:  as many as you like. Copy one before trying something risky, or use "Undo last raid" to go back to the
          moment your last raid started. In NEW SAVE, tick "Start with lots of gear and infinite money" for a test
          save with a full stash.

  CONTROLS (the game's own controls are unchanged; the mod adds these):
    F6        your crew: hire, dismiss, and choose who comes on raids (lobby and raids)
    F3        AI tuning: every enemy, rival and crew setting as a slider, including how many spawn (lobby and raids)
    F9        debug menu: god mode, extract now, spawn a soldier, and more (lobby and raids)
    N         minimap on or off (raids)
    M         minimap full overview, and back (raids)
    B         minimap: follow the next task (raids)
    K         move the item under the mouse between your stash and your pockets or bags (lobby: LOADOUT, TRADE)
    J         discard the item under the mouse, press twice (lobby: LOADOUT, TRADE)
    F2        play as a woman or a man (also a launcher setting)
    Left click  while flying with a crew gunner aboard: send them after the ship or space turret nearest the middle of
              your view. Click empty space to send them back to whoever is attacking you.
    F         on a turret seat: man the turret yourself. Left click fires, F stands you up.

  TOO BUSY OR TOO QUIET?
    Every raid's population can be tuned to your liking. Press F3 and open the "How many" tab: rival crews per raid,
    people in each crew, guards at each station, and how many ship battles break out around you. "Rival ships" sets how
    often crews attack and board, and "Difficulty" at the top picks a preset. Changes save themselves. Crew numbers take
    effect from your next raid, guard numbers from the next station you visit. Save setups you like under "Saved setups".


LINUX AND STEAM DECK  (experimental: not yet tested under Proton, please report how it goes)
--------------------
  Steam's PLAY button starts the mod through a launch option (Game Mode works too). The launcher window is optional
  on Linux: install.sh adds it to your app menu if your Python has Tk and Pillow (SteamOS doesn't).
  1. Unzip this folder somewhere permanent (internal storage is safest; no non-English letters in the path).
  2. In a terminal, in this folder:   sh linux/install.sh
     It finds the game in your Steam libraries and prints a line for
     Marauders > Properties > General > Launch options, like:
         "/home/deck/MaraudersOffline/linux/marauders-offline.sh" %command%
  3. Press PLAY in Steam. The game folder goes offline for that game and back to stock when it closes; if the game
     is killed or the Deck loses power, the next start puts it back first.
  Saves:  python3 scripts/pvemode.py saves | use <id> | new <name> [--cheat]
  Online again:  clear the launch option, or  python3 scripts/pvemode.py steam off   ("steam on" to switch back)


IS MY ONLINE GAME SAFE?
-----------------------
  PLAY switches the game folder to offline mode (it adds the mod loader, and points the game's backend at your own PC),
  starts the game directly without Easy Anti-Cheat, and puts every file back to stock when you close the game. The
  online game is untouched: launch Marauders from Steam as usual whenever the launcher isn't running a game.

  If your PC crashed mid-game, open the launcher once and close it again, or run Uninstall.bat: either puts the game
  back to stock. Don't start Marauders from Steam while the game folder is in offline mode.

  Hold off game updates: an update to Marauders is unlikely, but if one came it could break the mod. In Steam,
  right-click Marauders > Properties > Updates and choose "Only update this game when I launch it". The launcher starts
  the game without going through Steam, so playing offline won't trigger an update.


KNOWN ISSUES
------------
  - Rarely, dark flat slabs hang in space on the solo maps.
  - Dead boarders' legs can stretch into odd poses.
  - Space_Solo_02 now and then finds no stations, so that raid has no station tasks.
  - Soldiers on a station you haven't reached yet are asleep until you get close. This is on purpose, to save
    performance.


REPORTING BUGS
--------------
  After the game has closed, press REPORT in the launcher. It makes one zip on your Desktop with the logs, the crash
  report if the game crashed, and your build number, with your Windows user name, Steam ID and in-game name taken out.
  Post it on the Discord or in a GitHub issue (https://github.com/HaywireHayley/Marauders-PvE/issues/new/choose) and
  say what you were doing. A save that shows the problem (backend\saves\<name>) helps too.


TROUBLESHOOTING
---------------
  "The game didn't start"     Is Steam running? Is the game updated and installed where Install.bat found it?
                              Run Install.bat again to pick the game folder.
  The launcher won't open     Run Install.bat again; it checks Python and Pillow.
  Game updated and something  The mod patches the game in memory and checks every patch first; after a game update
  stopped working             some patches may be skipped. Check backend\last_game.log for "SKIPPED" and report it.


UNINSTALL
---------
  Run Uninstall.bat (puts the game back to stock, removes the shortcuts), then delete this folder.


CREDITS
-------
  Built with UE4SS (https://github.com/UE4SS-RE/RE-UE4SS, MIT licence).
