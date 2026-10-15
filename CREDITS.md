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

## Generated in code

`floor`, `ceiling`, `metal`, `locker`, `cork`, `board` textures: `tools/gen_textures.py`. Placeholder sounds:
`scripts/sfx.gd` (synthesised at runtime).
