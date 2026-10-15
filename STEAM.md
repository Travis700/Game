# Getting Night Shift onto Steam

Everything in the game is done. Textures, sounds, field guide sketches, the icon and the store
capsules are in (see CREDITS.md); the monsters and props are still built from simple shapes, so a
models pass is what's left on the art side.
This page is the checklist for the Steam side: what's already built in, and the steps only
you can do (they need your Steamworks account).

## What's already in the game

- **Steam lobbies** (through the GodotSteam add-on): hosting creates a lobby with a 6-letter
  code; friends type the code or accept an invite (Esc menu → *Invite Steam friends*, or
  Steam's own *Join game*). Networking uses Steam's relay, so nobody forwards ports.
- **Steam names** over each guard, **rich presence** ("Night 4 of 9") in the friends list.
- **36 achievements** and **6 stats**, mirrored to Steam (list below).
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
| `HIDE_AND_SEEK` | Hide and seek | Be hidden in a cupboard when a lockdown ends. |
| `STEADY_NERVES` | Nerves of steel | Clock out of night 6 or later with your nerve above 70. |
| `EMF_FIVE` | Five lights | See an EMF reader hit 5. |
| `TRAINED` | Fully trained | Finish the training shift. |
| `LEGEND` | Legend of Westfield | Reach the top rank. |
| `CLOSE_CALL` | Close call | Get knocked out by a monster you'd never logged, and live to log it. |
| `TEAM_DAILY` | Team player | Finish a daily shift as a team. |
| `SECOND_CHANCE` | Second chance | Win a run on the last night's retry. |
| `DOWN_TO_THE_WIRE` | Down to the wire | Get out through the gate in the finale after 5:55 AM. |
| `LAST_BELL` | Last bell | Get out through the front gate in the final night's finale. |
| `OVERTIME` | Overtime | Survive a night of Overtime, after the ninth. |
| `WORKAHOLIC` | Workaholic | Survive night 15. |
| `GRADE_ONE` | Making the grade | Win a run at Grade 1 or higher. |
| `TOP_GRADE` | Top of the class | Win a run at Grade 5. |
| `CASE_FILES` | Case files | Collect 18 case file stamps. |
| `CASE_WORK` | Detective work | Collect 36 case file stamps. |
| `CASE_CLOSED` | Case closed | Collect every case file stamp (54). |
| `LIGHTS_ON` | Who turned out the lights? | Reset the breaker after a power cut. |

Stats (type INT, set by client): `nights_survived`, `runs_won`, `correct_logs`, `times_caught`,
`monsters_logged`, `stations_punched`.

Achievement icons are ready in `steam/achievements/`: `<API_NAME>.png` (unlocked) and
`<API_NAME>_locked.png`, 64×64 each, drawn in code (DejaVu Sans symbols, free licence).

## 3b. Leaderboards

The game creates its leaderboards itself the first time they're used (`findOrCreateLeaderboard`),
so there's nothing to set up beyond leaving client-side leaderboard writes allowed (the default,
not "trusted"):

- `daily_YYYYMMDD`: one per day, the daily shift's score (higher is better). The menu shows the
  player's friends' scores for today.
- `furthest_night`: the furthest Overtime night a player has clocked out of.
- `daily_YYYYMMDD_teamN`: a team of N's daily shift score (everyone's pay added up), when the daily is hosted.

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
- Store page: capsule art is ready in `steam/art/` (header 920×430, small 462×174, main 1232×706,
  library 600×900, all from `keyart_final.jpg`; the library capsule's title is set in Inter). Still to make: the library hero
  (3840×1240, needs a wider/higher-res key art), screenshots and a trailer.
- Content survey: mild horror, no gore. Multiplayer: online co-op 1-4, voice chat.
- Price: about US$5 as planned.

## 8. Store page copy (draft)

**Short description** (under 300 characters):

> Night security at Westfield High. Watch the cameras, log what's changed, punch your rounds,
> and learn the rules of eighteen things that walk the halls after dark. Nine nights. Up to four
> guards. Proximity voice chat, and one of them can copy your voice.

**About this game:**

> Your shift starts at midnight. The school is empty. Mostly.
>
> Sit at the guard room monitors and spot what's different: a bench that's moved, a box that
> wasn't there, a figure that's gone when you look again. Log it on your clipboard. Walk your
> round and punch the stations. Reset the breaker when the lights die. And learn the rules,
> because every monster in Westfield High has one. The Hall Monitor hates running. The Mascot
> only moves when nobody's watching. The Lunch Lady is blind, but she can hear you breathe.
>
> Survive nine nights, then get out through the front gate before the last bell.

**Features:**

- 1–4 player online co-op (Steam invites or room codes), or solo.
- Proximity voice chat and walkie-talkies, and a monster that mimics your teammates' voices.
- 18 monsters across three wings, each with its own rule, a field guide to fill in, and moods
  that change how hard they bite.
- A different night every time: random anomalies and places, shift notes (fog, a full moon,
  camera faults...), nightly bonus objectives and a work target from the district.
- A nine-night run with checkpoints and a finale, then endless Overtime. Hardcore if you dare.
- A daily shift that's the same for everyone, with friends' scores.
- Ranks, perks and hats to unlock, 36 achievements and career records.
- A guided training shift, close calls that teach you a monster's rule the first time, sound
  captions, controller support and rebindable keys.
