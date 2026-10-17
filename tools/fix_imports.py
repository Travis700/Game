"""Sets every texture under assets/textures/ to import for 3D: VRAM compressed (BPTC for colour,
RGTC for normal maps) with mipmaps. Godot only does this by itself when a texture is first seen
in a 3D scene in the editor; this project is built headless. Run, then reimport:
python3 tools/fix_imports.py && godot --headless --import
"""
import glob, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
for path in glob.glob(os.path.join(HERE, '..', 'assets', 'textures', '**', '*.import'), recursive=True):
    text = open(path).read()
    normal = re.search(r'_n\.(jpg|png)\.import$', path) is not None
    text = re.sub(r'compress/mode=\d', 'compress/mode=2', text)
    text = re.sub(r'mipmaps/generate=\w+', 'mipmaps/generate=true', text)
    text = re.sub(r'compress/high_quality=\w+', 'compress/high_quality=%s' % ('false' if normal else 'true'), text)
    text = re.sub(r'compress/normal_map=\d', 'compress/normal_map=%d' % (1 if normal else 0), text)
    open(path, 'w').write(text)
