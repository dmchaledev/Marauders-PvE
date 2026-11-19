# Player damage reference

How a shot from you becomes damage on a bot in this mod, with every number that decides it: health, hit zone multipliers,
armour ratings for every vest and helmet, base damage per gun, and the shotgun volley. Written 2026-11-18 for issue #123
(`botdamage.lua`, `hitzones.lua`). The research log with the reasoning is the section "Your shots at bots" in
[docs/notes/combat.md](../notes/combat.md); this file is the lookup table.

Every number below says where it came from:

| Source | Meaning |
| --- | --- |
| Measured | Read in game on a test install: one dummy per item, shot with a known gun, health lost per hit. |
| Game value | Read from the running game (the F9 "Dump game values" button, a property, or a log line). |
| Logged hits | Taken from hits logged in play testing, with the gun's damage worked out from the health lost. |
| Patch notes | From the Guilds 1.0 patch notes, and confirmed against logged hits where the notes say so. |
| Guess | A stand in. Nothing in the game could be read for it. |

## 1. What happens to a shot

1. You fire. Offline the game is the authority, so the shot goes through the game's own character damage function with
   the player's own damage numbers. `hitzones.lua` gave every bot the player's hit capsules, so that function can tell
   where the bot was hit (the capsule's AreaHitType).
2. The function takes the armour rating of the piece covering that zone off the hit, flat, then multiplies by the zone
   multiplier. Armour is not a percentage.

   `damage taken = (base damage minus armour, never below 0) x zone multiplier`

3. A soldier's helmet and vest are only meshes: they are not armour items, so the game's function finds no armour and
   every hit did the full damage. `botdamage.lua` fixes that after the fact. A rifle or pistol hit that did exactly the
   gun's base damage times a zone multiplier gets the armour handed back as health (health up by the smaller of the rating
   and the base damage, times the multiplier). A hit that killed is not refunded, because the death has already run.
   Shotguns are different: offline their own pellets never reach the function, so `botdamage.lua` fires
   the pellets itself and takes the armour off each one.
4. Bodies built through the game's kit step (rival and crew bodies, and the test dummies) wear real armour items, and the
   game's own function already applies it. A hit that already had armour taken off is not exactly base damage times a
   multiplier, so the refund check skips it.
5. A third problem sat in front of the first two: the helmet, vest and backpack meshes blocked the weapon traces, so a
   bullet could stop on a helmet and never reach the zone behind it. Every mesh on a bot now ignores the channels the
   capsules block (3 and 9 to 15).

Worked example. A soldier in a Panzer chest (rating 11) is shot in the torso with an STG44 (base 34): `(34 minus 11) x 1`
is 23 damage. Shot in the head by a soldier helmet with rating 7: `(34 minus 7) x 3.5` is 94.5.

## 2. Health and hit zones

### Health

| Who | Health | Source |
| --- | --- | --- |
| You | 100 | Game value |
| Soldier (BotPawn) | 80 | Game value |
| Military (BotPawnMilitary) | 200 | Game value |
| Guard (BotPawnGuard) | 200 | Logged hits (a guard was not in the world during the value dump) |
| Rival and crew bodies | 100, crew plus 10 per level above 1 | Set by the mod ([combat.md](../notes/combat.md), [crew.md](../notes/crew.md)); the rival 100 was never seen in game |
| Test dummies | 100000, put back after every hit | Test setup only |

### Hit zones and multipliers

AreaHitType is read from the capsule the shot hits: 1 head, 2 body, 3 and 4 arms, 5 and 6 legs.

| Zone | AreaHitType | Multiplier on a bot | Armour that applies | Source |
| --- | --- | --- | --- | --- |
| Head | 1 | 3.5 soldiers, military and raiders; 4.0 guards; 3.25 you | Helmet | Game value; guard 4.0 from logged hits |
| Body | 2 | 1 | Vest | Measured |
| Arms | 3, 4 | 1 | Vest (the same rating as the body) | Measured |
| Legs | 5, 6 | 0.5 on soldiers and you; 0.25 measured on raider dummies | None | Game value; measured |

Things the table does not say:

- A head with no helmet took the head multiplier twice on every hit in the final dummy test: 416.5, which is 34 x 3.5 x 3.5.
  A helmeted head takes it once, and that is the only reading that gives whole number ratings. One earlier run showed
  119 (34 x 3.5) mixed in on bare head hits, never explained. It may be deliberate (so an unarmoured headshot is a one
  shot kill) or a bug we introduced; that is not settled.
