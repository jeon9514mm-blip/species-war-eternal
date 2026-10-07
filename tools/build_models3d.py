"""Build original volume meshes, weighted rigs and animation GLBs in Blender.

Run: blender --background --factory-startup --python tools/build_models3d.py
All geometry is authored here; the previous paintings remain as art references.
"""
import bpy
import json
import math
import random
import hashlib
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models3d-v1'
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'characters').mkdir(exist_ok=True)
(OUT/'environments').mkdir(exist_ok=True)
(OUT/'source').mkdir(exist_ok=True)
ROSTER=json.loads((ROOT/'assets/heroes/sd-v36/roster-reference.json').read_text(encoding='utf-8'))
FEMALE=set('mira elisia kairen seria astel lunea tessa naia odelia valeria nyx isolde veyra bora selene'.split())
STYLES={
 'leonhardt':('e6bb63','3152a5','sword','short'), 'mira':('a84238','862b38','bow','ponytail'),
 'elisia':('ecdcbc','7a9e5f','staff','long'), 'kairen':('c5c6e9','5e548d','staff','long'),
 'orwin':('ddb26b','36539c','sword','short'), 'seria':('ebdec1','649c79','staff','long'),
 'astel':('e8d9cd','ddd0ad','orb','long'), 'darius':('b6a4af','60313c','sword','short'),
 'lunea':('d1d0e8','7163a3','staff','long'), 'caelum':('e4b860','38599a','spear','short'),
 'adrien':('e4c079','335b9e','sword','short'), 'tessa':('9b7151','6a4b37','hammer','ponytail'),
 'naia':('d6d0ed','7471ac','bow','long'), 'sael':('ddc8a8','647f42','sword','long'),
 'odelia':('eddddd','c2b0cd','staff','long'), 'valeria':('bd8991','772b44','sword','long'),
 'morgas':('403441','562d46','staff','long'), 'ragna':('686272','442e3d','axe','short'),
 'bron':('9c7778','5e303b','hammer','short'), 'nyx':('baa8bb','3d314f','staff','long'),
 'fenris':('bfc0c9','543946','claws','short'), 'isolde':('e5cad3','913949','staff','long'),
 'garm':('cac4c4','4e3741','axe','short'), 'veyra':('855765','5b293d','bow','hood'),
 'ulric':('928eaa','493342','sword','long'), 'lucien':('a48b97','673a44','sword','short'),
 'corvin':('51404e','302a3c','spear','short'), 'rokan':('797183','453340','axe','short'),
 'bora':('dfdce2','9684a9','claws','ponytail'), 'selene':('cba7b2','863943','staff','long')
}
MONSTERS=['goblin','wild_dog','bristle_boar','iron_mole','mushroom','moon_wolf','wind_crow','mine_orc','lava_bat','crystal_spider','forest_wraith','night_raven','frost_deer','grun','morgul','selene_boss']
MATS={};PARTS=[];CURRENT_COLLECTION=None
def rgba(value):
    v=value.lstrip('#');srgb=[int(v[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in srgb)+(1,)
def material(name,color,metal=0,rough=.65,emission=0):
    key=(name,color,metal,rough,emission)
    if key in MATS:return MATS[key]
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=rgba(color)
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    if emission:p.inputs['Emission Color'].default_value=rgba(color);p.inputs['Emission Strength'].default_value=emission
    MATS[key]=m;return m
GOLD=material('Engraved gold','bd9b57',.7,.38)
SILVER=material('Brushed armor','a9b9c6',.58,.43)
LEATHER=material('Dark leather','302c35',0,.78)
EYE=material('Eyes and seams','181d2c',0,.62)
IVORY=material('Ivory trim','eee3c9',0,.65)
STONE=material('Sculpted stone','747c7b',0,.88)
def move_to_collection(o):
    for c in list(o.users_collection):c.objects.unlink(o)
    CURRENT_COLLECTION.objects.link(o)
def finish(o,name,mat,bone='Root',smooth=True):
    o.name=name;move_to_collection(o)
    if mat:o.data.materials.append(mat)
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    if bone:
        group=o.vertex_groups.new(name=bone);group.add(range(len(o.data.vertices)),1,'REPLACE')
    for p in o.data.polygons:p.use_smooth=smooth
    PARTS.append(o);return o
def ell(name,loc,scale,mat,bone='Root',segments=16,rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=loc)
    o=bpy.context.object;o.scale=scale;return finish(o,name,mat,bone)
def ico(name,loc,scale,mat,bone='Root',sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,location=loc)
    o=bpy.context.object;o.scale=scale;return finish(o,name,mat,bone,False)
def cube(name,loc,scale,mat,bone='Root',bevel=.04):
    bpy.ops.mesh.primitive_cube_add(size=2,location=loc);o=bpy.context.object;o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Rounded edges','BEVEL');mod.width=bevel;mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,name,mat,bone,False)
def tube(name,a,b,r,mat,bone='Root',r2=None,sides=10):
    a=Vector(a);b=Vector(b);d=b-a
    bpy.ops.mesh.primitive_cone_add(vertices=sides,radius1=r,radius2=r if r2 is None else r2,depth=d.length,location=(a+b)*.5)
    o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=d.to_track_quat('Z','Y')
    return finish(o,name,mat,bone)
def strip(name,points,widths,mat,bone='Root',sides=6):
    vertices=[];faces=[]
    for i,p in enumerate(points):
        p=Vector(p);direction=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
        if direction.length<.001:direction=Vector((0,0,1))
        normal=direction.normalized().cross(Vector((0,1,0)))
        if normal.length<.01:normal=Vector((1,0,0))
        normal.normalize();other=direction.normalized().cross(normal)
        for j in range(sides):vertices.append(p+(normal*math.cos(j*math.tau/sides)+other*math.sin(j*math.tau/sides))*widths[i])
    for i in range(len(points)-1):
        for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);CURRENT_COLLECTION.objects.link(o);return finish(o,name,mat,bone)
def humanoid_bones():
    b={'Root':((0,0,.02),(0,0,.18),None),'Pelvis':((0,0,.85),(0,0,1.00),'Root'),'Chest':((0,0,1.00),(0,0,1.35),'Pelvis'),'Head':((0,0,1.42),(0,0,1.74),'Chest'),'Cape':((0,.12,1.35),(0,.22,.85),'Chest')}
    for side,s in [('L',1),('R',-1)]:
        b['Arm.'+side]=((s*.26,0,1.34),(s*.36,0,1.10),'Chest')
        b['Forearm.'+side]=((s*.36,0,1.10),(s*.41,-.02,.89),'Arm.'+side)
        b['Hand.'+side]=((s*.41,-.02,.89),(s*.41,-.04,.79),'Forearm.'+side)
        b['Thigh.'+side]=((s*.135,0,.85),(s*.14,0,.48),'Pelvis')
        b['Shin.'+side]=((s*.14,0,.48),(s*.14,0,.13),'Thigh.'+side)
        b['Foot.'+side]=((s*.14,0,.13),(s*.14,-.15,.08),'Shin.'+side)
    return b
def humanoid(id,profile,monster=False):
    hair,cloth,weapon,style=STYLES.get(id,('93ad58','597339','axe','short'))
    if id=='mine_orc':hair,cloth,weapon,style='292624','6c5a4c','axe','short'
    if id=='grun':hair,cloth,weapon,style='526e30','748e3b','hammer','short'
    if id=='morgul':hair,cloth,weapon,style='647976','636f6c','hammer','short'
    if id=='selene_boss':hair,cloth,weapon,style='d8c8e3','63509c','staff','long'
    female=id in FEMALE or id=='selene_boss';faction=profile.get('faction','noxfera' if monster else 'aurelia')
    skin_color='cfa891' if faction=='aurelia' else 'bca2ae'
    if id in ['goblin','grun','mine_orc']:skin_color='779b49'
    if id=='morgul':skin_color='647c77'
    skin=material(id+' skin',skin_color,0,.72);fabric=material(id+' cloth',cloth,0,.83)
    hair_mat=material(id+' hair',hair,0,.68);armor=material(id+' armor','b8c6d8' if faction=='aurelia' else '5b525f',.52,.48)
    accent=material(id+' focus','84d9dc' if faction=='aurelia' else 'c370b7',.15,.35,.35)
    if id=='morgul':armor=STONE;fabric=material('Golem patina','4b6b62',.15,.85)
    bulky=id in ['bron','ragna','rokan','grun','morgul','mine_orc'];w=1.22 if bulky else .89 if female else 1
    ell('core', (0,0,1.14),(.225*w,.145,.255),skin,'Chest')
    ell('waist',(0,0,.89),(.207*w,.13,.16),fabric,'Pelvis')
    ell('breastplate',(0,-.034,1.19),(.232*w,.157,.23),armor,'Chest')
    cube('waist belt',(0,-.002,.91),(.212*w,.137,.038),LEATHER,'Pelvis',.02)
    cube('buckle',(0,-.152,.91),(.038,.014,.043),GOLD,'Pelvis',.015)
    # Connected neck and skull volumes; head, hair and face share the head bone.
    ell('neck',(0,0,1.425),(.07,.067,.12),skin,'Head')
    ell('face',(0,-.018,1.62),(.165,.139,.196),skin,'Head',20,14)
    ell('hair crown',(0,.012,1.715),(.174,.149,.126),hair_mat,'Head',20,12)
    ell('nose',(0,-.16,1.593),(.029,.046,.046),skin,'Head',12,8)
    ell('mouth',(0,-.151,1.527),(.047,.008,.009),material('Lips','956879',0,.83),'Head',12,6)
    for s in [-1,1]:
        ell('eye white',(s*.062,-.143,1.632),(.038,.016,.022),IVORY,'Head',12,8)
        ell('iris',(s*.061,-.159,1.632),(.014,.004,.015),accent,'Head',10,6)
        ell('pupil',(s*.061,-.164,1.632),(.007,.003,.011),EYE,'Head',10,6)
        strip('eyebrow',[(s*.029,-.147,1.67),(s*.064,-.155,1.681),(s*.102,-.142,1.671)],[.009,.009,.005],hair_mat,'Head')
        if '엘프' in profile.get('race','') or id in ['goblin','grun','mine_orc']:
            tube('pointed ear',(s*.145,.0,1.61),(s*.278,.035,1.685),.065,skin,'Head',.006,8)
        else:ell('ear',(s*.16,0,1.612),(.039,.028,.057),skin,'Head',10,6)
        upper='Arm.'+('L' if s>0 else 'R');lower='Forearm.'+('L' if s>0 else 'R');hand='Hand.'+('L' if s>0 else 'R')
        ell('shoulder',(s*.261,0,1.324),(.125*w,.117,.115),armor,upper)
        tube('upper sleeve',(s*.275,0,1.295),(s*.36,0,1.11),.079,skin,upper,.067)
        ell('elbow',(s*.36,0,1.11),(.073,.07,.073),skin,lower)
        tube('vambrace',(s*.36,0,1.10),(s*.405,-.02,.92),.079,armor,lower,.058)
        ell('hand',(s*.415,-.02,.87),(.06,.057,.083),skin,hand)
        for j in range(3):tube('finger',(s*(.385+j*.018),-.061,.864),(s*(.389+j*.018),-.064,.807),.010,skin,hand,.008,6)
        thigh='Thigh.'+('L' if s>0 else 'R');shin='Shin.'+('L' if s>0 else 'R');foot='Foot.'+('L' if s>0 else 'R')
        tube('trousers',(s*.132,0,.84),(s*.14,0,.50),.103,fabric,thigh,.083)
        ell('knee',(s*.14,-.012,.49),(.093,.094,.08),armor,shin)
        tube('greave',(s*.14,0,.48),(s*.14,0,.15),.090,armor,shin,.060)
        ell('boot',(s*.14,-.072,.085),(.087,.165,.080),LEATHER,foot)
        tube('boot gold trim',(s*.14,-.027,.19),(s*.14,-.022,.21),.071,GOLD,shin,.071)
        strip('shoulder trim',[(s*.16,-.106,1.38),(s*.27,-.125,1.395),(s*.353,-.085,1.34)],[.022,.022,.012],GOLD,upper)
    # Asymmetric hair strands and split cloth give individual 3D silhouettes.
    rng=random.Random(int(hashlib.sha256(id.encode()).hexdigest()[:8],16))
    for j in range(18):
        angle=j*math.tau/18;front=math.sin(angle)<-.3
        start=(math.cos(angle)*.125,math.sin(angle)*.110,1.79)
        end_z=(1.53 if front else 1.18 if style in ['long','ponytail'] else 1.57)+rng.uniform(-.035,.035)
        bend=(math.cos(angle)*.181,math.sin(angle)*.16,1.69)
        tip=(math.cos(angle)*(.19 if front else .24),math.sin(angle)*.18+(0 if front else .11),end_z)
        strip('hair lock',[start,bend,tip],[.046,.041,.009],hair_mat,'Head',6)
    if style=='hood':
        ell('hood',(0,.036,1.69),(.197,.16,.184),fabric,'Head')
        # Front opening stays outside the skin geometry, not over the face.
        strip('hood rim',[(-.16,-.12,1.55),(-.18,-.13,1.72),(0,-.15,1.86),(.18,-.13,1.72),(.16,-.12,1.55)],[.023]*5,GOLD,'Head')
    cloak_long=id not in ['orwin','caelum','bron','ragna','mine_orc','goblin','grun','morgul']
    for s in [-1,1]:
        for j in range(3):
            x=s*(.06+j*.08)
            strip('cloak fold',[(x,.12,1.34),(x*1.45,.20,.94),(x*1.9,.30,.45 if cloak_long else .78)],[.071,.075,.036],fabric,'Cape',8)
            strip('cloak edge',[(x,.19,1.26),(x*1.45,.28,.92),(x*1.9,.35,.49 if cloak_long else .80)],[.008,.010,.004],GOLD,'Cape',6)
    if female or weapon in ['staff','orb']:
        for j in range(8):
            a=j*math.tau/8
            strip('split skirt',[(math.cos(a)*.19,math.sin(a)*.13,.90),(math.cos(a)*.25,math.sin(a)*.21,.68),(math.cos(a)*.29,math.sin(a)*.25,.51)],[.073,.082,.062],fabric,'Pelvis',8)
    if id in ['fenris','garm','bora','rokan']:
        for s in [-1,1]:tube('beast ear',(s*.12,.035,1.765),(s*.155,.065,2.015),.067,hair_mat,'Head',.005,8)
        if id in ['fenris','garm']:
            ell('muzzle',(0,-.164,1.575),(.092,.112,.065),hair_mat,'Head');ell('nose tip',(0,-.268,1.59),(.035,.022,.027),EYE,'Head')
        strip('fur tail',[(0,.11,.9),(0,.4,.82),(.18,.63,1.0)],[.084,.073,.009],hair_mat,'Pelvis',8)
    if id in ['grun','morgul','selene_boss']:
        for j in range(5):
            a=j*math.tau/5
            tube('crown',(.135*math.cos(a),.135*math.sin(a),1.78),(.19*math.cos(a),.19*math.sin(a),1.98),.025,GOLD,'Head',.004)
    # Weapon geometry is a true volume attached to the hand's deform bone.
    hand='Hand.R';x=-.415;y=-.055;z=.85
    if weapon in ['sword','spear']:
        long=1.15 if weapon=='spear' else .58
        tube('weapon handle',(x,y,z-.13),(x,y,z+.10),.028,LEATHER,hand)
        cube('weapon crossguard',(x,y,z+.11),(.13,.035,.025),GOLD,hand,.018)
        tube('weapon blade',(x,y,z+.15),(x,y,z+.15+long),.061,SILVER,hand,.005,4)
        strip('weapon fuller',[(x,y-.04,z+.20),(x,y-.028,z+.13+long)],[.008,.003],GOLD,hand,4)
        if weapon=='sword' and id not in ['sael','valeria','lucien','ulric','darius']:
            cube('shield',(.425,-.080,1.01),(.20,.055,.31),fabric,'Hand.L',.055)
            cube('shield boss',(.425,-.15,1.02),(.04,.023,.095),GOLD,'Hand.L',.025)
            for s in [-1,1]:tube('shield rim',(.425+s*.19,-.10,.76),(.425+s*.19,-.10,1.29),.015,GOLD,'Hand.L')
    elif weapon in ['staff','orb']:
        tube('weapon staff',(x,y,.15),(x,y,1.93),.031,LEATHER,hand,.028)
        for zz in [.45,1.15,1.7]:tube('staff ring',(x,y,zz),(x,y,zz+.065),.044,GOLD,hand)
        ell('staff focus',(x,y,1.99),(.103,.10,.103),accent,hand)
        for s in [-1,1]:strip('staff prong',[(x+s*.09,y,1.8),(x+s*.13,y,1.99),(x+s*.07,y,2.12)],[.018,.017,.006],GOLD,hand)
    elif weapon=='bow':
        pts=[(x+.14*math.sin(j*math.pi/8),y-.06,z-.38+j*.10) for j in range(9)]
        strip('weapon bow',pts,[.023]*9,GOLD,hand)
        tube('bow string',pts[0],pts[-1],.003,IVORY,hand,.003,6)
        tube('arrow',(x-.2,y-.07,1.01),(x+.28,y-.07,1.01),.007,LEATHER,'Hand.L',.005)
        cube('quiver',(0,.28,1.20),(.09,.072,.26),LEATHER,'Chest',.03)
    elif weapon in ['axe','hammer']:
        tube('weapon shaft',(x,y,.65),(x,y,1.46),.042,LEATHER,hand)
        if weapon=='hammer':cube('weapon hammer head',(x,y,1.48),(.19,.10,.13),armor,hand,.025)
        else:
            ico('weapon axe blade',(x-.09,y,1.48),(.22,.05,.18),SILVER,hand,1)
            tube('axe gilding',(x,y,1.38),(x,y,1.57),.046,GOLD,hand)
    else:
        for s in [-1,1]:
            for j in range(3):tube('claw',(s*(.38+j*.025),-.077,.86),(s*(.4+j*.032),-.19,.71),.013,SILVER,'Hand.L' if s>0 else hand,.002)
    return humanoid_bones(),1.82

def creature(id):
    if id in ['goblin','mine_orc','grun','morgul','selene_boss']:return humanoid(id,{},True)
    colors={'wild_dog':'ae854e','bristle_boar':'906445','iron_mole':'839299','moon_wolf':'afc6d9','wind_crow':'284fad','lava_bat':'764844','crystal_spider':'7278ae','mushroom':'688950','forest_wraith':'72bbaa','night_raven':'252b40','frost_deer':'c3dce8'}
    body=material(id+' coat',colors[id],.12 if id in ['iron_mole','crystal_spider'] else 0,.78)
    glow=material(id+' eyes','80dbe4' if id!='lava_bat' else 'ef7143',0,.4,.6)
    bones={'Root':((0,0,.02),(0,0,.18),None),'Chest':((0,0,.35),(0,-.25,.45),'Root'),'Head':((0,-.34,.48),(0,-.55,.56),'Chest'),'Tail':((0,.40,.44),(0,.75,.5),'Root')}
    if id in ['wind_crow','night_raven','lava_bat']:
        ell('bird body',(0,0,.37),(.16,.26,.20),body,'Chest')
        ell('head',(0,-.19,.57),(.13,.13,.12),body,'Head')
        tube('beak',(0,-.24,.58),(0,-.46,.53),.065,GOLD,'Head',.003,6)
        for s in [-1,1]:
            bones['Arm.'+('L' if s>0 else 'R')]=((s*.11,0,.4),(s*.48,.08,.42),'Chest')
            wingbone='Arm.'+('L' if s>0 else 'R')
            for j in range(8):
                strip('wing feather',[(s*.10,j*.013,.44),(s*(.38+j*.016),.07+j*.035,.43),(s*(.60-j*.025),.32+j*.022,.35)],[.026,.045,.008],body,wingbone,6)
            ell('bright eye',(s*.095,-.283,.592),(.022,.012,.023),glow,'Head',10,6)
            tube('foot',(s*.07,-.03,.25),(s*.07,-.04,.05),.018,GOLD,'Root')
            if id=='lava_bat':tube('bat ear',(s*.08,-.17,.61),(s*.11,-.12,.88),.055,body,'Head',.003,7)
        strip('tail',[(0,.19,.35),(0,.49,.32),(0,.64,.33)],[.09,.09,.008],body,'Tail')
        return bones,.90 if id=='lava_bat' else .70
    if id=='crystal_spider':
        ell('abdomen',(0,.20,.40),(.30,.38,.26),body,'Root');ell('thorax',(0,-.22,.33),(.23,.23,.18),body,'Head')
        for j in range(4):
            for s in [-1,1]:
                name='Leg'+str(j)+('L' if s>0 else 'R');y=-.24+j*.16
                bones[name]=((s*.14,y,.32),(s*.59,y-.07,.40),'Root')
                strip('leg',[(s*.17,y,.33),(s*.49,y-.14,.51),(s*.75,y-.18,.08)],[.045,.034,.012],body,name)
        for s in [-1,1]:
            for j in range(2):ell('eye',(s*(.06+j*.05),-.419,.371),(.023,.014,.028),glow,'Head',10,6)
        for j in range(5):tube('crystal',(math.sin(j)*.13,.21,.57),(math.sin(j)*.21,.2+.06*math.cos(j),.83),.065,glow,'Root',.002,5)
        return bones,.86
    if id=='mushroom':
        ell('stalk',(0,0,.34),(.16,.15,.32),IVORY,'Root')
        ell('cap',(0,0,.66),(.47,.43,.22),body,'Head',24,12)
        ell('cap rim',(0,0,.57),(.44,.40,.046),IVORY,'Head',24,8)
        for j in range(12):
            a=j*2.4;r=.11+.23*(j%3)/2
            ell('cap spot',(math.cos(a)*r,math.sin(a)*r,.83-.08*(r/.34)**2),(.036,.037,.013),IVORY,'Head',10,6)
        for s in [-1,1]:ell('eye',(s*.063,-.15,.40),(.017,.007,.027),EYE,'Root',10,6)
        bones['Head']=((0,0,.5),(0,0,.72),'Root');return bones,.89
    if id=='forest_wraith':
        ell('hood',(0,0,.92),(.21,.17,.22),body,'Head')
        for s in [-1,1]:ell('ghost eye',(s*.07,-.165,.95),(.029,.015,.02),glow,'Head',12,6)
        for j in range(10):
            a=j*math.tau/10
            strip('ghost robe',[(math.cos(a)*.13,math.sin(a)*.13,.85),(math.cos(a)*.25,math.sin(a)*.2,.43),(math.cos(a)*.20,math.sin(a)*.16,.10+.10*(j%2))],[.08,.09,.025],body,'Root',8)
        bones['Head']=((0,0,.8),(0,0,1.02),'Root');return bones,1.17
    # Quadrupeds have their own volume, joints, muzzle, paws and tail.
    boar=id=='bristle_boar';deer=id=='frost_deer';mole=id=='iron_mole'
    ell('body',(0,.08,.48),(.32 if boar else .22,.48,.27 if boar else .20),body,'Chest',20,12)
    ell('haunch',(0,.39,.46),(.26,.22,.24),body,'Root')
    ell('head',(0,-.41,.55),(.23 if boar else .17,.25,.20),body,'Head',20,12)
    ell('muzzle',(0,-.61,.52),(.16 if boar else .095,.16,.105),body,'Head')
    ell('nose',(0,-.755,.53),(.103 if boar else .044,.028,.045),EYE,'Head',12,8)
    for s in [-1,1]:
        ell('eye',(s*.143,-.52,.627),(.023,.026,.023),glow,'Head',12,8)
        tube('ear',(s*.13,-.35,.67),(s*.18,-.30,.85),.065,body,'Head',.006,8)
        if boar:
            strip('tusk',[(s*.14,-.6,.45),(s*.19,-.67,.50),(s*.15,-.69,.61)],[.028,.019,.003],IVORY,'Head')
        for front,y in [(True,-.29),(False,.37)]:
            bone=('Arm.' if front else 'Thigh.')+('L' if s>0 else 'R');lower=('Forearm.' if front else 'Shin.')+('L' if s>0 else 'R')
            bones[bone]=((s*.17,y,.43),(s*.18,y,.22),'Chest' if front else 'Root')
            bones[lower]=((s*.18,y,.22),(s*.18,y-.03,.07),bone)
            tube('leg',(s*.18,y,.43),(s*.18,y,.20),.066 if boar else .045,body,bone,.043)
            tube('shin',(s*.18,y,.22),(s*.18,y-.02,.07),.048 if boar else .030,body,lower,.027)
            ell('paw',(s*.18,y-.045,.06),(.068,.091,.053),LEATHER,lower,12,8)
        if deer:
            for branch in range(3):
                pts=[(s*.10,-.34,.69),(s*.18,-.21,1.02),(s*(.24+.06*branch),-.28+.12*branch,1.28)]
                strip('antler',pts,[.022,.018,.003],IVORY,'Head')
    strip('tail',[(0,.46,.55),(.08,.74,.66),(.13,.84,.64)],[.047,.056,.006],body,'Tail')
    if boar:
        for j in range(9):tube('bristle',(0,-.1+j*.07,.65),(0,-.12+j*.07,.79),.017,LEATHER,'Chest',.002,5)
    if mole:
        for j in range(4):ell('iron plate',(0,-.15+j*.17,.65),(.26,.09,.064),SILVER,'Chest',12,8)
    return bones,1.31 if deer else .86

def make_rig(id,bones):
    data=bpy.data.armatures.new(id+' Skeleton');rig=bpy.data.objects.new(id+' Rig',data);CURRENT_COLLECTION.objects.link(rig)
    bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
    for name,(head,tail,parent) in bones.items():
        b=data.edit_bones.new(name);b.head=head;b.tail=tail
        if parent:b.parent=data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT');return rig
def animate(rig,id):
    armature=rig.data;rig.animation_data_create()
    names=['idle','walk','attack_1','attack_2','skill','ultimate','hit','death']
    for action_name in names:
        action=bpy.data.actions.new(action_name);rig.animation_data.action=action
        frames=[0,8,13.2,17,24,30] if action_name not in ['walk','idle'] else list(range(0,31,5))
        for frame in frames:
            t=frame/30;phase=t*math.tau
            for bone in rig.pose.bones:
                bone.rotation_mode='XYZ';bone.rotation_euler=(0,0,0);bone.location=(0,0,0);bone.scale=(1,1,1)
                n=bone.name
                if action_name=='idle':
                    if n=='Chest':bone.rotation_euler.x=.023*math.sin(phase)
                    if n=='Cape':bone.rotation_euler.x=.045*math.sin(phase+.6)
                    if n=='Root':bone.location.z=.012*math.sin(phase)
                    if n=='Tail':bone.rotation_euler.z=.18*math.sin(phase)
                elif action_name=='walk':
                    side=1 if n.endswith('.L') or n.endswith('L') else -1
                    if n.startswith(('Thigh','Arm','Leg')):bone.rotation_euler.x=side*.46*math.sin(phase)
                    if n.startswith(('Shin','Forearm')):bone.rotation_euler.x=max(0,-side*math.sin(phase))*.36
                    if n=='Root':bone.location.z=.02*(1-math.cos(phase*2))
                    if n=='Chest':bone.rotation_euler.z=.07*math.sin(phase)
                    if n=='Tail':bone.rotation_euler.z=.15*math.sin(phase)
                elif action_name in ['attack_1','attack_2','skill','ultimate']:
                    # Anticipation ends at .44, exactly matching the battle release.
                    wind=math.sin(min(t/.44,1)*math.pi*.5) if t<.44 else (1-t)/.56
                    strike=math.sin((t-.27)/.30*math.pi) if .27<t<.57 else 0
                    if n=='Arm.R':bone.rotation_euler.x=-.85*wind;bone.rotation_euler.y=-.45*strike
                    if n=='Forearm.R':bone.rotation_euler.x=-.65*wind
                    if n=='Arm.L':bone.rotation_euler.x=-.45*wind
                    if n=='Chest':bone.rotation_euler.z=.20*wind if action_name=='attack_1' else -.25*wind;bone.rotation_euler.x=.13*strike
                    if n=='Head':bone.rotation_euler.x=-.08*wind
                    if n=='Root' and action_name=='ultimate':bone.location.z=.14*math.sin(math.pi*t)
                    if n=='Cape':bone.rotation_euler.x=-.16*strike
                elif action_name=='hit':
                    recoil=math.sin(math.pi*t)*(1-t)
                    if n=='Chest':bone.rotation_euler.x=-.28*recoil
                    if n=='Head':bone.rotation_euler.x=-.15*recoil
                elif action_name=='death':
                    p=min(1,t*1.8)
                    if n=='Root':bone.rotation_euler.x=1.47*p;bone.location.z=.22*p
                    if n=='Head':bone.rotation_euler.x=.25*p
                    if n.startswith('Arm'):bone.rotation_euler.y=(.4 if n.endswith('.L') else -.4)*p
                bone.keyframe_insert('rotation_euler',frame=frame,group=n);bone.keyframe_insert('location',frame=frame,group=n)
        track=rig.animation_data.nla_tracks.new();track.name=action_name
        track.strips.new(action_name,0,action)
    rig.animation_data.action=None
    for bone in rig.pose.bones:bone.rotation_euler=(0,0,0);bone.location=(0,0,0)
    bpy.context.scene.frame_set(0)
def join_parts(id,rig=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in PARTS:o.select_set(True)
    bpy.context.view_layer.objects.active=PARTS[0];bpy.ops.object.join();body=bpy.context.object;body.name=id+' Geometry'
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    if rig:
        body.parent=rig;mod=body.modifiers.new('Real vertex skin','ARMATURE');mod.object=rig
    return body
def export(path,objects,animations=False):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=animations,export_animation_mode='NLA_TRACKS',export_force_sampling=False,export_nla_strips=True,export_anim_slide_to_zero=True,export_skins=True,export_materials='EXPORT',export_cameras=False,export_lights=False,export_copyright='Original geometry authored for Species War Eternal, 2026-10-07',export_extras=True)
def new_collection(name):
    global CURRENT_COLLECTION,PARTS
    CURRENT_COLLECTION=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(CURRENT_COLLECTION);PARTS=[]
def environment(zone,raid):
    id=zone+('_raid' if raid else '_hunt');new_collection(id)
    base=material(id+' floor','a69b85' if zone=='gray_meadow' else '77685d' if zone=='forgotten_mine' else '727e96',0,.87)
    moss=material('Velvet moss','526941',0,.98);bronze=material('Patinated bronze','8c7752',.52,.6)
    crystal=material(zone+' crystal','75cfdf' if zone=='gray_meadow' else 'e4a657' if zone=='forgotten_mine' else 'bcb3eb',.12,.25,.8)
    rng=random.Random(470+len(id))
    # Individual beveled tiles and staggered joints form a true modeled floor.
    for x in range(-6,39,3):
        for y in range(-8,31,3):
            o=cube('floor tile',(x+1.5+(1.5 if (y//3)%2 else 0),y+1.5,-.18),(1.47,1.47,.16),base,None,.065)
            o.rotation_euler.z=rng.uniform(-.015,.015)
    # Open gameplay floor remains unblocked; tall props are beyond its bounds.
    for x,y in [(-3,3),(-2,13),(34,4),(35,16),(5,-5),(19,-5),(29,-4),(6,25),(21,25),(31,24)]:
        if zone=='gray_meadow':
            for j in range(3):ico('weathered rock',(x+rng.uniform(-.7,.7),y+rng.uniform(-.7,.7),.45),(.7,.55,.55),STONE,None,2)
            tube('ruin column',(x,y,.1),(x,y,3.4),.42,base,None,sides=10)
            cube('column capital',(x,y,3.4),(.58,.58,.16),bronze,None,.04)
            for j in range(3):ico('moss growth',(x+.55*math.cos(j*2),y+.55*math.sin(j*2),.2),(.45,.38,.18),moss,None,2)
        elif zone=='forgotten_mine':
            ico('mine outcrop',(x,y,1.0),(1.2,.85,1.25),STONE,None,2)
            for j in range(4):tube('crystal seam',(x+.24*j,y,.4),(x+.24*j-.12,y+.12,1.5+.15*j),.16,crystal,None,.035,5)
            cube('timber post',(x+.7,y,1.4),(.13,.17,1.4),LEATHER,None,.02)
            tube('lantern hook',(x+.7,y,2.4),(x+.3,y,2.4),.06,bronze,None)
            cube('lantern',(x+.3,y,2.15),(.17,.13,.23),crystal,None,.03)
        else:
            tube('silver trunk',(x,y,.1),(x+.1,y,3.3),.18,base,None,.10)
            for j in range(3):
                end=(x+math.cos(j*2)*.9,y+math.sin(j*2)*.7,3.8)
                tube('branch',(x,y,2.3),end,.08,base,None,.025)
                ico('moon canopy',end,(1.15,.85,.55),material('Moon foliage','687d91',0,.95),None,2)
            for j in range(3):tube('moon crystal',(x+.2*j,y,.2),(x+.2*j,y+.08,.8+j*.15),.11,crystal,None,.004,5)
    if raid:
        # Raised architectural frame is outside the coordinate-exact arena.
        for x in [-2,34]:
            cube('arena parapet',(x,10,.28),(.75,13,.35),base,None,.12)
        for y in [-3,23]:cube('arena parapet',(16,y,.28),(18,.70,.35),base,None,.12)
        for r in [4.6,5.3]:
            for j in range(48):
                a=j*math.tau/48;pos=(16+r*math.cos(a),10+r*math.sin(a),.025)
                o=cube('bronze floor inlay',pos,(.31,.025,.009),bronze,None,.005);o.rotation_euler.z=a+math.pi/2
    body=join_parts(id);export(OUT/'environments'/f'{id}.glb',[body])
    return {'id':id,'path':'res://assets/models3d-v1/environments/'+id+'.glb','triangles':sum(len(p.vertices)-2 for p in body.data.polygons)}

def main():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    bpy.context.scene.render.fps=30;bpy.context.scene.frame_start=0;bpy.context.scene.frame_end=30
    entries={}
    for index,id in enumerate(list(ROSTER)+MONSTERS):
        new_collection(id)
        bones,height=humanoid(id,ROSTER[id]) if id in ROSTER else creature(id)
        rig=make_rig(id,bones);body=join_parts(id,rig);animate(rig,id)
        rig['identity']=id;rig['native_height']=height
        export(OUT/'characters'/f'{id}.glb',[rig,body],True)
        bounds=[body.matrix_world@v.co for v in body.data.vertices]
        width=max(p.x for p in bounds)-min(p.x for p in bounds);depth=max(p.y for p in bounds)-min(p.y for p in bounds)
        entries[id]={'id':id,'hero':id in ROSTER,'path':'res://assets/models3d-v1/characters/'+id+'.glb','native_height':height,'body_ratio':min(1.45,max(.60,math.hypot(width,depth)/height)),'bones':len(bones),'triangles':sum(len(p.vertices)-2 for p in body.data.polygons),'animations':['idle','walk','attack_1','attack_2','skill','ultimate','hit','death']}
        # Master .blend is an editable collection library, laid out for inspection.
        rig.location=(index%8*3.0,index//8*3.3,0)
        print('MODEL_EXPORTED',id,entries[id]['triangles'],flush=True)
    environments=[]
    for zone in ['gray_meadow','forgotten_mine','moonrest_forest']:
        for raid in [False,True]:environments.append(environment(zone,raid))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/eternal-model-library.blend'),compress=True)
    (OUT/'catalog.json').write_text(json.dumps({'version':1,'renderer':'real skinned GLB geometry','blender':bpy.app.version_string,'entries':entries,'environments':environments},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('MODELS3D_BUILD_OK',len(entries),len(environments),flush=True)
if __name__=='__main__':main()
