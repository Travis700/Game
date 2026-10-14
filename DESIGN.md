# Night Shift — Design Document

*Status: version 1.0.0, feature complete in greybox. Left: the art and audio pass (textures, models, sounds), then the Steamworks steps in STEAM.md and the store page. Numbers marked (tunable) are starting points to adjust during playtesting.*

## 1. Overview

A first-person co-op light-horror game for 1–4 players. The players are night security guards at an American high school. Each night they clock in, watch the cameras, patrol the building, log anomalies on their clipboards, and try to survive until 6am. The early nights are mostly ordinary. From night 7 the horror ramps up sharply.

- **Engine:** Godot 4 (latest stable)
- **Platform:** PC, released on Steam at about $5
- **Players:** 1–4 online co-op. A solo player can finish the whole game.
- **Run length:** 9 nights

## 2. Core loop

1. **Before the shift.** Players spawn at the school's front gate, walk into the building and go to the guard room. They can buy items from the vending machine. The school is brightly lit (street lights, floodlights on the building, every light on inside) so arriving feels ordinary and safe.
2. **Clock in.** Each player enters their employee number on the clock machine in the guard room. The night starts once the players have clocked in: the floodlights cut out one by one, some ceiling lights click off, the rest dim, the fog closes in and the faulty lights start to flicker.
3. **During the shift (midnight to 6am).** Players watch the cameras from the desks, go out on the night's round (punch stations around the school), reset the breaker when the power goes, handle monsters and hazards, and log anomalies on their own clipboards. The split between "watch the screens" and "go out there" is the core co-op tension: the guard at the desk guides the ones in the dark.
4. **Clock out at 6am.** A player only gets paid if they make it back to the clock machine and clock out.
5. **End of night.** Scores are tallied, and players spend points on items before the next night.

**Night length:** about 12 minutes of real time, so roughly 80 seconds per in-game hour (tunable).

## 3. Lobby and sessions

- **Joining (now).** The host's address is shown as a short **room code** (top right), and the host can set a **room password**. Joiners type the code (or an address) and the password. Codes work on a LAN, or over the internet with port 7777 forwarded.
- **Joining (Steam, later).** Steam lobbies and invites, using the same code and password screen, with Steam's relay so nobody needs to forward ports.
- **Employee badge.** Each computer gets a badge number the first time it plays. Guards type it into the time clock to clock in, and saved points are linked to it.
- **Difficulty.** Auto picks one level per guard (capped at 3). The host can pick 1–3 instead; each option has an explanation on the menu.
- **Keep gear on restart.** When on, upgrades and carried items survive a team wipe and points reset. When off, everything resets.
- **Saving.** The host's computer saves after every night report (next night, difficulty, upgrades, doors, and each badge's points, item and flashlight). The menu offers to continue it.

- **Voice chat.** Proximity voice (push to talk on V, or open mic). The dead hear the living; only ghosts hear ghosts. Monsters hear voices too: louder carries further (Lunch Lady, Librarian, Hall Monitor react), so keeping quiet is sometimes the way to survive.

## 4. The school and difficulty

The map is one high school. Each difficulty opens another wing, through red doors at the ends of the main hallway. There are three levels (a fourth, outdoor level was dropped: three is plenty of school).

| Difficulty | Areas | Cameras |
|---|---|---|
| D1 | Front gate, lobby, front office, guard room, main hallway, cafeteria and kitchen, gym | 8 |
| D2 | + classroom wing: West Hall, Rooms 101–103, library, nurse's office | 13 |
| D3 | + science wing: East Hall, science lab, art room, locker rooms | 17 |

Closed wings stay behind locked doors; their cameras, clipboard areas, anomalies and monsters are left out.

## 5. The guard room

- **4 desks, each with 4 monitors.** Any player can sit at any desk. Each monitor cycles through camera views.
- **Empty desks still work.** A solo player can move between desks to reach more cameras. Moving takes a few seconds.
- **Clock machine.** Used to clock in and clock out.
- **Vending machine.** Players buy items here, and purchases drop into the tray.
- **Shared doors.** From night 7, monsters can enter the guard room, so its doors and defenses matter (see section 10).

