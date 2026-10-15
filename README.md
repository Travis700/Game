# Night Shift

A first-person co-op light-horror game about night security at an American high school, made in Godot 4.
The full plan is in [DESIGN.md](DESIGN.md).

## Status

Version 1.0.0. The game is complete apart from the art and audio pass: every model is a
placeholder made of boxes, and every sound is generated in code. Everything else is in:
nine nights with a last-bell finale, then Overtime; three difficulties (main building, classroom
wing, science wing); 18 monsters with moods, a field guide and R. Hale's notebook; the guard room
and its 16 cameras; watchman rounds, power cuts, shift notes and nightly bonuses; a training shift,
close calls and incident photos; ranks with hats and perks; the vending machine; saving and
checkpoints; a daily shift (solo or as a team); achievements and records; proximity voice chat,
walkie-talkies and the desk's base station (and a monster that copies your voice); marks; joining
mid-shift; captions, controller support and settings; and Steam lobbies, invites and leaderboards
(see [STEAM.md](STEAM.md) for the Steamworks steps that need your account).

## Running it

1. Open Godot 4.7 or newer.
2. In the Project Manager, click **Import**, choose this folder's `project.godot`, then **Import & Edit**.
3. Press **F5** (or the ▶ button at the top right) to play.

The first time you open it, Godot spends a few seconds importing. That's normal.

The game opens on a menu: **Play solo**, **Host a game**, or **Join**.

### Playing together

The host clicks **Host a game**. Their **room code** (like `DALS-AJW`) shows in the top-right corner.
Everyone else types that code (or the host's address) next to **Join**. If the host typed a room
password before hosting, joiners type the same password. Room codes work on the same network, or over
the internet if the host forwards port 7777 on their router. On Steam, friends can join through the
invite or the Steam overlay instead, with no ports to forward.

### The menu

- **Training** walks a new guard through one guided shift: the cameras, logging, the round, the breaker and
  hiding. It never touches the saved run.

- **How to play**, **Records** (career stats, best scores, achievements) and **Credits** (with the
  software licences) are along the bottom.

- **Your employee badge** is a number this computer picked for you the first time you played. You type it
  into the time clock to clock in, and your saved points are linked to it.
- **Difficulty** sets how much of the school is open. *Auto* picks one level per guard.
  1 is the main building, 2 adds the classroom wing, 3 adds the science wing too. Each wing has its own monsters.
- **Checkpoints and Hardcore:** if the whole team is caught, the run goes back to the last checkpoint
  (night 1, 4 or 7): everyone keeps their gear and half their points. Tick **Hardcore** for the old rule:
  back to night 1 with nothing. (A wipe in Overtime ends the run.)
- **Continue saved run** appears once you've finished a night. The host's computer saves after every night
  report: the next night, the difficulty, upgrades, and each guard's points and item (by badge number).
  Survive night 9 and the run is won.

## How a night works

1. Walk from the gate to the guard room and clock in at the time clock: press E, type your badge number
   and press Enter (everyone in the session has to).
2. The lights go down and the clock starts at 12:00 AM. A night lasts 12 minutes.
3. Things change around the school: objects move, go missing or appear, and from night 2, figures.
   Watch the cameras, and when you spot something, press Tab and log where it is and what it is.
   You hear straight away whether you were right (✓ or ✗).
4. Someone has to go out on **tonight's round** (top of the screen): punch stations with amber lamps
   around the school. Hold E at one to punch it. The station's bell rings, and monsters nearby hear it.
5. At 6:00 AM the lights come back on. Clock out at the time clock within about 90 seconds.
6. The report shows everyone's pay: 100 for clocking out, +25 per correct log (+25 more for naming
   the monster), -10 per false report, +20 per station you punched, +50 each if the whole round was
   punched, -10 each per station missed, and -50 for every guard caught that night (everyone pays;
   a revive at a totem refunds it). It also shows the XP everyone earned.

**Work target:** from night 2 the team must earn (30 + 22 × night) points from work, plus 60% of that for each
extra guard: correct logs, named monsters and punched stations, minus false reports (not clocking out). Miss it and everyone gets a write-up; three write-ups
and the team is fired, back to the last checkpoint (night 1 on Hardcore). Shown under the clock and on the board.

