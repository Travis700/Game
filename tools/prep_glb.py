"""Tidies a downloaded model with Blender's Python module (pip install bpy) before slim_glb.py:

    prep_glb.py in.glb out.glb [--keep a,b] [--drop a,b] [--turn deg] [--tris n]

--keep / --drop pick mesh objects by name (any of the comma-separated pieces), --turn spins the model
about the vertical axis (models should face +Z), --tris decimates to about that many triangles
(UVs kept). Everything left is joined into one mesh with its transforms applied.
"""
import argparse, math
import bpy, mathutils

parser = argparse.ArgumentParser()
parser.add_argument('src')
parser.add_argument('dst')
parser.add_argument('--keep', default='')
parser.add_argument('--drop', default='')
parser.add_argument('--turn', type=float, default=0.0)
parser.add_argument('--tris', type=int, default=0)
args = parser.parse_args()

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=args.src)
keep = [part for part in args.keep.split(',') if part]
drop = [part for part in args.drop.split(',') if part]
meshes = []
for obj in list(bpy.data.objects):
    if obj.type != 'MESH':
        continue
    if (keep and not any(part in obj.name for part in keep)) or any(part in obj.name for part in drop):
        bpy.data.objects.remove(obj)
    else:
        meshes.append(obj)
# Bake every transform into the meshes, then drop the empties and bones that held them.
for obj in meshes:
    matrix = obj.matrix_world.copy()
    obj.parent = None
    obj.matrix_world = matrix
for obj in list(bpy.data.objects):
    if obj.type != 'MESH':
        bpy.data.objects.remove(obj)
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:
    obj.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
model = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# Blender's up is Z, so turning about it turns the model about glTF's up (Y).
model.data.transform(mathutils.Matrix.Rotation(math.radians(args.turn), 4, 'Z'))

model.data.calc_loop_triangles()
tris = len(model.data.loop_triangles)
if args.tris and tris > args.tris:
    modifier = model.modifiers.new('decimate', 'DECIMATE')
    modifier.ratio = args.tris / tris
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    model.data.calc_loop_triangles()
print('%s: %d -> %d triangles' % (args.dst, tris, len(model.data.loop_triangles)))
bpy.ops.export_scene.gltf(filepath=args.dst, export_format='GLB', use_selection=True, export_yup=True)