- Raider dummies took 8.5 from a 34 damage leg hit, which is x0.25, while the game lists 0.5 for the soldier and player
  pawns. The dummies are GOAPNodeBot_Raider_C, not BotPawn_C, and the leg multiplier was not measured on soldiers.
  The shotgun code still uses 0.5.
- Armour does nothing on legs. Every one of the 54 vests and helmets left a leg hit at exactly the bare value, and the
  game's damage function (disassembled 2026-11-08) has no armour step for legs. The same is true of helmets on the body and
  arms, and vests on the head.

## 3. Armour ratings

All 24 vests and 30 helmets in the item table, measured 2026-11-18. A raider dummy wore one piece, stood 5 m away with
the view locked on the part under test, and was shot with the STG44 (base 34): 5 hits per zone, only hits whose
line trace met that zone counted. Every set of 5 hits was identical and every rating came out a whole number.

- Vest rating = 34 minus the torso damage taken. Arm damage came out the same as torso damage for every vest.
- Helmet rating = 34 minus the head damage divided by 3.5.
- The mesh column is what `botdamage.lua` looks the rating up by (the bot's helmet is the component "Helemt", its
  vest the component "ChestSlot"). It is the mesh name the game puts on a bot, not the item row, because that is all a
  soldier has. A mesh that is not listed is matched by the longest listed name inside it, else rated 0 and logged once.
- Some item rows share a look but not a rating, and some meshes carry a doubled name (Full_Plate_Skel_01 twice); the
  names below are exactly as the game reports them.

### Vests, best first

| Rating | Vests |
| --- | --- |
| 13 | BAHeavyVest, FullPanzerChest, FullPanzerRig |
| 12 | FullShermanPlate, FullShermanRig, HeavyPilotArmourChest |
| 11 | PanzerChest, PanzerRig, ShermanPlate, ShermanRig |
| 10 | CEFullPlate, FullPlateChest, PilotArmourChest |
| 9 | CEPlate, HalfPlateChest, PlateRig |
| 8 | BAFlakVest, MK3FlakVest, Mk3FlakRig |
| 7 | M1FlakChest, M1FlakRig, M2FlakChest |
| 6 | LeatherJerkinChest |
| 5 | PouchRig |

| Item row | Mesh the bot wears | Rating | STG44 torso hit | STG44 arm hit | STG44 leg hit |
| --- | --- | --- | --- | --- | --- |
| BAHeavyVest | BA_Flak_Vest_Heavy_Skel_01 | 13 | 21 | 21 | 8.5 |
| FullPanzerChest | Full_Panzer_Armour_Skel_01 | 13 | 21 | 21 | 8.5 |
| FullPanzerRig | Full_Panzer_Rig_Skel_01 | 13 | 21 | 21 | 8.5 |
| FullShermanPlate | Full_Sherman_Plate_Skel_01 | 12 | 22 | 22 | 8.5 |
| FullShermanRig | Full_Sherman_Rig_Skel_01 | 12 | 22 | 22 | 8.5 |
| HeavyPilotArmourChest | Heavy_Pilot_Armour_Skel_01 | 12 | 22 | 22 | 8.5 |
| PanzerChest | Panzer_Armour_Skel_01 | 11 | 23 | 23 | 8.5 |
| PanzerRig | Panzer_Rig_Skel_01 | 11 | 23 | 23 | 8.5 |
| ShermanPlate | Sherman_Plate_Skel_01 | 11 | 23 | 23 | 8.5 |
| ShermanRig | Sherman_Rig_Skel_01 | 11 | 23 | 23 | 8.5 |
| CEFullPlate | CE_Full_Plate_Rig_Skel_01 | 10 | 24 | 24 | 8.5 |
| FullPlateChest | Full_Plate_Skel_01_Full_Plate_Skel_01 | 10 | 24 | 24 | 8.5 |
| PilotArmourChest | Pilot_Armour_Skel_01 | 10 | 24 | 24 | 8.5 |
| CEPlate | CE_Plate_Skel_01 | 9 | 25 | 25 | 8.5 |
| HalfPlateChest | Half_Plate_Skel_01_Half_Plate_Skel_01 | 9 | 25 | 25 | 8.5 |
| PlateRig | Plate_Rig_Skel_01 | 9 | 25 | 25 | 8.5 |
| BAFlakVest | BA_Flak_Vest_Skel_01 | 8 | 26 | 26 | 8.5 |
| MK3FlakVest | M3_Flak_Vest_Skel_01 | 8 | 26 | 26 | 8.5 |
| Mk3FlakRig | M3_Flak_Rig_Skel_01 | 8 | 26 | 26 | 8.5 |
| M1FlakChest | M1_Flak_Vest_Skel_01_M1_Flak_Vest_Skel_01 | 7 | 27 | 27 | 8.5 |
| M1FlakRig | M1_Flak_Rig_Skel_01 | 7 | 27 | 27 | 8.5 |
| M2FlakChest | M2_Flak_Vest_Skel_01_M2_Flak_Vest_Skel_01 | 7 | 27 | 27 | 8.5 |
| LeatherJerkinChest | Leather_Jerkin_Skel_01_Leather_Jerkin_Skel_01 | 6 | 28 | 28 | 8.5 |
| PouchRig | Pouch_Rig_Skel_01 | 5 | 29 | 29 | 8.5 |

