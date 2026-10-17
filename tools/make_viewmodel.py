"""Builds the first-person arm holding the flashlight (Blender's Python module: pip install bpy):

    make_viewmodel.py arms.glb torch.glb out.glb [curl_deg] [thumb_deg]

arms.glb is "First Person hands rigged" by David Fischer and torch.glb "Flashlight Swiss Arms" by
TheSolomon (both Sketchfab, CC BY; fetch with tools/sketchfab.py). The right hand's fingers are curled
round (curl_deg, default 75; the thumb, thumb_deg, default 0, lies along the torch), the pose is baked
and everything but the right forearm and hand dropped. The torch goes across the palm, along the
knuckles, its head out past the thumb, sized to the hand. Then the lot is turned so the beam points
straight ahead (glTF -Z) with the forearm off down and to the right, the lens at the origin, in metres.
Then: slim_glb.py out.glb assets/models/viewmodel_flashlight.glb 1024
"""
import sys, math, bpy, mathutils
src, torch_src, out = sys.argv[1:4]
# The torch's length and radius, and how far it sits out past the thumb, in hand widths.
TORCH_L, TORCH_R, TORCH_SHIFT = 2.1, 0.17, 0.25
curl = math.radians(float(sys.argv[4]) if len(sys.argv) > 4 else 75)
thumb = math.radians(float(sys.argv[5]) if len(sys.argv) > 5 else 0)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
pb = arm.pose.bones
def find(stem):
    return next(b for b in pb if b.name.startswith(stem))
for f in ['index', 'middle', 'ring', 'pinky']:
    for seg in ['01', '02', '03']:
        b = find('f_%s.%s.R' % (f, seg))
        b.rotation_mode = 'XYZ'
        b.rotation_euler = (curl, 0, 0)
for seg, k in [('01', 0.3), ('02', 1.0), ('03', 1.0)]:
    b = find('thumb.%s.R' % seg)
    b.rotation_mode = 'XYZ'
    b.rotation_euler = (thumb * k, 0, 0)
bpy.context.view_layer.update()
def head(stem):
    return arm.matrix_world @ find(stem).head
def tail(stem):
    return arm.matrix_world @ find(stem).tail
idx, pky = head('f_index.01.R'), head('f_pinky.01.R')
wrist, elbow = head('hand.R'), head('forearm.R_')
tips = [head('f_%s.03.R_end' % f) for f in ['index', 'middle', 'ring', 'pinky']]
tips_mid = sum(tips, mathutils.Vector()) / 4
mids = [head('f_%s.02.R' % f) for f in ['index', 'middle', 'ring', 'pinky']]
mids_mid = sum(mids, mathutils.Vector()) / 4
thumb_tip = tail('thumb.03.R')
bpy.ops.object.mode_set(mode='OBJECT')
# Bake the pose into the meshes and keep only what hangs off the right forearm.
meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o.vertex_groups]
for o in meshes:
    bpy.context.view_layer.objects.active = o
    for m in o.modifiers:
        if m.type == 'ARMATURE':
            bpy.ops.object.modifier_apply(modifier=m.name)
    keep = {g.index for g in o.vertex_groups if ('.R' in g.name) and not g.name.startswith(('clavicle', 'deltoid', 'upper_arm'))}
    import bmesh
    bm = bmesh.new(); bm.from_mesh(o.data)
    deform = bm.verts.layers.deform.active
    kill = []
    for v in bm.verts:
        w = sum(wt for gi, wt in v[deform].items() if gi in keep) if deform else 0
        if w < 0.5:
            kill.append(v)
    bmesh.ops.delete(bm, geom=kill, context='VERTS')
    bm.to_mesh(o.data); bm.free()
for o in [o for o in bpy.data.objects if o.type == 'MESH']:
    m = o.matrix_world.copy(); o.parent = None; o.matrix_world = m
for o in list(bpy.data.objects):
    if o.type != 'MESH' or not o.data.polygons or o.name.startswith('Icosphere'):
        bpy.data.objects.remove(o)
