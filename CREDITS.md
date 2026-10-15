# Asset credits and licences

Every third-party asset in Night Shift is listed here with its source and licence. Anything not
listed was made for the game (in code, or by `tools/gen_textures.py`).

## Textures: Poly Haven (CC0, public domain)

From https://polyhaven.com, licensed CC0: free for any use, commercial included, no attribution
required (credited anyway, with thanks). 1k diffuse + OpenGL normal maps, in `assets/textures/`.

| File | Poly Haven asset | Authors |
| --- | --- | --- |
| wall | concrete_pavement | Charlotte Baglioni |
| brick | red_brick_03 | Rob Tuytel |
| concrete | brushed_concrete | Dario Barresi, Dimitrios Savva |
| asphalt | clean_asphalt | Dimitrios Savva |
| grass | grass_ground | Charlotte Baglioni |
| gym_floor | laminate_floor_02 | Dario Barresi, Charlotte Baglioni |
| wood | wood_floor | Dimitrios Savva |
| desk | kitchen_wood | Rob Tuytel |

## Sounds: Kenney (CC0, public domain)

From https://kenney.nl (Impact Sounds, Interface Sounds and RPG Audio packs), licensed CC0. In
`assets/sounds/`: footsteps (`step_concrete_*`, `step_grass_*`, `step_wood_*`), `creak_*`,
`door_open_*`, `door_close_*`, `latch`, `metal_click`, `land_*` (thrown clutter), `slam_metal`,
`ui_*`, `glitch_*`, `paper_*`, `cloth_*`, `switch`, `ping`.

## Sounds: generated for this game

Made for Night Shift with ElevenLabs Sound Effects v2 through Creative Claw (creativeclaw.co),
on the project owner's account, then levelled and converted to mono OGG. Check the provider's
current terms for commercial use before release. In `assets/sounds/`: whistles (`whistle_*`),
`lunch_hum`, `monitor_beep`, `flash_charge`, `flash_pop`, `shush`, `hiss`, `skitter`, `giggle`,
`wet_voice`, `ghost_breath`, `phone_ring`, `school_bell`, `siren`, `intercom`, `punch_clock`,
`power_down`, `power_up`, `scream`, `stinger`, `ambience`, `heartbeat`, `door_bang`, `gate`,
`air_horn`, `hand_bell`, `radio`, `whispers`, `ball_bounce`, `principal_steps`, `rush_steps`,
`squelch`, `vend`, `menu_theme` (title music), `chase` (chase music).

## Field guide illustrations: generated for this game

`assets/guide/`: R. Hale's notebook sketches. The Hall Monitor was made with SpriteCook
(spritecook.ai, asset 081469bf-dbaa-47a1-ae73-027395576c47, see `spritecook-assets.json`); it was
then the style reference for two 3x3 sheets made with Google Nano Banana 2 through Creative Claw,
cut into the other 17 monsters and the 0451 badge. Check each provider's current terms for
commercial use before release.

## 3D models: generated for this game

- `assets/models/hall_monitor.glb`, `lunch_lady.glb`, `principal.glb` (and their `_run.glb`
  animations): made with Meshy from the field-guide drawings (clean copy, image to 3D, auto-rig
  with walking and running clips); see `tools/MESHY.md`.
- `assets/models/mascot.glb`: the Mascot, made with Meshy (meshy.ai) from a text description,
  remeshed to about 12,500 triangles; textures shrunk to 1024 px JPEG by
  `tools/slim_glb.py`. Make sure the Meshy account's plan gives commercial rights before
  release (free-plan output is CC BY 4.0 and needs a credit line).

## Icon, key art and store capsules

`icon.png` / `icon.ico` were made with SpriteCook (see `spritecook-assets.json`). The key art
`steam/art/keyart_final.jpg` (store capsules and the boot splash) is the project owner's corrected
version of a SpriteCook image (`keyart_raw.png`, superseded). Capsule titles are set in Inter (SIL Open Font Licence).

## Generated in code

`floor`, `ceiling`, `metal`, `locker`, `cork`, `board` textures: `tools/gen_textures.py`. Fallback sounds (used where
there's no recording): `scripts/sfx.gd`, synthesised at runtime.
