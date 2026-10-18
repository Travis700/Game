# Night Shift — Design Document

*Status: version 1.2.0, feature complete, with 3D models for every monster and the guards, photo textures and recorded sounds. School furniture: Poly Haven and Sketchfab models. Left: the Steamworks steps in STEAM.md and the store page. Numbers marked (tunable) are starting points to adjust during playtesting.*

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
- **Hardcore.** Off (default): a wipe goes back to the last checkpoint (nights 1, 4, 7) keeping gear, with points halved. On: back to night 1 with nothing.
- **Saving.** The host's computer saves after every night report (next night, difficulty, upgrades, doors, and each badge's points, item and flashlight). The menu offers to continue it. Walking out mid-shift (quitting, a crash) counts as the whole team being caught: the next Continue applies the wipe rules (the checkpoint with half points; night 1 on Hardcore or in Overtime). The Esc menu warns about it.

- **Voice chat.** Proximity voice (push to talk on V, or open mic). The dead hear the living; only ghosts hear ghosts. Monsters hear voices too: louder carries further (Lunch Lady, Librarian, Hall Monitor react), so keeping quiet is sometimes the way to survive.

## 4. The school and difficulty

The map is one high school. Each difficulty opens another wing, through red doors at the ends of the main hallway. There are three levels (a fourth, outdoor level was dropped: three is plenty of school).

| Difficulty | Areas | Cameras |
|---|---|---|
| D1 | Front gate, lobby, front office, guard room, main hallway, cafeteria and kitchen, gym | 8 |
| D2 | + classroom wing: West Hall, Rooms 101–103, library, nurse's office | 13 |
| D3 | + science wing: East Hall, science lab, art room, locker rooms | 17 |

Closed wings stay behind locked doors; their cameras, clipboard areas, anomalies and monsters are left out.

Every doorway has a door (wooden, with a narrow vision window): guards open and shut them, and monsters shove them open as they come, so a door opening by itself is a warning. Doors don't stop monsters; they slow sight lines and give the crew a glimpse through the glass. The guard room's doorways stay empty until a door kit is fitted (section 11).

