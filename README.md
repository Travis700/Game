# Night Shift

A first-person co-op light-horror game about night security at an American high school, made in Godot 4.
The full plan is in [DESIGN.md](DESIGN.md).

## Running it

1. Open Godot 4 (4.5 or newer).
2. In the Project Manager, click **Import**, choose this folder's `project.godot`, then **Import & Edit**.
3. Press **F5** (or the ▶ button at the top right) to play.

The first time you open it, Godot spends a few seconds importing. That's normal.

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
- `scripts/shift.gd` — clocking in and starting the night.
- `scripts/shift_lighting.gd` — the bright before-shift lighting and the lights-out sequence.
- `scripts/hud.gd` — crosshair, prompts and messages.
- `scripts/controls.gd` — key bindings.
