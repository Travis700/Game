# Night Shift

A first-person co-op light-horror game about night security at an American high school, made in Godot 4.
The full plan is in [DESIGN.md](DESIGN.md).

## Running it

1. Open Godot 4.7 or newer.
2. In the Project Manager, click **Import**, choose this folder's `project.godot`, then **Import & Edit**.
3. Press **F5** (or the ▶ button at the top right) to play.

The first time you open it, Godot spends a few seconds importing. That's normal.

The game opens on a menu: **Play solo**, **Host a game**, or **Join**.

### The menu

- **Your employee badge** is a number this computer picked for you the first time you played. You type it
  into the time clock to clock in, and your saved points are linked to it.
- **Difficulty** sets how much of the school is open. *Auto* picks one level per guard.
  1 is the main building, 2 adds the classroom wing, 3 adds the science wing too. Each wing has its own monsters.
- **Keep gear if the whole team is caught:** upgrades and carried items survive a restart (points don't).
- **Continue saved run** appears once you've finished a night. The host's computer saves after every night
  report: the next night, the difficulty, upgrades, and each guard's points and item (by badge number).
  Survive night 9 and the run is won.

## How a night works

1. Walk from the gate to the guard room and clock in at the time clock: press E, type your badge number
   and press Enter (everyone in the session has to).
2. The lights go down and the clock starts at 12:00 AM. A night lasts 12 minutes.
3. Things change around the school: objects move, go missing or appear, and from night 2, figures.
   Watch the cameras, and when you spot something, press Tab and log where it is and what it is.
4. At 6:00 AM the lights come back on. Clock out at the time clock within about 90 seconds.
5. The report shows everyone's pay: 100 for clocking out, +25 per correct log, -10 per false report.

## The vending machine

Press E on the vending machine in the guard room to spend points. Purchases drop into the tray; press E
to pick them up. You can carry one thing at a time (shown in the bottom-right corner).

- **Spectral camera kit (150):** stand at a desk's chair with it and press E, then stay there for 10
  seconds. That desk's monitors switch to spectral feeds, which show the Ghost.
- **Lucky rabbit's foot (60):** carry it to a revive totem. Your roll revives on 5 in 6 instead of 4 in 6.

Upgrades and points last for the whole run, and are lost if the whole team is caught (unless the host
ticked "Keep gear", which keeps upgrades and items).

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
| The Substitute | 1 | Classroom wing (difficulty 2+) | Takes the register when you come near: "Guard 2?" Look at it and press E to answer, or get detention. |
| The Librarian | 2 | Library, West Hall (difficulty 2+) | Hates light and noise. Shine your flashlight on it or run nearby and it shushes you, then hunts you until it's dark and quiet. |
| The Nurse | 3 | Classroom wing (difficulty 2+) | Follows any guard who's on their own, slowly and steadily, with a heart monitor's beep. Stick together and she leaves you be. |

The real **night cleaner** works every night pushing a mop cart. They're harmless, and logging them is a false report.

**Getting caught:** you become a ghost. You can walk around and watch, but can't use anything, and
only other ghosts can see you. Each death costs every guard 50 points. If the whole team is caught,
the run starts over from night 1.

**Revive totems:** three glowing stones are hidden around the school each night. A living guard can
use one for a dead teammate: 4 in 6 brings them back, 2 in 6 lets a shade out that hunts whoever rolled.

To try the vending machine straight away, add `--rich` (everyone starts with 1000 points).

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

## Controls

| Key | Action |
|---|---|
| W A S D / arrow keys | Walk |
| Shift | Run |
| Mouse | Look |
| F | Flashlight |
| E | Use. Press E on the time clock in the guard room to clock in and start the night. |
| Esc | Free the mouse (click to look around again) |
| Tab | Clipboard: log anything odd you spot (after clocking in) |
| F11 | Switch between fullscreen and a window |

**At a guard room desk** (press E on a chair to sit):

| Key | Action |
|---|---|
| Mouse | Look at a monitor |
| A / D | Change which camera that monitor shows |
| Space, left click or E | Show that camera full screen (press again to go back) |
| 1 / 2 / 3 / 4 | Show that monitor full screen (numbers are on each monitor's frame) |
| S | Stand up |

## Project layout

- `scenes/` — the main scene and the player.
- `scripts/school_builder.gd` — builds the placeholder school from boxes. The floor plan is drawn at the top of the file.
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