### Helmets, best first

| Rating | Helmets |
| --- | --- |
| 14 | WardenRiotHelmet |
| 13 | CustomPSHHelmet |
| 12 | BAHeavyHelmet, HeavyStahlhelmHelmet |
| 11 | HeavyPilotHelmet, HeavyRiotHelmet, PSHHelmet |
| 10 | M5Helmet, PilotHelmet |
| 9 | HeavyM1Helmet, RedStahlhelmHelmet, WeldersMask |
| 8 | BAHelmet, RiotHelmet |
| 7 | BrodieHelmet, GuildHelmet, M1Helmet, SecurityHelmet, StahlhelmHelmet |
| 6 | PirateHelmet, PirateHelmetBlue, SafetyHelmet |
| 5 | CivilianHelmet, LeatherCap |
| 4 | BABeret, BaronCap, CommandoCap, GuildBeret, SASBeret |
| 3 | ClothCap |

| Item row | Mesh the bot wears | Rating | STG44 head hit | STG44 arm hit | STG44 leg hit |
| --- | --- | --- | --- | --- | --- |
| WardenRiotHelmet | Warden_Riot_Helmet_Skel_01 | 14 | 70 | 34 | 8.5 |
| CustomPSHHelmet | Custom_PSH_Helmet_Skel_01 | 13 | 73.5 | 34 | 8.5 |
| BAHeavyHelmet | BA_Helmet_Heavy_Skel_01 | 12 | 77 | 34 | 8.5 |
| HeavyStahlhelmHelmet | Heavy_Stahlhelm_Skel_01 | 12 | 77 | 34 | 8.5 |
| HeavyPilotHelmet | Heavy_Pilot_Helmet_Skel_01 | 11 | 80.5 | 34 | 8.5 |
| HeavyRiotHelmet | Heavy_Riot_Helmet_Skel_01 | 11 | 80.5 | 34 | 8.5 |
| PSHHelmet | PSH_Helmet_Skel_01 | 11 | 80.5 | 34 | 8.5 |
| M5Helmet | M5_Helmet_Skel_01_M5_Helmet_Skel_01 | 10 | 84 | 34 | 8.5 |
| PilotHelmet | Pilot_Helmet_Skel_01 | 10 | 84 | 34 | 8.5 |
| HeavyM1Helmet | HeavyM1_Helmet_Skel_01 | 9 | 87.5 | 34 | 8.5 |
| RedStahlhelmHelmet | Red_Stahlhelm_Skel_01 | 9 | 87.5 | 34 | 8.5 |
| WeldersMask | Welder_Mask_Skel_01_Welder_Mask_Skel_01 | 9 | 87.5 | 34 | 8.5 |
| BAHelmet | BA_Helmet_Skel_01 | 8 | 91 | 34 | 8.5 |
| RiotHelmet | Riot_Helmet_Skel_01 | 8 | 91 | 34 | 8.5 |
| BrodieHelmet | Brodie_Helmet_Skel_01_Brodie_Helmet_Skel_01 | 7 | 94.5 | 34 | 8.5 |
| GuildHelmet | Guild_Helmet_Skel_01 | 7 | 94.5 | 34 | 8.5 |
| M1Helmet | M1_Helmet_Skel_01_M1_Helmet_Skel_01 | 7 | 94.5 | 34 | 8.5 |
| SecurityHelmet | Security_Helmet_Skel_01 | 7 | 94.5 | 34 | 8.5 |
| StahlhelmHelmet | Stahlhelm_Skel_01_Stahlhelm_Skel_01 | 7 | 94.5 | 34 | 8.5 |
| PirateHelmet | Pirate_Helmet_Skel_01 | 6 | 98 | 34 | 8.5 |
| PirateHelmetBlue | Pirate_Helmet_B_Skel_01 | 6 | 98 | 34 | 8.5 |
| SafetyHelmet | Safety_Helmet_Skel_01_Safety_Helmet_Skel_01 | 6 | 98 | 34 | 8.5 |
| CivilianHelmet | Civilian_Helmet_Skel_01_Civilian_Helmet_Skel_01 | 5 | 101.5 | 34 | 8.5 |
| LeatherCap | LeatherCap_Skel_01 | 5 | 101.5 | 34 | 8.5 |
| BABeret | SAS_Beret_Skel_02 | 4 | 105 | 34 | 8.5 |
| BaronCap | Baron_Cap_Skel_01 | 4 | 105 | 34 | 8.5 |
| CommandoCap | Commando_Cap_Skel_01 | 4 | 105 | 34 | 8.5 |
| GuildBeret | Guild_Beret_Skel_01 | 4 | 105 | 34 | 8.5 |
| SASBeret | SAS_Beret_Skel_01 | 4 | 105 | 34 | 8.5 |
| ClothCap | Cloth_Cap_Skel_01 | 3 | 108.5 | 34 | 8.5 |

