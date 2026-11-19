# Bot AI design

How the bots think, and how each part maps onto our UE4SS Lua director
(PvEDirector main.lua soldier AI + rivals.lua), with one shared brain and difficulty profiles so the same system
drives both the player-like rivals and the (much weaker) NPC bots.

## 1. The reference design

**Decision loop, 10 times a second, first match wins** (BotDecisionManager.getDecision):

1. Avoid grenade
2. No enemy -> nothing (patrol)
3. **Self actions**: reload (ammo ratio below thresholds that depend on the situation), heal or surgery. These are
   done *in cover*, so the combat decision becomes SeekCover.
4. Dogfight (enemy at point blank)
5. Keep moving to the cover it already chose
6. **Squad decisions**: push a suppressed enemy, group search, suppress for a retreating squadmate, help a squadmate
   whose enemy is visible and within 30 m (stop at 45 m)
7. **Enemy decisions** (EnemyDecisionClass):
   - Retreat: no bullets, or reloading
   - Stand and shoot: enemy visible, shootable and within 1.25x the weapon's effective range, held for a
     per-personality "hold ground" time (longer if the enemy is looking at me)
   - Shoot a distant enemy in short bursts
   - *Only if not heavily suppressed:*
     - Rush: path under 10 m (20 m with sprint) and the enemy is reloading, healing or badly hurt. Only some
       personalities rush.
     - Throw grenade
     - Move to engage: enemy unreachable or a sniper, so find a firing position
     - Search: after a personality-dependent wait
   - Freeze: indoors, heard the enemy while at peace, enemy not seen for 4 min. Waits 10-120 s divided by
     aggression (the "rat" ambush).
   - Shift cover (enemy not seen for a while)
   - Otherwise seek cover

**Senses**
- Vision has a **gain-sight time**: spotting you takes time. It's faster at short range and slower in peripheral
  vision (beyond 30°, up to 2x slower). Crouched (1.25x) or prone (1.75x) targets are slower to spot; moving
  targets are 2x faster. The target being above or below (up to 2.5x / 0.75x), how much of the body shows
  (0.9-2x) and being suppressed also change it. If the bot isn't looking your way, it gets an accuracy penalty
  for up to 4 s.
- Hearing: gunshots and footsteps, with **dispersion**. The bot hears *roughly* where you are, the error growing
  linearly with distance. Bullet impacts nearby are heard too. "Heard while at peace" triggers a personality
  reaction: freeze, charge or search.

**Suppression**: bullets passing close add points, giving Light, Medium, Heavy or Extreme. Each state scales
accuracy, aim speed, spotting speed, sight distance and hearing (Light: accuracy x1.2 slower, scatter x1.35, sight
x0.85). Heavy or Extreme blocks aggressive actions.

**Search**: move toward the last known position in stages (advance, wait/peek, direct move). It slows at corners,
sometimes sprints, and has a 40% chance to check loot on the way.

**Squads**: shared enemies (out to about 35 m without a radio, unlimited with an earpiece). Covering fire for a
retreating member, a buddy pushes the target being suppressed, group search.

**Personalities** (8): Wreckless, GigaChad, Chad, Normal, Rat, Timmy, SnappingTurtle, Coward. Each sets:
- aggression multiplier and hold-ground time
- whether it rushes reloading or healing enemies, jumps corners, bunny-hops
- search willingness, delay and sprint chance; whether it sneaks
- heard-from-peace behaviour (freeze or charge)
- cover shifting, suppression resistance
- taunts, begging, faking death

Assignment is weighted by a gear "power level" (better-geared bots lean Chad/GigaChad).

**Difficulty multipliers** (DifficultySettings), which are exactly the knob for "same AI, weaker NPCs":
VisibleDist, GainSight (spotting speed), Scattering (spread), HearingDistance, Aggression, Precision speed and
Accuracy speed (how fast aim settles).

**Aim**: since 4.5 it weights which body parts to aim at instead of always centre mass. Aim settles over time after
acquiring a target.

## 2. What we have today (Lua)

- Soldier AI (main.lua): instant notice (LoS within 6000 / 70° or 900 hearing), then the game's BotBehavior tree
  shoots `MyEnemy`. We add cover finding (LoS probes), a peek/hide cycle with firing points, side-step strafing,
  advancing to the last seen spot, sprinting to cover, and posture/animation fixes. Single target: the player.
- Rivals (rivals.lua): crews with ships, kit tiers, docking/raiding, pod boarding, sharper senses (8000 / 80° /
  1600), boarders who know your position.
- Missing: gradual spotting, hearing gunfire, suppression, personalities, squad play, retreat/reload/heal
  behaviour, rushing vulnerable targets, searching, and fights between bots (rivals vs NPCs vs each other).

## 3. Plan: one brain (`ai.lua`), profiles per bot

A new module `mods/PvEDirector/Scripts/ai.lua` that both the director's soldiers and rivals use. Each bot entry gets
`profile` (difficulty) and `personality`. The existing cover, peek and strafe code becomes the brain's *actions*;
the brain picks which runs.

### 3a. Knowledge: per-bot "known enemies"
For each enemy (player, other crews, NPCs by team): last seen (position, time), last heard (dispersed position,
time), visible now, sight progress (0..1), heard-from-peace, vulnerable now (reloading/healing), health status.
Squadmates (same crew) share entries within radio range: all rivals have radios, NPC squads 35 m.

