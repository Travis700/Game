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
| Small Plastic Torch (the torch other players see in a guard's hand, darkened) | Abiyyu Panggalih (Abiyyu_xyz) |

## Models: Sketchfab (CC BY 4.0)

From https://sketchfab.com, licensed Creative Commons Attribution 4.0
(https://creativecommons.org/licenses/by/4.0/): free for commercial use as long as the authors are
credited, here and on the in-game Credits page. Fetched with `tools/sketchfab.py`, then changed for
the game: trimmed, turned to face +Z and (the fountain) decimated with `tools/prep_glb.py`, and
textures shrunk with `tools/slim_glb.py` (the cobwebs and crumpled papers are single pieces cut
from their packs; the first-person arm is the right one of the pair, its fingers posed round the torch in
Blender and the two baked into one model). In `assets/models/`:

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
| viewmodel_flashlight (the arm) | First Person hands rigged | David Fischer | https://sketchfab.com/3d-models/first-person-hands-rigged-547a45535f0c4fe787948f7a7a6a88db |
| viewmodel_flashlight (the torch) | Flashlight Swiss Arms | TheSolomon | https://sketchfab.com/3d-models/flashlight-swiss-arms-d996eb16f53f47df9b13ddbf8fd279bb |
| prop_toilet | Toilet | SushiKev3d | https://sketchfab.com/3d-models/toilet-868beb5a0e6840d7a1d647a42a5e5a8c |
| prop_sink | Bathroom Sink 01 | OliverMatheGames | https://sketchfab.com/3d-models/bathroom-sink-01-2568c7d17d894bc7974b62cf93da0b48 |
| prop_urinal | Urinal | ASA21 | https://sketchfab.com/3d-models/urinal-6bc39524d14f4dbfbe475d40ee7d9469 |
| prop_piano | Brown Cherry Wood Upright Piano | Glowbox 3D | https://sketchfab.com/3d-models/brown-cherry-wood-upright-piano-ae0529d9da834820b8a9c30ec0b6228f |
| prop_music_stand | Manhasset Music Stand | JeremyMichael | https://sketchfab.com/3d-models/manhasset-music-stand-17cff430f0354453b978bbd6d6f65e61 |
| prop_guitar_case (the case alone) | Old Guitar Case | berryjoy | https://sketchfab.com/3d-models/old-guitar-case-3d33cf9d086f4ca1866df0b488c6532c |
| hat_beanie | Beanie With Pom-Pom | lord cabal | https://sketchfab.com/3d-models/beanie-with-pom-pom-16569f9d12da457aa20884fb8ea97080 |
| hat_hard_hat | Hard Hat2 | Kristiyan Marinov | https://sketchfab.com/3d-models/hard-hat2-16001d2137214a63846f6ba68c9cbe94 |
| hat_cone | Traffic Cone | Silent | https://sketchfab.com/3d-models/traffic-cone-66a16ed89c964ce7a923216cf6400f51 |
| hat_top_hat | Top Hat | Ariss | https://sketchfab.com/3d-models/top-hat-959430b632f642cb9b732b9cd4b63751 |
| hat_bucket (worn upside down) | Plastic Bucket | MaX3Dd | https://sketchfab.com/3d-models/plastic-bucket-006d0f237b4141ac93960fa51d6f0634 |
| hat_party (stood upright) | party cone | ayumi ikeda | https://sketchfab.com/3d-models/party-cone-bf59a4f1a65647319a28a0ba170db992 |
| hat_night_owl (decimated; the strap is made in code) | Low Poly Modern Warfare's GPNVGs | haitrieu611601 | https://sketchfab.com/3d-models/low-poly-modern-warfares-gpnvgs-b1a9cf126aaa413cb7024a78bfea938c |
| hat_deerstalker (the hat alone, tinted brown) | Deerstalker Hat | alyx | https://sketchfab.com/3d-models/deerstalker-hat-9088fdc12c7e4b3ba05613adafbea8d2 |
| hat_fedora | Fedora Hat | alexnoiseless | https://sketchfab.com/3d-models/fedora-hat-008a0b9867c241a190eb5941f5b4dffb |
| hat_badge_cap | Police Hat | Dreadler | https://sketchfab.com/3d-models/police-hat-c9d5ffb346d44d64b009f2d0b16e4102 |

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

Made for Night Shift with ElevenLabs Sound Effects v2 through Creative Claw (creativeclaw.co), on
the project owner's account, then levelled and converted to mono OGG. Check the provider's current
terms for commercial use before release. In `assets/sounds/`: whistles (`whistle_*`), `lunch_hum`,
`monitor_beep`, `flash_charge`, `flash_pop`, `shush`, `hiss`, `skitter`, `giggle`, `wet_voice`,
`ghost_breath`, `phone_ring`, `school_bell`, `siren`, `intercom`, `punch_clock`, `power_down`,
`power_up`, `scream`, `stinger`, `ambience`, `heartbeat`, `door_bang`, `gate`, `air_horn`,
`hand_bell`, `radio`, `whispers`, `ball_bounce`, `principal_steps`, `rush_steps`, `squelch`, `vend`,
`menu_theme` (title music), `chase` (chase music), and the storm and the building at night: `rain`,
`thunder_*`, `pipe_knock_*`, `panting`, `tv_hum`, `swish` (a ball through the gym's net) (the hum made seamless and every one levelled to
-18 LUFS).

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
- Hats: the halo, the bulldog ears and the antennae (and the night-vision goggles' strap) are made in
  code from simple shapes (`scripts/hats.gd`).
- The first-person hand and flashlight (`assets/models/fp_hand_torch.glb`): made with Meshy from a
  generated reference image.
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
- Permanent Marker (the writing on the classroom whiteboards) by Font Diner, Apache License 2.0;
  only used to paint that texture, so it lives in `tools/fonts/` and isn't part of the game.
  All from Google Fonts; the first two are in `assets/fonts/`.

## Generated in code

`floor`, `ceiling`, `metal`, `locker`, `cork`, `board` textures: `tools/gen_textures.py`. The flashlight's
beam pattern (`assets/textures/flashlight_cookie.png`): `tools/gen_flashlight.py`. Fallback sounds (used where
there's no recording): `scripts/sfx.gd`, synthesised at runtime. The room tones (`room_fridge`, `room_vending`,
`room_fluorescent`, `clock_tick` in `assets/sounds/`) are synthesised by `tools/gen_room_tones.py`. The restroom and band
room sounds (`tap_water`, `toilet_flush`, `piano_*`) are synthesised by `tools/gen_fixture_sounds.py`.