## 4. Effective damage

Tables for a rifle bullet or any other single hit. Pick the base damage of the gun (section 5) and the rating of the
piece covering the zone (section 3).

### Body or arm: damage taken

| Rating | base 20 | base 25 | base 30 | base 35 | base 40 |
| --- | --- | --- | --- | --- | --- |
| 0 | 20 | 25 | 30 | 35 | 40 |
| 1 | 19 | 24 | 29 | 34 | 39 |
| 2 | 18 | 23 | 28 | 33 | 38 |
| 3 | 17 | 22 | 27 | 32 | 37 |
| 4 | 16 | 21 | 26 | 31 | 36 |
| 5 | 15 | 20 | 25 | 30 | 35 |
| 6 | 14 | 19 | 24 | 29 | 34 |
| 7 | 13 | 18 | 23 | 28 | 33 |
| 8 | 12 | 17 | 22 | 27 | 32 |
| 9 | 11 | 16 | 21 | 26 | 31 |
| 10 | 10 | 15 | 20 | 25 | 30 |
| 11 | 9 | 14 | 19 | 24 | 29 |
| 12 | 8 | 13 | 18 | 23 | 28 |
| 13 | 7 | 12 | 17 | 22 | 27 |
| 14 | 6 | 11 | 16 | 21 | 26 |

### Head on a soldier, military or raider (x3.5): damage taken

| Rating | base 20 | base 25 | base 30 | base 35 | base 40 |
| --- | --- | --- | --- | --- | --- |
| 0 | 70 | 87.5 | 105 | 122.5 | 140 |
| 1 | 66.5 | 84 | 101.5 | 119 | 136.5 |
| 2 | 63 | 80.5 | 98 | 115.5 | 133 |
| 3 | 59.5 | 77 | 94.5 | 112 | 129.5 |
| 4 | 56 | 73.5 | 91 | 108.5 | 126 |
| 5 | 52.5 | 70 | 87.5 | 105 | 122.5 |
| 6 | 49 | 66.5 | 84 | 101.5 | 119 |
| 7 | 45.5 | 63 | 80.5 | 98 | 115.5 |
| 8 | 42 | 59.5 | 77 | 94.5 | 112 |
| 9 | 38.5 | 56 | 73.5 | 91 | 108.5 |
| 10 | 35 | 52.5 | 70 | 87.5 | 105 |
| 11 | 31.5 | 49 | 66.5 | 84 | 101.5 |
| 12 | 28 | 45.5 | 63 | 80.5 | 98 |
| 13 | 24.5 | 42 | 59.5 | 77 | 94.5 |
| 14 | 21 | 38.5 | 56 | 73.5 | 91 |

A bare head (rating 0) takes the multiplier twice in the dummy test, so multiply the rating 0 row of the head table by
3.5 again for what the game actually does.

### Worked example: STG44 (base 34), hits to kill

