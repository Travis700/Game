# Getting Night Shift onto Steam

Everything in the game is done except the art and audio pass (textures, models, sounds).
This page is the checklist for the Steam side: what's already built in, and the steps only
you can do (they need your Steamworks account).

## What's already in the game

- **Steam lobbies** (through the GodotSteam add-on): hosting creates a lobby with a 6-letter
  code; friends type the code or accept an invite (Esc menu → *Invite Steam friends*, or
  Steam's own *Join game*). Networking uses Steam's relay, so nobody forwards ports.
- **Steam names** over each guard, **rich presence** ("Night 4 of 9") in the friends list.
- **15 achievements** and **5 stats**, mirrored to Steam (list below).
- **Falls back** to direct connections and room codes when Steam isn't running, so the
  game also works outside Steam (handy for testing).
- Settings (keys, mouse, FOV, volume, voice chat, graphics), a pause menu, How to play,
  Records and Credits (with the required Godot and GodotSteam licence notices), saving,
  a version number (`application/config/version` in project settings).
- Export presets for **Windows** and **Linux** (Steam Deck/Linux players).
- Saves and settings live in the user folder (`%APPDATA%\NightShift` on Windows,
  `~/.local/share/NightShift` on Linux), ready for Steam Cloud.

## 1. Steamworks

1. Join the Steamworks partner program (Steam Direct fee: US$100 per game) at
   partner.steamgames.com and create the app. You get an **App ID**.
2. In Godot: **Project → Project Settings → (Advanced) → night_shift → steam → app_id**: set it to
   your App ID (it's 480, Valve's test app "Spacewar", until then).
3. Edit **night_shift → credits → author** if you want a different name in the credits.

## 2. Install GodotSteam (one time)

1. In the Godot editor open the **AssetLib** tab, search for **GodotSteam** and install
   **GodotSteam GDExtension** (the 4.x version for Godot 4.4 and newer). It goes in `addons/godotsteam`.
2. Restart the editor. Nothing else is needed: the game finds GodotSteam by itself
   (`scripts/steam_service.gd`). If it isn't installed, the menu says "Steam isn't running".
3. To test from the editor, run the Steam client and put a file called `steam_appid.txt`
   containing your App ID (or 480) in the project folder. **Don't ship that file**: Steam
   provides the App ID when players start the game from Steam.

Test with two Steam accounts (two PCs, or a friend): host, share the 6-letter code, join.

## 3. Achievements and stats (Steamworks → Stats & Achievements)

Create these with exactly these API names. Mark them as set by the client.

| API name | Name | How to get it |
|---|---|---|
| `FIRST_SHIFT` | First shift | Clock out after your first night. |
| `NIGHT_FIVE` | Halfway there | Survive night 5. |
| `RUN_WON` | Nine nights | Survive all nine nights. |
| `RUN_WON_SOLO` | Night owl | Survive all nine nights on your own. |
| `RUN_WON_D3` | The whole school | Survive all nine nights at difficulty 3. |
| `SHARP_EYES` | Sharp eyes | Log 10 things correctly in one night. |
| `BY_THE_BOOK` | By the book | Log at least 5 things correctly in a night with no false reports. |
| `MONSTER_EXPERT` | Field guide | Log every kind of monster at least once (across all your runs). |
| `GOOD_SAMARITAN` | Good Samaritan | Walk a real lost student to safety. |
| `BACK_FROM_DEAD` | Not dead yet | Be brought back at a revive totem. |
| `LIFESAVER` | Lifesaver | Bring a teammate back at a revive totem. |
| `PRESENT` | Present! | Answer the Substitute's register. |
| `ART_CRITIC` | Art critic | Turn the Self-Portrait to the wall. |
| `BIG_SPENDER` | Big spender | Spend 1000 points at the vending machine in one run. |
| `HOLD_THE_DOOR` | Hold the door | Clock out of a night where a monster battered a guard room door. |
| `FULL_ROUND` | Full round | Punch every station on a night's round. |
| `DAILY` | Clocking on | Finish a daily shift. |
| `DAILY_STREAK` | Regular | Play the daily shift five days in a row. |
| `OVERTIME` | Overtime | Survive a night of Overtime, after the ninth. |
| `WORKAHOLIC` | Workaholic | Survive night 15. |
| `LIGHTS_ON` | Who turned out the lights? | Reset the breaker after a power cut. |

Stats (type INT, set by client): `nights_survived`, `runs_won`, `correct_logs`, `times_caught`,
`monsters_logged`, `stations_punched`.

Achievement icons are part of the art pass (64×64 locked and unlocked versions each).

## 3b. Leaderboards

The game creates its leaderboards itself the first time they're used (`findOrCreateLeaderboard`),
so there's nothing to set up beyond leaving client-side leaderboard writes allowed (the default,
not "trusted"):

- `daily_YYYYMMDD`: one per day, the daily shift's score (higher is better). The menu shows the
  player's friends' scores for today.
- `furthest_night`: the furthest Overtime night a player has clocked out of.

## 4. Rich presence

Upload `steam/rich_presence_english.vdf` under **Steamworks → Community → Rich Presence
Localization**. It shows the game's status text in the friends list.

## 5. Steam Cloud (optional but recommended)

**Steamworks → Application → Steam Cloud**: set a byte quota (1 MB is plenty) and add
root-overrides/paths for the save folder:

- Windows: `WinAppDataRoaming` → `NightShift`, pattern `*.cfg` and `*.json`
- Linux: `LinuxXdgDataHome` → `NightShift`, same patterns

## 6. Builds and depots

1. Install export templates once (Editor → Manage Export Templates → Download and Install).
2. Project → Export → **Windows Desktop** → Export Project (untick *Export With Debug*):
   `builds/windows/NightShift.exe`. Copy the GodotSteam add-on's Windows library and
   `steam_api64.dll` next to the exe if the export doesn't include them (GodotSteam's
   instructions cover this).
3. Same for **Linux** → `builds/linux/NightShift.x86_64` (with `libsteam_api.so`).
4. Upload each folder as a depot with SteamPipe (the Steamworks SDK's `steamcmd` / ContentBuilder),
   and set the launch options to `NightShift.exe` (Windows) and `NightShift.x86_64` (Linux).

## 7. Before release

- Play a full run solo, and a full run with 2-4 people over Steam.
- Store page: capsule art, screenshots, trailer and description (after the art pass).
- Content survey: mild horror, no gore. Multiplayer: online co-op 1-4, voice chat.
- Price: about US$5 as planned.
