"""Rewrite a GLB with smaller JPEG textures: slim_glb.py in.glb out.glb [size] [mask] [tint=r,g,b].

Colour maps of see-through materials keep their alpha (as PNG). With "mask", alpha-blended
materials become alpha-tested instead (leaves: they sort properly and cast shadows). "tint=r,g,b"
multiplies every material's colour (e.g. warms a grey tweed to brown). Small textures aren't blown up.
The metal/rough/AO map goes, so occlusion maps (usually the same picture) go with it; all-black glow
maps go; and "see-through" materials whose colour map has nothing see-through in it become opaque."""
import io, json, struct, sys
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
size = int(sys.argv[3]) if len(sys.argv) > 3 else 1024
mask = 'mask' in sys.argv[4:]
tint = next(([float(c) for c in arg[5:].split(',')] for arg in sys.argv[4:] if arg.startswith('tint=')), None)
b = open(src, 'rb').read()
jl = struct.unpack('<I', b[12:16])[0]
j = json.loads(b[20:20 + jl])
bin_start = 20 + jl + 8
blob = b[bin_start:bin_start + struct.unpack('<I', b[20 + jl:24 + jl])[0]]


def picture(texture):
    view = j['bufferViews'][j['images'][j['textures'][texture['index']]['source']]['bufferView']]
    start = view.get('byteOffset', 0)
    return Image.open(io.BytesIO(blob[start:start + view['byteLength']]))


for m in j['materials']:
    m.pop('occlusionTexture', None)
    if m.get('emissiveTexture') and max(high for low, high in picture(m['emissiveTexture']).convert('RGB').getextrema()) == 0:
        m.pop('emissiveTexture')
        m.pop('emissiveFactor', None)
    colour = m.get('pbrMetallicRoughness', {}).get('baseColorTexture')
    if colour and m.get('alphaMode', 'OPAQUE') != 'OPAQUE' and picture(colour).convert('RGBA').getextrema()[3][0] == 255:
        m.pop('alphaMode')
        m.pop('alphaCutoff', None)
    if mask and m.get('alphaMode') == 'BLEND':
        m['alphaMode'] = 'MASK'
        m['alphaCutoff'] = 0.4
    pbr = m.setdefault('pbrMetallicRoughness', {})
    pbr.pop('metallicRoughnessTexture', None)
    pbr['metallicFactor'] = 0.0
    pbr['roughnessFactor'] = 0.85
    if tint:
        colour = pbr.get('baseColorFactor', [1.0, 1.0, 1.0, 1.0])
        pbr['baseColorFactor'] = [colour[i] * tint[i] for i in range(3)] + [colour[3]]
used = set()
# Colour maps of cut-out or see-through materials (leaves, glass) keep their alpha, as PNG.
keep_alpha = set()
for m in j['materials']:
    for t in [m.get('pbrMetallicRoughness', {}).get('baseColorTexture'), m.get('normalTexture'), m.get('emissiveTexture')]:
        if t: used.add(j['textures'][t['index']]['source'])
    colour = m.get('pbrMetallicRoughness', {}).get('baseColorTexture')
    if colour and m.get('alphaMode', 'OPAQUE') != 'OPAQUE':
        keep_alpha.add(j['textures'][colour['index']]['source'])

new_views, out = [], bytearray()
def add(data):
    off = len(out); out.extend(data)
    while len(out) % 4: out.append(0)
    new_views.append({'buffer': 0, 'byteOffset': off, 'byteLength': len(data)})
    return len(new_views) - 1

j.setdefault('images', [])
image_views = {j['images'][i]['bufferView'] for i in range(len(j['images']))}
remap = {}
for i, v in enumerate(j['bufferViews']):
    if i in image_views: continue
    nv = dict(v); data = blob[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]
    off = len(out); out.extend(data)
    while len(out) % 4: out.append(0)
    nv['byteOffset'] = off; new_views.append(nv); remap[i] = len(new_views) - 1
for a in j['accessors']:
    if 'bufferView' in a: a['bufferView'] = remap[a['bufferView']]
for idx, im in enumerate(j['images']):
    v = j['bufferViews'][im['bufferView']]
    data = blob[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']]
    if idx not in used:
        buf = io.BytesIO(); Image.new('RGB', (4, 4)).save(buf, 'JPEG'); data = buf.getvalue()
    elif idx in keep_alpha:
        pic = Image.open(io.BytesIO(data)).convert('RGBA')
        side = min(size, max(pic.size))
        pic = pic.resize((side, side), Image.LANCZOS)
        buf = io.BytesIO(); pic.save(buf, 'PNG', optimize=True); data = buf.getvalue()
    else:
        pic = Image.open(io.BytesIO(data)).convert('RGB')
        side = min(size, max(pic.size))
        pic = pic.resize((side, side), Image.LANCZOS)
        buf = io.BytesIO(); pic.save(buf, 'JPEG', quality=88); data = buf.getvalue()
    im['bufferView'] = add(data); im['mimeType'] = 'image/png' if idx in keep_alpha else 'image/jpeg'
j['bufferViews'] = new_views
j['buffers'] = [{'byteLength': len(out)}]
js = json.dumps(j, separators=(',', ':')).encode()
while len(js) % 4: js += b' '
total = 12 + 8 + len(js) + 8 + len(out)
with open(dst, 'wb') as f:
    f.write(struct.pack('<III', 0x46546C67, 2, total))
    f.write(struct.pack('<II', len(js), 0x4E4F534A)); f.write(js)
    f.write(struct.pack('<II', len(out), 0x004E4942)); f.write(out)
print(dst, total)
