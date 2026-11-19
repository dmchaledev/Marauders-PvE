# Contributing

Thanks for helping! This guide assumes you've never used Git before.

## The idea in 30 seconds

- The project lives on GitHub. Everyone has their own copy on their PC.
- You never change the main version directly. You make your changes on a **branch** (your own side copy), then open a
  **pull request**: "here's what I changed, please take a look".
- The maintainer reviews it, maybe asks questions, and **merges** it into the main version.

## Doing it with GitHub Desktop

1. **Once:** install [GitHub Desktop](https://desktop.github.com), sign in, accept the invite to this repository
   (it arrives by email), then File → Clone repository → pick it. Follow the setup in
   [docs/DEVELOPING.md](docs/DEVELOPING.md#setting-it-up-on-your-pc).
2. **Before you start something:** click **Fetch origin** / **Pull origin** to get the latest version.
3. **Make a branch:** Current branch → New branch, and name it after what you're doing, e.g. `crew-medic-fix`.
4. **Make your changes** in any editor, and test them in game (see below).
5. **Commit:** GitHub Desktop lists every file you changed. Check that the list only contains what you meant to
   change, write a short summary ("Crew medics heal downed players") and click **Commit**.
6. **Push and open a pull request:** click **Publish branch**, then **Create Pull Request**. In the description say
   what you changed, why, and how you tested it.
7. If changes are requested, just make them on the same branch, commit and push again: the pull request updates itself.

Small pull requests (one fix or feature each) get reviewed much faster than big ones.

## Ground rules

- **Offline only.** Nothing in this project may ever be used in, or affect, live Marauders matches or the live servers.
- **No game files, no keys, no captures.** Never commit files from the game, things extracted from it, the pak key,
  or logs/captures from a real account. `.gitignore` blocks the usual ones; if GitHub Desktop shows such a file, untick
  it and tell the maintainer.
- **Leave the game folder stock** when you're done: closing the launcher's game does this; otherwise run
  `powershell -NoProfile -File scripts\mode.ps1 online`.
- **Write down what you learn** in the research log. [NOTES.md](NOTES.md) lists the topic files under
  [`docs/notes/`](docs/notes/) (AI, rivals, crew, space, launcher...): add a dated section at the end of the one it
  belongs to, and its title to the NOTES.md index. It's how the next person (or AI agent) understands why the code is
  the way it is. A finding big enough for its own diagram or table (a whole chain of calls, a data table) goes in a file
  under [`docs/internals/`](docs/README.md), linked from that section.

## Testing tips

- Test on a throwaway save: in the launcher's NEW SAVE dialog, tick "Start with lots of gear and infinite money (for
  testing)" for one with a full stash.
- In game: **F9** debug menu (god mode, extract now, spawn a soldier), **F3** AI tuning sliders.
- Logs after a session: `backend\last_game.log` (the mod) and `backend\server.log` (the backend).
- Lua changes: `pip install lupa` once (or run `scripts\setup-dev.ps1 -Research`), then `python scripts\luacheck.py mods\PvEDirector\Scripts\main.lua` (any
  files you changed) catches syntax errors before you launch the game.
- `scripts/send.sh "status"` talks to the running game through PvEBridge (from Git Bash).

## Native DLLs

`native/pvenet.dll` and `native/pvepatch.dll` are committed so you don't need a compiler. If you change their `.c`
source, rebuild with MinGW-w64 GCC (`winget install BrechtSanders.WinLibs.POSIX.UCRT`) and commit the new DLL together
with the source. `native/build.sh` shows the flags; pass `-DPVE_ROOT="\"<project folder>/\""` for the research DLLs
that write logs.

## Releases

Player zips are built by the maintainer with `python tools/release/build_release.py`. It needs a private capture of a
real account, which isn't shared, so contributors don't build releases.
