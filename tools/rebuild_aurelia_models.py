"""Author the second rigged volume-mesh pass of the three Aurelia pilot heroes.

Blender: --background --factory-startup --python tools/rebuild_aurelia_models.py
This is a production-development mesh pass, not concept-quality acceptance.
No artwork is placed on a billboard or a camera-facing character plane.
"""
from pathlib import Path
import json
import math
import bpy
import bmesh
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/graphics-rebuild-v1/models'
UNITY=ROOT/'Unity/Assets/Game/Resources/Eternal/GraphicsRebuild/Heroes'
OUT.mkdir(parents=True,exist_ok=True);UNITY.mkdir(parents=True,exist_ok=True)
PARTS=[];MATS={}

def mat(name,hexcolor,metal=0,rough=.65,emit=0):
    key=(name,hexcolor,metal,rough,emit)
    if key in MATS:return MATS[key]
    m=bpy.data.materials.new(name);m.use_nodes=True
    c=tuple(int(hexcolor[i:i+2],16)/255 for i in (0,2,4))+(1,)
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=c
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    p.inputs['Emission Color'].default_value=c;p.inputs['Emission Strength'].default_value=emit
    m.diffuse_color=c;m.metallic=metal;m.roughness=rough
    m['surface_role']=name;m['authoring_metallic']=metal;m['authoring_roughness']=rough
    if 'Skin' in name:
        p.inputs['Subsurface Weight'].default_value=.10
        p.inputs['Subsurface Radius'].default_value=(1,.38,.22)
    if 'hair' in name.lower():
        anisotropy=p.inputs.get('Anisotropic') or p.inputs.get('Anisotropic IOR Level')
        if anisotropy:anisotropy.default_value=.38
    MATS[key]=m;return m

def mesh(name,vertices,faces,material,bone,smooth=True):
    data=bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update()
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o);o.data.materials.append(material)
    group=o.vertex_groups.new(name=bone);group.add(list(range(len(vertices))),1,'REPLACE')
    for f in data.polygons:f.use_smooth=smooth
    # A usable UV layer is authored on every surface. Structured builders below
    # replace this fallback box projection with seam-aware cylindrical/grid UVs.
    uv=data.uv_layers.new(name='UVMap')
    bounds=[(min(v.co[a] for v in data.vertices),max(v.co[a] for v in data.vertices)) for a in range(3)]
    for poly in data.polygons:
        axis=max(range(3),key=lambda a:abs(poly.normal[a]));axes=[a for a in range(3) if a!=axis]
        for index in poly.loop_indices:
            co=data.vertices[data.loops[index].vertex_index].co
            uv.data[index].uv=tuple((co[a]-bounds[a][0])/max(.001,bounds[a][1]-bounds[a][0]) for a in axes)
    o['geometry_authoring']='closed volume / articulated surface; no artwork plane'
    PARTS.append(o);return o


