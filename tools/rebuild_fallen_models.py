"""Author three original skinned fallen enemies for the native Unity rebuild.

Blender --background --factory-startup --python tools/rebuild_fallen_models.py
Explicit contour anatomy, closed armor shells and sculpted fur clumps are actual
volume meshes. This production-development pass is not final art acceptance.
"""
from pathlib import Path
import json
import math
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/graphics-rebuild-v1/monsters'
UNITY = ROOT / 'Unity/Assets/Game/Resources/Eternal/GraphicsRebuild/Monsters'
PARTS = []
MATERIALS = {}
SCALE = (1, 1, 1)


def point(v):
    return tuple(v[i] * SCALE[i] for i in range(3))


def material(name, color, metallic=0.0, roughness=.7, emission=0.0):
    name = 'Fallen_' + name
    if name in MATERIALS:
        return MATERIALS[name]['material']
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    rgba = tuple(int(color[i:i+2], 16) / 255 for i in (0, 2, 4)) + (1,)
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = rgba
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Emission Color'].default_value = rgba
    bsdf.inputs['Emission Strength'].default_value = emission
    mat.diffuse_color = rgba
    MATERIALS[name] = dict(material=mat, name=mat.name, color='#' + color.upper(),
                           metallic=metallic, roughness=roughness, emission=emission)
    return mat


