# Developing the mod

This page is for working on the mod itself. To just play, follow the
[quick start in the README](../README.md#quick-start).

New here? Read [CONTRIBUTING.md](../CONTRIBUTING.md) for how to send changes, and the research log for how everything
works: [NOTES.md](../NOTES.md) lists every finding by topic, and the topics are files under [notes/](notes/) (newest
findings at the end of each). Reference chains and number tables are under [internals/](README.md#internals): every
damage and armour number (health, hit zones, vest and helmet ratings, base damage per gun, shotguns) is in
[DAMAGE_REFERENCE.md](internals/DAMAGE_REFERENCE.md). AI agents: [AGENTS.md](../AGENTS.md) has the rules and checks.

## Contents

- [How it works, in one paragraph](#how-it-works-in-one-paragraph)
- [Folder map](#folder-map)
- [Setting it up on your PC](#setting-it-up-on-your-pc)
- [Not in this repository (on purpose)](#not-in-this-repository-on-purpose)

## How it works, in one paragraph

[UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) loads our Lua mods into the game. `scripts/mode.ps1 offline` copies
UE4SS and our mods into the game folder and points the game's backend at this PC. `backend/nakama_standin.py` is a
small local server that answers what the real backend used to (account, stash, loadouts). `native/pvenet.dll` and
`native/pvepatch.dll` are small helpers the mods load. `mode.ps1 online` puts every game file back to stock.

## Folder map

| Folder | What's in it |
|---|---|
| `mods/PvEDirector/Scripts` | The mod itself: AI (`ai.lua`, `rivals.lua`), crew, missions, minimap, loading screens... `main.lua` is the entry point |
| `mods/PvEBridge` | Dev bridge: lets scripts outside the game send commands into it (`scripts/send.sh`) |
| `backend/` | The local stand-in server. `seed.json` is the anonymous starting account |
| `launcher/` | The launcher window (saves, settings, Play) |
| `native/` | C helpers. Only `pvenet.dll` and `pvepatch.dll` are needed to play; the rest are research tools |
| `scripts/` | Switch online/offline, launch, bridge helpers. `pvepaths.py` tells Python tools where things are |
| `assets/` | Our art: loading screens, minimap images, menu logo |
| `config/` | Mod settings. `game_path.txt` (yours, not shared) says where the game is installed |
| `tools/` | Research and build tools: `release/build_release.py` makes the player zip |
| `cover/` | Cover points per map, for the AI |

Most folders have a short README of their own. [`backend/README.md`](../backend/README.md) has diagrams of how the game's online services are
replaced offline, and why that takes so much guessing.

## Setting it up on your PC

1. **Have Marauders installed through Steam**, and **Python 3.9 or newer** from python.org (tick "Add Python to PATH").
2. **Get this repository** with GitHub Desktop (File → Clone repository). Put it in a plain folder like
   `C:\Mods\MaraudersPvE`.
3. **Run the setup script** in a terminal, from the repository folder:

   ```bash
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\setup-dev.ps1
   ```

   It installs the Python packages (`requirements.txt`), finds the game in your Steam libraries and writes
   `config\game_path.txt`, and downloads UE4SS v3.0.1 into `tools\ue4ss\` (checked against a known SHA-256). It doesn't
   touch the game folder, and it's safe to run again. Add `-Research` to also install what the research tools under
   `tools/` and `scripts/luacheck.py` need (`requirements-research.txt`).

   <details><summary>Doing it by hand instead</summary>

   - `pip install -r requirements.txt` (and `-r requirements-research.txt` for the research tools).
   - Create `config\game_path.txt` with one line, the folder that holds `RaidGame\`, e.g.
     `C:\Program Files (x86)\Steam\steamapps\common\PHtest` (in Steam: right-click Marauders → Manage → Browse local
     files shows it).
   - Unzip `UE4SS_v3.0.1.zip` from the [RE-UE4SS releases page](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v3.0.1)
     into `tools\ue4ss\`, so that `tools\ue4ss\dwmapi.dll`, `tools\ue4ss\UE4SS.dll` and `tools\ue4ss\Mods\` exist.

   </details>
4. **Play:** run `python launcher\launcher.pyw`, make a save and press PLAY. Closing the game puts the game folder
   back to stock.

If anything goes wrong, this always puts the game back to its normal, online-safe state:

```bash
powershell -NoProfile -File scripts\mode.ps1 online
```

## Not in this repository (on purpose)

The game's own files and anything extracted from them, the pak decryption key, captured traffic from real accounts,
personal saves and settings, and trailer tooling and recordings. `.gitignore` keeps them out. Please never add them.

Optional extras you can make yourself from your own copy of the game: the female outfits
(`tools/female/make_female.py`, which needs the pak key: `scripts/find_aes.py` finds it in your own install).