def grid_uv(o,columns,rows,wrap=False):
    layer=o.data.uv_layers.active
    for poly in o.data.polygons:
        vertex_ids=[o.data.loops[i].vertex_index for i in poly.loop_indices]
        seam=wrap and any(v%columns==0 for v in vertex_ids) and any(v%columns==columns-1 for v in vertex_ids)
        for index in poly.loop_indices:
            v=o.data.loops[index].vertex_index;column=v%columns
            u=1.0 if seam and column==0 else column/(columns if wrap else max(1,columns-1))
            layer.data[index].uv=(u,(v//columns)/max(1,rows-1))
    return o


def weight(o,weights):
    """Normalize a callable's per-vertex influences; never rely on auto-weights."""
    o.vertex_groups.clear()
    for vertex in o.data.vertices:
        values={k:v for k,v in weights(vertex.co).items() if v>.0001};total=sum(values.values())
        for name,value in values.items():
            group=o.vertex_groups.get(name) or o.vertex_groups.new(name=name)
            group.add([vertex.index],value/total,'REPLACE')
    return o


def height_weights(z,anchors):
    if z<=anchors[0][0]:return {anchors[0][1]:1}
    for (lo,a),(hi,b) in zip(anchors,anchors[1:]):
        if z<=hi:
            t=max(0,min(1,(z-lo)/(hi-lo)));t=t*t*(3-2*t)
            return {a:1-t,b:t} if a!=b else {a:1}
    return {anchors[-1][1]:1}

def contour(name,sections,material,bone,sides=16):
    # Each section: center x/y/z and elliptical width/depth. Explicit contours
    # give the torso, jaw, armor and boots different silhouettes.
    vs=[];fs=[]
    for x,y,z,w,d in sections:
        for i in range(sides):
            a=i*math.tau/sides;vs.append((x+math.sin(a)*w,y+math.cos(a)*d,z))
    for row in range(len(sections)-1):
        for i in range(sides):
            a=row*sides+i;b=row*sides+(i+1)%sides
            fs.append((a,a+sides,b+sides,b))
    fs.extend([tuple(range(sides)),tuple(reversed(tuple((len(sections)-1)*sides+i for i in range(sides))))])
    return grid_uv(mesh(name,vs,fs,material,bone),sides,len(sections),True)

def tube(name,points,radii,material,bone,sides=8):
    vs=[];fs=[]
    for j,p in enumerate(points):
        up=Vector(points[min(j+1,len(points)-1)])-Vector(points[max(0,j-1)])
        up.normalize();right=up.cross(Vector((0,0,1)))
        if right.length<.001:right=up.cross(Vector((0,1,0)))
        right.normalize();side=up.cross(right).normalized()
        radius=radii[j]
        for i in range(sides):vs.append(Vector(p)+(right*math.cos(i*math.tau/sides)+side*math.sin(i*math.tau/sides))*radius)
    for j in range(len(points)-1):
        for i in range(sides):a=j*sides+i;b=j*sides+(i+1)%sides;fs.append((a,b,b+sides,a+sides))
    fs.extend([tuple(reversed(range(sides))),tuple((len(points)-1)*sides+i for i in range(sides))])
    return grid_uv(mesh(name,vs,fs,material,bone),sides,len(points),True)

def ell(name,p,r,material,bone,segments=18,rings=10):
    vs=[];fs=[]
    for j in range(rings+1):
        a=j/rings*math.pi
        for i in range(segments):
            b=i/segments*math.tau;vs.append((p[0]+r[0]*math.sin(a)*math.cos(b),p[1]+r[1]*math.sin(a)*math.sin(b),p[2]+r[2]*math.cos(a)))
    for j in range(rings):
        for i in range(segments):a=j*segments+i;b=j*segments+(i+1)%segments;fs.append((a,a+segments,b+segments,b))
    return grid_uv(mesh(name,vs,fs,material,bone),segments,rings+1,True)

def panel(name,rows,material,bones,width=9):
    vs=[];fs=[]
    for j,(x,y,z,span) in enumerate(rows):
        for i in range(width):
            u=i/(width-1)-.5
            vs.append((x+u*span,y+math.cos(u*math.pi*6)*.022*(j/max(1,len(rows)-1)),z+math.sin(u*math.pi)*.012))
    for j in range(len(rows)-1):
        for i in range(width-1):a=j*width+i;fs.append((a,a+width,a+width+1,a+1))
    o=grid_uv(mesh(name,vs,fs,material,bones[0]),width,len(rows));o.vertex_groups.clear()
    for j in range(len(rows)):
        segment=j/max(1,len(rows)-1)*(len(bones)-1);lower=int(segment);blend=segment-lower
        for b,value in [(bones[lower],1-blend),(bones[min(len(bones)-1,lower+1)],blend)]:
            if value<.0001:continue
            g=o.vertex_groups.get(b) or o.vertex_groups.new(name=b)
            g.add(list(range(j*width,(j+1)*width)),value,'ADD')
    solid=o.modifiers.new('Cloth thickness','SOLIDIFY');solid.thickness=.009
    return o

def hair_lock(name,points,width,depth,material,bone='Head'):
    # Sculpted tapered ribbons with a convex profile and real side/back faces.
    vs=[];fs=[]
    for j,p in enumerate(points):
        fraction=j/max(1,len(points)-1);w=width*(.25+.75*math.sin((fraction+.1)*math.pi/.95)) if j<len(points)-1 else .001
        w=max(.001,w)
        for u in range(5):
            x=u/4-.5;vs.append((p[0]+x*w,p[1]-math.cos(x*math.pi)*depth*(1-fraction*.7),p[2]))
    for j in range(len(points)-1):
        for i in range(4):a=j*5+i;fs.append((a,a+5,a+6,a+1))
    o=grid_uv(mesh(name,vs,fs,material,bone),5,len(points));s=o.modifiers.new('Hair volume','SOLIDIFY');s.thickness=.008
    return o

def bone(arm,name,head,tail,parent=None):
    b=arm.edit_bones.new(name);b.head=head;b.tail=tail
    if parent:b.parent=arm.edit_bones[parent]
    return b

def rig(hero):
    data=bpy.data.armatures.new(hero+' skeleton');o=bpy.data.objects.new(hero+' Rig',data);bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
    bone(data,'Root',(0,0,0),(0,0,.18));bone(data,'Hips',(0,0,.93),(0,0,1.10),'Root')
    bone(data,'Spine',(0,0,1.10),(0,0,1.38),'Hips');bone(data,'Chest',(0,0,1.38),(0,0,1.62),'Spine')
    bone(data,'Neck',(0,0,1.62),(0,0,1.78),'Chest');bone(data,'Head',(0,0,1.78),(0,0,2.14),'Neck')
    for s in [-1,1]:
        suffix='L' if s>0 else 'R'
        bone(data,'UpperArm.'+suffix,(s*.27,0,1.55),(s*.40,-.01,1.24),'Chest')
        bone(data,'Forearm.'+suffix,(s*.40,-.01,1.24),(s*.47,-.055,.99),'UpperArm.'+suffix)
        bone(data,'Hand.'+suffix,(s*.47,-.055,.99),(s*.48,-.08,.86),'Forearm.'+suffix)
        bone(data,'Thigh.'+suffix,(s*.12,0,.98),(s*.14,-.01,.56),'Hips')
        bone(data,'Shin.'+suffix,(s*.14,-.01,.56),(s*.15,0,.13),'Thigh.'+suffix)
        bone(data,'Foot.'+suffix,(s*.15,0,.13),(s*.15,-.18,.08),'Shin.'+suffix)
    for i in range(5):bone(data,'Cape'+str(i),(0,.16+i*.035,1.53-i*.22),(0,.195+i*.035,1.31-i*.22),'Chest' if i==0 else 'Cape'+str(i-1))
    for i in range(3):
        bone(data,'Hair'+str(i),(0,.18+i*.10,2.10-i*.28),(0,.28+i*.07,1.82-i*.28),'Head' if i==0 else 'Hair'+str(i-1))
    for side in ['Front','L','R']:
        x=0 if side=='Front' else .2 if side=='L' else -.2;y=-.16 if side=='Front' else .04
        for i in range(4):bone(data,'Skirt'+side+str(i),(x,y,1.08-i*.22),(x,y,.86-i*.22),'Hips' if i==0 else 'Skirt'+side+str(i-1))
    bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False);return o

def face(hero,skin,ink,eye,hair):
    male=hero=='leonhardt';jaw=1 if male else .90
    contour('Sculpted jaw cheeks brow and cranium',[(0,.01,1.765,.035,.040),(0,.002,1.795,.075*jaw,.073),(0,.002,1.825,.105*jaw,.09),(0,.008,1.865,.137*jaw,.114),(0,.005,1.905,.155,.129),(0,.003,1.940,.165,.137),(0,.008,1.975,.169,.140),(0,.012,2.02,.171,.147),(0,.024,2.06,.161,.143),(0,.029,2.10,.145,.130),(0,.030,2.14,.103,.102),(0,.030,2.175,.043,.048)],skin,'Head',32)
    rim=mat('Warm eyelid skin','d4a18f',0,.70)
    for s in [-1,1]:
        ell('Ear helix',(s*.172,.015,1.95),(.029,.031,.060),skin,'Head',12,8)
        ell('Ear inner concha',(s*.192,-.006,1.950),(.012,.016,.037),rim,'Head',12,6)
        # Flattened eyeballs sit inside a distinct almond-shaped lid volume.
        ell('Sclera',(s*.073,-.131,1.970),(.042,.014,.026 if male else .029),mat('Eye ivory','f8f1df',0,.3),'Head',20,10)
        ell('Iris limbal rim',(s*.073,-.147,1.970),(.019,.002,.023),ink,'Head',16,8)
        ell('Iris',(s*.073,-.150,1.970),(.0155,.002,.019),eye,'Head',18,10)
        ell('Pupil',(s*.073,-.153,1.970),(.007,.002,.012),ink,'Head',14,8)
        ell('Eye catchlight',(s*.067,-.156,1.979),(.004,.0015,.005),mat('Eye light','ffffff',0,.2),'Head',10,6)
        top=[(s*.032,-.135,1.974),(s*.052,-.149,1.994),(s*.081,-.149,1.998),(s*.113,-.124,1.984)]
        bottom=[(s*.032,-.135,1.971),(s*.061,-.148,1.947),(s*.088,-.140,1.948),(s*.113,-.124,1.984)]
        tube('Upper eyelid anatomy',[(x,y+.002,z+.003) for x,y,z in top],[.004,.006,.006,.002],rim,'Head',6)
        tube('Fine upper lashes',top,[.002,.0035,.004,.001],ink,'Head',6)
        tube('Lower eyelid anatomy',bottom,[.002,.0035,.003,.001],rim,'Head',6)
        tube('Eyebrow',[(s*.035,-.133,2.018),(s*.074,-.143,2.030),(s*.113,-.119,2.022)],[.002,.005 if male else .0035,.001],hair,'Head',6)
        if not male:tube('Outer eyelash',[(s*.099,-.137,1.991),(s*.121,-.126,1.997)],[.003,.0005],ink,'Head',5)
    contour('Nose sculpt',[(0,-.126,1.913,.011,.008),(0,-.142,1.924,.018,.015),(0,-.148,1.937,.012,.022),(0,-.130,1.969,.009,.011),(0,-.130,1.989,.008,.004)],skin,'Head',12)
    lip=mat('Lip rose','ae7770' if male else 'c88482',0,.62)
    tube('Upper lip bow',[(-.026,-.121,1.867),(-.010,-.136,1.871),(0,-.138,1.868),(.010,-.136,1.871),(.026,-.121,1.867)],[.001,.002,.002,.002,.001],lip,'Head',6)
    tube('Lower lip',[(-.021,-.124,1.864),(0,-.139,1.860),(.021,-.124,1.864)],[.001,.003,.001],rim,'Head',6)


def plaque(name,outline,y,depth,material,bone,rim=None):
    """Convex sculpted armor/ornament, with an actual bevel and back surface."""
    cx=sum(x for x,z in outline)/len(outline);cz=sum(z for x,z in outline)/len(outline)
    vertices=[(x,y,z) for x,z in outline]+[(cx,y-depth,cz)]
    faces=[(len(outline),i,(i+1)%len(outline)) for i in range(len(outline))]
    o=mesh(name,vertices,faces,material,bone,False)
    solid=o.modifiers.new('Metal plate thickness','SOLIDIFY');solid.thickness=.012
    if rim:
        points=[(x,y-.004,z) for x,z in outline]+[(outline[0][0],y-.004,outline[0][1])]
        tube(name+' raised edge',points,[.007]*len(points),rim,bone,6)
    return o


def leaf(name,p,w,h,material,bone,angle=0):
    vertices=[]
    for x,z in [(0,-h/2),(-w/2,-h*.12),(-w*.31,h*.30),(0,h/2),(w*.31,h*.30),(w/2,-h*.12)]:
        vertices.append((p[0]+x*math.cos(angle)-z*math.sin(angle),p[2]+x*math.sin(angle)+z*math.cos(angle)))
    return plaque(name,vertices,p[1],.011,material,bone)


def gem(name,p,w,h,material,bone):
    x,y,z=p
    return mesh(name,[(x-w,y,z),(x,y,z+h),(x+w,y,z),(x,y,z-h),(x,y-.022,z),(x,y+.016,z)],[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(1,0,5),(2,1,5),(3,2,5),(0,3,5)],material,bone,False)


def wardrobe(hero,gold,ivory,leather,cloth):
    steel=mat('Recessed armor steel','5d6573',.8,.39)
    silk=mat('Ivory silk','eee5cf',0,.82)
    # Belts articulate with the hips; chest armor is rigid over a smoothly
    # weighted undergarment. The waist therefore no longer stretches a cuirass.
    contour('Hip leather belt',[(0,0,1.02,.196,.14),(0,0,1.09,.205,.145)],leather,'Hips',24)
    plaque('Belt buckle',[(-.045,1.026),(.045,1.026),(.054,1.092),(-.054,1.092)],-.151,.009,gold,'Hips')
    gem('Belt inset',(0,-.170,1.059),.017,.022,cloth,'Hips')
    if hero=='leonhardt':
        # Separate cuirass, gorget, abdominal lames and hip tassets.
        plaque('Sculpted breastplate',[(-.14,1.30),(.14,1.30),(.22,1.43),(.19,1.54),(.10,1.59),(0,1.54),(-.10,1.59),(-.19,1.54),(-.22,1.43)],-.129,.058,ivory,'Chest',gold)
        contour('Gorget collar',[(0,0,1.57,.103,.087),(0,0,1.655,.085,.077)],steel,'Chest',20)
        for j in range(3):
            z=1.105+j*.063;w=.166+j*.008
            plaque('Articulated abdominal lame '+str(j),[(-w,z), (w,z),(w*.92,z+.076),(-w*.92,z+.076)],-.135,.027,ivory,'Spine',gold)
        gem('Cuirass sapphire',(0,-.198,1.463),.035,.051,mat('Crown sapphire','2e67b7',.5,.20),'Chest')
        for s in [-1,1]:
            plaque('Hip tasset '+str(s),[(s*.055,.87),(s*.190,.81),(s*.255,.93),(s*.211,1.058),(s*.077,1.041)],-.145,.021,ivory,'Thigh.'+('L' if s>0 else 'R'),gold)
            for j in range(3):
                leaf('Cuirass chased gold leaf',(s*(.058+j*.039),-.193+j*.011,1.435+j*.031),.027,.060,gold,'Chest',s*-.65)
            for z in [1.145,1.204,1.267]:
                tube('Abdominal side rivet',[(s*.139,-.154,z),(s*.141,-.167,z)],[.007,.007],gold,'Spine',7)
            # Ankle-to-knee articulated plates are separated by dark joint gaps.
            suffix='L' if s>0 else 'R'
            plaque('Pointed knee poleyn '+suffix,[(s*.14-.071,.54),(s*.14,.482),(s*.14+.071,.54),(s*.14+.052,.623),(s*.14,.647),(s*.14-.052,.623)],-.074,.025,ivory,'Shin.'+suffix,gold)
            plaque('Ridged greave '+suffix,[(s*.15-.043,.18),(s*.15+.043,.18),(s*.15+.077,.41),(s*.15+.045,.505),(s*.15-.045,.505),(s*.15-.077,.41)],-.051,.037,ivory,'Shin.'+suffix,gold)
            for j in range(3):
                z=1.305+j*.057;x=s*(.389-j*.018)
                plaque('Overlapping arm lame '+suffix+str(j),[(x-.052,z-.033),(x+.052,z-.033),(x+.058,z+.033),(x-.058,z+.033)],-.080,.014,ivory,'UpperArm.'+suffix,gold)
        # Physical insignia: four heraldic rays, no copied artwork texture.
        for a in [0,math.pi/2,math.pi,3*math.pi/2]:leaf('Blue tabard heraldry',(0,-.209,.867),.029,.16,gold,'Hips',a)
    elif hero=='mira':
        contour('Fitted leather waist corset',[(0,0,1.08,.184,.145),(0,0,1.20,.152,.12),(0,0,1.34,.190,.151)],leather,'Spine',24)
        for s in [-1,1]:
            suffix='L' if s>0 else 'R'
            plaque('White split tunic '+suffix,[(s*.018,1.306),(s*.166,1.317),(s*.226,1.466),(s*.144,1.565),(s*.040,1.518)],-.13,.041,silk,'Chest',gold)
            plaque('Leather hip skirt '+suffix,[(s*.019,.89),(s*.242,.862),(s*.225,1.052),(s*.050,1.052)],-.145,.014,leather,'Hips',gold)
            # Pale insets, thigh straps and fitted open kneecaps read separately.
            plaque('Ivory skirt inset '+suffix,[(s*.044,.92),(s*.166,.917),(s*.161,1.029),(s*.054,1.028)],-.166,.006,silk,'Hips')
            for z in [.797,.722]:
                contour('Thigh harness '+suffix,[(s*.132,-.002,z-.019,.082,.087),(s*.132,-.002,z+.019,.082,.087)],leather,'Thigh.'+suffix,16)
                gem('Thigh buckle '+suffix,(s*.132,-.095,z),.018,.014,gold,'Thigh.'+suffix)
            plaque('Archer kneecap '+suffix,[(s*.14-.050,.52),(s*.14,.48),(s*.14+.050,.52),(s*.14+.049,.60),(s*.14,.63),(s*.14-.049,.60)],-.076,.015,gold,'Shin.'+suffix)
            for j in range(4):
                z=.30+j*.055
                tube('Boot lace '+suffix+str(j),[(s*.15-.029,-.059,z),(s*.15+.029,-.059,z+.03)],[.003,.003],gold,'Shin.'+suffix,5)
        for j in range(4):
            z=1.115+j*.047
            tube('Corset crossed lace A',[(-.04,-.152,z),(.04,-.152,z+.037)],[.003,.003],gold,'Spine',5)
            tube('Corset crossed lace B',[(.04,-.153,z),(-.04,-.153,z+.037)],[.003,.003],gold,'Spine',5)
        # Visible diagonal quiver harness sits across the chest with a buckle.
        tube('Quiver leather harness',[(-.16,-.153,1.52),(-.075,-.195,1.39),(.085,-.149,1.13)],[.020,.024,.020],leather,'Chest',6)
        gem('Harness gold clasp',(-.09,-.216,1.408),.025,.033,gold,'Chest')
    else:
        # Leaf-shaped bodice with a waist blossom and green layered skirt.
        for s in [-1,1]:
            leaf('Ivory bodice petal',(s*.080,-.148,1.438),.153,.29,silk,'Chest',s*-.27)
            leaf('Green bodice leaf',(s*.145,-.141,1.344),.095,.23,cloth,'Spine',s*-.39)
            tube('Golden waist vine',[(s*.19,-.119,1.184),(s*.10,-.158,1.248),(0,-.164,1.296)],[.008,.010,.010],gold,'Spine',7)
            tube('Bare shoulder floral chain',[(s*.105,-.025,1.606),(s*.172,-.073,1.559),(s*.228,-.055,1.510)],[.005,.005,.005],gold,'Chest',6)
            for j in range(4):
                leaf('Gown embroidered leaf',(s*(.25+j*.016),-.094,.40+j*.15),.043,.13,gold,'Skirt'+('L' if s>0 else 'R')+str(max(0,3-j)),s*-.32)
            contour('Silk ankle shoe '+str(s),[(s*.15,-.076,.03,.071,.134),(s*.15,-.080,.10,.065,.127),(s*.15,-.026,.15,.047,.060)],silk,'Foot.'+('L' if s>0 else 'R'),16)
        for i in range(5):leaf('Waist blossom petal',(0,-.176,1.247),.029,.105,ivory,'Spine',i*math.tau/5)
        gem('Waist emerald',(0,-.194,1.247),.014,.019,mat('Forest emerald','438343',.3,.25),'Spine')

def build(hero):
    global PARTS,MATS
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);PARTS=[];MATS={}
    for collection in [bpy.data.meshes,bpy.data.armatures,bpy.data.materials,bpy.data.actions]:
        for block in list(collection):
            if block.users==0:collection.remove(block)
    gold=mat('Aurelia engraved gold','c39a48',.8,.3);ivory=mat('Ivory enamel plate','e9e3cf',.55,.35)
    leather=mat('Dark leather','30272c',0,.82);ink=mat('Dark eye and seams','171922',0,.64)
    skin=mat('Skin','f2cab0',0,.7);blue=mat('Royal blue cloth','21418b',0,.82);green=mat('Forest silk','547c3e',0,.75);red=mat('Royal crimson cloth','8e242a',0,.82)
    hair=mat('Hero hair',{'leonhardt':'d9a64d','elisia':'e8d8c9','mira':'923831'}[hero],0,.52)
    hair_high=mat('Hair highlights',{'leonhardt':'f2cc7e','elisia':'f4e7d9','mira':'b34a3c'}[hero],0,.5)
    eye=mat('Iris',{'leonhardt':'3b80b4','elisia':'55834c','mira':'ac573e'}[hero],0,.24)
    arm=rig(hero);female=hero!='leonhardt';width=.20 if female else .255
    torso=contour('Weighted torso undergarment',[(0,0,.96,width*.8,.13),(0,0,1.04,width*.9,.13),(0,0,1.10,width*.83,.12),(0,0,1.20,width*.72,.105),(0,0,1.30,width*.85,.13),(0,0,1.40,width,.14),(0,0,1.51,width*1.08,.13),(0,0,1.59,width*.65,.09)],green if hero=='elisia' else leather,'Chest',24)
    weight(torso,lambda v:height_weights(v.z,[(1.03,'Hips'),(1.20,'Spine'),(1.48,'Chest')]))
    neck=contour('Neck',[(0,0,1.57,.073,.070),(0,0,1.63,.064,.061),(0,0,1.71,.060,.060),(0,0,1.78,.060,.060)],skin,'Neck',16)
    weight(neck,lambda v:height_weights(v.z,[(1.59,'Chest'),(1.67,'Neck'),(1.78,'Head')]))
    face(hero,skin,ink,eye,hair)
    for s in [-1,1]:
        suffix='L' if s>0 else 'R';arm_mat=ivory if hero=='leonhardt' else skin
        arm_body=contour('Weighted continuous arm '+suffix,[(s*.27,0,1.54,.077,.081),(s*.32,0,1.44,.078,.080),(s*.374,-.01,1.31,.056,.060),(s*.40,-.01,1.25,.053,.055),(s*.411,-.016,1.21,.054,.056),(s*.44,-.03,1.12,.060,.061),(s*.47,-.055,.99,.042,.042)],leather if hero=='leonhardt' else skin,'UpperArm.'+suffix)
        weight(arm_body,lambda v,suffix=suffix:height_weights(v.z,[(.99,'Hand.'+suffix),(1.08,'Forearm.'+suffix),(1.19,'Forearm.'+suffix),(1.31,'UpperArm.'+suffix),(1.54,'UpperArm.'+suffix)]))
        bracer=contour('Raised vambrace '+suffix,[(s*.425,-.027,1.19,.066,.067),(s*.442,-.035,1.13,.069,.070),(s*.460,-.045,1.048,.052,.052)],ivory if hero=='leonhardt' else leather,'Forearm.'+suffix,16)
        hand_mat=leather if hero!='elisia' else skin
        contour('Hand '+suffix,[(s*.47,-.055,1,.042,.031),(s*.48,-.075,.91,.046,.031),(s*.48,-.085,.87,.031,.025)],hand_mat,'Hand.'+suffix,12)
        for f in range(4):tube('Articulated finger '+suffix+str(f),[(s*.48+(f-1.5)*.016,-.09,.92),(s*.48+(f-1.5)*.015,-.119,.887),(s*.48+(f-1.5)*.013,-.129,.872),(s*.48+(f-1.5)*.012,-.114,.853)],[.008,.008,.007,.004],hand_mat,'Hand.'+suffix,6)
        tube('Opposed thumb '+suffix,[(s*.44,-.064,.971),(s*.423,-.088,.948),(s*.434,-.119,.930)],[.014,.011,.007],hand_mat,'Hand.'+suffix,8)
        leg=contour('Weighted continuous leg '+suffix,[(s*.115,0,1.01,.087,.10),(s*.123,0,.90,.088,.096),(s*.13,0,.78,.082,.084),(s*.137,-.01,.64,.060,.062),(s*.14,-.01,.58,.056,.06),(s*.14,-.005,.53,.058,.059),(s*.145,.015,.44,.074,.067),(s*.15,0,.24,.045,.048),(s*.15,0,.16,.042,.042)],leather if hero=='leonhardt' else skin,'Thigh.'+suffix,18)
        weight(leg,lambda v,suffix=suffix:height_weights(v.z,[(.16,'Foot.'+suffix),(.25,'Shin.'+suffix),(.51,'Shin.'+suffix),(.64,'Thigh.'+suffix),(1.01,'Thigh.'+suffix)]))
        contour('Fitted stocking '+suffix,[(s*.145,.015,.51,.064,.064),(s*.147,.015,.44,.080,.072),(s*.15,0,.16,.047,.047)],ivory if hero=='leonhardt' else leather,'Shin.'+suffix)
        contour('Boot '+suffix,[(s*.15,-.065,.035,.070,.135),(s*.15,-.065,.09,.074,.139),(s*.15,-.020,.16,.056,.065)],ivory if hero=='leonhardt' else leather,'Foot.'+suffix)
        for z,x,r,b in [(1.21,s*.411,.070,'Forearm.'+suffix),(.55,s*.14,.070,'Shin.'+suffix),(.19,s*.15,.049,'Shin.'+suffix)]:
            contour('Gold armor binding',[(x,-.008,z-.015,r,.077),(x,-.008,z+.015,r,.077)],gold,b)
        if hero!='elisia':
            ell('Pauldrons '+suffix,(s*.285,0,1.545),(.125,.145,.095),ivory,'UpperArm.'+suffix)
            tube('Pauldron gold rim',[(s*.18,-.113,1.54),(s*.28,-.15,1.48),(s*.38,-.10,1.52)],[.014,.017,.012],gold,'UpperArm.'+suffix)
            for j in range(3):
                ell('Engraved leaf',(s*(.25+j*.035),-.138,1.57-j*.018),(.015,.008,.032),gold,'UpperArm.'+suffix,10,6)
    # Metal edging follows actual torso contours instead of a painted decal.
    cloth=blue if hero=='leonhardt' else red if hero=='mira' else green
    cape_rows=[(0,.15,1.55,.50),(0,.19,1.34,.55),(0,.25,1.10,.63),(0,.31,.85,.76),(0,.37,.61,.87),(0,.40,.40,1.02)]
    if hero=='elisia':
        for s in [-1,1]:
            rows=[(s*.16,0,1.13,.18),(s*.19,.025,.92,.24),(s*.26,.055,.67,.32),(s*.30,.08,.38,.40),(s*.32,.10,.19,.44)]
            skirt_side='L' if s>0 else 'R'
            panel('Leaf dress layer',rows,green,['Hips']+['Skirt'+skirt_side+str(i) for i in range(4)])
            for i in range(4):
                p=rows[i];q=rows[i+1];trim=tube('Golden dress hem',[(p[0]+s*p[3]/2,p[1]-.025,p[2]),(q[0]+s*q[3]/2,q[1]-.025,q[2])],[.009,.010],gold,'Skirt'+skirt_side+str(i),8)
                weight(trim,lambda v,skirt_side=skirt_side:height_weights(v.z,[(.20,'Skirt'+skirt_side+'3'),(.42,'Skirt'+skirt_side+'2'),(.65,'Skirt'+skirt_side+'1'),(.89,'Skirt'+skirt_side+'0'),(1.13,'Hips')]))
        # Narrow central petal preserves the original open layered skirt.
        panel('Ivory dress front',[(0,-.14,1.12,.18),(0,-.17,.92,.20),(0,-.19,.75,.20),(0,-.20,.59,.17),(0,-.20,.51,.01)],mat('Ivory silk','eee5cf',0,.82),['Hips','SkirtFront0','SkirtFront1','SkirtFront2','SkirtFront3'])
        panel('Ivory rear gown',[(0,.13,1.12,.32),(0,.17,.88,.37),(0,.22,.65,.47),(0,.28,.41,.59),(0,.31,.21,.62)],ivory,['Hips','Cape1','Cape2','Cape3','Cape4'])
        for s in [-1,1]:
            mesh('Pointed elf ear',[(s*.16,.005,1.96),(s*.30,.025,2.02),(s*.19,-.018,1.90),(s*.18,.04,1.94)],[(0,1,2),(2,1,3),(3,1,0),(0,2,3)],skin,'Head')
            sleeve=contour('Flared silk sleeve '+str(s),[(s*.34,0,1.39,.10,.09),(s*.38,-.01,1.27,.12,.115),(s*.405,-.02,1.16,.155,.142),(s*.438,-.03,1.05,.176,.158)],green,'Forearm.'+('L' if s>0 else 'R'))
            weight(sleeve,lambda v,s=s:height_weights(v.z,[(1.17,'Forearm.'+('L' if s>0 else 'R')),(1.38,'UpperArm.'+('L' if s>0 else 'R'))]))
    else:
        panel('Royal cape',cape_rows,cloth,['Cape0','Cape1','Cape2','Cape3','Cape4'])
        for s in [-1,1]:
            for i in range(len(cape_rows)-1):
                p=cape_rows[i];q=cape_rows[i+1];tube('Cape gold border',[(s*p[3]/2,p[1],p[2]),(s*q[3]/2,q[1],q[2])],[.009,.009],gold,'Cape'+str(min(i,4)),8)
        tube('Cape lower gold hem',[(-.5,.40,.40),(0,.40,.40),(.5,.40,.40)],[.01,.01,.01],gold,'Cape4',8)
        if hero=='leonhardt':panel('Royal tabard',[(0,-.15,1.10,.18),(0,-.17,.94,.19),(0,-.18,.76,.23),(0,-.20,.62,.25)],cloth,['Hips','SkirtFront0','SkirtFront1','SkirtFront2'],7)
        contour('Turned cloth collar',[(0,.018,1.565,.095,.085),(0,.021,1.667,.094,.075)],cloth,'Chest',20)
        for s in [-1,1]:
            ell('Cape clasp',(s*.155,-.064,1.586),(.034,.017,.031),gold,'Chest',14,8)
        tube('Cape chain',[(-.15,-.089,1.575),(0,-.131,1.526),(.15,-.089,1.575)],[.004,.004,.004],gold,'Chest',6)
    wardrobe(hero,gold,ivory,leather,cloth)
    # Layered closed locks are real geometry. A scalp cap closes parting gaps;
    # long hair follows three deform bones. No static head-attached ponytail.
    contour('Hair scalp foundation',[(0,.03,2.015,.166,.148),(0,.026,2.09,.164,.148),(0,.022,2.15,.120,.110),(0,.022,2.192,.035,.035)],hair,'Head',28)
    for i in range(40):
        a=i*math.tau/40;x=math.sin(a)*.160;y=.025+math.cos(a)*.150
        z=2.09+math.sin(a*3)*.03
        if hero=='leonhardt':points=[(x*.45+.015,y*.45,2.212),(x*.92,y*.85,2.166),(x,y,z),(x*1.35+.015,y*1.18,z-.10-(i%3)*.025)]
        elif hero=='elisia' and math.cos(a)>-.30:
            points=[(x*.55,y*.6,2.19),(x,y,z),(x*1.25,y+.075,1.85),(x*1.80,y+.14,1.59),(x*1.40,y+.21,1.37),(x*2.10,y+.25,1.12+(i%3)*.04)]
        else:points=[(x*.55,y*.55,2.20),(x,y,z),(x*1.05,y+.025,1.995-(i%3)*.020)]
        lock=hair_lock('Sculpted hair lock '+str(i),points,.057 if hero=='leonhardt' else .072,.020,hair_high if i%6==0 else hair)
        if hero=='elisia' and len(points)>4:
            weight(lock,lambda v:height_weights(v.z,[(1.18,'Hair2'),(1.50,'Hair1'),(1.82,'Hair0'),(2.03,'Head')]))
        # Narrow secondary ridge catches a different highlight across the lock.
        if i%3==0:
            ridge=hair_lock('Fine hair ridge '+str(i),[(p[0]+.012,p[1]-.020,p[2]-.005) for p in points],.014,.005,hair_high)
            if hero=='elisia' and len(points)>4:weight(ridge,lambda v:height_weights(v.z,[(1.18,'Hair2'),(1.50,'Hair1'),(1.82,'Hair0'),(2.03,'Head')]))
    for i in range(11):
        x=(i-5)*.028
        tip=2.013+(i%3)*.022
        # A side-swept open part leaves both eyes readable at gameplay scale.
        points=[(x*.45+.016,-.075,2.176),(x*.88,-.143,2.120),(x+.022*math.sin(i),-.166,tip)]
        hair_lock('Swept fringe '+str(i),points,.049,.023,hair_high if i%4==0 else hair)
    if hero=='mira':
        for i in range(28):
            a=i*math.tau/28
            lock=hair_lock('Weighted ponytail lock '+str(i),[(.04*math.sin(a),.17,2.13),(.035+.067*math.sin(a),.32+.025*math.cos(a),2.035),(.07+.099*math.sin(a),.43+.04*math.cos(a),1.85),(.12+.126*math.sin(a),.46+.06*math.cos(a),1.61),(.20+.13*math.sin(a),.43+.06*math.cos(a),1.40),(.29+.11*math.sin(a),.34+.06*math.cos(a),1.24)],.077,.022,hair_high if i%6==0 else hair)
            weight(lock,lambda v:height_weights(v.z,[(1.26,'Hair2'),(1.56,'Hair1'),(1.87,'Hair0'),(2.13,'Head')]))
        ell('Hair clasp',(0,.17,2.12),(.064,.031,.035),gold,'Head',12,8)
        for s in [-1,1]:leaf('Ponytail clasp leaf',(s*.039,.13,2.145),.048,.116,gold,'Head',s*-.62)
    elif hero=='elisia':
        for s in [-1,1]:
            for j in range(3):leaf('Hair laurel leaf',(s*(.146+j*.011),-.02,2.08+j*.039),.039,.093,green,'Head',s*-.4)
    else:
        for i in range(9):
            a=i*math.tau/9
            hair_lock('Crown outward wisp '+str(i),[(.052*math.sin(a),.024+.045*math.cos(a),2.185),(.10*math.sin(a),.023+.083*math.cos(a),2.237),(.145*math.sin(a)+.027,.025+.135*math.cos(a),2.18)],.044,.018,hair_high if i%3==0 else hair)
    weapon(hero,gold,leather,ivory,cloth)
    # Apply volume and bevel modifiers before adding the armature deform.
    for o in PARTS:
        bpy.context.view_layer.objects.active=o;o.select_set(True)
        for modifier in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
        bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
        o.select_set(False);o.parent=arm
        m=o.modifiers.new('Weighted skeleton','ARMATURE');m.object=arm
    animate(arm,hero)
    bpy.ops.object.select_all(action='DESELECT');arm.select_set(True)
    for o in PARTS:o.select_set(True)
    bpy.context.view_layer.objects.active=arm
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(hero+'-volume-pass.blend')))
    bpy.ops.export_scene.fbx(filepath=str(UNITY/(hero+'.fbx')),use_selection=True,object_types={'ARMATURE','MESH'},add_leaf_bones=False,axis_forward='-Z',axis_up='Y',bake_anim=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=True,bake_anim_simplify_factor=0,apply_scale_options='FBX_SCALE_ALL',use_mesh_modifiers=True)
    tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in PARTS)
    materials=[{'name':m.name,'color':'#'+key[1],'metallic':key[2],'roughness':key[3],'emission':key[4]} for key,m in MATS.items()]
    (UNITY/(hero+'-materials.json')).write_text(json.dumps({'hero':hero,'materials':materials},ensure_ascii=False,indent=2),encoding='utf-8')
    weighted=sum(1 for o in PARTS if len(o.vertex_groups)>1)
    return {'hero':hero,'triangles':tris,'mesh_parts':len(PARTS),'bones':len(arm.data.bones),'continuously_weighted_parts':weighted,'uv_meshes':sum(bool(o.data.uv_layers) for o in PARTS),'fbx':str((UNITY/(hero+'.fbx')).relative_to(ROOT)).replace('\\','/'),'source':str((OUT/(hero+'-volume-pass.blend')).relative_to(ROOT)).replace('\\','/'),'materials':str((UNITY/(hero+'-materials.json')).relative_to(ROOT)).replace('\\','/'),'status':'second articulated mesh craft development pass; visual acceptance deferred','animations':['Idle','Walk','Attack','Skill1','Skill2','Ultimate','Death'],'hair':'closed sculpted locks with three deform bones; no claimed 600-card simulation','cloth':'five cape bones and independent front/side skirt chains; authored motion, not physical cloth simulation','uv':'cylindrical/seam-aware, grid and box-projected UVs; no baked albedo/normal atlas yet'}