## 6. Cameras and anomalies

- Camera views are live views of the school.
- **Anomalies** are changes that shouldn't be there: a moved object, an open door, a figure, lights off. Each monster also produces its own warning signs (section 9).
- Some changes are normal. For example, the real night cleaner moves things. Players learn what's ordinary.
- **Monitor upgrades** are bought from the vending machine and installed by hand at each desk (about 10 seconds per desk; a monster can interrupt). Upgraded monitors can see the Ghost.

## 7. Clipboards and scoring

Each player has their **own clipboard and their own points.**

- **Logging.** Choose the area or camera and the type of anomaly. The time is recorded automatically. The result (✓ or ✗) is shown straight away, so players learn what counts.
- **Naming monsters.** A monster logged correctly goes into that player's **field guide** (kept across runs): its signs and how to survive it; undiscovered monsters show a rumour. Once it's in the guide, a Monster log can name it for +25 more.
- **Rounds.** Each night has a work order of punch stations (3 on night 1, up to 7) in open areas. Hold E to punch: +20 to the puncher, +50 each if the whole round is done, -10 each per missed station. The station's bell is as loud as a shout, so monsters that listen come for it.
- **End-of-night score for each player:**
  - Survival points, if they clock out
  - Plus points for each correct anomaly logged
  - Minus points for each false report
  - Minus a penalty for **every guard who died that night.** Deaths reduce *every* player's score.
- Points carry over between nights and are spent at the vending machine.

## 8. Death, ghosts and revives

- A guard who dies becomes a **ghost**. Ghosts can move around and watch, but can't interact with anything.
- **Revive totems** are hidden around the map. Using one is a dice roll: **4 in 6 revives** a dead teammate, **2 in 6 summons a monster** near the totem (odds shown on the totem; tunable). Rarer totems or shop items may improve the odds.
- **If every guard dies, the run restarts from night 1.** For a solo player, one death ends the run.

## 9. Monsters

**Home rule:** every monster has a home area and can only appear if that area is open at tonight's difficulty.

| # | Monster | Home | Difficulty | From night | How it works |
|---|---|---|---|---|---|
| 1 | Hall Monitor | Main hallway | D1 | 1 | Walks the hall; chases anyone it sees running. |
| 2 | The Mascot | Gym | D1 | 1 | Only moves while nobody watches it, in person or on a monitor. |
| 3 | Lunch Lady | Cafeteria | D1 | 2 | Blind, humming; hears running from far away. |
| 4 | Locker Thing | Main hallway | D1 | 3 | Lockers swing open; walk past one and you're pulled in. Shut them with E. |
| 5 | The Principal | Front office | D1 | 3 | Calls a guard to the office over the intercom; 45 seconds to get there. |
| 6 | The Other Cleaner | Roams | D1 | 5 | A fake night cleaner with no cart. Log it and it leaves. |
| 7 | The Student | Main hallway | D1 | 5 | A kid asking you to follow. Usually a trap; sometimes real. |
| 8 | The Ghost | Roams | D1 | 5 | Only on spectral monitors; knocks out cameras; an extra name on the time clock. |
| 8b | The Photographer | Main building | D1 | 3 | Charges a flash when it sees you; looking at it when it fires blinds you and it rushes you. Don't watch it. |
| 9 | The Substitute | Classroom wing | D2 | 1 | Takes the register: answer "Here!" with E, or get detention. |
| 10 | The Librarian | Library | D2 | 2 | Hates light and noise: shushes, then hunts until it's dark and quiet. |
| 11 | The Nurse | Nurse's office | D2 | 3 | Slowly follows any guard who's on their own. Stick together. |
| 12 | The Crossing Guard | Science wing | D3 | 1 | Holds up a STOP sign; anyone it sees moving gets run down. |
| 13 | The Self-Portrait | Art room | D3 | 2 | Paints one guard stage by stage; finished, it catches them. Turn it to the wall. |
| 14 | The Specimen | Science lab | D3 | 3 | Crawls after you in the dark; flees from flashlight beams into the ceiling. |
| 15 | The Understudy | Locker rooms | D3 | 4 | Dressed as a guard, follows one; stand still in its sight and it steps in. |

