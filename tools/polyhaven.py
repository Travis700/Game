"""Fetches a CC0 model from Poly Haven as one GLB: polyhaven.py asset_id out.glb.

Downloads the 1k glTF (its .bin and textures), packs it into a GLB, and leaves the texture
slimming to slim_glb.py. Run with the agent proxy's environment (HTTPS_PROXY) as usual.
"""
import json, os, struct, sys, urllib.request

asset, dst = sys.argv[1], sys.argv[2]


def get(url):
    # (Poly Haven turns away Python's default user agent.)
    request = urllib.request.Request(url, headers={'User-Agent': 'NightShift-asset-fetch/1.0'})
    with urllib.request.urlopen(request) as reply:
        return reply.read()


files = json.loads(get('https://api.polyhaven.com/files/' + asset))
entry = files['gltf']['1k']['gltf']
gltf = json.loads(get(entry['url']))
parts = {name: get(info['url']) for name, info in entry['include'].items()}

# One buffer holding the old buffer(s) and then every image.
blob = bytearray()
starts = []
for buf in gltf['buffers']:
    starts.append(len(blob))
    blob.extend(parts[buf['uri']])
    while len(blob) % 4:
        blob.append(0)
for view in gltf['bufferViews']:
    view['byteOffset'] = view.get('byteOffset', 0) + starts[view.get('buffer', 0)]
    view['buffer'] = 0
for image in gltf.get('images', []):
    data = parts[image.pop('uri')]
    gltf['bufferViews'].append({'buffer': 0, 'byteOffset': len(blob), 'byteLength': len(data)})
    blob.extend(data)
    while len(blob) % 4:
        blob.append(0)
    image['bufferView'] = len(gltf['bufferViews']) - 1
    image['mimeType'] = 'image/png' if data[:4] == b'\x89PNG' else 'image/jpeg'
gltf['buffers'] = [{'byteLength': len(blob)}]

js = json.dumps(gltf, separators=(',', ':')).encode()
while len(js) % 4:
    js += b' '
with open(dst, 'wb') as out:
    out.write(struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob)))
    out.write(struct.pack('<II', len(js), 0x4E4F534A))
    out.write(js)
    out.write(struct.pack('<II', len(blob), 0x004E4942))
    out.write(blob)
print(dst, os.path.getsize(dst))