def weapon(hero,gold,leather,ivory,cloth):
    if hero=='leonhardt':
        # Right-hand sword, left-arm convex heraldic shield, anatomically named.
        tube('Sword grip',[(-.48,-.1,.86),(-.48,-.1,1.04)],[.023,.023],leather,'Hand.R',10)
        tube('Sword guard',[(-.62,-.1,.865),(-.48,-.1,.85),(-.34,-.1,.865)],[.017,.022,.017],gold,'Hand.R',8)
        steel=mat('Sword polished steel','b8cbd4',.92,.2)
        vertices=[]
        for z,w,d in [(.045,.001,.001),(.20,.044,.017),(.65,.052,.020),(.78,.061,.022),(.842,.043,.019)]:
            vertices.extend([(-.48-w,-.1,z),(-.48,-.1-d,z),(-.48+w,-.1,z),(-.48,-.1+d,z)])
        faces=[]
        for j in range(4):
            for i in range(4):a=j*4+i;b=j*4+(i+1)%4;faces.append((a,b,b+4,a+4))
        faces.extend([(3,2,1,0),(16,17,18,19)])
        grid_uv(mesh('Forged diamond-section longsword',vertices,faces,steel,'Hand.R',False),4,5,True)
        for j in range(8):
            z=.885+j*.018;tube('Sword leather grip winding',[(-.496,-.120,z),(-.461,-.120,z+.013)],[.003,.003],gold,'Hand.R',5)
        ell('Sword pommel',(-.48,-.10,1.062),(.031,.029,.035),gold,'Hand.R',12,8)
        gem('Sword guard sapphire',(-.48,-.13,.86),.026,.031,mat('Crown sapphire','2e67b7',.5,.20),'Hand.R')
        for s in [-1,1]:leaf('Sword winged quillon',(-.48+s*.099,-.1,.887),.038,.132,gold,'Hand.R',s*.9)
        vs=[(.27,-.24,1.46),(.50,-.30,1.51),(.73,-.24,1.46),(.70,-.28,.99),(.50,-.34,.79),(.30,-.28,.99),(.50,-.37,1.20)]
        faces=[((i+1)%6,i,6) for i in range(6)];shield=mesh('Convex heraldic shield',vs,faces,mat('Blue enamel shield','29468b',.45,.4),'Forearm.L',False)
        solid=shield.modifiers.new('Shield plate depth','SOLIDIFY');solid.thickness=.035
        for i in range(6):tube('Shield gold rim',[vs[i],vs[(i+1)%6]],[.013,.013],gold,'Forearm.L',8)
        tube('Shield central heraldry',[(.50,-.382,1.40),(.50,-.386,.95)],[.018,.012],gold,'Forearm.L',8)
        for s in [-1,1]:tube('Shield crown',[ (.50,-.388,1.22),(.50+s*.095,-.354,1.31),(.50+s*.07,-.347,1.37)],[.010,.012,.005],gold,'Forearm.L',8)
        for a in [0,math.pi/2,math.pi,3*math.pi/2]:leaf('Shield radiant crest',(.50,-.385,1.17),.040,.31,gold,'Forearm.L',a)
        gem('Shield crest heart',(.50,-.408,1.17),.027,.037,ivory,'Forearm.L')
        for x,z in [(.32,1.423),(.50,1.469),(.68,1.423),(.662,1.02),(.50,.86),(.338,1.02)]:ell('Shield gold rivet',(x,-.31,z),(.009,.010,.009),gold,'Forearm.L',8,6)
    elif hero=='elisia':
        tube('Leaf staff shaft',[(.51,-.1,.02),(.49,-.1,1.87)],[.022,.018],gold,'Hand.L',10)
        ring=[(.50+math.cos(i*math.tau/32)*.13,-.10,1.99+math.sin(i*math.tau/32)*.18) for i in range(33)]
        tube('Staff gold crown',ring,[.012]*len(ring),gold,'Hand.L',8)
        inner=[(.50+math.cos(i*math.tau/32)*.095,-.12,1.99+math.sin(i*math.tau/32)*.145) for i in range(33)]
        tube('Inner staff halo',inner,[.006]*len(inner),gold,'Hand.L',6)
        emerald=mat('Green gem','52ce62',.3,.2,.35)
        gem('Faceted staff emerald',(.50,-.11,1.99),.070,.118,emerald,'Hand.L')
        for j in range(7):
            a=j/6*math.pi
            leaf('Staff crown laurel',(.50+math.cos(a)*.15,-.10,2.0+math.sin(a)*.19),.048,.142,mat('Staff leaf green','4b7537'), 'Hand.L',a-math.pi/2)
        for j in range(4):
            z=.50+j*.29
            tube('Staff twisting gold vine',[(.49,-.125,z),(.515,-.120,z+.08),(.48,-.126,z+.16)],[.006,.006,.004],gold,'Hand.L',6)
            leaf('Staff vine leaf',(.51,-.128,z+.075),.031,.086,mat('Staff leaf green','4b7537'),'Hand.L',-.6)
        for s in [-1,1]:
            for i in range(5):ell('Hair flower petal',(s*.15+math.cos(i*math.tau/5)*.025,-.04,2.06+math.sin(i*math.tau/5)*.025),(.014,.009,.021),ivory,'Head',10,6)
    else:
        points=[(.49,-.12,.35),(.46,-.12,.44),(.59,-.12,.54),(.64,-.12,.67),(.57,-.12,.84),(.485,-.12,.96),(.57,-.12,1.09),(.64,-.12,1.25),(.59,-.12,1.40),(.46,-.12,1.49),(.49,-.12,1.59)]
        tube('Golden recurve bow limbs',points,[.004,.014,.021,.027,.024,.020,.024,.027,.021,.014,.004],gold,'Hand.L',10)
        tube('Bow inner leather limb',[(x-.009,y-.014,z) for x,y,z in points[1:-1]],[.007]*9,leather,'Hand.L',6)
        tube('Bowstring',[points[0],(.455,-.12,.96),points[-1]],[.0015,.0015,.0015],mat('Bowstring','d0bba1',0,.85),'Hand.L',6)
        tube('Leather bow grip',[(.485,-.12,.91),(.485,-.12,1.015)],[.025,.025],leather,'Hand.L',10)
        for z in [.54,1.40]:
            gem('Bow ruby',(.59,-.15,z),.031,.048,mat('Ruby lacquer','a93b42',.35,.25),'Hand.L')
            for s in [-1,1]:leaf('Bow gold leaf',(.59+s*.034,-.12,z),.025,.11,gold,'Hand.L',s*.62)
        tube('Quiver',[(-.16,.22,1.09),(-.27,.28,1.59)],[.067,.072],leather,'Chest',12)
        for i in range(6):
            x=-.27+(i-2.5)*.019;tube('Quiver arrow',[(x,.28,1.20),(x,.28,1.77)],[.004,.004],gold,'Chest',6)
            mesh('Arrow fletching',[(x,.28,1.69),(x+.025,.28,1.73),(x,.28,1.77),(x-.025,.28,1.73)],[(0,1,2),(0,2,3)],cloth,'Chest')

