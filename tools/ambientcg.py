"""Fetches a CC0 material from ambientCG into assets/textures/: ambientcg.py AssetId name [size]

Writes <name>.jpg (colour), <name>_n.jpg (OpenGL normal map) at `size` px (default 2048), and
<name>_orm.jpg (ambient occlusion in red, roughness in green) at half that, and prints the
material's real-world size so the builder can tile it at the right scale.
"""
import io, json, os, sys, time, urllib.request, zipfile
from PIL import Image

asset, name = sys.argv[1], sys.argv[2]
size = int(sys.argv[3]) if len(sys.argv) > 3 else 2048
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'assets', 'textures')


def get(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'NightShift-asset-fetch/1.0'})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(request, timeout=120) as reply:
                return reply.read()
        except OSError:
            if attempt == 4:
                raise
            time.sleep(2 ** attempt)


def square(image):
    """Repeats a rectangular texture along its short side so it tiles as a square."""
    w, h = image.size
    if w == h:
        return image
    side = max(w, h)
    out = Image.new(image.mode, (side, side))
    for y in range(0, side, h):
        for x in range(0, side, w):
            out.paste(image, (x, y))
    return out


info = json.loads(get('https://ambientcg.com/api/v2/full_json?id=%s&include=downloadData,dimensionsData' % asset))
found = info['foundAssets'][0]
zipped = zipfile.ZipFile(io.BytesIO(get('https://ambientcg.com/get?file=%s_2K-JPG.zip' % asset)))
maps = {}
for entry in zipped.namelist():
    for key in ('Color', 'NormalGL', 'Roughness', 'AmbientOcclusion'):
        if entry.endswith('_%s.jpg' % key):
            maps[key] = square(Image.open(io.BytesIO(zipped.read(entry))))

colour = maps['Color'].convert('RGB').resize((size, size), Image.LANCZOS)
colour.save(os.path.join(OUT, name + '.jpg'), quality=92)
maps['NormalGL'].convert('RGB').resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name + '_n.jpg'), quality=95)
half = size // 2
rough = maps['Roughness'].convert('L').resize((half, half), Image.LANCZOS)
ao = maps['AmbientOcclusion'].convert('L').resize((half, half), Image.LANCZOS) if 'AmbientOcclusion' in maps \
    else Image.new('L', (half, half), 255)
Image.merge('RGB', (ao, rough, Image.new('L', (half, half), 0))).save(os.path.join(OUT, name + '_orm.jpg'), quality=92)
print(name, asset, 'size (cm):', found.get('dimensionX'), found.get('dimensionY'), 'maps:', sorted(maps))
