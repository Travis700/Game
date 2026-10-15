# Monster models (Meshy)

Every monster model is made **from its field-guide drawing** (`assets/guide/<Name>.png`), never
from a text description, so it looks exactly like the notebook:

1. **Clean copy.** Meshy image-to-image (`nano-banana-pro`, 9:16) with the drawing as the
   reference: "Extract the exact same character from this pencil drawing onto a plain flat white
   background, full body ... keep the design, proportions, clothing and face exactly as drawn ...
   realistic colour, front view, arms slightly away from the body." Check it against the drawing.
2. **3D.** image-to-3d from the clean copy: `--model-type smart-topology --target-polycount 15000
   --should-texture true --texture-resolution 2k --pose-mode a-pose`.
3. **Rig** (anything that walks): `rigging create --height-meters H`. Take
   `basic_animations.walking_glb_url` (mesh + walk) and `running_armature_glb_url` (run only).
4. **Slim and install:** `python3 tools/slim_glb.py walk.glb assets/models/<name>.glb 1024`, and copy
   the run file to `assets/models/<name>_run.glb`.
5. **Use it:** in the monster's `_build_body()`, `if use_model("<name>", height): return` (the
   block body stays as the fallback). Heights must clear the 2.4 m door frames.

Cost so far: about 45 credits a monster (9 clean copy, 15 model, 5 rig, plus retries).