def pose_curve(t,points):
    for (a,x),(b,y) in zip(points,points[1:]):
        if t<=b:
            u=max(0,min(1,(t-a)/(b-a)));u=u*u*(3-2*u)
            return x+(y-x)*u
    return points[-1][1]


def animate(arm,hero):
    """Separate authored actions, with wind-up, contact and recovery timing.

    Animation is an offline skeletal authoring pass. There is no runtime cloth,
    IK, facial-expression rig or final animation quality claim in this export.
    """
    bpy.context.scene.render.fps=30
    clips=[('Idle',1,90),('Walk',110,30),('Attack',160,36),('Skill1',220,54),('Skill2',300,66),('Ultimate',390,102),('Death',510,60)]
    bones=arm.pose.bones
    def rotate(name,x=0,y=0,z=0):
        # Torso bones run on local Y (world Z). Interpret their third value as
        # an anatomical torso twist, keeping arm values in their authored basis.
        bones[name].rotation_euler=(x,z,-y) if name in ['Root','Hips','Spine','Chest','Neck','Head'] else (x,y,z)
    def move(name,x=0,y=0,z=0):
        bones[name].location=bones[name].bone.matrix_local.to_3x3().inverted()@Vector((x,y,z))
    for name,start,length in clips:
        action=bpy.data.actions.new(name);arm.animation_data_create();arm.animation_data.action=action
        for f in range(0,length+1,2):
            u=f/length;t=u*math.tau
            for b in bones:
                b.rotation_mode='XYZ';b.rotation_euler=(0,0,0);b.location=(0,0,0);b.scale=(1,1,1)
            breathing=.014*math.sin(t)
            rotate('Chest',breathing);rotate('Neck',-.4*breathing);rotate('Head',.3*breathing)
            # Weighted bone motion keeps body volume constant; no hero-scale pulse.
            move('Hips',z=.004*math.sin(t))
            for i in range(5):rotate('Cape'+str(i),.025*math.sin(t-i*.65),.011*math.sin(t-i*.40))
            for i in range(3):rotate('Hair'+str(i),.014*math.sin(t-i*.80),.012*math.sin(t-i*.65))
            for side in ['Front','L','R']:
                for i in range(4):rotate('Skirt'+side+str(i),.009*math.sin(t-i*.70),.008*math.sin(t-i*.4))
            if hero=='leonhardt':rotate('Forearm.L',-.12);rotate('Hand.R',.05)
            elif hero=='elisia':rotate('Forearm.R',-.11);rotate('Hand.R',0,0,.12)
            else:rotate('Forearm.R',-.13);rotate('Hand.L',.04)
            if name=='Walk':
                stride=.33 if hero=='elisia' else .42
                for side,sign in [('L',1),('R',-1)]:
                    phase=math.sin(t)*sign
                    rotate('Thigh.'+side,stride*phase)
                    rotate('Shin.'+side,.48*max(0,-phase))
                    rotate('Foot.'+side,-.19*max(0,phase))
                    rotate('UpperArm.'+side,-.20*phase)
                    rotate('Forearm.'+side,-.12-.08*max(0,phase))
                rotate('Spine',0,0,.035*math.sin(t));rotate('Chest',breathing,0,-.025*math.sin(t))
                move('Hips',z=.018*abs(math.sin(t)))
                for i in range(5):rotate('Cape'+str(i),.065+.032*math.sin(t-i*.65),.023*math.sin(t-i*.8))
                for i in range(3):rotate('Hair'+str(i),.031+.033*math.sin(t-i*.80),.019*math.sin(t-i*.65))
                for side,sign in [('L',1),('R',-1)]:
                    for i in range(4):rotate('Skirt'+side+str(i),.075*math.sin(t-i*.45)*sign)
            elif name in ['Attack','Skill1','Skill2','Ultimate']:
                hold=pose_curve(u,[(0,0),(.16,.75),(.36,1),(.58,1),(.88,.18),(1,0)])
                release=pose_curve(u,[(0,0),(.30,0),(.48,1),(.64,.65),(1,0)])
                charge=pose_curve(u,[(0,0),(.2,.7),(.44,1),(.57,.1),(1,0)])
                if hero=='leonhardt':
                    if name=='Attack':
                        rotate('UpperArm.R',-1.68*charge-.32*release,0,-.28*charge+.60*release)
                        rotate('Forearm.R',-.52*charge-.18*release)
                        rotate('Chest',.025*hold,0,-.24*charge+.30*release)
                        rotate('Spine',-.03*charge,0,-.08*charge+.13*release)
                        rotate('Forearm.L',-.22*hold)
                    elif name=='Skill1':
                        rotate('UpperArm.R',-2.22*charge-.13*release,0,-.1*charge+.55*release)
                        rotate('Forearm.R',-.55*charge)
                        rotate('Chest',-.13*charge+.17*release,0,-.26*charge+.32*release)
                        rotate('UpperArm.L',-.42*hold)
                        move('Root',y=-.13*release)
                    elif name=='Skill2':
                        rotate('UpperArm.L',-1.34*hold,0,-.22*hold)
                        rotate('Forearm.L',-.59*hold)
                        rotate('UpperArm.R',-.36*hold,0,.11*hold)
                        rotate('Chest',.12*hold,0,.09*hold)
                        rotate('Thigh.L',-.13*hold);rotate('Shin.L',.15*hold)
                    else:
                        flourish=math.sin(u*math.pi)*hold
                        rotate('UpperArm.R',-2.35*charge-.6*release,0,.72*flourish)
                        rotate('Forearm.R',-.40*hold)
                        rotate('UpperArm.L',-.66*hold,0,-.1*hold)
                        rotate('Chest',-.1*charge+.2*release,0,-.42*charge+.57*release)
                        rotate('Spine',0,0,-.13*charge+.25*release)
                        move('Root',y=-.19*release)
                    rotate('Head',-.04*hold,0,-.08*hold)
                elif hero=='mira':
                    # The archer raises the bow arm, draws with the opposite
                    # hand and recoils on release; no shared sword-swing clip.
                    aim=hold;draw=charge
                    rotate('UpperArm.L',-1.36*aim,0,-.27*aim)
                    rotate('Forearm.L',-.13*aim)
                    rotate('Hand.L',.13*aim,0,-.08*aim)
                    rotate('UpperArm.R',-.93*aim,-.28*draw,.67*draw)
                    rotate('Forearm.R',-1.10*draw-.14*aim,0,-.22*draw)
                    rotate('Hand.R',.20*draw)
                    rotate('Chest',-.03*draw+.08*release,0,.18*draw)
                    rotate('Head',0,0,-.10*draw)
                    if name=='Skill1':
                        pulse=math.sin(u*math.pi*6)*hold*.11
                        bones['Forearm.R'].rotation_euler.x+=pulse
                        bones['UpperArm.L'].rotation_euler.x-=.08*hold
                    elif name=='Skill2':
                        rotate('Thigh.R',-.21*hold);rotate('Shin.R',.32*hold)
                        rotate('Thigh.L',.13*hold);rotate('Chest',.08*hold,0,.32*draw)
                        move('Root',y=.16*release)
                    elif name=='Ultimate':
                        bones['UpperArm.L'].rotation_euler.x-=.58*charge
                        bones['UpperArm.R'].rotation_euler.x-=.37*charge
                        rotate('Head',-.16*charge,0,-.10*draw)
                        rotate('Spine',-.12*charge+.10*release,0,.1*draw)
                else:
                    # Staff-led casting uses the left hand and an open right
                    # palm; support and ultimate clips have distinct gestures.
                    rotate('UpperArm.L',-.52*hold-.30*release,0,-.08*hold)
                    rotate('Forearm.L',-.22*hold)
                    rotate('UpperArm.R',-.71*hold,0,.35*hold)
                    rotate('Forearm.R',-.48*hold)
                    rotate('Hand.R',-.15*hold,0,.25*hold)
                    rotate('Chest',-.05*charge+.05*release,0,-.10*hold)
                    if name=='Skill1':
                        rotate('UpperArm.L',-1.04*hold,0,-.13*hold)
                        rotate('Forearm.L',-.34*hold)
                        rotate('UpperArm.R',-.48*hold,0,.66*hold)
                    elif name=='Skill2':
                        rotate('UpperArm.L',-.22*hold,0,-.31*hold)
                        rotate('UpperArm.R',-.38*hold,0,.94*hold)
                        rotate('Forearm.R',-.65*hold)
                        rotate('Head',.10*hold)
                    elif name=='Ultimate':
                        rotate('UpperArm.L',-1.32*hold,0,-.22*hold)
                        rotate('UpperArm.R',-1.10*hold,0,.70*hold)
                        rotate('Forearm.R',-.45*hold)
                        rotate('Head',-.12*hold)
                        move('Root',z=.085*math.sin(math.pi*u)**2)
                for i in range(5):
                    bones['Cape'+str(i)].rotation_euler.x+=.045*release*(1+i*.2)
                    bones['Cape'+str(i)].rotation_euler.y+=.025*math.sin(t-i*.7)*hold
                for i in range(3):bones['Hair'+str(i)].rotation_euler.x+=.03*release*(i+1)
            elif name=='Death':
                fall=pose_curve(u,[(0,0),(.20,.12),(.65,1),(1,1)])
                rotate('Root',0,-1.35*fall,.10*fall)
                move('Root',z=.14*fall)
                rotate('Chest',.20*fall);rotate('Head',.19*fall)
                rotate('UpperArm.L',-.27*fall);rotate('UpperArm.R',.23*fall)
                rotate('Thigh.L',-.25*fall);rotate('Shin.L',.53*fall)
                for i in range(5):rotate('Cape'+str(i),-.035*fall)
            for b in bones:
                b.keyframe_insert('rotation_euler',frame=start+f,group=b.name)
                if b.name in ['Root','Hips']:b.keyframe_insert('location',frame=start+f,group=b.name)
        track=arm.animation_data.nla_tracks.new();track.name=name
        strip=track.strips.new(name,start,action);strip.action_frame_start=start;strip.action_frame_end=start+length
        strip.extrapolation='NOTHING';strip.blend_type='REPLACE'
    arm.animation_data.action=None;bpy.context.scene.frame_set(1)

def main():
    results=[build(hero) for hero in ['leonhardt','elisia','mira']]
    (OUT/'development-manifest.json').write_text(json.dumps({'pipeline':'native Blender mesh/armature to Unity FBX; no sprite substitution','heroes':results,'quality_acceptance':'deferred; no claim of final concept equivalence'},ensure_ascii=False,indent=2),encoding='utf-8')
    print('AURELIA_VOLUME_PASS_EXPORTED',json.dumps(results))


if __name__ == '__main__':
    main()
