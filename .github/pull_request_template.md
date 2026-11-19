Fixes #

## What was wrong

<!-- The bug or the missing feature, as a player would see it. -->

## What changed

<!-- Which modules or files, and how. -->

## How it was tested

<!-- What you ran (luacheck, py_compile, launcher/test_ui.py) and what you did in game, on a throwaway save.
     Say plainly what was NOT tested in game. -->

## Checklist

- [ ] One issue per PR, branch named `fix/<issue>-<slug>` or `feat/<issue>-<slug>`
- [ ] Lua: `python scripts/luacheck.py <files>` passes, with 20 locals to spare at each file's top level
- [ ] Python: `python -m py_compile <files>` passes
- [ ] No game files, extracted assets, pak key, captures, logs, crash dumps or saves in the diff
- [ ] What I learned is in the research log ([NOTES.md](../NOTES.md) index, [docs/notes/](../docs/notes/))
