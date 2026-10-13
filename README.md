# Night Shift

A first-person co-op light-horror game about night security at an American high school, made in Godot 4.
The full plan is in [DESIGN.md](DESIGN.md).

## Running it

1. Open Godot 4.7 or newer.
2. In the Project Manager, click **Import**, choose this folder's `project.godot`, then **Import & Edit**.
3. Press **F5** (or the ▶ button at the top right) to play.

The first time you open it, Godot spends a few seconds importing. That's normal.

The game opens on a menu: **Play solo**, **Host a game**, or **Join**.

## Testing multiplayer on one computer

You don't need a second person. Godot can open several copies of the game at once.

1. In the editor's top menu, open **Debug → Customize Run Instances...**
2. Tick **Enable Multiple Instances** and set the number to **2** (up to 4 works).
3. In the list below, type `--host` in the first instance's **Launch Arguments** box, and `--join` in the second's.
4. Click **OK**, then press **F5**.

Two game windows open (they may be stacked on top of each other, so drag one aside). The first hosts and the
second joins it automatically. Click into a window to control that guard. Each guard has to clock in at the
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

## Project layout

- `scenes/` — the main scene and the player.
- `scripts/school_builder.gd` — builds the placeholder school from boxes. The floor plan is drawn at the top of the file.
- `scripts/player.gd` — the first-person guard.
- `scripts/main.gd` — the menu choices, hosting and joining, spawning a guard for each player.
- `scripts/menu.gd` — the start menu.
- `scripts/shift.gd` — clocking in and starting the night.
- `scripts/shift_lighting.gd` — the bright before-shift lighting and the lights-out sequence.
- `scripts/hud.gd` — crosshair, prompts and messages.
- `scripts/controls.gd` — key bindings.
