# Night Shift — Design Document

*Working title. Status: agreed baseline, before any building starts. Numbers marked (tunable) are starting points to adjust during playtesting.*

## 1. Overview

A first-person co-op light-horror game for 1–4 players. The players are night security guards at an American high school. Each night they clock in, watch the cameras, patrol the building, log anomalies on their clipboards, and try to survive until 6am. The early nights are mostly ordinary. From night 7 the horror ramps up sharply.

- **Engine:** Godot 4 (latest stable)
- **Platform:** PC, released on Steam at about $5
- **Players:** 1–4 online co-op. A solo player can finish the whole game.
- **Run length:** 9 nights

## 2. Core loop

1. **Before the shift.** Players spawn at the school's front gate, walk into the building and go to the guard room. They can buy items from the vending machine.
2. **Clock in.** Each player enters their employee number on the clock machine in the guard room. The night starts once the players have clocked in.
3. **During the shift (midnight to 6am).** Players watch the cameras from the desks, patrol the school, handle monsters and hazards, and log anomalies on their own clipboards.
4. **Clock out at 6am.** A player only gets paid if they make it back to the clock machine and clock out.
5. **End of night.** Scores are tallied, and players spend points on items before the next night.

**Night length:** about 12 minutes of real time, so roughly 80 seconds per in-game hour (tunable).

## 3. Lobby and sessions

- **Joining.** The host creates a Steam lobby. The game shows a **room code** and a **password** that every player in the session can see (in the guard room and the pause menu). Friends can also join through Steam invites.
- **Difficulty.** Set automatically to the number of players (1–4). The host can raise or lower it. Each option shows a short explanation, e.g. "Difficulty 3: 3 wings, ~20 cameras, built for 3 guards."
- **Lobby option "Keep gear on restart."** When on, items survive a run reset and points reset. When off, everything resets.

## 4. The school and difficulty

The map is one high school. Each difficulty level adds areas and cameras.

| Difficulty | Areas | Cameras (approx.) |
|---|---|---|
| D1 | Front gate, front office, guard room, main hallway, cafeteria and kitchen, gym | 8 |
| D2 | + classroom wing, library, nurse's office | 14 |
| D3 | + second floor, science labs, art room, locker rooms | 20 |
| D4 | + auditorium, boiler room, parking lot, football field | 28 |

Areas not used at a difficulty are locked off (shutters, locked doors, "closed for renovation").

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

**Home rule:** every monster has a home area and can only appear if that area is in the map. Roaming monsters can appear at any difficulty. Every counter is reachable within the monster's home area or the core building.

| # | Monster | Home | Min. difficulty | Warning sign | How to deal with it |
|---|---|---|---|---|---|
| 1 | Hall Monitor | Main hallway | D1 | Tall figure with a sash and clipboard | Walk, don't run. It hunts anyone running. |
| 2 | The Mascot | Gym | D1 | Bulldog costume missing from its stand | Keep it on a monitor. It only moves when nobody is watching it. |
| 3 | Lunch Lady | Cafeteria | D1 | Humming, trays moved | Stay quiet. Throw items to draw her away. |
| 4 | Locker Thing | Main hallway | D1 | Locker doors open on camera | Close the lockers, or set traps. |
| 5 | The Principal | Front office | D1 | Names one guard over the loudspeakers | That guard must reach the office within 60 seconds, or it comes to them. |
| 6 | The Other Cleaner | Roams | D1 | Two cleaners on camera at once | Spot the fake. The real cleaner is harmless. |
| 7 | The Student | Roams | D1 | A kid asking for help | Check the cameras before following. Rarely, the kid is real. |
| 8 | The Ghost | Roams | D1 (late game) | An extra clock-in under an unknown employee number | Only visible on upgraded monitors. Stay out of its path. |
| 9 | The Substitute | Classroom wing | D2 | Teacher at the front of a class, with something subtly wrong | Log it fast, or it takes attendance and hunts. |
| 10 | The Librarian | Library | D2 | Library lights switched off | Turn the lights back on. A flashlight stuns it. |
| 11 | The Nurse | Nurse's office | D2 | Medicine cabinet open | Drags injured guards to her office. Teammates must rescue them. |
| 12 | The Specimen | Science labs | D3 | Empty jar, a camera covered over | Small, fast, uses vents. Use traps. |
| 13 | The Self-Portrait | Art room | D3 | A painting of a guard, more finished each check | Log it and cover the canvas before it's finished. |
| 14 | The Understudy | Auditorium | D4 | Stage lights on, curtain moving | Copies teammates' voices on the radio. Use a code word. |
| 15 | The Crossing Guard | Parking lot | D4 | Stop sign raised | When it shows STOP, everyone outside must freeze. |

**Hazard: The Bell.** The school bell rings at the wrong time and every monster speeds up for 30 seconds. It's reset in the front office.

**Monsters available per difficulty:** D1: 8, D2: 11, D3: 13, D4: 15.

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

## 11. Vending machine (first item list)

- Flashlight upgrades and spare batteries
- Coffee
- Radio (talk to teammates anywhere in the school)
- Door locks and motion sensors
- Traps
- Extra cameras
- Monitor system upgrade (needed to see the Ghost)
- Guard room door reinforcement (matters from night 7)

Prices and exact effects are to be set during building.

## 12. Technical plan

- **Godot 4**, scripts in GDScript.
- **Multiplayer:** Godot's built-in multiplayer with the host in charge of game state. Local testing uses a direct connection; release uses **GodotSteam** for Steam lobbies, room codes and Steam's free relay servers. Development uses Steam's test app ID until the game has its own.
- **Art:** blocky placeholder shapes first, then free 3D asset packs (e.g. Kenney, Quaternius) for school props.
- **Testing:** Claude writes the project; the user runs it in Godot and reports back.

## 13. Build order

1. **Project setup:** Godot project, folder structure, repo.
2. **Walking around:** first-person controller, greybox D1 school, gate to guard room.
3. **Multiplayer foundation:** hosting and joining, synced players. Built early so nothing has to be rewritten later.
4. **Guard room:** sitting at desks, 4 live monitors per desk, cycling views, clock machine.
5. **Night loop:** timer, anomalies, clipboard, scoring, clock-out.
6. **First monster:** Hall Monitor, plus death, ghosts and revive totems.
7. **Vending machine and items:** purchases, traps, monitor upgrade install.
8. **Content:** remaining monsters, D2–D4 areas, nights 1–9.
9. **Steam:** lobbies, room code and password, store page, release build.

## 14. Open questions

- Game name.
- Which night each monster unlocks.
- Exact point values for survival, correct logs, false reports and deaths.
- What happens to a guard who is alive at 6am but hasn't clocked out (grace period, or no pay)?
- Can ghosts talk to living players?
- Guard room defenses from night 7: locked doors, a power limit, or something else?
- Story: who is the Ghost, and why does the school have monsters?
