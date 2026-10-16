"""Repaint the head of a slimmed GLB: paint_head.py model.glb above_fraction R G B.

Every triangle whose corners all sit above `above_fraction` of the model's height gets its
texture area painted in the given colour, with a little pencil-like grain. Used to give the
Principal back the shaded skin of his notebook drawing.
"""
import io, json, random, struct, sys
from PIL import Image, ImageDraw, ImageFilter

path, above = sys.argv[1], float(sys.argv[2])
colour = tuple(int(c) for c in sys.argv[3:6])
data = open(path, 'rb').read()
json_len = struct.unpack('<I', data[12:16])[0]
gltf = json.loads(data[20:20 + json_len])
bin_at = 20 + json_len + 8
blob = bytearray(data[bin_at:])

def read(accessor_index):
    acc = gltf['accessors'][accessor_index]
    view = gltf['bufferViews'][acc['bufferView']]
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[acc['type']]
    fmt = {5126: 'f', 5125: 'I', 5123: 'H'}[acc['componentType']]
    size = struct.calcsize(fmt)
    stride = view.get('byteStride', size * width)
    start = view.get('byteOffset', 0) + acc.get('byteOffset', 0)
    return [struct.unpack_from('<' + fmt * width, blob, start + i * stride) for i in range(acc['count'])]

prim = gltf['meshes'][0]['primitives'][0]
pos = read(prim['attributes']['POSITION'])
uv = read(prim['attributes']['TEXCOORD_0'])
idx = [i[0] for i in read(prim['indices'])]
ys = [p[1] for p in pos]
cut = min(ys) + (max(ys) - min(ys)) * above

material = gltf['materials'][prim.get('material', 0)]
image_index = gltf['textures'][material['pbrMetallicRoughness']['baseColorTexture']['index']]['source']
view = gltf['bufferViews'][gltf['images'][image_index]['bufferView']]
texture = Image.open(io.BytesIO(bytes(blob[view['byteOffset']:view['byteOffset'] + view['byteLength']]))).convert('RGB')
w, h = texture.size
mask = Image.new('L', texture.size, 0)
draw = ImageDraw.Draw(mask)
for t in range(0, len(idx), 3):
    corners = idx[t:t + 3]
    if all(pos[c][1] > cut for c in corners):
        draw.polygon([(uv[c][0] * w, uv[c][1] * h) for c in corners], fill=255)
mask = mask.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(2))
random.seed(7)
grain = Image.new('RGB', texture.size)
pixels = grain.load()
for y in range(h):
    for x in range(w):
        k = 0.82 + random.random() * 0.3
        pixels[x, y] = tuple(int(c * k) for c in colour)
grain = grain.filter(ImageFilter.GaussianBlur(0.8))
texture = Image.composite(grain, texture, mask)

out = io.BytesIO(); texture.save(out, 'JPEG', quality=88); jpg = out.getvalue()
# Put the new image at the end of the binary chunk and point the image at it.
while len(blob) % 4: blob.append(0)
offset = len(blob); blob.extend(jpg)
while len(blob) % 4: blob.append(0)
gltf['bufferViews'].append({'buffer': 0, 'byteOffset': offset, 'byteLength': len(jpg)})
gltf['images'][image_index]['bufferView'] = len(gltf['bufferViews']) - 1
gltf['buffers'][0]['byteLength'] = len(blob)
js = json.dumps(gltf, separators=(',', ':')).encode()
while len(js) % 4: js += b' '
with open(path, 'wb') as f:
    f.write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob)))
    f.write(struct.pack('<II', len(js), 0x4E4F534A)); f.write(js)
    f.write(struct.pack('<II', len(blob), 0x004E4942)); f.write(blob)
print(path, 'painted', sum(mask.histogram()[129:]), 'texels')
