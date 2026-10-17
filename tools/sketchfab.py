"""Finds and fetches CC0 / CC-BY models from Sketchfab.

    sketchfab.py search words...      lists downloadable CC0 and CC-BY matches (uid, faces, licence, name)
    sketchfab.py get uid out.glb      downloads one as a single GLB and prints its credit line

The API needs a token: SKETCHFAB_TOKEN if it's set (sent as "Authorization: Token ..."), otherwise
the agent proxy adds it. Only CC0 ("cc0") and CC-BY ("by") models are ever fetched: CC-BY needs a
credit in CREDITS.md, so `get` prints the name, author, licence and URL to paste there. Textures
are left full size for slim_glb.py.
"""
import io, json, os, struct, sys, urllib.parse, urllib.request, zipfile

API = 'https://api.sketchfab.com/v3/'
LICENCES = {'cc0': 'CC0', 'by': 'CC BY 4.0'}
# Search results name the licence by uid only.
LICENCE_UIDS = {'7c23a1ba438d4306920229c12afcb5f9': 'cc0', '322a749bcfa841b29dff1e8a1bb74b0b': 'by'}


def get(url, auth=True):
    headers = {'User-Agent': 'NightShift-asset-fetch/1.0'}
    if auth and os.environ.get('SKETCHFAB_TOKEN'):
        headers['Authorization'] = 'Token ' + os.environ['SKETCHFAB_TOKEN']
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers)) as reply:
        return reply.read()


def licence(model):
    entry = model.get('license') or {}
    return entry.get('slug') or LICENCE_UIDS.get(entry.get('uid', ''), entry.get('uid', ''))


def search(words):
    for slug in LICENCES:
        query = urllib.parse.urlencode({'type': 'models', 'downloadable': 'true', 'q': words, 'count': 24,
                'license': slug})
        for model in json.loads(get(API + 'search?' + query))['results']:
            if licence(model) in LICENCES:
                print(model['uid'], model.get('faceCount'), licence(model), '|', model['name'], '|',
                        model['user']['displayName'])


def pack(gltf, read):
    """One GLB from a glTF and its side files (read(name) -> bytes), like polyhaven.py."""
    blob = bytearray()
    starts = []
    for buf in gltf['buffers']:
        starts.append(len(blob))
        blob.extend(read(urllib.parse.unquote(buf['uri'])))
        while len(blob) % 4:
            blob.append(0)
    for view in gltf['bufferViews']:
        view['byteOffset'] = view.get('byteOffset', 0) + starts[view.get('buffer', 0)]
        view['buffer'] = 0
    for image in gltf.get('images', []):
        if 'uri' not in image:
            continue
        data = read(urllib.parse.unquote(image.pop('uri')))
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
    return (struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob))
            + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(blob), 0x004E4942) + bytes(blob))


def fetch(uid, dst):
    model = json.loads(get(API + 'models/' + uid))
    if licence(model) not in LICENCES:
        sys.exit('%s is %s: only CC0 and CC-BY models are allowed' % (uid, licence(model) or 'unlicensed'))
    links = json.loads(get(API + 'models/%s/download' % uid))
    if 'glb' in links:
        data = get(links['glb']['url'], auth=False)
    else:
        archive = zipfile.ZipFile(io.BytesIO(get(links['gltf']['url'], auth=False)))
        scene = next(name for name in archive.namelist() if name.endswith('.gltf'))
        base = os.path.dirname(scene)
        data = pack(json.loads(archive.read(scene)), lambda name: archive.read(os.path.join(base, name) if base else name))
    with open(dst, 'wb') as out:
        out.write(data)
    print(dst, len(data))
    print('| %s | %s | %s | %s |' % (model['name'], model['user']['displayName'], LICENCES[licence(model)],
            model['viewerUrl']))


if __name__ == '__main__':
    if sys.argv[1] == 'search':
        search(' '.join(sys.argv[2:]))
    else:
        fetch(sys.argv[2], sys.argv[3])