**Power cuts:** from night 2 the power goes out now and then (more often later in the run). The lights
die, every camera shows NO POWER and the vending machine stops; only red emergency lights are left.
Reset the breaker in the custodian's closet (across the main hallway from the lobby) by holding E on it.
Whoever resets it is paid like a correct log.

**Nerve:** each guard's nerve (bottom left) drains in the dark, alone (with a team), near monsters and when a
teammate is caught, and recovers in the lit guard room, near teammates, or with a **thermos of coffee**
(vending machine, 30, +40). Low nerve: monsters notice you from up to 30% further away, and below 40 you
get hallucinations (footsteps behind you, whispers, knocking, a figure at the edge of your vision).

**Stamina:** running uses up stamina (about 6 seconds from full, shown at the bottom of the screen while it
isn't full). Run out and you're winded until it comes back up; an energy drink means no tiring for 30 seconds.

**Lockdown:** from night 6 (once a night; twice from night 9 and in Overtime) an alarm wails and for 30 seconds
every monster hunts the nearest guard it can reach. Hide, get to the guard room (before night 7), or outrun them.

**The last bell:** the front gate is chained shut all shift. At 5 AM on night 9 the intercom calls an
assembly, the alarm goes and doesn't stop, and every monster hunts, faster as six gets closer. The gate's
padlock key turns up deep in the school (the intercom says where): fetch it and bring it to the gate, and the
gate opens. Anyone standing out in the street is safe. Whoever's still inside at 6 AM is caught; one guard out
wins the run. If the key's carrier is caught, the key lies where they fell.

**Custom shift:** on the menu, tick shift notes (fog, full moon, camera faults...) to have every night of the
run, for your own challenge runs. Each still adds 15% XP.

**Joining late:** you can join a team mid-shift. You come in as a ghost (watch, leave cold spots, knock things
over; a revive totem can bring you back) and clock in properly from the next night.

**Base station:** sitting at a guard room desk, hold the walkie-talkie key (B) to call the whole team over the
radio, no walkie needed. Field guards need a walkie-talkie to call back. Careful: the call comes out loud wherever
your teammates are, and anything near them hears it too.

**Incident photos:** when someone's caught, the nearest camera that can see it takes a picture, and the night
report shows it.

**Close calls:** the first time a monster you've never logged catches you, you're knocked out instead and wake
in the guard room, shaken, knowing its rule. Playing solo, you also get one second wind a night (it costs 50).
The night report lists what was missed and which monsters were out.

**Moods:** from night 5 a monster can come in restless (faster, never stays put), keen (notices you from
further off) or drowsy (slower and duller). Log it correctly and you're told which.

**Marking:** Q (B on a controller) marks the spot you're looking at for the whole team, in your colour and
through walls, for 8 seconds; a mark on a monster reads MONSTER! (except the disguised ones). At a desk, Q flags
the camera instead.

**Throwing things:** eleven bits of clutter (a traffic cone, a basketball, a lunch tray, books...) lie about the
school. E picks one up, E again throws it; it clatters where it lands and draws the sound-hunting monsters. Ghosts
can knock clutter over (E while looking at it, every 20 seconds).

**Hiding:** a dozen slatted cupboards stand around the school (and wings). Press E to climb in and E to climb
out. Nothing can find you inside, and a chase ends when you hide, unless the monster saw you go in, in
which case it pulls you out.

**The phone:** from night 3 the front office phone rings once or twice a night. Answer it (E) within about
35 seconds for a tip-off about where something is out of place right now. Let it ring out and the power goes.

**The field guide:** log a monster correctly and it goes in your field guide (the button at the top of
your clipboard, and on the Records screen): what it looks like and how to survive it. Monsters you
haven't found yet show only a rumour. Once a monster is in your guide, you can name it in a Monster log
for +25 more. The guide is kept on your computer across runs.

**Overtime:** after winning night 9, the host can keep going instead of starting a new run: night 10,
11 and on, keeping points and gear, with one more monster and one more shift note each night. Your
furthest night is kept on the Records screen.

**Daily shift:** the menu's **Daily shift** button plays today's shift: one solo night that's the same for
everyone that day (night, conditions, round, bonus objective and monster plan are all seeded from the
date). Score is that night's pay. Your best per day and your streak of days are kept; the saved run
isn't touched. **Host today's daily** plays it as a team: friends join as usual, the score is everyone's
pay added up, and it goes on a Steam board for teams that size (team bests are kept apart from solo ones).

**Shift notes and bonus objectives:** from night 3 each night has one or two conditions (bonus objectives from night 2) (fog, faulty
wiring, old batteries, a full moon, an inspector's visit, sound carrying, a messy school, hazard pay,
camera faults, a lockdown drill, an early start),
each worth +15% XP. Every night also has a team bonus objective (nobody runs, nobody shouts, log N
things, name a monster, finish the round by 3 AM, nobody caught) worth +60 and +50 XP. Test conditions
with `--conditions=fog,batteries`.

**Ranks:** every night earns XP (even one where you're caught), kept across runs. There are eight ranks,
from Trainee to Legend of Westfield. Your rank is on your name tag and the menu, and some vending
machine items need a rank. Ranks and some achievements unlock hats (12 of them), picked on the menu
and worn for everyone, and the cameras, to see.

**Being scared:** when a monster is close, you hear your heartbeat speed up; a low drone comes in when
something is chasing nearby, and flashlights flicker near monsters. Getting caught turns you to face
whatever got you.

Logging the same thing twice isn't counted as a false report. Anomalies nobody logs fade after a while
(and can come back later). Points never drop below zero.

## The vending machine

Press E on the vending machine in the guard room to spend points. Purchases drop into the tray; press E
to pick them up. You can carry one thing at a time (shown in the bottom-right corner). Some items need
a rank (in brackets); the machine shows which.

- **Spectral camera kit (150, rank 2):** stand by a desk's chair with it and press G, then stay there for 10
  seconds. That desk's monitors switch to spectral feeds, which show the Ghost.
- **Lucky rabbit's foot (60):** carry it to a revive totem. Your roll revives on 5 in 6 instead of 4 in 6.
- **Guard room door kit (120):** stand in one of the guard room's two doorways and press E to fit a door,
  then E to open and shut it. From night 7 monsters can come into the guard room: a shut door holds
  them for about 15 seconds of banging, then gives way and hangs open for a minute.
- **Motion sensor (40):** press G to put it down. When a monster walks past, everyone hears which area.
- **Industrial glue trap (60, rank 2):** press G to put it down. The first monster to step on it is stuck for 20 seconds.
- **Portable camera (100, rank 3):** press G to set it up where you stand, facing the way you look. It appears on
  the guard room monitors (A / D to find it) until morning. Two at most per night.
- **Walkie-talkie (90):** press G to clip it on; it's yours for the run. Hold **B** to talk to everyone
  else with a radio, wherever they are (it sounds like a radio, with a click when a call comes in).
  But a radio blares when a call comes in: monsters near the guard *receiving* the call hear it as
  if that guard were talking. Think before you call someone who's hiding.
- **Pocket EMF reader (70, rank 2):** press G to clip it on; it's yours for the run. Its five lights (bottom
  left) climb as monsters get close, even ones you can't see. Most top out at 4 (harmless ones at 3), but
  the Ghost, the Specimen, the Understudy and the Other Cleaner push it to **EMF 5** up close: evidence,
  and the surest way to tell the Other Cleaner from the real one.
- **Thermos of coffee (30):** press G to drink it: +40 nerve.
- **Energy drink (25):** press G to drink it and run faster for 30 seconds.
- **Heavy-duty flashlight (80, rank 3):** press G to fit it. A longer, wider beam for the rest of the run.
- **Air horn (70, rank 4):** press G to blast it. Every monster within 15 metres freezes for 6 seconds,
  but everything in the school hears it.
- **Decoy radio (60, rank 2):** press G to put it down. Eight seconds later it blares music for twenty, and
  everything that hunts by sound goes to look.
- **Box of donuts for the district (300, rank 3):** press G to send it: the district forgets one write-up.

Sensors and traps are cleared away each morning.

Upgrades and points last for the whole run, and are lost if the whole team is caught (unless the host
ticked Hardcore, which sends a wiped team back to night 1 with nothing).

## Voice chat

Talk to your team in the game. Voices come from each guard and fade with distance, so if you split
up you can't hear each other. Ghosts hear the living, but only other ghosts hear a ghost.

- **Hold V to talk** (push to talk). In the Esc menu you can switch to **Open mic** (it sends whenever
  you're loud enough; set how loud with the slider and watch the level meter), pick your microphone,
  or turn voice chat off.
- While you're being heard, **TALKING** shows in the bottom left with how loud you are. Teammates who
  are talking get a marker over their name.
- **Monsters can hear you.** The louder you talk, the further it carries:
  - the **Lunch Lady** hears even a whisper close by, and a normal voice from across the cafeteria;
  - the **Librarian** treats talking near the stacks like noise: she shushes, then hunts;
  - the **Hall Monitor** chases anyone talking loudly in the halls.
  Sometimes the only way to stay alive is to keep quiet.
- **Walkie-talkies** (vending machine) let split-up guards talk at any distance, but every radio that
  receives a call is loud enough for monsters near it to hear.
- **The Understudy copies voices.** The host's game keeps the last few things each guard said (in
  memory only, never saved), and the Understudy plays one back now and then, in that guard's voice,
  from where it's standing. Untick **May copy my voice** in the Esc menu to opt out.

## Captions

Monsters' telling noises (a whistle, giggling, a flash charging, skittering...) are captioned at the bottom
right with which way they came from, e.g. "[Whistle blast, behind you]". Turn them off in the Esc menu.

## Sound

Everything is generated in code for now (no audio files): footsteps for every guard and monster
(you hear your teammates', and the monsters' too; running is louder), a low hum in the building at
night with the odd creak or thump, plus each monster's own noises. Real recordings come with the art pass.

## The Bell

From night 5 the school bell sometimes rings in the middle of the night (twice a night from night 8).
While it rings, every monster moves faster. Shut it off at the bell panel in the front office (press E),
or wait about a minute for it to stop.

## Monsters

Each night brings more monsters (1, 1, 2, 2, 3, 3, 4, 4, 5 over the nine nights, plus one per open wing),
picked from the ones that have unlocked and whose home is open at tonight's difficulty. They can't come into the guard room until night 7. Spot one on camera and log it
on your clipboard as "Monster" in that area for points.

| Monster | From night | Where | How it works |
|---|---|---|---|
| Hall Monitor | 1 | Main hallway | Walks the hallway. Leaves walkers alone, but chases anyone it sees running. |
| The Mascot | 1 | Gym | Steps off its stand. Only moves while nobody is looking at it, in person or on a monitor. |
| Lunch Lady | 2 | Cafeteria, kitchen | Blind and humming. Hears running from far away, walking only up close. |
| Locker Thing | 3 | Main hallway | Locker doors swing open. Walk past an open one and you're pulled in. Press E to shut them. |
| The Principal | 3 | Front office | Calls one guard to the office over the intercom. Get there within 45 seconds, or it comes to find you. |
| The Other Cleaner | 5 | Anywhere | A copy of the night cleaner, with no cart and its head at a wrong angle. Gets close, then attacks. Log it and it leaves. |
| The Student | 5 | Main hallway | A kid who asks you to follow them. Usually a trap, and the fake never shows on the cameras. Sometimes they're real (+25). |
| The Ghost | 5 | Anywhere | Invisible to your eyes. Drifts through walls toward the living and knocks out cameras it passes. Only spectral monitors show it, and the time clock lists one name too many. |
| The Photographer | 3 | Main building | An old flash camera for a face. When it sees you, its flash whines as it charges: look away or get out of sight before it fires, or you're blinded and it rushes you. |
| The Substitute | 1 | Classroom wing (difficulty 2+) | Takes the register when you come near: "Guard 2?" Look at it and press E to answer, or get detention. |
| The Twins | 2 | Rooms 101 and 102 (difficulty 2+) | Two girls who only move when neither is being watched, in person or on a monitor. Keep one on a screen at all times. |
| The Librarian | 2 | Library, West Hall (difficulty 2+) | Hates light and noise. Shine your flashlight on it or run nearby and it shushes you, then hunts you until it's dark and quiet. |
| The Nurse | 3 | Classroom wing (difficulty 2+) | Follows any guard who's on their own, slowly and steadily, with a heart monitor's beep. Stick together and she leaves you be. |
| The Crossing Guard | 1 | Science wing, east main hall (difficulty 3) | Blows its whistle and holds up a STOP sign at a "crossing". Don't move while the sign is up, or it runs you down. |
| The Coach | 2 | Locker rooms, East Hall (difficulty 3) | Whistles when it sees you: then run, and keep running until you're out of its sight. Walking or standing where it can see you gets you chased. |
| The Self-Portrait | 2 | Art room (difficulty 3) | A canvas painting one of the guards, a stage at a time (watch the Art Room camera). Finished, it catches them. Turn it to the wall (E) to wipe it. |
| The Specimen | 3 | Science lab (difficulty 3) | Crawls after you in the dark. Catch it in your flashlight and it hides in the ceiling for a while. |
| The Understudy | 4 | Locker rooms (difficulty 3) | Dressed as one of you, following at a distance. Stand still where it can see you and it steps in. It says things your teammates said, in their voices. Log it and it takes a bow. |

The real **night cleaner** works every night pushing a mop cart. They're harmless, and logging them is a false report.

**Getting caught:** you become a ghost. You can walk around and watch, but can't use anything, and
only other ghosts can see you. Press E to leave a cold spot where you're looking: a blue glow and a
chill the living can see, so you can still point things out to them. Press G to watch through a living teammate's eyes
(G again for the next, and back to yourself). Each death costs every guard 50 points. If the whole team is caught,
the run starts over from night 1.

**Revive totems:** three glowing stones are hidden around the school each night. A living guard can
use one for a dead teammate: 4 in 6 brings them back, 2 in 6 lets a shade out that hunts whoever rolled.

To try the vending machine straight away, add `--rich` (everyone starts with 1000 points).
To open the wings, add `--difficulty=2` or `--difficulty=3`. To start on a later night, add e.g. `--night=7`.
For example: `--solo --rich --fast-night --difficulty=3 --night=5`.

To test a whole night quickly, add `--fast-night` to the launch arguments (with `--solo` or `--host`):
the night then lasts about a minute.

## Testing multiplayer on one computer

You don't need a second person. Godot can open several copies of the game at once.

1. In the editor's top menu, open **Debug → Customize Run Instances...**
2. Tick **Enable Multiple Instances** and set the number to **2** (up to 4 works).
3. In the list below, type `--host` in the first instance's **Launch Arguments** box, and `--join` in the second's.
4. Click **OK**, then press **F5**.

Two game windows open side by side: the host on the left, the player who joins on the right. Click into a window to control that guard. Each guard has to clock in at the
time clock before the night starts.

Without launch arguments, each window shows the menu: choose **Host a game** in one and **Join** (address
`127.0.0.1`) in the other.

## Steam

Steam lobbies, invites, Steam names, rich presence and achievements are built in. They switch on
when the GodotSteam add-on is installed and Steam is running; see [STEAM.md](STEAM.md) for the
steps (App ID, GodotSteam, achievements, builds). Without Steam the game uses direct connections.

## Making a .exe to share

The project comes with a Windows export preset, so you can make a stand-alone game that friends can
run without Godot.

1. The first time only: in Godot, open **Editor → Manage Export Templates...** and click **Download and
   Install**. (It's a few hundred MB, and it has to match your Godot version.)
2. Open **Project → Export...**, pick **Windows Desktop**, and click **Export Project**.
3. Keep the suggested path, `builds/windows/NightShift.exe`, untick **Export With Debug**, and save.

That gives you a single `NightShift.exe`. There's a **Linux** preset too (for Steam Deck and Linux). Zip it and send it. The `builds` folder is ignored by git,
so builds never end up in the repository. Windows may warn about an unknown publisher the first time
it runs; that's normal for games that aren't signed (Steam builds don't show it).

## Controls

| Key | Action |
|---|---|
| W A S D / arrow keys | Walk |
| Shift | Run |
| Mouse | Look |
| F | Flashlight |
| E | Use. Press E on the time clock in the guard room to clock in and start the night. Hold E on punch stations and the breaker. |
| Esc | Menu: mouse sensitivity, field of view, brightness, volume, voice chat, captions, change keys, graphics (resolution, anti-aliasing, shadows, V-sync), fullscreen, leave the game (pauses solo; in a group the night keeps going) |
| Tab | Clipboard: log anything odd you spot (after clocking in); its Field guide button shows what you know about each monster |
| G | Use or put down what you're carrying (sensors, traps, energy drink, coffee, flashlight, EMF reader, air horn, decoy radio, donuts). As a ghost: watch through a teammate's eyes |
| V | Push to talk (voice chat) |
| B | Talk on the walkie-talkie (once you have one) |
| F11 | Switch between fullscreen and a window |

**With a controller** (Xbox names; PlayStation and Switch pads work the same way): left stick move,
right stick look, L3 run, A use, Y flashlight, X full-screen camera, Back clipboard, RB use item,
LB push to talk, RT walkie-talkie, Start menu. In menus, the D-pad moves and A selects; B goes back.

**At a guard room desk** (press E on a chair to sit):

| Key | Action |
|---|---|
| Mouse | Look at a monitor |
| A / D | Change which camera that monitor shows |
| Space, left click or E | Show that camera full screen (press again to go back) |
| 1 / 2 / 3 / 4 | Show that monitor full screen (numbers are on each monitor's frame) |
| F (full screen) | Set off that camera's speaker: an alarm that draws the Lunch Lady, the Librarian and the Hall Monitor to it (once a minute) |
| Q | Flag the camera you're watching full screen: everyone gets a message and a marker over that area for 20 seconds |
| S | Stand up |

## Project layout

- `scenes/` — the main scene and the player.
- `scripts/school_builder.gd` — builds the placeholder school from boxes, wings included. The floor plan is drawn at the top of the file.
- `scripts/player.gd` — the first-person guard.
- `scripts/main.gd` — the menu choices, hosting and joining, spawning a guard for each player.
- `scripts/menu.gd` — the start menu.
- `scripts/shift.gd` — clocking in and starting the night.
- `scripts/shift_lighting.gd` — the bright before-shift lighting and the lights-out sequence.
- `scripts/security_cameras.gd` — the CCTV cameras and their feeds.
- `scripts/guard_room.gd` — the 16 monitors, sitting at desks, and the full-screen camera view.
- `scripts/night.gd` — the night clock, when anomalies appear, checking logs, clocking out and pay.
- `scripts/anomalies.gd` — every anomaly and the props they move, hide or add.
- `scripts/clipboard.gd` — the clipboard (incident log).
- `scripts/report.gd` — the end-of-night report.
- `scripts/monster_director.gd` — which monsters come out each night, navigation, catching guards.
- `scripts/monsters/` — one script per monster.
- `scripts/lockers.gd` — the hallway locker doors and the Locker Thing.
- `scripts/shop.gd`, `scripts/vending_ui.gd` — the vending machine and carrying items.
- `scripts/totems.gd` — revive totems.
- `scripts/sfx.gd` — simple generated sounds (whistle, humming, lockers).
- `scripts/hud.gd` — crosshair, prompts and messages.
- `scripts/controls.gd` — key bindings.
- `scripts/guard_room_doors.gd` — the guard room's two fittable doors.
- `scripts/self_portrait.gd` — the art room canvas that paints a guard.
- `scripts/profile.gd` — your badge number and settings. `scripts/run_save.gd` — the saved run.
- `scripts/keypad_ui.gd` — the time clock keypad. `scripts/pause_menu.gd` — the Esc menu.
- `scripts/room_code.gd` — turning addresses into room codes.
- `scripts/rounds.gd` — the watchman rounds' punch stations. `scripts/power.gd` — power cuts and the breaker.
- `scripts/dread.gd` — heartbeat, chase drone, flashlight flicker and the jumpscare.
- `scripts/field_guide.gd` — the field guide's entries and page. `scripts/career.gd` — achievements, stats, XP and ranks.