Monsters per night: 1, 1, 2, 2, 3, 3, 4, 4, 5, plus one for each open wing. The real night cleaner works every night.

**Hazard: power cuts.** From night 2 (1 a night; 2 from night 5; 3 from night 8) the power fails: lights and cameras die, red emergency lights come on, the vending machine stops. Someone must hold E on the breaker in the custodian's closet; it pays like a correct log.

**Fear feedback.** A heartbeat that speeds up as the nearest monster gets closer, a low drone while something nearby is chasing, flashlights that flicker near monsters, and a jumpscare (the camera snaps to whatever caught you) before the ghost view.

**Voice mimicry.** The host keeps each guard's last few spoken lines in memory; the Understudy replays them in that guard's voice from where it stands. Opt out in the Esc menu.

**Hazard: the Bell.** From night 4 the school bell rings at the wrong time (twice a night from night 7) and every monster moves 35% faster until someone shuts it off at the panel in the front office, or a minute passes.

## 10. Night progression

Each night picks its monsters at random from the pool available at that difficulty and night.

| Night | Monsters per night (tunable) | Notes |
|---|---|---|
| 1 | 1 | Mostly ordinary. Teaches cameras, clipboard and clocking in. |
| 2 | 1 | |
| 3 | 2 | |
| 4 | 2 | The Bell can start ringing. |
| 5 | 3 | The Ghost can appear. |
| 6 | 3 | |
| 7 | 4 | **Sharp ramp:** monsters can now enter the guard room. |
| 8 | 4 | |
| 9 | 5 | Final night. |

Which monsters are unlocked on which night is still to be set (section 14).

## 11. Vending machine

| Item | Price | Effect |
|---|---|---|
| Spectral camera kit | 150 | Installed at a desk with G (10 s): that desk's monitors show the Ghost. |
| Lucky rabbit's foot | 60 | Revive totems succeed on 5 in 6 (co-op only; solo has no totems). |
| Guard room door kit | 120 | A door for one of the two doorways; holds monsters about 15 s of banging. |
| Motion sensor | 40 | Put down with G; announces which area a monster passed. |
| Industrial glue trap | 60 | Put down with G; holds the first monster for 20 s. |
| Portable camera | 100 | Set up anywhere with G; an extra monitor feed until morning (two at most). |
| Walkie-talkie | 90 | Personal, for the run. Hold B to talk to every radio; receiving radios are loud enough for monsters to hear. |
| Energy drink | 25 | Faster running for 30 s. |
| Heavy-duty flashlight | 80 | Longer, wider beam for the rest of the run. |
| Air horn | 70 | Freezes monsters within 15 m for 6 s; everything hears it. |

**Rank locks:** spectral camera kit and glue trap need rank 2, portable camera and heavy-duty flashlight rank 3, air horn rank 4.

## 11b. Ranks

XP per night: 100 + 10 × night number for clocking out (25 if caught), +20 per correct log, +20 per named monster, +10 per punched station. Ranks at 0, 400, 1200, 2500, 4500, 7500, 12000 and 20000 XP: Trainee, Night Watch, Patrol Officer, Senior Guard, Shift Supervisor, Head of Security, Night Warden, Legend of Westfield. Promotions show on the night report with what they unlock.

**Ideas not built yet:** coffee.

## 11c. Replayability and long-term goals

What keeps a player coming back after the first run:

