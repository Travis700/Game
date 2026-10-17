"""Rewrite a GLB with smaller JPEG textures: slim_glb.py in.glb out.glb [size] [mask].

Colour maps of see-through materials keep their alpha (as PNG). With "mask", alpha-blended
materials become alpha-tested instead (leaves: they sort properly and cast shadows)."""
import io, json, struct, sys
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
size = int(sys.argv[3]) if len(sys.argv) > 3 else 1024
mask = 'mask' in sys.argv[4:]
b = open(src, 'rb').read()
jl = struct.unpack('<I', b[12:16])[0]
j = json.loads(b[20:20 + jl])
bin_start = 20 + jl + 8
blob = b[bin_start:bin_start + struct.unpack('<I', b[20 + jl:24 + jl])[0]]

for m in j['materials']:
    if mask and m.get('alphaMode') == 'BLEND':
        m['alphaMode'] = 'MASK'
        m['alphaCutoff'] = 0.4
    pbr = m.setdefault('pbrMetallicRoughness', {})
    pbr.pop('metallicRoughnessTexture', None)
    pbr['metallicFactor'] = 0.0
    pbr['roughnessFactor'] = 0.85
used = set()
# Colour maps of cut-out or see-through materials (leaves, glass) keep their alpha, as PNG.
keep_alpha = set()
for m in j['materials']:
    for t in [m.get('pbrMetallicRoughness', {}).get('baseColorTexture'), m.get('normalTexture')]:
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
        pic = Image.open(io.BytesIO(data)).convert('RGBA').resize((size, size), Image.LANCZOS)
        buf = io.BytesIO(); pic.save(buf, 'PNG', optimize=True); data = buf.getvalue()
    else:
        pic = Image.open(io.BytesIO(data)).convert('RGB').resize((size, size), Image.LANCZOS)
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
