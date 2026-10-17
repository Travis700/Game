# Asset credits and licences

Every third-party asset in Night Shift is listed here with its source and licence. Anything not
listed was made for the game (in code, or by `tools/gen_textures.py`).

## Textures: Poly Haven (CC0, public domain)

From https://polyhaven.com, licensed CC0: free for any use, commercial included, no attribution
required (credited anyway, with thanks). 1k diffuse + OpenGL normal maps, in `assets/textures/`.

| File | Poly Haven asset | Authors |
| --- | --- | --- |
| desk | kitchen_wood | Rob Tuytel |

## Textures: ambientCG (CC0, public domain)

From https://ambientcg.com, licensed CC0, fetched at 2K with `tools/ambientcg.py` (colour, OpenGL
normal map, and roughness + ambient occlusion packed into `<name>_orm.jpg`). In `assets/textures/`:

| File | ambientCG asset |
| --- | --- |
| ceiling (acoustic tiles) | OfficeCeiling001 |
| wall (block, painted cream for the school) | Bricks066 |
| terrazzo (halls and lobby) | Terrazzo005 |
| checker (cafeteria, recoloured cream and slate) | Tiles014 |
| quarry (kitchen, recoloured terracotta) | Tiles047 |
| carpet (library) | Carpet012 |
| white_tile (locker rooms, nurse) | Tiles107 |
| gym_floor | WoodFloor040 |
| brick | Bricks085 |
| concrete | Concrete034 |
| wood | WoodFloor051 |
| grass | Grass004 |
| asphalt | Asphalt033 |
| door_wood (the doors) | Wood058 |

## Models: Poly Haven (CC0, public domain)

From https://polyhaven.com, licensed CC0, fetched with `tools/polyhaven.py` (1k glTF) and slimmed
with `tools/slim_glb.py`. In `assets/models/` as `prop_<asset>.glb`.

| Poly Haven asset | Authors |
| --- | --- |
| Hanging Industrial Lamp | Kuutti Siitonen |
| Wall Clock | PierreB3D |
| Fire Alarm | Slinc |
| Plastic Crate 01 | PierreB3D |
| Steel Frame Shelves 01 | James Ray Cock |
| Classic Laptop | Arrangemonk |
| Hanging Picture Frame 01 | James Ray Cock |
| Shelf 01 | Gabriel Radić |
| Desk Lamp Arm 01 | Yann Kervran, Kuutti Siitonen |
| Old Bed Frame | Luca B |
| Medical Box | Ulan Cabanilla |
| Metal Stool 02 | Ulan Cabanilla |
| Industrial Microscope | Lukas Walzer |
| Vintage Microscope | Luis José Fernández Rodríguez |
| Chemistry Set | Jiří Ptáček |
| Bunsen Burner | BKS |
| Painted Wooden Stool | Kirill Sannikov |
| Spray Paint Bottles | James Ray Cock |
| Wooden Display Shelves 01 | James Ray Cock |
| Ceramic Vase 01 | James Ray Cock |
| Planter Pot Clay | Amal Kumar |
| Industrial Storage Cart | Jule Bielitz |
| Electric Stove | Kuutti Siitonen |
| Vintage Microwave | Adam Nekola |
| Plastic Container | PierreB3D |
| Cardboard Box 01 | Rahul Chaudhary |
| Television 02 | Benny Weimer |
| Plastic Broom | L |
| Multi Cleaner 5 Litre | James Ray Cock |
| Covered Car | MP |
| Wooden Ladder | Miroslav Turura |
| Binder Notebook | DaDrood |
| Clipboard | ProgrammerOnCoffee |
| Vintage Stapler | Mateusz Sadek |
| Food Apple 01 | Oliver Harries |
| Drawer Cabinet | Ulan Cabanilla |
| Security Camera 01 | Alexander Otterbeck, Yann Kervran |
| Pot Enamel 01 | Kuutti Siitonen |
| Wooden Cutting Board | Kuutti Siitonen |
| Metal Jug | Anzor Lezhava |
| Street Lamp 01 | Josh Dean |
| Painted Wooden Bench | Kirill Sannikov |

## Models: Sketchfab (CC BY 4.0)