- **Shift notes (conditions).** From night 2 each night rolls 1 (nights 2–4) or 2 (5+) conditions, +1 per Overtime night: Fog advisory (thick fog), Faulty wiring (+2 power cuts), Inspector's visit (+3 stations, double punch pay), Sound carries (monsters hear voices 1.5× as far), Old batteries (dim, short flashlights), Messy school (no cleaner, 1.5× anomalies), Full moon (monsters 15% faster), Hazard pay (+1 monster, pay ×1.5). Each is worth +15% XP.
- **Bonus objective.** One team challenge a night, tracked live: nobody runs, nobody raises their voice, log N things, name a monster, finish the round by 3 AM, nobody caught. +60 points and +50 XP each.
- **Overtime.** After winning night 9 the host can keep going: points and gear carry on, +1 monster and +1 condition a night. Furthest night is a career record and a Steam leaderboard; achievements at night 10 and 15.
- **Daily shift.** One solo night a day, seeded from the date (night 4–8, difficulty 2, two conditions, 250 starting points): the same monsters, round and objective for everyone. Score = that night's pay. Best per day and the streak of days are kept; friends' scores show on the menu (Steam leaderboard per day).
- **Hats.** 12 hats unlocked by rank (8) and achievements (4), worn for everyone and the cameras to see.
- **The phone.** From night 2 the front office phone rings 1–2 times a night: answer within 35 s for a tip about a live anomaly, or the power goes.
- **First-night moment.** A harmless, local glimpse of a figure at the end of the main hallway on night 1.

## 11d. Survival pillars (genre parity)

- **Hiding.** 13 slatted cupboards (one per main area, one in the guard room). Inside, a guard isn't a target and any chase on them ends; a monster within 10 m that saw them climb in pulls them out after 1.4 s.
- **Lockdown (the hunt).** From night 6 (1 a night, 2 from night 9): an alarm, then 30 s in which every monster (except the Ghost and the Shade) heads for the nearest reachable guard at 3.6 m/s, faster than walking and slower than running.
- **Nerve (sanity).** 0–100 per guard, kept by the host. Drains: base 0.04/s, alone (in a team) 0.12/s, dark (power cut) 0.5/s, monster within 12 m 0.7/s, teammate caught −15. Gains: lit guard room 0.5/s, teammate within 8 m 0.08/s, coffee +40. Monsters notice a guard from up to 1.3× further as nerve falls; below 40, local hallucinations (footsteps, whispers, knocks, a figure at the edge of vision) every 8–30 s.
- **Evidence.** The pocket EMF reader (rank 2) shows 1–4 by distance to the nearest monster (harmless ones cap at 3); the Ghost, Specimen, Understudy and Other Cleaner read EMF 5 within 6 m.
- **Ghost agency.** Caught guards can leave a cold spot (E) every 4 s: a blue glow and a chill the living see, with a message if they're near.
- **More monsters.** The Photographer (D1, night 3: don't look when the flash fires) and the Twins (D2, night 2: move only when neither is watched).

## 12. Technical plan

- **Godot 4**, scripts in GDScript.
- **Multiplayer:** Godot's built-in multiplayer with the host in charge of game state. Local testing uses a direct connection; release uses **GodotSteam** for Steam lobbies, room codes and Steam's free relay servers. Development uses Steam's test app ID until the game has its own.
- **Art:** blocky placeholder shapes first, then free 3D asset packs (e.g. Kenney, Quaternius) for school props.
- **Testing:** Claude writes the project; the user runs it in Godot and reports back.

## 13. Build order

1. ~~Project setup~~
2. ~~Walking around: first-person controller, greybox school, gate to guard room~~
3. ~~Multiplayer foundation~~
4. ~~Guard room: desks, 16 live monitors, clock machine~~
5. ~~Night loop: timer, anomalies, clipboard, scoring, clock-out~~
6. ~~Monsters, death, ghosts and revive totems~~
7. ~~Vending machine and items~~
8. ~~Content: all 15 monsters, D2 and D3 wings, nights 1–9, saving, badges, room codes, Esc menu~~
9. ~~Steam: lobbies with codes, invites, rich presence, achievements and stats (GodotSteam, optional at runtime)~~
10. ~~Release features: voice chat and walkie-talkies, controller support, settings (keys, graphics, FOV, audio, voice), records, credits and licences, Windows and Linux builds~~
11. **Next:** the art and audio pass (textures, models, sounds); then the Steamworks steps (STEAM.md), store page and release.

## 14. Open questions

- Game name.
- Which night each monster unlocks.
- Exact point values for survival, correct logs, false reports and deaths.
- What happens to a guard who is alive at 6am but hasn't clocked out (grace period, or no pay)?
- Can ghosts talk to living players?
- Guard room defenses from night 7: locked doors, a power limit, or something else?
- Story: who is the Ghost, and why does the school have monsters?