| Rating | Torso or arm hit | Hits to kill a soldier (80) | Hits to kill a military or guard (200) | Head hit (x3.5) | Hits, soldier (80) | Hits, military (200) | Head hit on a guard (x4) | Hits, guard (200) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 34 | 3 | 6 | 119 | 1 | 2 | 136 | 2 |
| 1 | 33 | 3 | 7 | 115.5 | 1 | 2 | 132 | 2 |
| 2 | 32 | 3 | 7 | 112 | 1 | 2 | 128 | 2 |
| 3 | 31 | 3 | 7 | 108.5 | 1 | 2 | 124 | 2 |
| 4 | 30 | 3 | 7 | 105 | 1 | 2 | 120 | 2 |
| 5 | 29 | 3 | 7 | 101.5 | 1 | 2 | 116 | 2 |
| 6 | 28 | 3 | 8 | 98 | 1 | 3 | 112 | 2 |
| 7 | 27 | 3 | 8 | 94.5 | 1 | 3 | 108 | 2 |
| 8 | 26 | 4 | 8 | 91 | 1 | 3 | 104 | 2 |
| 9 | 25 | 4 | 8 | 87.5 | 1 | 3 | 100 | 2 |
| 10 | 24 | 4 | 9 | 84 | 1 | 3 | 96 | 3 |
| 11 | 23 | 4 | 9 | 80.5 | 1 | 3 | 92 | 3 |
| 12 | 22 | 4 | 10 | 77 | 2 | 3 | 88 | 3 |
| 13 | 21 | 4 | 10 | 73.5 | 2 | 3 | 84 | 3 |
| 14 | 20 | 4 | 10 | 70 | 2 | 3 | 80 | 3 |

Legs do 0.5 of base (0.25 on raider dummies) whatever is worn: a 34 damage rifle does 17 to a soldier's leg.

## 5. Base damage per gun

Base damage is the damage of one bullet before armour and zone. The game does not expose it: the F9 dump of 192 rows
holds fire rate, stamina, durability, ADS and ammo values for guns, but no damage, recoil, spread or pellet property.
So these come from logged hits (health lost per hit with the zone and armour worked out) and from the patch notes.

- `botdamage.lua` BASE_DAMAGE holds them by weapon class. A gun that is missing, or a wrong value, means no
  armour refund for that gun, never a wrong refund, because a refund needs the hit to be exactly base x a zone
  multiplier (tolerance 0.03).
- Pistols and some SMGs lose damage with range, so a far hit is below base and gets no refund. SPP1 measured 32 at 127
  to 616 cm and 22 at 1635 cm. The table gives the close range value. Other guns' falloff was not measured.
- Fire interval is the game's TimeBetweenShots from the value dump. Semi automatic guns fire no faster than you pull the
  trigger, so it is the limit and not the usual rate of fire.
- Only a hit within 0.5 s of your gun's clip dropping is refunded, so damage from a crewmate or another bot is not.

