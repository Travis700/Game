# Night Shift — Design Document

*Working title. Status: all core features built in greybox (blocky placeholder art); next are playtesting, Steam and the art pass. Numbers marked (tunable) are starting points to adjust during playtesting.*

## 1. Overview

A first-person co-op light-horror game for 1–4 players. The players are night security guards at an American high school. Each night they clock in, watch the cameras, patrol the building, log anomalies on their clipboards, and try to survive until 6am. The early nights are mostly ordinary. From night 7 the horror ramps up sharply.

- **Engine:** Godot 4 (latest stable)
- **Platform:** PC, released on Steam at about $5
- **Players:** 1–4 online co-op. A solo player can finish the whole game.
- **Run length:** 9 nights

## 2. Core loop

1. **Before the shift.** Players spawn at the school's front gate, walk into the building and go to the guard room. They can buy items from the vending machine. The school is brightly lit (street lights, floodlights on the building, every light on inside) so arriving feels ordinary and safe.
2. **Clock in.** Each player enters their employee number on the clock machine in the guard room. The night starts once the players have clocked in: the floodlights cut out one by one, some ceiling lights click off, the rest dim, the fog closes in and the faulty lights start to flicker.
3. **During the shift (midnight to 6am).** Players watch the cameras from the desks, patrol the school, handle monsters and hazards, and log anomalies on their own clipboards.
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

- **Logging.** Choose the area or camera and the type of anomaly. The time is recorded automatically.
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
| 9 | The Substitute | Classroom wing | D2 | 1 | Takes the register: answer "Here!" with E, or get detention. |
| 10 | The Librarian | Library | D2 | 2 | Hates light and noise: shushes, then hunts until it's dark and quiet. |
| 11 | The Nurse | Nurse's office | D2 | 3 | Slowly follows any guard who's on their own. Stick together. |
| 12 | The Crossing Guard | Science wing | D3 | 1 | Holds up a STOP sign; anyone it sees moving gets run down. |
| 13 | The Self-Portrait | Art room | D3 | 2 | Paints one guard stage by stage; finished, it catches them. Turn it to the wall. |
| 14 | The Specimen | Science lab | D3 | 3 | Crawls after you in the dark; flees from flashlight beams into the ceiling. |
| 15 | The Understudy | Locker rooms | D3 | 4 | Dressed as a guard, follows one; stand still in its sight and it steps in. |

Monsters per night: 1, 1, 2, 2, 3, 3, 4, 4, 5, plus one for each open wing. The real night cleaner works every night.

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
| Spectral camera kit | 150 | Installed at a desk (10 s): that desk's monitors show the Ghost. |
| Lucky rabbit's foot | 60 | Revive totems succeed on 5 in 6. |
| Guard room door kit | 120 | A door for one of the two doorways; holds monsters about 15 s of banging. |
| Motion sensor | 40 | Put down with G; announces which area a monster passed. |
| Industrial glue trap | 60 | Put down with G; holds the first monster for 20 s. |
| Energy drink | 25 | Faster running for 30 s. |
| Heavy-duty flashlight | 80 | Longer, wider beam for the rest of the run. |

**Ideas not built yet:** radio, extra cameras, coffee.

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
9. **Next:** playtesting and balance; Steam (GodotSteam lobbies and relay, store page); art pass (textures, models, sounds) before the store page.

## 14. Open questions

- Game name.
- Which night each monster unlocks.
- Exact point values for survival, correct logs, false reports and deaths.
- What happens to a guard who is alive at 6am but hasn't clocked out (grace period, or no pay)?
- Can ghosts talk to living players?
- Guard room defenses from night 7: locked doors, a power limit, or something else?
- Story: who is the Ghost, and why does the school have monsters?