def mesh(name, vertices, faces, mat, bone, smooth=True, weights=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata([point(v) for v in vertices], [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    data.materials.append(mat)
    if weights:
        for i, row in enumerate(weights):
            for key, value in row.items():
                group = obj.vertex_groups.get(key) or obj.vertex_groups.new(name=key)
                group.add([i], value, 'REPLACE')
    else:
        group = obj.vertex_groups.new(name=bone)
        group.add(list(range(len(vertices))), 1, 'REPLACE')
    # UVs establish an editable surface foundation; this pass uses authored
    # material regions rather than pretending a flat concept is a 3D texture.
    uv = data.uv_layers.new(name='SurfaceUV')
    for polygon in data.polygons:
        polygon.use_smooth = smooth
        for loop in polygon.loop_indices:
            v = vertices[data.loops[loop].vertex_index]
            uv.data[loop].uv = ((math.atan2(v[0], v[1]) / math.tau + .5) % 1, v[2] / 2.5)
    PARTS.append(obj)
    return obj


def contour(name, sections, mat, bone, sides=16, row_weights=None, smooth=True):
    vertices, faces, weights = [], [], []
    for row, (x, y, z, width, depth) in enumerate(sections):
        for i in range(sides):
            a = i * math.tau / sides
            vertices.append((x + math.sin(a)*width, y + math.cos(a)*depth, z))
            if row_weights:
                weights.append(row_weights[row])
    for row in range(len(sections)-1):
        for i in range(sides):
            a = row*sides+i
            b = row*sides+(i+1) % sides
            faces.append((a, a+sides, b+sides, b))
    faces.extend([tuple(range(sides)), tuple(reversed(range((len(sections)-1)*sides, len(sections)*sides)))])
    return mesh(name, vertices, faces, mat, bone, smooth, weights or None)


def tube(name, points, radii, mat, bone, sides=8):
    vertices, faces = [], []
    for j, p in enumerate(points):
        tangent = Vector(points[min(j+1, len(points)-1)]) - Vector(points[max(0, j-1)])
        tangent.normalize()
        u = tangent.cross(Vector((0, 0, 1)))
        if u.length < .001:
            u = tangent.cross(Vector((0, 1, 0)))
        u.normalize()
        v = tangent.cross(u).normalized()
        for i in range(sides):
            a = i*math.tau/sides
            vertices.append(tuple(Vector(p) + (u*math.cos(a)+v*math.sin(a))*radii[j]))
    for j in range(len(points)-1):
        for i in range(sides):
            a = j*sides+i
            b = j*sides+(i+1) % sides
            faces.append((a, b, b+sides, a+sides))
    faces.extend([tuple(reversed(range(sides))), tuple((len(points)-1)*sides+i for i in range(sides))])
    return mesh(name, vertices, faces, mat, bone)


def bevel_plate(name, outline, depth, mat, bone):
    # A closed beveled prism with explicit front/back/side surfaces.
    n = len(outline)
    center = Vector(tuple(sum(v[k] for v in outline)/n for k in range(3)))
    inner = []
    for v in outline:
        p = center + (Vector(v)-center)*.89
        p.y -= .014
        inner.append(tuple(p))
    vertices = inner + outline + [(x, y+depth, z) for x, y, z in outline]
    faces = [tuple(reversed(range(n))), tuple(range(n*2, n*3))]
    for i in range(n):
        j = (i+1) % n
        faces.extend([(i, j, j+n, i+n), (i+n, j+n, j+n*2, i+n*2)])
    return mesh(name, vertices, faces, mat, bone, False)


def blade(name, a, b, width, mat, bone):
    a, b = Vector(a), Vector(b)
    tangent = (b-a).normalized()
    cross = tangent.cross(Vector((0, 1, 0))).normalized()*width
    center = a.lerp(b, .38)
    front = center + Vector((0, -.023, 0))
    back = center + Vector((0, .018, 0))
    vs = [a-cross*.55, a+cross*.55, center+cross, b, center-cross, front, back]
    fs = [(5, i, (i+1) % 5) for i in range(5)] + [(6, (i+1) % 5, i) for i in range(5)]
    return mesh(name, [tuple(v) for v in vs], fs, mat, bone, False)


def fur_lock(name, points, width, depth, mat, bone):
    # A closed, curved diamond clump with separate ridge and shadow facets.
    vertices, faces = [], []
    for j, (x, y, z) in enumerate(points):
        t = j/(len(points)-1)
        w = width * (1-t)**.65 + .001
        d = depth * (1-t*.65)
        vertices.extend([(x-w, y, z), (x, y-d, z+.006), (x+w, y, z), (x, y+d*.4, z)])
    for row in range(len(points)-1):
        for i in range(4):
            a = row*4+i
            b = row*4+(i+1) % 4
            faces.append((a, a+4, b+4, b))
    faces.extend([(0, 1, 2, 3), tuple(reversed(range(len(vertices)-4, len(vertices))))])
    return mesh(name, vertices, faces, mat, bone)


def bone(data, name, head, tail, parent=None):
    item = data.edit_bones.new(name)
    item.head, item.tail = point(head), point(tail)
    if parent:
        item.parent = data.edit_bones[parent]


def create_rig(identifier, wolf):
    data = bpy.data.armatures.new(identifier + '_Skeleton')
    arm = bpy.data.objects.new(identifier + '_Rig', data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bone(data, 'Root', (0, 0, 0), (0, 0, .18))
    bone(data, 'Hips', (0, .015, .95), (0, .015, 1.13), 'Root')
    bone(data, 'Spine', (0, .015, 1.13), (0, -.04 if wolf else 0, 1.4), 'Hips')
    bone(data, 'Chest', (0, -.04 if wolf else 0, 1.4), (0, -.07 if wolf else 0, 1.64), 'Spine')
    bone(data, 'Neck', (0, -.07 if wolf else 0, 1.64), (0, -.11 if wolf else 0, 1.81), 'Chest')
    bone(data, 'Head', (0, -.11 if wolf else 0, 1.81), (0, -.11 if wolf else 0, 2.14), 'Neck')
    for sign in (-1, 1):
        side = 'L' if sign > 0 else 'R'
        bone(data, 'UpperArm.'+side, (sign*.30, 0, 1.58), (sign*.46, -.025, 1.30), 'Chest')
        bone(data, 'Forearm.'+side, (sign*.46, -.025, 1.30), (sign*.53, -.065, 1.03), 'UpperArm.'+side)
        bone(data, 'Hand.'+side, (sign*.53, -.065, 1.03), (sign*.54, -.10, .85), 'Forearm.'+side)
        bone(data, 'Thigh.'+side, (sign*.13, .015, .98), (sign*.18, -.02, .58), 'Hips')
        bone(data, 'Shin.'+side, (sign*.18, -.02, .58), (sign*.19, .11 if wolf else 0, .16), 'Thigh.'+side)
        bone(data, 'Foot.'+side, (sign*.19, .11 if wolf else 0, .16), (sign*.19, -.16, .07), 'Shin.'+side)
    for i in range(3):
        bone(data, 'Cape'+str(i), (0, .15+i*.07, 1.53-i*.3), (0, .22+i*.07, 1.23-i*.3), 'Chest' if i == 0 else 'Cape'+str(i-1))
    bone(data, 'Tail', (0, .14, 1.0), (0, .49, .77), 'Hips')
    bone(data, 'TailTip', (0, .49, .77), (0, .70, .48), 'Tail')
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.select_set(False)
    return arm


def torso(kind, skin, leather, armor):
    wolf, dwarf = kind == 'fallen_werewolf', kind == 'fallen_dwarf'
    if wolf:
        rows = [(0,.05,.96,.18,.13),(0,.04,1.10,.19,.13),(0,-.01,1.28,.24,.16),(0,-.06,1.45,.32,.21),(0,-.05,1.60,.33,.19),(0,-.04,1.68,.19,.14)]
    elif dwarf:
        rows = [(0,0,.96,.23,.18),(0,0,1.08,.29,.20),(0,0,1.25,.31,.22),(0,0,1.44,.30,.21),(0,0,1.59,.27,.16),(0,0,1.64,.16,.12)]
    else:
        rows = [(0,0,.96,.17,.12),(0,0,1.08,.20,.12),(0,0,1.24,.16,.105),(0,0,1.41,.23,.14),(0,0,1.57,.265,.14),(0,0,1.63,.15,.10)]
    weights = [{'Hips':1},{'Hips':.6,'Spine':.4},{'Spine':.8,'Chest':.2},{'Spine':.3,'Chest':.7},{'Chest':1},{'Chest':1}]
    contour('Weighted_Anatomy_Torso', rows, skin if wolf else leather, 'Chest', 24, weights)
    contour('Anatomy_Neck', [(0,-.09 if wolf else 0,1.59,.10 if dwarf or wolf else .07,.09),(0,-.11 if wolf else 0,1.85,.10 if dwarf or wolf else .063,.075)], skin, 'Neck', 16)
    for sign in (-1, 1):
        side = 'L' if sign > 0 else 'R'
        width = .109 if wolf or dwarf else .070
        contour('Anatomy_Arm_'+side, [(sign*.29,0,1.57,width,.099),(sign*.36,0,1.46,width*.96,.092),(sign*.46,-.025,1.29,width*.66,.063)], skin if wolf else leather, 'UpperArm.'+side, 16)
        contour('Anatomy_Forearm_'+side, [(sign*.46,-.025,1.32,width*.76,.070),(sign*.49,-.04,1.20,width*.91,.08),(sign*.53,-.065,1.01,width*.58,.045)], skin if wolf else leather, 'Forearm.'+side, 16)
        contour('Anatomy_Palm_'+side, [(sign*.53,-.065,1.04,width*.70,.041),(sign*.54,-.10,.93,width*.72,.04),(sign*.54,-.11,.87,width*.53,.029)], skin, 'Hand.'+side, 12)
        for digit in range(4):
            x = sign*.54+(digit-1.5)*(.031 if wolf else .023)
            p = [(x,-.13,.95),(x,-.155,.88),(x,-.16,.84)]
            tube('Finger_'+side+str(digit), p, [.016 if wolf else .011,.012,.007], skin,'Hand.'+side,6)
        tube('Thumb_'+side, [(sign*.50,-.075,1.0),(sign*.47,-.14,.94),(sign*.47,-.16,.90)], [.02,.016,.009],skin,'Hand.'+side,8)
        contour('Anatomy_Thigh_'+side, [(sign*.13,.015,1.00,.111,.12),(sign*.16,0,.80,.118 if wolf else .10,.12),(sign*.18,-.02,.57,.074,.073)], skin if wolf else leather,'Thigh.'+side,16)
        if wolf:
            contour('Digitigrade_Calf_'+side,[(sign*.18,-.02,.59,.084,.076),(sign*.20,.055,.43,.076,.068),(sign*.19,.11,.19,.045,.05)],skin,'Shin.'+side,16)
            contour('Digitigrade_Paw_'+side,[(sign*.19,-.065,.045,.105,.15),(sign*.19,-.06,.11,.113,.157),(sign*.19,.085,.21,.05,.06)],skin,'Foot.'+side,16)
        else:
            contour('Anatomy_Shin_'+side, [(sign*.18,-.02,.60,.075,.07),(sign*.185,.01,.43,.084,.077),(sign*.19,0,.15,.047,.05)], leather,'Shin.'+side,16)
            contour('Armored_Boot_'+side,[(sign*.19,-.065,.035,.085,.14),(sign*.19,-.065,.09,.09,.15),(sign*.19,-.005,.18,.062,.076)],armor,'Foot.'+side,16)


def humanoid_face(kind, skin, eye, dark, hair):
    dwarf = kind == 'fallen_dwarf'
    width = 1.14 if dwarf else .9
    rows = [(0,-.005,1.76,.05,.05),(0,-.005,1.81,.11,.094),(0,0,1.89,.155,.13),(0,.005,1.99,.17,.145),(0,.015,2.08,.16,.135),(0,.02,2.17,.095,.08),(0,.02,2.19,.015,.014)]
    contour('Sculpted_Head', [(x,y,z,w*width,d) for x,y,z,w,d in rows],skin,'Head',24)
    white = material('Sclera','D2CCB7',0,.32)
    for s in (-1,1):
        # Faceted eyelids and inlaid eyes have their own surface depth.
        bevel_plate('EyeSocket', [(s*.027,-.139,2.015),(s*.112,-.129,2.020),(s*.110,-.140,1.969),(s*.034,-.148,1.974)],.012,dark,'Head')
        bevel_plate('EyeWhite',[(s*.037,-.154,2.002),(s*.102,-.148,2.007),(s*.099,-.154,1.979),(s*.041,-.161,1.981)],.004,white,'Head')
        bevel_plate('Corrupted_Iris',[(s*.06,-.17,2.006),(s*.079,-.168,2.004),(s*.079,-.17,1.98),(s*.060,-.17,1.981)],.003,eye,'Head')
        tube('Angled_Brow',[(s*.025,-.151,2.042),(s*.075,-.154,2.056),(s*.13,-.125,2.047)],[.009,.011,.004],hair,'Head',6)
        if not dwarf:
            bevel_plate('Long_Elven_Ear',[(s*.15,.01,2.02),(s*.315,.018,2.105),(s*.19,-.01,1.921)],.031,skin,'Head')
            tube('Ear_Cartilage',[(s*.17,-.014,1.965),(s*.265,-.011,2.070)],[.011,.001],material('Elf_InnerSkin','795268',0,.8),'Head',6)
    bevel_plate('Nose_Anatomy',[(-.020,-.145,2.012),(.021,-.145,2.012),(.040 if dwarf else .023,-.155,1.92),(0,-.22 if dwarf else -.185,1.915),(-.041 if dwarf else -.023,-.155,1.92)],.02,skin,'Head')
    tube('Mouth_Seam',[(-.048,-.130,1.861),(0,-.150,1.853),(.048,-.130,1.861)],[.004,.005,.004],dark,'Head',6)


def armor_details(kind, armor, trim, leather, violet):
    dwarf = kind == 'fallen_dwarf'
    for s in (-1,1):
        side='L' if s>0 else 'R'
        bevel_plate('Sculpted_Pauldron_'+side,[(s*.21,-.08,1.63),(s*.32,-.13,1.72),(s*.45,-.08,1.60),(s*.43,-.10,1.49),(s*.30,-.16,1.49)],.19,armor,'UpperArm.'+side)
        tube('Pauldron_Fillet_'+side,[(s*.21,-.096,1.63),(s*.32,-.146,1.72),(s*.45,-.10,1.60),(s*.43,-.12,1.49),(s*.30,-.18,1.49)],[.01]*5,trim,'UpperArm.'+side,6)
        for j in range(3 if dwarf else 2):
            x=s*(.29+j*.057)
            blade('Armor_Thorn',(x,-.014,1.64-j*.013),(x+s*.065,-.005,1.82+j*.028),.033,trim,'UpperArm.'+side)
        bevel_plate('Vambrace_'+side,[(s*.41,-.08,1.30),(s*.50,-.105,1.31),(s*.59,-.12,1.08),(s*.49,-.15,1.01),(s*.44,-.13,1.17)],.095,armor,'Forearm.'+side)
        tube('Bracer_Inlay',[(s*.49,-.147,1.10),(s*.47,-.14,1.20),(s*.46,-.12,1.27)],[.006,.009,.005],violet,'Forearm.'+side,6)
        bevel_plate('Knee_Guard_'+side,[(s*.18,-.104,.66),(s*.26,-.08,.57),(s*.20,-.115,.49),(s*.12,-.08,.56)],.075,armor,'Shin.'+side)
        bevel_plate('Greave_'+side,[(s*.12,-.094,.49),(s*.25,-.094,.49),(s*.24,-.068,.20),(s*.14,-.083,.15)],.072,armor,'Shin.'+side)
        tube('Greave_Ridge',[(s*.18,-.134,.48),(s*.19,-.113,.21)],[.008,.005],trim,'Shin.'+side,6)
    if dwarf:
        bevel_plate('Layered_Breastplate',[(-.255,-.174,1.55),(0,-.213,1.65),(.255,-.174,1.55),(.282,-.215,1.25),(0,-.259,1.16),(-.282,-.215,1.25)],.08,armor,'Chest')
        for z in [1.25,1.34,1.43]:
            tube('Breastplate_Bands',[(-.26,-.247,z),(0,-.28,z-.025),(.26,-.247,z)],[.012]*3,trim,'Chest',6)
        for s in (-1,1):
            for j in range(3):
                bevel_plate('Riveted_Fauld',[(s*.06,-.15,1.10-j*.08),(s*.30,-.11,1.10-j*.08),(s*.32,-.13,1.0-j*.08),(s*.08,-.19,1.0-j*.08)],.06,armor,'Hips')
    else:
        for s in (-1,1):
            bevel_plate('Leaf_Plate_Breast_'+str(s),[(s*.02,-.145,1.58),(s*.21,-.131,1.55),(s*.225,-.151,1.37),(s*.07,-.168,1.24)],.045,armor,'Chest')
            tube('Elven_Chest_Filigree',[(s*.035,-.179,1.53),(s*.15,-.176,1.47),(s*.08,-.186,1.32)],[.009,.008,.002],trim,'Chest',6)
    contour('Heavy_Belt',[(0,0,1.035,.25 if dwarf else .195,.163),(0,0,1.09,.25 if dwarf else .195,.163)],leather,'Hips',20)
    bevel_plate('Corruption_Belt_Sigil',[(-.053,-.18,1.092),(.053,-.18,1.092),(.044,-.205,1.02),(-.044,-.205,1.02)],.025,trim,'Hips')
    blade('Belt_Inlaid_Crystal',(0,-.224,1.022),(0,-.224,1.097),.018,violet,'Hips')


def elf_outfit(hair, trim, violet, dark):
    cloth = material('Elf_TornVerdigris','234E4D',0,.83)
    for i in range(22):
        a=i*math.tau/22
        x,y=.15*math.sin(a),.02+.14*math.cos(a)
        fur_lock('Swept_Silver_Hair'+str(i),[(x*.6,y*.55,2.18),(x,y,2.09),(x*1.12,y+.045,1.92),(x*1.12,y+.13,1.72)],.032,.022,hair,'Head')
    for i in range(6):
        x=(i-2.5)*.042
        fur_lock('Angular_Fringe'+str(i),[(x*.7,-.07,2.17),(x,-.153,2.09),(x+.022,-.156,2.01)],.032,.018,hair,'Head')
    for s in (-1,1):
        # Separate front/back cape faces and weighted rows, not a billboard.
        rows=[(s*.13,.155,1.57,.16),(s*.15,.20,1.31,.18),(s*.18,.28,1.03,.23),(s*.22,.35,.72,.26),(s*.23,.37,.50,.25)]
        vs=[]
        for x,y,z,w in rows:
            vs += [(x-w,y,z),(x,y+.024,z+.018),(x+w,y,z)]
        fs=[]
        for j in range(len(rows)-1):
            for i in range(2):
                a=j*3+i;fs.append((a,a+3,a+4,a+1))
        weights=[]
        for j in range(len(rows)):
            weights += [{'Cape'+str(min(2,j//2)):1}]*3
        o=mesh('Torn_Elven_Cape',vs,fs,cloth,'Cape0',True,weights)
        modifier=o.modifiers.new('Woven cloth thickness','SOLIDIFY');modifier.thickness=.012
        for j in range(4):
            x,y,z,w=rows[j]
            q=rows[j+1]
            tube('Cape_Bronze_Edge',[(x+s*w,y-.016,z),(q[0]+s*q[3],q[1]-.016,q[2])],[.006,.006],trim,'Cape'+str(min(2,j//2)),6)
    # A recurved bow is physically gripped in the left hand.
    pts=[(.57,-.16,.58),(.73,-.18,.80),(.64,-.16,1.02),(.63,-.15,1.19),(.75,-.17,1.42),(.62,-.14,1.66)]
    tube('Thorn_Recurve_Bow',pts,[.012,.025,.025,.026,.022,.009],trim,'Hand.L',10)
    tube('Bowstring',[(.57,-.16,.58),(.59,-.25,1.12),(.62,-.14,1.66)],[.002]*3,material('Bowstring','B9B49D',0,.8),'Hand.L',4)
    for j in [1,4]:
        x,y,z=pts[j]
        blade('Bow_Corruption_Thorn',(x,y,z),(x+.16,y,z+.08),.03,violet,'Hand.L')
    tube('Arrow_Shaft',[(-.56,-.14,.89),(-.53,-.14,1.60)],[.008,.006],dark,'Hand.R',6)
    blade('Arrowhead',(-.53,-.14,1.58),(-.53,-.14,1.76),.044,violet,'Hand.R')
    contour('Back_Quiver',[(.12,.20,1.04,.10,.07),(.12,.20,1.52,.10,.075)],material('Oiled_Leather','27252A',0,.9),'Chest',12)
    for i in range(4):
        x=.06+i*.037
        tube('Quivered_Arrow'+str(i),[(x,.21,1.40),(x+.03,.22,1.83)],[.007,.005],dark,'Chest',6)
        blade('Arrow_Fletch'+str(i),(x+.02,.22,1.70),(x+.03,.22,1.83),.024,cloth,'Chest')


def dwarf_outfit(hair, armor, trim, violet, leather):
    # Helmet has a heavy raised brow, layered crest and open face.
    contour('Forged_Helmet_Crown',[(0,.025,2.06,.188,.162),(0,.02,2.18,.17,.15),(0,.02,2.26,.08,.085)],armor,'Head',16)
    tube('Helmet_Brow_Rim',[(-.18,-.13,2.07),(0,-.178,2.055),(.18,-.13,2.07)],[.015,.021,.015],trim,'Head',8)
    for s in (-1,1):
        bevel_plate('Helmet_Cheek',[(s*.16,-.10,2.10),(s*.21,-.04,2.08),(s*.18,-.035,1.88),(s*.12,-.13,1.89)],.04,armor,'Head')
        tube('Broken_Helmet_Horn',[(s*.17,.04,2.16),(s*.29,.05,2.21),(s*.33,.045,2.34),(s*.30,.035,2.40)],[.055,.045,.025,.001],trim,'Head',10)
    for i in range(15):
        x=(i-7)*.022
        length=.34 + .10*math.cos(i*.8)
        fur_lock('Braided_Beard_Lock'+str(i),[(x,-.13,1.91),(x*1.06,-.16,1.79),(x*.9,-.18,1.65),(x*.7,-.17,1.91-length)],.029,.024,hair,'Head')
        if i in (3,7,11):
            contour('Beard_Bronze_Cuff',[(x*.86,-.18,1.62,.018,.025),(x*.86,-.18,1.665,.019,.026)],trim,'Head',8)
    for s in (-1,1):
        fur_lock('Heavy_Moustache',[(s*.014,-.218,1.936),(s*.073,-.209,1.925),(s*.142,-.178,1.86)],.041,.027,hair,'Head')
    # Right hand war axe with a solid, faceted crescent blade and chipped edge.
    tube('Axe_Haft',[(-.55,-.11,.55),(-.55,-.11,1.56)],[.022,.024],leather,'Hand.R',10)
    for z in [.62,.73,.84,1.07,1.18]:
        contour('Axe_Wrapped_Bands',[(-.55,-.11,z,.031,.032),(-.55,-.11,z+.032,.031,.032)],trim,'Hand.R',10)
    bevel_plate('Axe_Crescent_Blade',[(-.56,-.12,1.48),(-.81,-.12,1.67),(-.96,-.12,1.59),(-1.00,-.12,1.36),(-.94,-.12,1.20),(-.79,-.12,1.25),(-.60,-.12,1.36)],.10,armor,'Hand.R')
    tube('Axe_Sharpened_Edge',[(-.81,-.15,1.67),(-.96,-.15,1.59),(-1.0,-.15,1.36),(-.94,-.15,1.20),(-.79,-.15,1.25)],[.014]*5,trim,'Hand.R',6)
    blade('Axe_Corrupt_Rune',(-.82,-.158,1.34),(-.88,-.158,1.52),.035,violet,'Hand.R')
    # The left fist carries a separate small iron buckler.
    bevel_plate('Dwarf_Spiked_Buckler',[(.35,-.18,1.22),(.54,-.20,1.31),(.75,-.18,1.18),(.72,-.18,.91),(.53,-.20,.84),(.35,-.18,.94)],.11,armor,'Hand.L')
    blade('Buckler_Spike',(.54,-.27,1.06),(.54,-.45,1.13),.07,trim,'Hand.L')


def wolf_features(skin, dark, fur, light, eye, claw):
    # Brow, muzzle, nose and split jaw establish a wolf rather than a human mask.
    contour('Wolf_Cranium',[(0,-.09,1.78,.08,.09),(0,-.11,1.88,.16,.13),(0,-.10,2.01,.175,.14),(0,-.07,2.12,.15,.12),(0,-.04,2.17,.085,.06)],skin,'Head',20)
    contour('Wolf_Muzzle',[(0,-.22,1.87,.083,.13),(0,-.22,1.94,.09,.16),(0,-.20,2.0,.09,.13)],light,'Head',14)
    bevel_plate('Wolf_Nose',[(-.056,-.382,1.974),(0,-.40,1.99),(.056,-.382,1.974),(.038,-.386,1.936),(-.035,-.386,1.936)],.044,dark,'Head')
    bevel_plate('Wolf_Open_Mouth',[(-.083,-.346,1.90),(.083,-.346,1.90),(.07,-.307,1.848),(-.065,-.307,1.848)],.035,dark,'Head')
    for s in (-1,1):
        tube('Wolf_Brow',[(s*.05,-.233,2.065),(s*.105,-.221,2.07),(s*.166,-.16,2.032)],[.025,.027,.012],fur,'Head',8)
        blade('Wolf_Glow_Eye',(s*.06,-.238,2.035),(s*.126,-.216,2.035),.015,eye,'Head')
        bevel_plate('Pointed_Wolf_Ear',[(s*.07,-.035,2.14),(s*.16,-.005,2.36),(s*.216,.016,2.12),(s*.17,.05,2.10)],.046,fur,'Head')
        bevel_plate('Wolf_Inner_Ear',[(s*.105,-.055,2.16),(s*.164,-.031,2.30),(s*.188,-.034,2.15)],.007,light,'Head')
        blade('Upper_Wolf_Fang',(s*.061,-.348,1.914),(s*.063,-.333,1.843),.013,claw,'Head')
        blade('Lower_Wolf_Fang',(s*.048,-.313,1.852),(s*.048,-.324,1.893),.01,claw,'Head')
        for j in range(5):
            z=2.035-j*.048
            fur_lock('Cheek_Ruff',[(s*.14,-.11,z),(s*.218,-.106,z-.04),(s*.27,-.07,z-.11)],.03,.025,light if j%2==0 else fur,'Head')
    # Large direction-following clumps make the mane readable at gameplay size.
    for i in range(42):
        a=i*math.tau/21
        row=i//21
        x=.29*math.sin(a)
        y=-.025+.19*math.cos(a)
        z=1.67-row*.13+.025*math.sin(i)
        fur_lock('Layered_Mane_'+str(i),[(x*.85,y,z+.07),(x*1.04,y+.04,z-.04),(x*1.22,y+.08,z-.20)],.045,.028,light if i%6==0 else fur,'Chest')
    for s in (-1,1):
        side='L' if s>0 else 'R'
        for j in range(7):
            z=1.40-j*.066
            x=s*(.41+(1.4-z)*.17)
            fur_lock('Forearm_Fur_'+side+str(j),[(x,.015,z),(x+s*.075,.02,z-.06),(x+s*.10,.04,z-.15)],.036,.027,fur,'Forearm.'+side)
        for digit in range(4):
            x=s*.54+(digit-1.5)*.031
            tube('Hand_Claw_'+side+str(digit),[(x,-.162,.862),(x,-.20,.824),(x,-.21,.785)],[.012,.008,.001],claw,'Hand.'+side,7)
        for toe in range(3):
            x=s*.19+(toe-1)*.06
            tube('Paw_Claw_'+side+str(toe),[(x,-.173,.11),(x,-.22,.09),(x,-.263,.06)],[.019,.014,.001],claw,'Foot.'+side,8)
        for j in range(7):
            x=s*(.13+j*.013)
            z=.99-j*.04
            fur_lock('Haunch_Fur_'+side+str(j),[(x,.07,z),(x+s*.066,.12,z-.13),(x+s*.075,.14,z-.22)],.033,.03,fur,'Thigh.'+side)
    tube('Wolf_Tail_Base',[(0,.14,1.0),(0,.30,.89),(0,.49,.77)],[.068,.075,.061],fur,'Tail',12)
    tube('Wolf_Tail_Tip',[(0,.49,.77),(.03,.63,.64),(.04,.71,.47)],[.061,.07,.007],fur,'TailTip',12)
    for i in range(10):
        a=i*math.tau/10
        fur_lock('Tail_Fur',[(.046*math.sin(a),.49+.02*math.cos(a),.78),(.045+.075*math.sin(a),.65,.64),(.05+.018*math.sin(a),.73,.43)],.028,.028,light if i%4==0 else fur,'TailTip')
    # Scars and broken restraints communicate the corrupted variant.
    wound=material('Wolf_Scar','755060',0,.91)
    for i in range(3):
        tube('Chest_Healed_Scar',[(.025+i*.055,-.231,1.56),(-.025+i*.055,-.218,1.44),(-.06+i*.055,-.192,1.37)],[.004,.006,.002],wound,'Chest',5)
    iron=material('Broken_Iron','3F4549',.75,.55)
    for s in (-1,1):
        side='L' if s>0 else 'R'
        contour('Broken_Wrist_Shackle',[(s*.514,-.059,1.074,.087,.077),(s*.528,-.067,1.02,.086,.076)],iron,'Forearm.'+side,12)
        for j in range(3):
            x=s*(.60+.012*j)
            z=1.065-.051*j
            pts=[(x+.012*math.cos(a*math.tau/10),-.015+.008*math.sin(a*math.tau/10),z+.028*math.sin(a*math.tau/10)) for a in range(11)]
            tube('Broken_Chain_Link',pts,[.006]*11,iron,'Forearm.'+side,5)


def animate(arm, identifier):
    arm.animation_data_create()
    scene=bpy.context.scene
    scene.render.fps=30
    for name,length,start in [('Idle',60,1),('Walk',30,70),('Attack',28,110),('Death',40,150)]:
        action=bpy.data.actions.new(name)
        arm.animation_data.action=action
        for f in range(length+1,):
            t=f/length
            wave=math.sin(t*math.tau)
            for b in arm.pose.bones:
                b.rotation_mode='XYZ';b.rotation_euler=(0,0,0);b.location=(0,0,0)
            arm.pose.bones['Chest'].rotation_euler.x=.018*wave
            arm.pose.bones['Head'].rotation_euler.z=.022*math.sin(t*math.tau+.4)
            for i in range(3):
                arm.pose.bones['Cape'+str(i)].rotation_euler.x=.04*math.sin(t*math.tau-i*.6)
            arm.pose.bones['Tail'].rotation_euler.y=.13*wave
            arm.pose.bones['TailTip'].rotation_euler.z=.14*math.sin(t*math.tau-.6)
            if name=='Walk':
                for side,sign in [('L',1),('R',-1)]:
                    arm.pose.bones['Thigh.'+side].rotation_euler.x=.43*wave*sign
                    arm.pose.bones['Shin.'+side].rotation_euler.x=.43*max(0,-wave*sign)
                    arm.pose.bones['Foot.'+side].rotation_euler.x=-.14*wave*sign
                    arm.pose.bones['UpperArm.'+side].rotation_euler.x=-.26*wave*sign
                arm.pose.bones['Hips'].location.z=.018*math.sin(t*math.tau*2)
                arm.pose.bones['Chest'].rotation_euler.z=.05*wave
            elif name=='Attack':
                # Authored windup/contact/recovery curve, distinct by weapon.
                wind=math.sin(min(t/.45,1)*math.pi/2)
                hit=math.sin(max(0,min((t-.30)/.70,1))*math.pi)
                recover=math.sin(t*math.pi)
                if identifier=='fallen_elf':
                    arm.pose.bones['UpperArm.L'].rotation_euler.x=-1.0*recover
                    arm.pose.bones['UpperArm.L'].rotation_euler.z=-.40*recover
                    arm.pose.bones['Forearm.R'].rotation_euler.x=-1.45*recover
                    arm.pose.bones['UpperArm.R'].rotation_euler.z=.36*recover
                    arm.pose.bones['Chest'].rotation_euler.z=-.18*recover
                elif identifier=='fallen_dwarf':
                    arm.pose.bones['UpperArm.R'].rotation_euler.x=-1.5*recover+.75*hit
                    arm.pose.bones['Forearm.R'].rotation_euler.x=-.50*recover
                    arm.pose.bones['Chest'].rotation_euler.z=.27*recover-.48*hit
                    arm.pose.bones['Chest'].rotation_euler.x=.18*hit
                else:
                    arm.pose.bones['UpperArm.R'].rotation_euler.x=-.85*recover
                    arm.pose.bones['UpperArm.R'].rotation_euler.z=.55*recover-.82*hit
                    arm.pose.bones['Forearm.R'].rotation_euler.x=-.34*recover
                    arm.pose.bones['UpperArm.L'].rotation_euler.x=-.35*recover
                    arm.pose.bones['Chest'].rotation_euler.z=.22*recover-.40*hit
                    arm.pose.bones['Chest'].rotation_euler.x=.2*hit
            elif name=='Death':
                ease=min(1,t/.82);ease=ease*ease*(3-2*ease)
                arm.pose.bones['Root'].rotation_euler.x=-1.46*ease
                arm.pose.bones['Root'].location.z=.17*ease
                arm.pose.bones['Head'].rotation_euler.x=.18*ease
                arm.pose.bones['UpperArm.L'].rotation_euler.z=-.55*ease
                arm.pose.bones['UpperArm.R'].rotation_euler.z=.42*ease
                arm.pose.bones['Thigh.L'].rotation_euler.x=.22*ease
                arm.pose.bones['Shin.L'].rotation_euler.x=.40*ease
            for b in arm.pose.bones:
                b.keyframe_insert('rotation_euler',frame=start+f,group=b.name)
                b.keyframe_insert('location',frame=start+f,group=b.name)
        track=arm.animation_data.nla_tracks.new();track.name=name
        strip=track.strips.new(name,start,action)
        strip.action_frame_start=start;strip.action_frame_end=start+length
    arm.animation_data.action=None
    scene.frame_set(1)


def build(identifier):
    global PARTS,MATERIALS,SCALE
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    PARTS=[];MATERIALS={}
    SCALE={'fallen_elf':(1,1,1),'fallen_dwarf':(1.25,1.14,.77),'fallen_werewolf':(1.19,1.10,1.08)}[identifier]
    skin=material({'fallen_elf':'Elf_AshenSkin','fallen_dwarf':'Dwarf_RuddySkin','fallen_werewolf':'Wolf_Undercoat'}[identifier],{'fallen_elf':'AA9DAD','fallen_dwarf':'99745E','fallen_werewolf':'55535E'}[identifier],0,.77)
    armor=material('Obsidian_Armor','303847',.72,.37)
    trim=material('Tarnished_Bronze','AA8A55',.80,.40)
    leather=material('Weathered_Leather','332C34',0,.88)
    dark=material('Deep_Seams','171D27',0,.81)
    violet=material('Corruption_Crystal','AE69CE',.12,.3,.65)
    eye=material('Corruption_Eyes','EAAF65',0,.24,1.5)
    hair=material('Elf_SilverHair' if identifier=='fallen_elf' else 'Dwarf_IronBeard','A6B6BD' if identifier=='fallen_elf' else '615E68',0,.7)
    arm=create_rig(identifier,identifier=='fallen_werewolf')
    torso(identifier,skin,leather,armor)
    if identifier=='fallen_werewolf':
        fur=material('Wolf_GuardFur','313744',0,.84)
        light=material('Wolf_PaleFur','A6A6A1',0,.83)
        claw=material('Wolf_BoneClaws','C9C4A7',0,.46)
        wolf_features(skin,dark,fur,light,eye,claw)
    else:
        humanoid_face(identifier,skin,eye,dark,hair)
        armor_details(identifier,armor,trim,leather,violet)
        if identifier=='fallen_elf':elf_outfit(hair,trim,violet,dark)
        else:dwarf_outfit(hair,armor,trim,violet,leather)
    for obj in PARTS:
        bpy.context.view_layer.objects.active=obj;obj.select_set(True)
        for modifier in list(obj.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
        obj.select_set(False)
    # One skinned renderer per model, material regions retained for Unity remap.
    bpy.ops.object.select_all(action='DESELECT')
    for obj in PARTS:obj.select_set(True)
    bpy.context.view_layer.objects.active=PARTS[0]
    bpy.ops.object.join()
    body=bpy.context.object;body.name=identifier+'_SkinnedBody'
    body.parent=arm
    modifier=body.modifiers.new('Weighted_Bone_Deformation','ARMATURE');modifier.object=arm
    animate(arm,identifier)
    bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);body.select_set(True)
    bpy.context.view_layer.objects.active=arm
    bpy.context.scene.unit_settings.system='METRIC'
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(identifier+'.blend')))
    bpy.ops.export_scene.fbx(filepath=str(UNITY/(identifier+'.fbx')),use_selection=True,object_types={'ARMATURE','MESH'},add_leaf_bones=False,axis_forward='-Z',axis_up='Y',bake_anim=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=True,bake_anim_simplify_factor=0,apply_scale_options='FBX_SCALE_ALL',use_mesh_modifiers=True)
    mats=[{k:v for k,v in row.items() if k!='material'} for row in MATERIALS.values()]
    manifest={'id':identifier,'display_name':{'fallen_elf':'타락한 엘프','fallen_dwarf':'타락한 드워프','fallen_werewolf':'타락한 늑대인간'}[identifier],'status':'native rigged volume development asset; visual acceptance and runtime validation deferred','source':str((OUT/(identifier+'.blend')).relative_to(ROOT)).replace('\\','/'),'resource':'Eternal/GraphicsRebuild/Monsters/'+identifier,'fbx':str((UNITY/(identifier+'.fbx')).relative_to(ROOT)).replace('\\','/'),'nominal_height_m':{'fallen_elf':2.20,'fallen_dwarf':1.85,'fallen_werewolf':2.55}[identifier],'forward':'Blender -Y; FBX export -Z forward / Y up','triangles':sum(len(p.vertices)-2 for p in body.data.polygons),'bones':len(arm.data.bones),'clips':['Idle','Walk','Attack','Death'],'clip_fps':30,'materials':mats,'limitations':['Material-color anatomy pass; final PBR texture painting remains.','Bone animation authored; final combat-timing and foot-contact acceptance deferred.','Fur is closed sculpted clumps, not simulated strands.','The source/reference quality target is not claimed achieved.']}
    (OUT/(identifier+'-manifest.json')).write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    (UNITY/(identifier+'-materials.json')).write_text(json.dumps({'id':identifier,'materials':mats},ensure_ascii=False,indent=2),encoding='utf-8')
    print('FALLEN_NATIVE_EXPORTED',identifier,manifest['triangles'],manifest['bones'])
    return manifest


if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True);UNITY.mkdir(parents=True,exist_ok=True)
    results=[build(identifier) for identifier in ['fallen_elf','fallen_dwarf','fallen_werewolf']]
    (OUT/'development-manifest.json').write_text(json.dumps({'pipeline':'Blender closed anatomical meshes and rigged FBX; no sprite or concept-image character substitute','monsters':results,'stage':'development; acceptance deferred'},ensure_ascii=False,indent=2),encoding='utf-8')