| Gun | Item row | Class | Base damage | Source | Fire interval (s) |
| --- | --- | --- | --- | --- | --- |
| AC14 | AC14Rifle | Rifle_AC14_Child_C | 35 | logged hits | 0.172 |
| AP_Mine | AP_Mine | AP_Mine01_Child_C | none | mine, not handled | 1.724 |
| APS | APSRifle | Rifle_APS_Rifle_Child_C | 34 | logged hits | 0.158 |
| BAR | BARRifle | Rifle_BAR_Child_C | 37 | logged hits | 0.141 |
| BlowTorch | BlowTorch | Base_BlowTorch_C | none | tool, not handled | 0.075 |
| Bren | BrenMk2Rifle | Rifle_Bren_MKII_Child_C | 36 | logged hits | 0.111 |
| Carl Gustav m/45 | M45CarlSMG | Rifle_M45_Child_C | 23 | logged hits | 0.12 |
| China Lake | ChinaLake | Launcher_ChinaLake_Child_C | none | launcher, not handled | 2.0 |
| Custom Mat 49 | CustomMat49 | Rifle_CustomMat49_Child_C | 24 | logged hits | 0.1 |
| Daewoo K1 | DaewooK1Rifle | Rifle_DaewooK1_Child_C | 32 | logged hits | 0.125 |
| De Lisle | DeLisleRifle | Rifle_DeLisle_Child_C | 38 | patch notes match | 2.0 |
| Double barrel | LongDoubleBarrel | Shotgun_LongDouble_Child_C | pellets | shotgun: 10 pellets of 18, see the shotgun section | 0.062 |
| DP 28 | DP28Rifle | Rifle_DP28_Child_C | 35 | patch notes match | 0.109 |
| EM 2 | EM2Rifle | Rifle_EM2_Child_C | 30 | logged hits | 0.12 |
| FAL | FALRifle | Rifle_FAL_Child_C | 37 | logged hits | 0.15 |
| FireExtinguisher | FireExtinguisher | Base_FireExtinguisher_C | none | tool, not handled | 0.12 |
| Flare gun | Flaregun01 | Flaregun01_Child_C | none | flare, not handled | 1.724 |
| Grease Gun | GreaseGun | Rifle_GreaseGun_Child_C | 25 | logged hits | 0.133 |
| Heavy Liberator | HeavyLiberatorShotgun | Shotgun_HeavyLiberator_Child_C | pellets | shotgun: 10 pellets of 18, see the shotgun section | 0.267 |
| Heavy MG42 | HeavyMG42Rifle | Rifle_HeavyMG42_Child_C | none | no value of its own, family guess 38 (a refund only fires on an exact match) | 0.12 |
| Heavy Thompson | HeavyThompsonSMG | Rifle_HeavyThompson_Child_C | none | no value of its own, family guess 26 (a refund only fires on an exact match) | 0.109 |
| HeavyShieldMelee | HeavyShieldMelee | Melee_HeavyShield_Child_C | none | melee, not handled | 1.0 |
| Jackhammer | Jackhammer | Shotgun_Jackhammer_Child_C | pellets | shotgun: 10 pellets of 18, see the shotgun section | 0.214 |
| Johnson | JohnsonRifle | Rifle_Johnson_Child_C | 40 | patch notes match | 0.172 |
| Klobb | KlobbSMG | Rifle_Klobb_Child_C | 19 | logged hits | 0.075 |
| Krasa | KrasaRifle | Rifle_Krasa_Child_C | 32 | logged hits | 0.092 |
| Liberator | LiberatorShotgun | Shotgun_Liberator_Child_C | pellets | shotgun: 10 pellets of 18, see the shotgun section | 0.267 |
| LPO flamethrower | LPOFlamethrower | LPO_Flamethrower_Child_C | none | flamethrower, not handled | 0.172 |
| Luger P08 | P08Pistol | Pistol_P08_Child_C | 23 | logged hits | 0.16 |
| M1 Carbine Para | M1ParaRifle | Rifle_M1_Para_Child_C | 28 | logged hits | 0.172 |
| M16 | M16Rifle | Rifle_M16_Child_C | 32 | logged hits | 0.1 |
| M1911 | 1911Pistol | Pistol_1911_Child_C | 28 | logged hits, a variant of its base gun | 0.172 |
| M1911 G | 1911GPistol | Pistol_1911_G_Child_C | 30 | logged hits | 0.172 |
| M712 | M712Pistol | Pistol_M712_Child_C | 28 | logged hits, a variant of its base gun | 0.1 |
| M712 Special | M712SpecialSMG | Rifle_M712_Special_Child_C | 24 | logged hits | 0.1 |
| MAC 10 | Mac10Rifle | Rifle_Mac10_Child_C | 24 | logged hits | 0.086 |
| MAS 44 | Mas44Rifle | Rifle_Mas44_Child_C | 39 | logged hits | 0.2 |
| Mat 49 | Mat49Rifle | Rifle_Mat49_Child_C | 22 | logged hits | 0.1 |
| MG42 | MG42Rifle | Rifle_MG42_Child_C | 38 | logged hits | 0.12 |
| Mini Thumper | MiniThumper | Launcher_Thumper_Child_C | none | launcher, not handled | 1.493 |
| MP40 | MP40Rifle | Rifle_MP40_Child_C | 25 | logged hits | 0.133 |
| Obrez | MosinObrezPistol | Pistol_Mosin_Child_C | 40 | patch notes match | 1.724 |
| PPSh | PPSHSmg | Rifle_PPSH_Child_C | 23 | logged hits | 0.086 |
| Reising | M50ReisingRifle | Rifle_M50reising_Child_C | 32 | logged hits, a variant of its base gun | 0.167 |
| Sawed off | SawedOffDouble | Shotgun_SawedOffDouble_Child_C | pellets | shotgun: 10 pellets of 18, see the shotgun section | 0.062 |
| SmallShieldMelee | SmallShieldMelee | Melee_SmallShield_Child_C | none | melee, not handled | 1.0 |
| SPP 1 | SPP1Pistol | Pistol_SPP1_Child_C | 32 | logged hits, a variant of its base gun | 0.3 |
| Sten | StenSMG | Rifle_Sten_Child_C | 21 | logged hits | 0.12 |
| Sterling | SterlingRifle | Rifle_SterlingMk4_Regular_Child_C | 22 | logged hits | 0.109 |
| Sterling (short) | SterlingRifle_Short | Rifle_SterlingMk4_Short_Child_C | 21 | logged hits, a variant of its base gun | 0.109 |
| Sterling Special | SterlingSpecial | Rifle_SterlingMk4_Suppressed_Child_C | 23 | logged hits, a variant of its base gun | 0.109 |
| STG44 | STG44Rifle | Rifle_STG44_Child_C | 34 | logged hits | 0.125 |
| Stoner | StonerRifle | Rifle_Stoner63A_Child_C | 28 | logged hits | 0.103 |
| SVT 40 | SVT40Rifle | Rifle_SVT40_Child_C | 37 | logged hits | 0.172 |
| SVU | SVURifle | Rifle_SVU_Special_Child_C | 40 | logged hits | 0.167 |
| Terminator | TerminatorShotgun | Shotgun_Terminator_Child_C | pellets | shotgun: 10 pellets of 18, see the shotgun section | 0.062 |
| Thompson | ThompsonSMG | Rifle_Thompson_Child_C | 26 | logged hits | 0.109 |
| Thompson Special | ThompsonSpecial | Rifle_Thompson_Special_Child_C | 28 | logged hits, a variant of its base gun | 0.109 |
| Trench gun | TrenchShotgun | Shotgun_TrenchGun_Child_C | pellets | shotgun: 10 pellets of 18, see the shotgun section | 0.429 |
| Uzi | UziSmg | Rifle_Uzi_Child_C | 20 | logged hits | 0.1 |
| Viper Mk1 | ViperMk1 | Rifle_ViperMK1_Child_C | 21 | logged hits | 0.115 |
| Webley | WebleyPistol | Pistol_Webley_Child_C | 38 | logged hits, a variant of its base gun | 0.188 |
| Welrod | WelrodPistol | Pistol_Welrod_Child_C | 36 | logged hits | 1.493 |