arm_meshes = [o for o in bpy.data.objects]
for o in arm_meshes:
    ws = [o.matrix_world @ v.co for v in o.data.vertices]
for o in arm_meshes:
    o.matrix_world = o.matrix_world.copy()
# The torch: across the palm, along the knuckle line, its head out past the thumb side.
bpy.ops.import_scene.gltf(filepath=torch_src)
torch = [o for o in bpy.data.objects if o not in arm_meshes and o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in torch:
    o.select_set(True)
bpy.context.view_layer.objects.active = torch[0]
for o in torch:
    m = o.matrix_world.copy(); o.parent = None; o.matrix_world = m
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.join()
tm = bpy.context.view_layer.objects.active
lo = mathutils.Vector((min(v.co[i] for v in tm.data.vertices) for i in range(3)))
hi = mathutils.Vector((max(v.co[i] for v in tm.data.vertices) for i in range(3)))
size = hi - lo
long_axis = max(range(3), key=lambda i: size[i])
# Knuckles, fingertips: where the fist closes round the torch.
knuckle_mid = (idx + pky) / 2
hand_w = (idx - pky).length
axis = (idx - pky).normalized()
inside = ((tips_mid + mids_mid) / 2 - knuckle_mid)
inside -= axis * inside.dot(axis)
radius = hand_w * TORCH_R
centre = knuckle_mid + inside.normalized() * (inside.length * 0.55)
# Scale the torch: its long axis to TORCH_L hand widths, then lay it along `axis`.
la = long_axis
scale = hand_w * TORCH_L / size[la]
tm.scale = (scale, scale, scale)
bpy.ops.object.transform_apply(scale=True)
lo = mathutils.Vector((min(v.co[i] for v in tm.data.vertices) for i in range(3)))
hi = mathutils.Vector((max(v.co[i] for v in tm.data.vertices) for i in range(3)))
mid = (lo + hi) / 2
# Which end is the head (the wider end)?
ends = []
for sign in (-1, 1):
    tip = mid[la] + sign * (hi[la] - lo[la]) * 0.45
    rs = [max(abs(v.co[(la + 1) % 3] - mid[(la + 1) % 3]), abs(v.co[(la + 2) % 3] - mid[(la + 2) % 3])) for v in tm.data.vertices if abs(v.co[la] - tip) < (hi[la] - lo[la]) * 0.05]
    ends.append(max(rs) if rs else 0)
head_sign = -1 if ends[0] > ends[1] else 1
local_axis = mathutils.Vector((0, 0, 0)); local_axis[la] = head_sign
for v in tm.data.vertices:
    v.co -= mid
rot = local_axis.rotation_difference(axis)
tm.matrix_world = mathutils.Matrix.Translation(centre + axis * hand_w * TORCH_SHIFT) @ rot.to_matrix().to_4x4()
bpy.ops.object.select_all(action='DESELECT')
tm.select_set(True)
bpy.context.view_layer.objects.active = tm
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
ws = [tm.matrix_world @ v.co for v in tm.data.vertices]
lens = centre + axis * (hand_w * TORCH_SHIFT + (hi[la] - lo[la]) / 2)
# Into view space: the beam straight ahead (Blender +Y, glTF -Z), the forearm off down and to the right.
fore = (elbow - wrist).normalized()
to_fwd = axis.rotation_difference(mathutils.Vector((0, 1, 0)))
f2 = to_fwd @ fore
f2.y = 0
want = mathutils.Vector((1, 0, -1.2)).normalized()
ang = math.atan2(f2.x, -f2.z) - math.atan2(want.x, -want.z)
roll = mathutils.Quaternion((0, 1, 0), ang)
final = (roll @ to_fwd).to_matrix().to_4x4() @ mathutils.Matrix.Translation(-lens)
for o in [o for o in bpy.data.objects if o.type == 'MESH']:
    o.matrix_world = final @ o.matrix_world
    o.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# Into metres: the hand about 8.5 cm across the knuckles.
k = 0.085 / hand_w
for o in [o for o in bpy.data.objects if o.type == 'MESH']:
    o.scale = (k, k, k)
bpy.ops.object.transform_apply(scale=True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB')