### 3b. Senses
- **Gain sight**: replace instant `notices()` with progress per check. Time to spot = base x distance curve x
  angle (peripheral) x posture x movement x suppression x difficulty, with notice only once progress reaches 1.
  LoS checks are round-robin with a per-frame budget.
- **Hearing gunshots**: hook the player's shots (pvepatch makes player fire call `ServerTraceFireProjectile`, which
  is hookable) and bots' shots (`ServerMultiSimulateWeaponFire`, already hooked). Range per weapon class; heard
  position = true position + error growing linearly with distance x the difficulty hearing coefficient.
- **Footsteps**: player speed (sprint/walk/crouch) gives a hearing radius.
- **Near misses → suppression**: for each player shot, distance from each bot to the shot line. Under about 3 m
  adds points; points decay over time; the state comes from thresholds.

### 3c. Decisions (5 Hz engaged, 1 Hz idle), in this order
1. Self: reload in cover when the magazine is low (bot ammo is infinite today; add a magazine count so they
   reload). Heal when hurt and not seen for a few seconds: retreat to cover and restore health over ~5 s with the
   game's healing animation (`MultiCast_HealingAnim`).
2. Squad: crews of 2-4 split roles. One suppresses (shoots at last known position), others flank or push. They
   help a member in a fight and regroup.
3. Enemy: Retreat (reloading / out of ammo / badly hurt), StandAndShoot (visible, in range, hold-ground time),
   Rush (you're reloading/healing/low and close: personality-gated), MoveToEngage (no line of fire), Search (last
   known position, staged, slow at corners), Freeze/ambush (Rat/Timmy indoors after hearing you), ShiftCover,
   SeekCover.

### 3d. Aim and fairness
- **Reaction time**: hold fire for a profile-dependent delay after gaining sight, plus an accuracy ramp (aim
  settles). Done by gating the tree's `Enemy`/`MyEnemy`, as the cover code already does.
- **Spread**: find what the bot fields `AIMissRate`, `GOAPAIMissRate`, `AiMissRange`, `AiMissRangeForAimedoff`
  and `AIDifficulty` do to `ShootEnemy` (measure hit rates). These become the profile's scatter knob.
- Suppression and "not looking at you" worsen both.

### 3e. Personalities and profiles
- Personalities: 8 archetypes, as Lua tables of the same parameters. Rivals are assigned by kit tier
  (geared → more Chad/GigaChad; budget → more Rat/Timmy/Coward).
- Profiles (difficulty multipliers), split by bot type: PMCs 1.0 on "Default", Scavs 0.3 on "Less
  Difficult", guards 0.55, bosses 0.75.

  | profile | type mod | spot speed | sight dist | visible angle | hearing | scatter | aim settle | aggression |
  |---|---|---|---|---|---|---|---|---|
  | rival (player-like, ≈ PMC) | 1.0 | 1.0 | 1.0 (150 m) | 160° | 1.0 | 0.75 | 0.8 | per personality |
  | NPC soldier / guard (≈ Scav) | 0.3 | 0.75 | 0.75 | 150° | 0.66 | 1.0 | 1.0 | 0.6 |
  | NPC boss / captain | 0.75 | 1.0 | 1.0 | 160° | 1.0 | 0.75 | 0.8 | 1.0 |

### 3f. Bots fighting bots
Hostility by team: player 1, rival crews each their own team, NPCs one team. Needed so rivals clear stations,
fight each other and NPCs. The brain picks the best target among known enemies (threat = visible, distance, who
is shooting at me).

### 3g. NPCs on the same system
- Raid soldiers (BotPawn*): move from the current special-case code onto `ai.lua` with the NPC profile.
- Station NPCs (sleeping GOAPNodeBot_Raider/Boss in stations and AI frigates): wake them with the full wake when
  you (or a materialized rival crew) enter the station, give them RaidAIController + tree as for rivals, NPC
  profile, and put them back to sleep when everyone leaves. Their own GOAP brain doesn't run offline.

## 4. Things to check in game before building on them
1. Can bots damage other bots? An earlier test on a *sleeping* NPC did nothing; try awake, possessed targets on
   another team. Required for 3f.
2. What the miss fields do (3d).
3. Can we detect the player reloading or healing? Candidates: weapon state +0x6DC, `IsHealing()`, the `bHealing`
   flag.
4. Which function the player's shot passes through for hearing and suppression (hook `ServerTraceFireProjectile`).
5. Bot reloading: does `ReloadAIWeapon()` play the reload animation if we track a magazine?
6. Suppressive fire: can a RaidAIController shoot at a *location* (GOAP controllers have `ShootAtLocation`;
   alternatively a hidden dummy target)?

## 5. Order of work (1 and 2 done 2026-10-31, see [docs/notes/ai.md](docs/notes/ai.md), "Shared AI brain")
1. Engine checks above (one session, short tests).
2. `ai.lua` skeleton: knowledge model, gain-sight vision, profiles; move rivals and soldiers onto it (same
   behaviour as today, but gradual spotting and difficulty).
3. Hearing + suppression.
4. Decision chain: retreat/reload/heal, rush, search, freeze, shift cover; personalities.
5. Squad roles for crews (suppress + flank, help, regroup, group search).
6. Bot-vs-bot targeting; wake station NPCs on the NPC profile.
7. Tuning passes with you playing: time-to-kill, how often you're flanked, whether NPCs feel weaker but not stupid.