## 6. Shotguns

Offline a shotgun's own pellets never reach the damage function (a Liberator fired 8 shots with 0 hits before
`botdamage.lua`). Each shot, detected by the clip dropping (up to 2 volleys a frame), now fires pellets from the script.

| Value | Number | Source |
| --- | --- | --- |
| Pellets per shot | 10 | Patch notes |
| Damage per pellet before armour | 18 | Patch notes |
| Pellet damage | `(18 minus armour) x zone multiplier`, dealt with GameplayStatics.ApplyDamage | Measured that armour comes off per pellet |
| Armour that applies | Vest on the body and arms, helmet on the head, none on legs | Measured |
| Zone multipliers | Head 3.5, body and arms 1, legs 0.5 | As section 2 |
| A pellet that hits a mesh and not a capsule | 18 flat | Behaviour of the code |
| Line trace | Starts 150 cm out along the aim line and ends at 5000 cm, aimed inside a cone | Code choice |

Cone half angles in degrees (all guesses; the weapon's own spread properties were looked for and not found): Trench gun
2.0, Liberator 3.0, Sawed off 4.5, Jackhammer 3.0, Double barrel 1.5, Terminator 3.0, anything else 3.0. The Heavy
Liberator is not listed and uses 3.0.

The throw. A volley pushes the bots it hits: 900 cm/s, times 1.25 for the sawed off and 1.15 for the Terminator,
scaled by the share of the 10 pellets that hit, at full strength when the average hit distance is 200 cm or less and
falling to nothing at 1000 cm (a push of 20 or less is dropped). The direction is the pellets' average aim with an
upward lift. It is tried up to 14 times, 0.12 s apart. A dead or ragdolled bot gets the push on all its bodies below the
pelvis, once. A live one gets a nudge once (30 percent of the push sideways, 120 up). All of it is a guess standing in for
the knockback the game once applied; the value was not read from the game.

### Volley damage by armour rating

| Rating | Body or arm pellet | Head pellet (x3.5) | Full volley of 10 on the body | Full volley of 10 on the head |
| --- | --- | --- | --- | --- |
| 0 | 18 | 63 | 180 | 630 |
| 1 | 17 | 59.5 | 170 | 595 |
| 2 | 16 | 56 | 160 | 560 |
| 3 | 15 | 52.5 | 150 | 525 |
| 4 | 14 | 49 | 140 | 490 |
| 5 | 13 | 45.5 | 130 | 455 |
| 6 | 12 | 42 | 120 | 420 |
| 7 | 11 | 38.5 | 110 | 385 |
| 8 | 10 | 35 | 100 | 350 |
| 9 | 9 | 31.5 | 90 | 315 |
| 10 | 8 | 28 | 80 | 280 |
| 11 | 7 | 24.5 | 70 | 245 |
| 12 | 6 | 21 | 60 | 210 |
| 13 | 5 | 17.5 | 50 | 175 |
| 14 | 4 | 14 | 40 | 140 |

Dummy test, 2026-11-18. A Liberator fired at dummies 5 m away. The game's own part did 0.0 to them, so the pellets from
`botdamage.lua` are the only damage. On a bare torso a volley took 126 to 180 (7 to 10 of the 10 pellets landed, 18
each) and in a Pouch Rig (rating 5) 91 to 130 (7 to 10 pellets of 13). The damage the test itself summed per shot was
mixed up with its own health resets and is not used.

## 7. Where the numbers live in the code

| Number | Where |
| --- | --- |
| Vest and helmet ratings | `botdamage.lua` VESTS and HELMETS, by mesh, with the item row as a comment |
| Base damage | `botdamage.lua` BASE_DAMAGE, then BASE_FAMILY for variants (Thompson 26, Sterling 22, MG42 38, 1911 30, M712 24) |
| Refund multipliers | `refund()`: 4, 3.5 and 1, tolerance 0.03; legs (0.5) are not refunded |
| Refund window | REFUND_WINDOW, 0.5 s after the clip drops |
| Pellets and pellet damage | PELLETS and PELLET_DAMAGE (10 and 18) |
| Pellet zone multipliers | ZONE (AreaHitType to multiplier) |
| Cones and throw | CONE, PUSH, `pellets()` and `pushStep()` |
| Which mesh a bot wears | `armour()`: components "Helemt" and "ChestSlot", read once per bot |
| Hit capsules | `hitzones.lua` and `pve_hit_capsule` in `native/pvepatch.c` |
| Turning it all off | `CFG.PLAYER_DAMAGE = false` in `main.lua` |

## 8. How the numbers were measured (so it can be done again)

The test code (an F9 button, "Armour test") lived in a test install only and is not in the repo. The method:

1. A hidden raider (`GOAPNodeBot_Raider_C`) is spawned and dressed with ONE item through the game's kit step
   (`pve_roll_kit`). A bare dummy is the control. The dummy gets its hit capsules (`hitzones.ensure`), its meshes stop
   blocking the capsule channels, its ticks are switched off, and it cannot be damaged until it is in place.
2. It stands 5 m in front of the player. Its health is 100000 and is put back after every hit, so it never dies and the
   health lost per hit is the damage. The next dummy is built 3 m to the side while the current one is shot, then
   swapped in.
3. The view is locked on the part under test every frame (before and after the game's own frame, so recoil does not
   matter). A line trace from the camera reads the zone the shot meets, and only hits on the wanted zone count: 5 hits
   per zone, median recorded, identical in every case.
4. All other AI on the map are killed at the start and every 5 seconds.
5. Rating comes from the formulas in section 3. Meshes are read off the dressed dummy before shooting.

Lessons that cost time:

- Turn bottomless mags on first so neither gun runs dry mid test. Shotgun detection depends on the clip dropping, so
  anything that stops the clip dropping makes the shotgun look broken.
- Reading a health drop and restoring health in the same frame as the shotgun code makes the per shot sums unreliable.
  Read the damage lines the damage code logs instead.
- Do not count a hit whose line trace met another zone: arms sit next to the torso, so a bone near the body may need
  another bone (lower arm, calf) to get a clean arm or leg reading.

## 9. Not measured, and open questions

- Why a bare head takes the multiplier twice (section 2), and the stray 119 readings on bare heads.
- The leg multiplier on soldiers (0.5 in the game values, 0.25 on raider dummies) and on you.
- The guard head multiplier (4.0) is from logged hits, not from the value dump.
- The real pellet count, pellet damage and spread of each shotgun. 10 x 18 is from the patch notes for all of them.
 
- Range falloff of pistols and SMGs other than the SPP1.
- Base damage of the Heavy MG42 and Heavy Thompson (they use their base gun's number), and every launcher, flare,
  mine, grenade, melee weapon and tool, which this code leaves out on purpose.
- Explosions, fire and melee against armour were not tested.
- This code has not run in game on build 8 yet; the measurements were taken on a test install of an earlier build.