Every room has a **light switch** just inside its door (the halls and lobby don't: their lights are on a timer). Guards flick a room's lights on to search it properly, or off to keep out of sight; the host keeps the switches in step for everyone. During a power cut they do nothing. Monsters put the lights out in rooms they pass through now and then (about one chance in eight every 4 seconds while a lit room has one in it; not the real night cleaner, nor anything in disguise or hidden; the Librarian, which can't stand light, three chances in five), so a room that has gone dark on the cameras is a sign. Ghosts can flick a switch they're standing by (within 4 m, once every 8 seconds each), one more way to point the living somewhere. The classroom TVs (on their carts) work the same way: a monster passing one may switch it on, and it glows with snow until a guard switches it off. They're quiet on purpose, so they're never mistaken for Room 101's hissing-TV Noise anomaly.

The library is the opposite: five rows of bookcases nearly up to the ceiling, with narrow aisles between them and a gap behind them along the back wall. You can't see down an aisle until you're at the end of it, and the Librarian shelves books in there.

The gym is the one big open space: a 7.5 m hall (the rest of the school is 3.5 m) with a painted court, glass backboards hung from the roof, two stands of bleachers you can climb, banners, scoreboards and high windows that let in a little moonlight. Most of its lamps go off at night, so it's mostly dark and wide open, the opposite of the hallways.

## 5. The guard room

- **4 desks, each with 4 monitors.** Any player can sit at any desk. Each monitor cycles through camera views.
- **Empty desks still work.** A solo player can move between desks to reach more cameras. Moving takes a few seconds.
- **Clock machine.** Used to clock in and clock out.
- **Vending machine.** Players buy items here, and purchases drop into the tray. What a guard carries is on their hotbar: the flashlight in slot 1 (the heavy-duty one replaces it when picked up), then up to four bought things; 1-5 or the mouse wheel pick a slot and G uses it (with the flashlight's slot picked, the first thing carried); X puts it on the floor, or hands it to the teammate in front of you (2.5 m). A caught guard's bag spills beside them; whatever's left on the floor goes back to its owner in the morning. The host keeps each guard's bag; saved runs keep the lot.
- **Flashlights.** F or the left mouse button. Your own is in your hand on screen (a CC BY arm and torch, posed in Blender, drawn small and close so it doesn't poke into walls, a dark uniform sleeve over the forearm; `tools/make_viewmodel.py`). A teammate's torch pointed at you flares, and in the middle of its beam, close enough and in the clear, it washes your screen out (Glare: each computer works out its own).
- **Hauntings** (`scripts/haunting.gd`): besides the monsters, the building itself acts up on its own clock, busier from 3 AM and quieter on night 1: a door slams, a locker bangs, a ball bounces in the gym, a phone rings once, giggling, running footsteps, pipes, a dark room's lights click on. Always 8-25 m from a guard and out of their sight if it can be, never in the guard room, and the same for everyone (host-picked, broadcast). A catch is heard by everyone nearby (the scream, and static on the walkies); monsters near you make your walkie crackle; a chasing monster bangs on a shut door and is held a moment.
- **The building's sounds and landmarks.** Wall clocks tell the shift's time (stop in a power cut; now and then one runs backwards for a few seconds). Fridges, vending machines, clocks and lit ceiling panels each have a quiet room tone (`scripts/room_tones.gd`, sounds from `tools/gen_room_tones.py`). Each wing's halls have their own colour stripe (blue main hall, amber classroom wing, green science wing) and signs at the junctions, so a team can say where to meet.
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
- **Ghosts watch the cameras.** Tab opens the school's camera feeds full screen from anywhere (left / right or the mouse wheel flick between the open ones, Tab or Esc closes). Look only: no flags, no speaker noise, no cold spots while it's up. Only the watched (normal, not spectral) feed is drawn, every frame, and only on that ghost's computer. It closes if they're revived or the report comes up.
- **Spirit box.** A living guard's switched-on spirit box (G toggles; host-tracked, synced to everyone, replayed to late joiners) hisses quietly with sweeping clicks, heard within 10 m. A ghost within 10 m of it is heard by the living within 10 m of it, through the walkie's Radio bus, for as long as they talk, cutting out 0.3 s in every 1.7 s; decided on each listener's computer. A ghost's cold spot within 10 m of it makes the box say a word to everyone near it ("run" with a monster within 15 m of the holder, "behind" if the spot is behind them, else "here" or "help"). Every 18–35 s the hiss is a faint 2 s noise only monsters within 12 m notice. It goes off when its holder is caught, puts it down or hands it over, and in the morning.
- **Revive totems** are hidden around the map. Using one is a dice roll: **4 in 6 revives** a dead teammate, **2 in 6 summons a monster** near the totem (odds shown on the totem; tunable). Rarer totems or shop items may improve the odds.
- **If every guard dies, the run goes back to the last checkpoint** (nights 1, 4 and 7, or 1 and 5 from Grade 3) with gear kept and points halved; on Hardcore it restarts from night 1 with nothing. A solo guard gets one second wind a night (Grade 5: none).

## 9. Monsters

**Home rule:** every monster has a home area and can only appear if that area is open at tonight's difficulty.

| # | Monster | Home | Difficulty | From night | How it works |
|---|---|---|---|---|---|
| 1 | Hall Monitor | Main hallway | D1 | 1 | Walks the hall; chases anyone it sees running. |
| 2 | The Mascot | Gym | D1 | 1 | Only moves while nobody watches it, in person or on the monitor a seated guard is looking at. |
| 3 | Lunch Lady | Cafeteria | D1 | 2 | Blind, humming; hears running from far away. |
| 4 | Locker Thing | Main hallway | D1 | 3 | Lockers swing open; walk past one and you're pulled in. Shut them with E. |
| 5 | The Principal | Front office | D1 | 3 | Calls a guard to the office over the intercom; 45 seconds to get there. |
| 6 | The Other Cleaner | Roams | D1 | 5 | A fake night cleaner with no cart. Log it and it leaves. |
| 7 | The Student | Main hallway | D1 | 5 | A kid asking you to follow. Usually a trap; sometimes real. |
| 8 | The Ghost | Roams | D1 | 5 | Only on spectral monitors; knocks out cameras; an extra name on the time clock. |
| 9 | The Photographer | Main building | D1 | 3 | Charges a flash when it sees you; looking at it when it fires blinds you and it rushes you. Don't watch it. |
| 10 | The Substitute | Classroom wing | D2 | 1 | Takes the register: answer "Here!" with E, or get detention. |
| 11 | The Librarian | Library | D2 | 2 | Hates light and noise: shushes, then hunts until it's dark and quiet. |
| 12 | The Nurse | Nurse's office | D2 | 3 | Slowly follows any guard who's on their own. Stick together. |
| 13 | The Twins | Rooms 101 and 102 | D2 | 2 | Two girls who only move while neither is watched (in person, or on the monitor a seated guard is looking at). One monster: logging the second is a repeat, not a mistake. |
| 14 | The Crossing Guard | Science wing | D3 | 1 | Holds up a STOP sign; anyone it sees moving gets run down. |
| 15 | The Self-Portrait | Art room | D3 | 2 | Paints one guard stage by stage; finished, it catches them. Turn it to the wall. |
| 16 | The Coach | Locker rooms, East Hall | D3 | 2 | Whistles when it sees you: run, and keep running until you're out of its sight (5 s of hustle and it lets you go). Walk or stand in its sight and it chases you. It excuses anyone stopped by the Crossing Guard, and the Hall Monitor leaves its runners be. |
| 17 | The Specimen | Science lab | D3 | 3 | Crawls after you in the dark; flees from flashlight beams (and the Photographer's flash) into the ceiling. Faster, and back sooner, in a power cut. |
| 18 | The Understudy | Locker rooms | D3 | 4 | Dressed as a guard, follows one; stand still in its sight and it steps in. |

Monsters per night: 1, 1, 2, 2, 3, 3, 4, 4, 5, plus one for each open wing. The real night cleaner works every night.

**Hazard: power cuts.** From night 2 (1 a night; 2 from night 5; 3 from night 8) the power fails: lights and cameras die, red emergency lights come on, the vending machine stops. Someone must hold E on the breaker in the custodian's closet; it pays like a correct log.

**Atmosphere.** The building's hum, creaks and the heating pipes knocking build towards 3-5 AM. The first time a monster walks onto a camera on a guard room monitor, that monitor tears with static for a moment (not for one in disguise). At 6 AM the birds start up.

**Fear feedback.** Low nerve shows on screen (below 70: the colour drains, the edges close in and grain creeps in). A heartbeat that speeds up as the nearest monster gets closer, a low drone while something nearby is chasing, flashlights and ceiling lights that flicker near monsters, and a jumpscare (the camera snaps to the face of whatever caught you) before the ghost view. None of it fires for a monster in disguise (the Other Cleaner, a fake Student or the Understudy before they show themselves) or for the Ghost: those you have to read for yourself.

**Voice mimicry.** The host keeps each guard's last few spoken lines in memory; the Understudy replays them in that guard's voice from where it stands. Opt out in the Esc menu.

**Hazard: the Bell.** From night 5 the school bell rings at the wrong time (twice a night from night 8) and every monster moves 35% faster until someone shuts it off at the panel in the front office, or a minute passes.

## 10. Night progression

Each night picks its monsters at random from the pool available at that difficulty and night.

| Night | Monsters per night (tunable) | Notes |
|---|---|---|
| 1 | 1 | Mostly ordinary. Teaches cameras, clipboard and clocking in. |
| 2 | 1 | |
| 3 | 2 | |
| 4 | 2 | |
| 5 | 3 | The Ghost can appear; the Bell can start ringing. |
| 6 | 3 | |
| 7 | 4 | **Sharp ramp:** monsters can now enter the guard room. |
| 8 | 4 | |
| 9 | 5 | Final night. |

Which monsters are unlocked on which night is still to be set (section 14).

## 11. Vending machine

| Item | Price | Effect |
|---|---|---|
| Spectral camera kit | 220 | Installed at a desk with G (10 s): that desk's monitors show the Ghost. |
| Lucky rabbit's foot | 60 | Revive totems succeed on 5 in 6 (co-op only; solo has no totems). |
| Guard room door kit | 180 | A door for one of the two doorways; holds monsters about 15 s of banging. |
| Motion sensor | 25 | Put down with G; announces which area a monster passed within 10 m. Can't be bought in a power cut (the machine is dark). |
| Industrial glue trap | 60 | Put down with G; holds the first monster for 20 s. |
| Portable camera | 140 | Set up anywhere with G; an extra monitor feed until morning (two at most). |
| Walkie-talkie | 130 | Personal, for the run. Hold B to talk to every radio; receiving radios are loud enough for monsters to hear. |
| Energy drink | 25 | Faster running for 30 s. |
| Heavy-duty flashlight | 140 | Longer, wider beam for the rest of the run. |
| Air horn | 70 | Freezes monsters within 15 m for 6 s; it's a loud noise everything within 60 m comes to check once the freeze ends. |
| Decoy radio | 60 | Put down; 8 s later it plays music for 20 s, a noise sound-hunters go to. |
| Box of donuts for the district | 300 (+100 for each box already sent this run) | Removes one of the team's write-ups. |
| Pocket EMF reader | 150 | Personal, for the run: 1–4 by distance to the nearest monster, 5 for the evidence monsters. |
| Thermos of coffee | 30 | +40 nerve. |
| Spirit box | 120 | Switched on and off with G. Lets the living near it hear ghosts near it, and says a word at a ghost's cold spot; monsters within 12 m hear its hiss now and then. |

**Rank locks:** spectral camera kit, glue trap, decoy radio and spirit box need rank 2, portable camera, heavy-duty flashlight and donuts rank 3, air horn rank 4.

## 11b. Ranks

XP per night: 100 + 10 × night number for clocking out (25 if caught), +20 per correct log, +20 per named monster, +10 per punched station. Ranks at 0, 400, 1200, 2500, 4500, 7500, 12000 and 20000 XP: Trainee, Night Watch, Patrol Officer, Senior Guard, Shift Supervisor, Head of Security, Night Warden, Legend of Westfield. Promotions show on the night report with what they unlock.

**Perks.** One per guard, picked on the menu, one unlocking per rank (sent in the spawn data, validated against the rank): Thermos (r1, nerve drains ×0.75), Track star (r2, stamina ×1.5), Spare batteries (r3, flashlight reach ×1.2, ignores Old batteries), Handy (r4, hold-E ×0.5), Low profile (r5, monsters' notice range ×0.85), Lookout (r6, built-in EMF reader), Cool head (r7, no hiding drain).

## 11c. Replayability and long-term goals

What keeps a player coming back after the first run:

- **Shift notes (conditions).** From night 3 each night rolls 1 (nights 3–4) or 2 (5+) conditions, 3 in Overtime: Fog advisory (thick fog), Faulty wiring (+2 power cuts), Inspector's visit (+3 stations, double punch pay), Sound carries (monsters hear voices 1.5× as far), Old batteries (dim, short flashlights), Messy school (no cleaner, 1.5× anomalies), Full moon (monsters 15% faster), Hazard pay (+1 monster, pay ×1.5), Camera faults (a third of the open cameras dead all night), Lockdown drill (one extra lockdown, from night 4), Early start (every monster out by about 2 AM), Thunderstorm (rain on the roof all night, thunder, lightning flashing in the windows; monsters hear voices only 0.7× as far; never with Sound carries). Each is worth +15% XP.
- **Bonus objective.** One team challenge a night, tracked live: nobody runs, nobody raises their voice, log N things, name a monster, finish the round by 3 AM, nobody caught. +60 points and +50 XP each.
- **Overtime.** After winning night 9 the host can keep going: points and gear carry on, +1 monster a night (up to +5), 3 conditions, and one new standing **district memo** a night (Memos, derived from the night number): night 10 every monster that can has a mood, 11 the bell rings three times, 12 three lockdowns, 13 two latecomers around 4 AM, 14 a third of the cameras dead. Every third Overtime night (12, 15, 18...) ends with the last bell again; each guard who gets out is paid +100. Furthest night is a career record and a Steam leaderboard; achievements at night 10 and 15.
- **Daily shift.** One solo night a day, seeded from the date (night 4–8, difficulty 2, two conditions, 250 starting points): the same monsters, round and objective for everyone. Score = that night's pay. Best per day and the streak of days are kept; friends' scores show on the menu (Steam leaderboard per day).
- **Case files.** Three stamps per monster (54): *spotted* (its field guide page), *named* (named right in a log) and *handled* (Substitute: answer its register; Self-Portrait: turn it to the wall; Student: walk a real one out; everything else: clock out of a night it was out on which it caught nobody). Stored per player in career.cfg; shown on each field guide page. 18, 36 and 54 stamps are achievements, each with a hat (Deerstalker, Detective's fedora, Chief's cap).
- **Grades.** Winning a run opens Grade 1 on the menu; winning at grade g opens g + 1 (career `best_grade`), up to 5. Each adds to those below and is +20% XP: G1 moods from night 1 and lockdowns from night 4; G2 false reports and wrong names cost double; G3 fired at 2 write-ups, checkpoints only nights 1 and 5; G4 monsters ×1.1 speed; G5 no second wind and no revive totems. The grade is saved with the run, sent with the night's start, and shown on the clock ("G3"). Achievements for a graded win and for Grade 5.
- **Hats.** 15 hats unlocked by rank (8) and achievements (7), worn for everyone and the cameras to see.
- **The phone.** From night 3 the front office phone rings 1–2 times a night: answer within 35 s for a tip about a live anomaly, or the power goes.
- **First-night moment.** A harmless, local glimpse of a figure at the end of the main hallway on night 1.

## 11d. Survival pillars (genre parity)

- **Hiding.** 13 slatted cupboards (one per main area, one in the guard room). Inside, a guard isn't a target and any chase on them ends; a monster within 10 m that saw them climb in pulls them out after 1.4 s.
- **Later anomalies.** Night 5 adds **Noise** (a new clipboard type, shown on the clipboard from night 5): seven invisible looping sounds (radio, static, whispering, a ball bouncing) audible within 12 m, captioned, never on camera, so someone has to be out listening. Night 6 adds three **walking figures**: logged as Figure, they step to their next spot in the same area every 15 in-game minutes while no guard is within 12 m, until logged. The night new ones unlock, two are forced into the pool and new ones are picked half the time. A one-off NEW TONIGHT message introduces each.
- **Lockdown (the hunt).** From night 6 (1 a night, 2 from night 9): an alarm (and every ceiling light within 24 m of each guard stutters, on their own screen), then 30 s in which every monster (except the Ghost and the Shade) heads for the nearest reachable guard at 3.6 m/s, faster than walking and slower than running. If a Hall Monitor, Lunch Lady, Mascot or Twins is out, the lockdown is that monster's **drill** (a different one each lockdown of a night where possible), announced and shown under the clock: *still* (Hall Monitor: only guards who ran or shouted, voice > 0.6, in the last 2 s are targets), *quiet* (Lunch Lady: targets are guards moving > 0.8 m/s within 12 m of a monster, or running/talking > 0.3 within 30 m), *watched* (Mascot/Twins: every monster freezes while `is_watched`). With no target a monster stands and listens. The finale is always a plain hunt.
- **The last bell (finale).** Night 9 of a run and every third Overtime night (not dailies), 5 AM, with no phone ring planned late enough to cut the power in it (and any ring or cut still going is ended when it starts): a permanent lockdown at 3.0 m/s rising to 3.8 m/s by 6 AM, plus a Hall Monitor and a Lunch Lady. The gate (chained shut every shift, so nobody camps the street) opens when the padlock key, placed at a round station deep in the school or in tonight's wings, is carried to within 3.5 m of it. Guards in the street (z > 45.6) aren't targets; once everyone living is out the night ends early. At 6 AM anyone inside is caught ("the school"). Escapees get the Last bell achievement.
- **Moods.** From night 5, each spawned monster (not the cleaner, students, the Ghost or the Shade) has a 45% chance of a mood: restless (speed ×1.15, patrol pauses halved), keen (notice range ×1.25) or drowsy (speed and notice range ×0.85). Speed never goes past max(its own speed, 5.4). A correct Monster log tells the logger its mood.
- **Close calls.** The first catch by each monster kind not in that guard's field guide (sent with the spawn data; once per kind per session) knocks them out instead: black screen, wake in the guard room, nerve −40, 8 s untargetable, and the monster's rule. Solo, once a night, any catch is a "second wind" (−50 pay). Not on Hardcore, in training or in the finale. A guard's first correct log of a monster shows its rule on screen.
- **Learning loop.** The report lists missed anomalies (area: type) and every monster that came out with whether anyone logged it. Night 1's first monster arrives 30–60 minutes in, and every night's first anomaly by about 12:25. The real cleaner leaves a WET FLOOR sign at each mop stop (a decoy: logging it is a false report; the Other Cleaner never leaves one).
- **Anomaly variety.** Most anomalies have 2–3 alternative spots (where a moved thing ends up, where an extra thing or figure appears), picked at random each time (never within 12 m of a guard), all checked to be on their area's camera. Each night only a random 70% of the possible anomalies (at least 6) are in play.
- **Custom shift.** The menu's shift-notes picker (saved in the profile) forces the ticked notes every night of a solo or hosted run (not the daily shift). Picked notes earn no XP bonus (otherwise the easy or lucrative ones would be free XP).
- **Joining mid-shift.** A player who connects during a shift spawns as a ghost: the host replays the night's start, clock, conditions, round, power, hiding, lockdown/bell and finale state to them, marks the already-caught as ghosts, and leaves them out of the work target. Also replayed: camera blackouts, totems, open lockers, placed sensors/traps and portable cameras, the phone, the Self-Portrait's progress, the Mascot's empty stand, the bonus line and the bodies of the caught (late joiners take no reference photos). A late joiner earns nothing that night ("Joined late" on the report), can't be revived by a totem, and doesn't count towards the team size (so a solo host keeps their second wind and solo awards). Someone who leaves a shift alive and rejoins it counts as caught. Ghost cooldowns are kept by badge, so reconnecting doesn't reset them. They play normally from the next night. Joining during the morning or the report is refused with "try again in a minute".
- **Base station.** A guard seated at a desk can hold the walkie-talkie key without owning one: everyone alive hears it as a radio call (field guards still need a walkie to answer). The Mascot and Twins only count as watched on the monitor a seated guard is actually looking at (full screen, the one under the cursor, or the last one they looked at).
- **Monster deck.** Each night's pool is weighted: monsters this run hasn't shown come first, and one that came the last two nights goes to the back. Solo guards' nerve drains 0.06/s on top of the base rate (the guard room still restores it).
- **Evidence for confirmations.** A teammate's confirmation of something already logged pays (+10) only if they could see it themselves: in that area within the last 90 s, or seated at a desk with that area's camera on one of their own four monitors since before the first log (switching to it afterwards doesn't count). Otherwise it's noted with no pay. Only first logs count toward a "log N things" bonus. Likewise only the monitors of occupied desks count as watching the Mascot and Twins.
- **Monster fairness pass.** The Lunch Lady stops 2 m short of a sound and only catches guards she can hear (standing still really is silent). The Other Cleaner's reveal has a sound and a 0.8 s pause, then chases at 4.5 for 7 s (giving up 3 s out of sight), with 20 s before it can do it again. The Understudy resets its step-in on a new target and excuses totems and desks as well as stations and the breaker. The Coach doesn't count standing still for the Crossing Guard's sign as slacking. A totem's Shade appears 8 m away and takes 1.5 s to rise. Hidden guards are only pulled out by monsters that could have seen them go in (not the Lunch Lady, Nurse, Substitute, Twins or Mascot). The Photographer won't line up the same guard for 30 s. The Principal reminds you with 15 s left, and stops hunting a guard who makes it to the office. The Self-Portrait's last stage is announced to everyone and it rests 45–70 minutes between paintings. The Nurse speeds up from 1.7 to 2.9 m/s the longer she follows (and follows a solo guard half as long). Cues: the Crossing Guard's all-clear whistles, locker creaks and Understudy step-ins are captioned, the Ghost breathes within 8 m, the Twins giggle at most every 4 s, the Specimen is louder, and the Librarian names what actually gave you away.
- **Staring.** Each second a monster (not the Mascot or Twins, never mid-chase) is within 20 m and in frame of a camera on an occupied desk's monitors, it has a 4% chance (once a night) of stopping for 2.5 s to look straight down the lens.
- **Incident photos.** When a guard is caught, the host picks the nearest open, working camera (within 30 m) with the spot in frame and nothing in the way; every computer snapshots that feed, and the night report shows the last four ("2:41 AM · Gym cam · Guard 2, caught by the Mascot").
- **R. Hale's notebook.** Every field guide page carries an entry from the notebook of the guard who had the job before (the name the time clock prints when the Ghost is out); fill the whole guide and his last entry appears.
- **The round counts.** At 6 AM every unpunched station takes a station's pay × (1 + 0.6 per extra guard) off the team's work total, and the target line shows what's owed while stations are left. The Understudy gives twice as long (8 s) to a guard standing at a punch station or the breaker, and warns at 40%. The Self-Portrait's stage 2 and 3 warnings point at the art room.
- **Run shape.** Auto difficulty opens a wing at nights 4 and 7 (or more for bigger teams), so solo guards meet all 18 monsters; extra monsters per wing only come for teams big enough to cover them (min(difficulty, guards) − 1). Losing the last night retries it once per run instead of going back to night 7, and a solo second wind still works in the finale. Being fired halves points like a wipe. "Nobody runs" is never tonight's bonus with the Coach out or a lockdown planned.
- **Onboarding.** One new thing at a time: night 1 has no bonus objective; night 2 adds the work target and power cuts (explained in one message); night 3 shift notes, the phone and the "name a monster" bonus; night 5 moods and the Bell. HUD messages replace each other (quick feedback should), except that a teaching message (shown 8 s or more: a monster's rule, the shift notes, tips) holds the screen while it's read and ordinary messages wait behind it, one per kind (teaching messages never collapse into each other), and are dropped if they waited over 8 s or shown for at most 3 s; urgent ones (catches, log results, lockdowns) always go straight up and requeue a teaching message they cut off. The queue clears on being caught, at the report and at the next night. The objective line lists at most three stations and drops the shift notes. Night 3 introduces the phone; every report teases the next night's new thing; nights 2-3 bring the first monster by 40-90 minutes and night 2's first power cut at 60-120; on night 1 the first monster's camera glitches with a "something's on it" message. Training (8 steps) teaches compare-with-photo and ends on "Start night 1". Night-1 tips stop after two runs; teams get a marking tip. The daily is locked until training is done. How to play greys out topics for nights the player hasn't reached. Every prompt and help text uses the player's own keys (`{use}`-style placeholders filled by Controls/KeyText), and controller buttons once a pad is used.
- **Honest logs.** A correct Monster log with the wrong name pays 10 less; the first repeat of an entry already paid is a warning, later repeats with nothing new are false reports. Ignoring the Principal's summons (it gives up on a living guard) docks 40. Dead guards don't block, clear or keep anomalies.
- **Marks.** Q (pad B) away from the desks: a 40 m ray, host rate-limited to one per 1.5 s, broadcast as a billboard Label3D (no depth test) in the guard's uniform colour for 8 s. Within 2.5 m of a non-disguised monster (not the Other Cleaner, Student or Understudy) it reads MONSTER! in red.
- **Nerve (sanity).** 0–100 per guard, kept by the host. Drains: base 0.04/s, alone (in a team) 0.12/s, dark (power cut) 0.5/s, monster within 12 m 0.7/s, teammate caught −15. Gains: lit guard room 0.5/s, any other room with its lights switched on 0.1/s, teammate within 8 m 0.08/s, coffee +40. Monsters notice a guard from up to 1.3× further as nerve falls; below 40, local hallucinations (footsteps, whispers, knocks, a figure at the edge of vision) every 8–30 s.
- **Evidence.** The pocket EMF reader (rank 2) shows 1–4 by distance to the nearest monster (harmless ones cap at 3); the Ghost, Specimen, Understudy and Other Cleaner read EMF 5 within 6 m.
- **Ghost agency.** Caught guards can leave a cold spot (E) every 4 s: a blue glow and a chill the living see, with a message if they're near.
- **More monsters.** The Photographer (D1, night 3: don't look when the flash fires) and the Twins (D2, night 2: move only when neither is watched).

## 11e. Onboarding, accessibility and wrap-up

- **Training shift.** A guided solo night with a frozen clock: sit at a desk, log the moved lobby bench, punch Main Hall East's station, reset the breaker, hide while a harmless Hall Monitor walks past. Offered first on the menu until done.
- **Captions.** Monster state changes that make a telling sound are captioned with a direction (ahead / behind / left / right / right next to you), within 30 m. Toggle in the Esc menu.
- **Spectating.** Ghosts press G to cycle through living teammates' views.
- **End-of-run summary.** Logs, named monsters, stations and catches for each guard over the whole run, and a run MVP in co-op.
- **More monsters.** The Coach (D3, night 2): once it whistles at you, run until you're out of its sight.
- **XP by difficulty.** +25% XP per open wing.
- **Performance.** Static school geometry is merged per material per 20 m cell (draw calls ~2000 → ~700).

## 11f. Stakes and agency (from the design critique)

- **The echo.** On night 3 with a team, once (80-220 min, retried every 20 min if nobody has spoken or no spot fits), a line a living guard said earlier plays from an empty hallway spot 15-28 m from the guards (open wings only), captioned; the report notes "Guard N says they never said that". Respects the voice-mimic opt-out. A taste of the Understudy before most teams meet it.
- **Ghost radio.** A ghost within 3 m of a living guard who carries a walkie-talkie comes through on that guard's radio (Radio bus, squelch, caption) in 3 s bursts, at most one burst per 20 s per ghost; decided on the listener's computer, never reported to monsters. The caught message tells ghosts how (in team games).
- **Call-outs.** A camera flag or a mark records a call-out for its area if the guard could see it (in or just visited the area, or it's on their desk's monitors); one live call-out per guard. When another guard makes the first correct log in that area within 60 s, the latest caller gets +15 points (counted towards the work target) and +10 XP. A Noise only counts as seen by being there, not on a monitor. "Best spotter" joins the team awards; "log 3 things a teammate called out first" is a team-only bonus objective.
- **Work target.** From night 2: (30 + 22 × night) × (1 + 0.6 × (guards − 1)) points from logs, named monsters and punched stations, less false reports and misnamed monsters. Each night has 4 + 2 × night + 2 × (guards − 1) anomalies. Missing it is a write-up; three write-ups and the team is fired (back to the last checkpoint; night 1 on Hardcore; ends the run in Overtime).
- **Checkpoints.** A team wipe (or being fired) goes back to night 1, 4 or 7 with gear kept and points halved. Hardcore restores the old back-to-night-1-with-nothing rule.
- **Log grace.** A Monster log still counts if the monster was in that area within the last 10 s (it may have stepped over a boundary while the clipboard was open).
- **First logger.** +25 to the first guard to log a thing; +10 to teammates confirming it.
- **Subtler anomalies.** Moved props move `lerp(home, to, 1.12 - 0.085 × night ± 0.08)` (clamped 0.3–1), so later nights need a closer look.
- **Pacing.** Monster arrivals spread over 12:25–3:40 AM; from night 2 one arrives around 4 AM with an announcement.
- **Desk agency.** Q flags a camera for everyone (message + marker); F (full screen) sets off a camera speaker, drawing the Lunch Lady (40 m), Librarian and Hall Monitor (25 m), once a minute per guard.
- **Stamina.** About 6 s of running from full; winded until 30%; energy drinks suspend it.
- **Hiding costs nerve.** −1/s while hiding; at 0 the guard panics out, screaming (heard as a shout).
- **Clutter.** 45 physics props (RigidBody3D, simulated on the host, moving ones sent about 10 times a second and settled ones not at all); guards push the light ones by walking into them, a throw tumbles and lands, a hard landing makes a noise the sound-hunters follow; ghosts can shove one every 20 s.
- **Restrooms and the band room** (behind the main hall's north wall): boys' and girls' restrooms with stalls whose doors swing (monsters push them open), sinks whose taps run (E) and toilets that flush (E; a short noise the sound-hunters hear), and a band room on risers with an upright piano (E plays a note, a noise heard 28 m off). The haunting can flush a toilet, run a tap, slam a stall door or play the piano by itself (`scripts/restrooms.gd`, `scripts/piano.gd`; sounds from `tools/gen_fixture_sounds.py`). Each has a camera, a light switch and anomaly spots; the band room has a hiding cupboard.
- **Drawers** (`scripts/drawers.gd`): 30 drawers in the offices, classrooms and nurse's office slide open with E for everyone. The host stocks a few each night: a spare battery (that guard's flashlight 25% brighter for the night), loose change (+10), an R. Hale note, and about one night in five a scare (a rat or a doll's giggle).
- **Learning loop.** Being caught shows that monster's rule (if it's in your guide); the guard room notice board lists tonight's notes, target, bonus and round.

## 12. Technical plan

- **Godot 4**, scripts in GDScript.
- **Multiplayer:** Godot's built-in multiplayer with the host in charge of game state. Local testing uses a direct connection; release uses **GodotSteam** for Steam lobbies, room codes and Steam's free relay servers. Development uses Steam's test app ID until the game has its own.
- **Art:** the building is made of boxes in code (merged into a few meshes per material), with photo textures from Poly Haven. Monsters and some props are Meshy models made from the notebook drawings; furniture and fittings are CC0 models from Poly Haven and CC BY models from Sketchfab (desks, chairs, cafeteria tables, the vending machine, whiteboards, and outside the trees, picnic tables, a bench and a school bus; fetched with `tools/sketchfab.py`, tidied with `tools/prep_glb.py`, credited in CREDITS.md and on the Credits page); posters, the court and other flat art are drawn by scripts in `tools/`. Lighting: the ceiling lights cast distance-faded shadows on Forward+ (off on the Compatibility renderer, which breaks up with that many), SDFGI and SSIL bounce light round the rooms (the "Bounced light" setting), and exit signs glow red all night on battery. Clutter (`scripts/set_dressing.gd`): books, papers and pencil cups on desks, bags by them, computers, mugs and a water cooler in the offices, milk cartons in the cafeteria, towels in the locker rooms, PA speakers, radiators, classroom flags, the day's lesson in marker on each whiteboard, fire evacuation plans, R. Hale's missing-person flyer, crumpled paper on the floors and cobwebs in the corners, laid from a fixed seed and drawn as one MultiMesh per model per 20 m square. The flashlight throws a reflector-pattern beam (`tools/gen_flashlight.py`) that trails the view a little, lit dust hangs round the guard, and the picture has a little film grain, vignette and colour fringing (the "Film grain" setting). Wear is decals from `tools/gen_wear.py` (scuffs, spills, water-stained ceiling tiles, grime along the hall walls) plus loose sheets of paper, laid from a fixed seed so every player sees the same school. The classroom vinyl tile (`tools/gen_vct.py`) and the front hedges (`tools/gen_hedge.py`) are generated textures.
- **Drawing less:** walls are occluders (occlusion culling is on), so other rooms' furniture isn't drawn, and small props fade out beyond about 20 m. The long grass outside is one tuft of blades made in code, drawn as MultiMeshes in 10 m patches: every tuft within 20 m, a third of them to 42 m, none beyond (a "Long grass" setting turns it off).
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

## 14. Settled questions

- Name: Night Shift. Unlock nights: the table above. Points: section 10 and the code's constants.
- Alive but not clocked out at 6 AM: 90 seconds to clock out, or no survival pay.
- Ghosts only talk to ghosts, except in short bursts over a living guard's walkie-talkie.
- The guard room from night 7: monsters can get in; doors from the vending machine hold them for a while.
- The story: R. Hale's notebook (the field guide) and the memos.