From https://sketchfab.com, licensed Creative Commons Attribution 4.0
(https://creativecommons.org/licenses/by/4.0/): free for commercial use as long as the authors are
credited, here and on the in-game Credits page. Fetched with `tools/sketchfab.py`, then changed for
the game: trimmed, turned to face +Z and (the fountain) decimated with `tools/prep_glb.py`, and
textures shrunk with `tools/slim_glb.py` (the cobwebs and crumpled papers are single pieces cut
from their packs). In `assets/models/`:

| File | Sketchfab model | Author | Link |
| --- | --- | --- | --- |
| prop_student_desk | School chair | N-Gon | https://sketchfab.com/3d-models/school-chair-9c35c03f6d614aa5874494e908a41904 |
| prop_cafeteria_table | School Cafeteria Table | Avot | https://sketchfab.com/3d-models/school-cafeteria-table-e0a0be3011da4e19963467d20daeaf61 |
| prop_vending_machine | Vending Machine | Emanuel Silva | https://sketchfab.com/3d-models/vending-machine-4bfb493631f84f8a9adc00bb69831000 |
| prop_trash_can | Trash Can | Yury Misiyuk | https://sketchfab.com/3d-models/trash-can-0ad3407cd8104ba58f71885c0e58ca9a |
| prop_school_chair | School Chair | heloisebelisle | https://sketchfab.com/3d-models/school-chair-4c846ff6d8d74b25b7da7078c091c365 |
| prop_teacher_desk | Teachers Desk | cig3d | https://sketchfab.com/3d-models/teachers-desk-9ee8608e76704de7aa67d022c81e42cc |
| prop_drinking_fountain | Drinking Fountain | FLUXIUM3D | https://sketchfab.com/3d-models/drinking-fountain-69f0147a64354ba9aaf2f63e86169322 |
| prop_fire_extinguisher | Fire Extinguisher | Loïc | https://sketchfab.com/3d-models/fire-extinguisher-5676b179b3b744c0aaae53a3dcea2300 |
| prop_bulletin_board | Bulletin Board | lydia.la | https://sketchfab.com/3d-models/bulletin-board-9a2ef796667449cfbace0ff446557738 |
| prop_whiteboard | Whiteboard | Darren McNerney 3D | https://sketchfab.com/3d-models/whiteboard-d92927c453a14702bb5b5ba3fb6a044a |
| prop_projector | Projector | GokouFG | https://sketchfab.com/3d-models/projector-0f1c6b1fa0bd4d5bbe5ac10e9eee31de |
| prop_tree | Realistic Tree | Daniel | https://sketchfab.com/3d-models/realistic-tree-d989c0f801d847b9a74992ec4ddcfdfc |
| prop_park_bench | Park Bench | RBG_illustrations | https://sketchfab.com/3d-models/park-bench-2ee2bc87756d4bf0932d83ab860ddb8f |
| prop_picnic_table | Wooden Picnic Table - 4096px² | Mark Peters | https://sketchfab.com/3d-models/wooden-picnic-table-4096px2-c7d39c0bcee04553894d0de081d3aa9c |
| prop_bike_rack | Bike Rack | Igrium | https://sketchfab.com/3d-models/bike-rack-bb71ca627c5c44aba68c610fbfa24cd2 |
| prop_dumpster | Dumpster | Chenchanchong | https://sketchfab.com/3d-models/dumpster-2d634c793e4c4b948c58cc07c33f1c3b |
| prop_fire_hydrant | Fire Hydrant | Denko | https://sketchfab.com/3d-models/fire-hydrant-91acc6e821a74ed3a3c0ae72643958a5 |
| prop_school_bus | School Bus | Macaroni | https://sketchfab.com/3d-models/school-bus-a959ee8ce17d434f9fdbc93cad199a21 |
| prop_old_computer | Old Computer, Mouse and Keyboard Low Poly | lucasalic00 | https://sketchfab.com/3d-models/old-computer-mouse-and-keyboard-low-poly-a41e98d3650e4d8ba544b6a589f3f4f3 |
| prop_book_stack | Simple Stack Of Books (Game Assets) | Skyler | https://sketchfab.com/3d-models/simple-stack-of-books-game-assets-1db71c06c6f441b5b82daff935c3e142 |
| prop_coffee_mug | Coffee Mug (School Project) | Ole Gunnar Isager | https://sketchfab.com/3d-models/coffee-mug-school-project-5f5ccee1514c440887c072fae8e0d699 |
| prop_radiator | Radiator | KurtSteiner | https://sketchfab.com/3d-models/radiator-1888639ee3fb473199c081b0a00ce71f |
| prop_water_cooler | Water Cooler | Glitching Light | https://sketchfab.com/3d-models/water-cooler-3ef7b240b2a0424c98f55be3a4feed29 |
| prop_pencil_cup | CC0 - Pencil Holder | plaggy | https://sketchfab.com/3d-models/cc0-pencil-holder-af1d78cea5b74f7bbe524b51693ce725 |
| prop_printer | Small Officer Desk Printer | Replexx | https://sketchfab.com/3d-models/small-officer-desk-printer-acf3a40a0da245c9b4bf70d1b8377723 |
| prop_milk_carton | Carton of Milk 4K PBR | GooPy | https://sketchfab.com/3d-models/carton-of-milk-4k-pbr-0db687e8e18b49f5a6458ad5a75f057b |
| prop_cobweb_corner, prop_cobweb_corner_b, prop_cobweb_sag | Free Pack - Cobwebs | PolyOne Studio | https://sketchfab.com/3d-models/free-pack-cobwebs-7092699196a94b4b9953225caadc23ca |
| prop_duffel_bag | Low-poly Duffel Bag | Station_09_studios | https://sketchfab.com/3d-models/low-poly-duffel-bag-6058bb33f14c4d86a4c45ee0e57499d7 |
| prop_paper_towel | Paper Towel Dispenser | Carolyn Wong | https://sketchfab.com/3d-models/paper-towel-dispenser-15c4a2aa81994874a8dfc8038339b08d |
| prop_paper_ball, prop_paper_ball_b, prop_paper_scrap | Dirty Crumpled Pieces of Paper - 6 Piece Set | Sunbox Games | https://sketchfab.com/3d-models/dirty-crumpled-pieces-of-paper-6-piece-set-7f8b8e5eeb74428f9f326a398baccb5d |
| prop_tissue_box | Tissue Box - Household Props Challenge | zhixson | https://sketchfab.com/3d-models/tissue-box-household-props-challenge-2bd98e8ea09f49bd85453a927011d31d |
| prop_pa_speaker | School wall mount speaker | Zixel | https://sketchfab.com/3d-models/school-wall-mount-speaker-170610808bad49a2b202a0284f1e6111 |
| prop_toolbox | Toolbox Photoscan LOWPOLY | EFX | https://sketchfab.com/3d-models/toolbox-photoscan-lowpoly-52c36208571b4664a89d8607f58c6a45 |
| prop_box_fan | animal company - box fan | Romeo rios vr | https://sketchfab.com/3d-models/animal-company-box-fan-23307ce851cc47cfaa91d65346ae3508 |
| prop_towel | Folded Towel | Nicothin | https://sketchfab.com/3d-models/folded-towel-c5f9e72edf7d4b5eaa2ec9b95c3b099d |

## Long grass: made for this game

The grass outside is made in code (`scripts/grass.gd`, `shaders/grass.gdshader`): one tuft of
blades, drawn thousands of times.

## School art: made for this game

The posters, the locker doors, the library's book spines, the art class's paintings, the periodic table, the
fire evacuation plans, the nurse's eye chart, the missing-guard flyer and the cafeteria menu in
`assets/textures/school/` are drawn by `tools/gen_school_art.py` (text in Bebas Neue and Special Elite, see
Fonts). The classroom floor's vinyl tile (`assets/textures/floor*.jpg`) is generated by `tools/gen_vct.py`,
and the front hedges' leaves (`assets/textures/hedge*.jpg`) by `tools/gen_hedge.py`.

## Gym art: made for this game

The court markings, scoreboard face, banners, basketball skin and net in `assets/textures/gym/`
are drawn by `tools/gen_gym_art.py` (text in Bebas Neue, see Fonts).

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

- Every monster model in `assets/models/` (and the `_run.glb` animations): made with Meshy from the
  field-guide drawings (clean copy, image to 3D, auto-rig with walking and running clips); see
  `tools/MESHY.md`. The Principal's face is the notebook drawing itself, smudged.
- The guard (`guard.glb`, its run and sit clips and `guard_uniform_*.jpg` shirt colours): made with
  Meshy from the key art.
- Props (`assets/models/prop_*.glb`, those not credited above): made with Meshy from generated
  reference images (time clock, office chair and the anomaly props).
- Make sure the Meshy account's plan gives commercial rights before release (free-plan output is
  CC BY 4.0 and needs a credit line).

## Icon, key art and store capsules

`icon.png` / `icon.ico` were made with SpriteCook (see `spritecook-assets.json`). The key art
`steam/art/keyart_final.jpg` (store capsules and the boot splash) is the project owner's corrected
version of a SpriteCook image (`keyart_raw.png`, superseded). Capsule titles are set in Inter (SIL Open Font Licence).

## Fonts

- Bebas Neue (titles) by Dharma Type, SIL Open Font License 1.1.
- Special Elite (the clipboard and notices) by Astigmatic, Apache License 2.0.
  Both from Google Fonts, in `assets/fonts/`.

## Generated in code

`floor`, `ceiling`, `metal`, `locker`, `cork`, `board` textures: `tools/gen_textures.py`. The flashlight's
beam pattern (`assets/textures/flashlight_cookie.png`): `tools/gen_flashlight.py`. The storm's `rain` and
`thunder_*`, the heating's `pipe_knock_*` and a winded guard's `panting` in `assets/sounds/`: synthesised by
`tools/gen_night_sounds.py`. Fallback sounds (used where there's no recording): `scripts/sfx.gd`, synthesised
at runtime.
