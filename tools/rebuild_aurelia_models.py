"""Author the first rigged volume-mesh pass of the three Aurelia pilot heroes.

Blender: --background --factory-startup --python tools/rebuild_aurelia_models.py
This is a development mesh pass, not acceptance of the concept's final quality.
No artwork is placed on a billboard or a camera-facing character plane.
"""
from pathlib import Path
import json
import math
import bpy
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
    MATS[key]=m;return m

def mesh(name,vertices,faces,material,bone,smooth=True):
    data=bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update()
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o);o.data.materials.append(material)
    group=o.vertex_groups.new(name=bone);group.add(list(range(len(vertices))),1,'REPLACE')
    for f in data.polygons:f.use_smooth=smooth
    PARTS.append(o);return o

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
    return mesh(name,vs,fs,material,bone)

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
    return mesh(name,vs,fs,material,bone)

def ell(name,p,r,material,bone,segments=18,rings=10):
    vs=[];fs=[]
    for j in range(rings+1):
        a=j/rings*math.pi
        for i in range(segments):
            b=i/segments*math.tau;vs.append((p[0]+r[0]*math.sin(a)*math.cos(b),p[1]+r[1]*math.sin(a)*math.sin(b),p[2]+r[2]*math.cos(a)))
    for j in range(rings):
        for i in range(segments):a=j*segments+i;b=j*segments+(i+1)%segments;fs.append((a,a+segments,b+segments,b))
    return mesh(name,vs,fs,material,bone)

def panel(name,rows,material,bones,width=9):
    vs=[];fs=[]
    for j,(x,y,z,span) in enumerate(rows):
        for i in range(width):
            u=i/(width-1)-.5
            vs.append((x+u*span,y+math.cos(u*math.pi*6)*.022*(j/max(1,len(rows)-1)),z+math.sin(u*math.pi)*.012))
    for j in range(len(rows)-1):
        for i in range(width-1):a=j*width+i;fs.append((a,a+width,a+width+1,a+1))
    o=mesh(name,vs,fs,material,bones[0]);o.vertex_groups.clear()
    for j in range(len(rows)):
        b=bones[min(len(bones)-1,j*len(bones)//len(rows))]
        g=o.vertex_groups.get(b) or o.vertex_groups.new(name=b);g.add(list(range(j*width,(j+1)*width)),1,'REPLACE')
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
    o=mesh(name,vs,fs,material,bone);s=o.modifiers.new('Hair volume','SOLIDIFY');s.thickness=.008
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
    bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False);return o

def face(hero,skin,ink,eye,hair):
    contour('Facial anatomy',[(0,.015,1.76,.040,.050),(0,.015,1.80,.102,.085),(0,0,1.87,.151,.122),(0,.002,1.94,.170,.141),(0,.015,2.03,.174,.150),(0,.025,2.10,.145,.130),(0,.030,2.16,.080,.075),(0,.030,2.18,.014,.013)],skin,'Head',32)
    for s in [-1,1]:
        ell('Ear',(s*.172,.015,1.95),(.029,.035,.060),skin,'Head',12,8)
        ell('Eye white',(s*.073,-.139,1.970),(.045,.011,.029),mat('Eye ivory','f8f1df',0,.3),'Head',20,10)
        ell('Iris',(s*.073,-.150,1.966),(.019,.003,.022),eye,'Head',18,10)
        ell('Pupil',(s*.073,-.153,1.967),(.008,.002,.014),ink,'Head',14,8)
        ell('Eye catchlight',(s*.065,-.156,1.977),(.005,.002,.006),mat('Eye light','ffffff',0,.2),'Head',10,6)
        tube('Upper eyelid',[(s*.034,-.149,1.982),(s*.070,-.155,2.001),(s*.111,-.138,1.990)],[.003,.005,.003],ink,'Head',6)
        tube('Eyebrow',[(s*.035,-.131,2.021),(s*.071,-.143,2.037),(s*.112,-.121,2.027)],[.003,.006,.002],hair,'Head',6)
    mesh('Nose bridge',[(-.012,-.135,1.977),(.012,-.135,1.977),(0,-.180,1.928),(-.018,-.145,1.920),(.018,-.145,1.920)],[(0,2,1),(0,3,2),(1,2,4),(3,4,2)],skin,'Head')
    tube('Mouth',[(-.028,-.124,1.875),(0,-.138,1.872),(.028,-.124,1.875)],[.0015,.002,.0015],mat('Lip rose','a76663',0,.75),'Head',6)

def build(hero):
    global PARTS,MATS
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);PARTS=[];MATS={}
    gold=mat('Aurelia engraved gold','c39a48',.8,.3);ivory=mat('Ivory enamel plate','e9e3cf',.55,.35)
    leather=mat('Dark leather','30272c',0,.82);ink=mat('Dark eye and seams','171922',0,.64)
    skin=mat('Skin','f2cab0',0,.7);blue=mat('Royal blue cloth','21418b',0,.82);green=mat('Forest silk','547c3e',0,.75);red=mat('Royal crimson cloth','8e242a',0,.82)
    hair=mat('Hero hair',{'leonhardt':'d9a64d','elisia':'e8d8c9','mira':'923831'}[hero],0,.52)
    hair_high=mat('Hair highlights',{'leonhardt':'f2cc7e','elisia':'f4e7d9','mira':'b34a3c'}[hero],0,.5)
    eye=mat('Iris',{'leonhardt':'3b80b4','elisia':'55834c','mira':'ac573e'}[hero],0,.24)
    arm=rig(hero);female=hero!='leonhardt';width=.20 if female else .255
    contour('Torso silhouette',[(0,0,.96,width*.8,.13),(0,0,1.07,width*.9,.13),(0,0,1.20,width*.72,.105),(0,0,1.40,width,.145),(0,0,1.51,width*1.15,.135),(0,0,1.59,width*.85,.105)],green if hero=='elisia' else ivory,'Chest',24)
    contour('Neck',[(0,0,1.57,.073,.070),(0,0,1.78,.060,.060)],skin,'Neck',16)
    face(hero,skin,ink,eye,hair)
    for s in [-1,1]:
        suffix='L' if s>0 else 'R';arm_mat=ivory if hero=='leonhardt' else skin
        contour('Upper arm '+suffix,[(s*.27,0,1.54,.080,.085),(s*.32,0,1.44,.082,.084),(s*.40,-.01,1.25,.059,.064)],arm_mat,'UpperArm.'+suffix)
        contour('Forearm '+suffix,[(s*.40,-.01,1.26,.066,.065),(s*.44,-.03,1.12,.065,.066),(s*.47,-.055,.99,.047,.045)],ivory if hero=='leonhardt' else leather,'Forearm.'+suffix)
        contour('Hand '+suffix,[(s*.47,-.055,1,.042,.031),(s*.48,-.075,.91,.046,.031),(s*.48,-.085,.87,.031,.025)],skin,'Hand.'+suffix,12)
        for f in range(4):tube('Finger '+suffix+str(f),[(s*.48+(f-1.5)*.016,-.09,.92),(s*.48+(f-1.5)*.015,-.116,.87),(s*.48+(f-1.5)*.013,-.11,.85)],[.008,.007,.004],skin,'Hand.'+suffix,6)
        contour('Thigh '+suffix,[(s*.115,0,1.01,.091,.105),(s*.125,0,.82,.090,.092),(s*.14,-.01,.58,.062,.063)],ivory if hero=='leonhardt' else leather if hero=='mira' else skin,'Thigh.'+suffix)
        contour('Shin '+suffix,[(s*.14,-.01,.60,.066,.067),(s*.145,.015,.44,.078,.070),(s*.15,0,.16,.044,.044)],ivory if hero=='leonhardt' else leather,'Shin.'+suffix)
        contour('Boot '+suffix,[(s*.15,-.065,.035,.070,.135),(s*.15,-.065,.09,.074,.139),(s*.15,-.020,.16,.056,.065)],ivory if hero=='leonhardt' else leather,'Foot.'+suffix)
        for z,x,r,b in [(1.21,s*.411,.070,'Forearm.'+suffix),(.55,s*.14,.070,'Shin.'+suffix),(.19,s*.15,.049,'Shin.'+suffix)]:
            contour('Gold armor binding',[(x,-.008,z-.015,r,.077),(x,-.008,z+.015,r,.077)],gold,b)
        if hero!='elisia':
            ell('Pauldrons '+suffix,(s*.285,0,1.545),(.125,.145,.095),ivory,'UpperArm.'+suffix)
            tube('Pauldron gold rim',[(s*.18,-.113,1.54),(s*.28,-.15,1.48),(s*.38,-.10,1.52)],[.014,.017,.012],gold,'UpperArm.'+suffix)
            for j in range(3):
                ell('Engraved leaf',(s*(.25+j*.035),-.138,1.57-j*.018),(.015,.008,.032),gold,'UpperArm.'+suffix,10,6)
    # Metal edging follows actual torso contours instead of a painted decal.
    for z,w in [(1.10,width*.93),(1.40,width*1.01)]:
        contour('Body gold edge',[(0,0,z-.018,w,.152),(0,0,z+.018,w,.152)],gold,'Chest',24)
    tube('Chest filigree',[(-width*.6,-.151,1.47),(0,-.17,1.34),(width*.6,-.151,1.47)],[.013,.016,.013],gold,'Chest',8)
    cloth=blue if hero=='leonhardt' else red if hero=='mira' else green
    cape_rows=[(0,.15,1.55,.50),(0,.19,1.34,.55),(0,.25,1.10,.63),(0,.31,.85,.76),(0,.37,.61,.87),(0,.40,.40,1.02)]
    if hero=='elisia':
        for s in [-1,1]:
            rows=[(s*.16,0,1.13,.18),(s*.19,.025,.92,.24),(s*.26,.055,.67,.32),(s*.30,.08,.38,.40),(s*.32,.10,.19,.44)]
            panel('Leaf dress layer',rows,green,['Hips','Cape1','Cape2','Cape3','Cape4'])
            for i in range(4):
                p=rows[i];q=rows[i+1];tube('Golden dress hem',[(p[0]+s*p[3]/2,p[1]-.025,p[2]),(q[0]+s*q[3]/2,q[1]-.025,q[2])],[.009,.010],gold,'Cape'+str(min(4,i+1)),8)
        panel('Ivory dress front',[(0,-.14,1.12,.22),(0,-.17,.86,.30),(0,-.20,.61,.38),(0,-.23,.38,.44),(0,-.26,.20,.50)],mat('Ivory silk','eee5cf',0,.82),['Hips','Cape1','Cape2','Cape3','Cape4'])
        for s in [-1,1]:
            mesh('Pointed elf ear',[(s*.16,.005,1.96),(s*.30,.025,2.02),(s*.19,-.018,1.90),(s*.18,.04,1.94)],[(0,1,2),(2,1,3),(3,1,0),(0,2,3)],skin,'Head')
            contour('Wide sleeve '+str(s),[(s*.30,0,1.48,.13,.12),(s*.38,-.01,1.19,.15,.14),(s*.43,-.03,1.04,.18,.16)],green,'Forearm.'+('L' if s>0 else 'R'))
    else:
        panel('Royal cape',cape_rows,cloth,['Cape0','Cape1','Cape2','Cape3','Cape4'])
        for s in [-1,1]:
            for i in range(len(cape_rows)-1):
                p=cape_rows[i];q=cape_rows[i+1];tube('Cape gold border',[(s*p[3]/2,p[1],p[2]),(s*q[3]/2,q[1],q[2])],[.009,.009],gold,'Cape'+str(min(i,4)),8)
        tube('Cape lower gold hem',[(-.5,.40,.40),(0,.40,.40),(.5,.40,.40)],[.01,.01,.01],gold,'Cape4',8)
        panel('Royal tabard',[(0,-.15,1.10,.18),(0,-.17,.94,.19),(0,-.18,.76,.23),(0,-.20,.62,.25)],cloth,['Hips','Hips','Thigh.L','Thigh.L'],7)
    # Hair is a sculpted-volume pass; final cards, anisotropic textures and
    # collision are intentionally not claimed by this script.
    for i in range(28):
        a=i*math.tau/28;x=math.sin(a)*.155;y=.025+math.cos(a)*.145
        z=2.09+math.sin(a*3)*.03
        if hero=='leonhardt':points=[(x*.55,y*.55,2.19),(x,y,z),(x*1.30,y*1.12,z-.10-(i%3)*.025)]
        elif hero=='elisia':points=[(x*.55,y*.6,2.17),(x,y,z),(x*1.15,y+.07,1.78),(x*1.5,y+.15,1.46),(x*1.9,y+.21,1.20)]
        else:points=[(x*.55,y*.55,2.19),(x,y,z),(x*.98,y+.025,1.98-(i%3)*.026)]
        hair_lock('Hair lock '+str(i),points,.069,.028,hair_high if i%5==0 else hair)
    for i in range(9):
        x=(i-4)*.032;hair_lock('Fringe '+str(i),[(x*.6,-.08,2.16),(x,-.155,2.09),(x+.025*math.sin(i),-.168,2.005+(i%3)*.024)],.070,.025,hair_high if i%4==0 else hair)
    if hero=='mira':
        for i in range(18):
            a=i*math.tau/18;hair_lock('Ponytail '+str(i),[(.035*math.sin(a),.15,2.13),(.08+.045*math.sin(a),.30,2.02),(.15+.07*math.sin(a),.38,1.73),(.23+.09*math.sin(a),.36,1.48),(.28+.10*math.sin(a),.28,1.28)],.066,.025,hair_high if i%5==0 else hair)
        ell('Hair clasp',(0,.16,2.12),(.055,.025,.030),gold,'Head',12,8)
    weapon(hero,gold,leather,ivory,cloth)
    # Apply volume and bevel modifiers before adding the armature deform.
    for o in PARTS:
        bpy.context.view_layer.objects.active=o;o.select_set(True)
        for modifier in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
        o.select_set(False);o.parent=arm
        m=o.modifiers.new('Weighted skeleton','ARMATURE');m.object=arm
    animate(arm,hero)
    bpy.ops.object.select_all(action='DESELECT');arm.select_set(True)
    for o in PARTS:o.select_set(True)
    bpy.context.view_layer.objects.active=arm
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(hero+'-volume-pass.blend')))
    bpy.ops.export_scene.fbx(filepath=str(UNITY/(hero+'.fbx')),use_selection=True,object_types={'ARMATURE','MESH'},add_leaf_bones=False,axis_forward='-Z',axis_up='Y',bake_anim=True,bake_anim_use_all_actions=False,bake_anim_use_nla_strips=True,bake_anim_simplify_factor=0,apply_scale_options='FBX_SCALE_ALL',use_mesh_modifiers=True)
    tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in PARTS)
    return {'hero':hero,'triangles':tris,'mesh_parts':len(PARTS),'fbx':str((UNITY/(hero+'.fbx')).relative_to(ROOT)).replace('\\','/'),'source':str((OUT/(hero+'-volume-pass.blend')).relative_to(ROOT)).replace('\\','/'),'status':'first rigged volume-mesh development pass; concept quality acceptance deferred','animations':['Idle','Walk','Attack'],'hair':'sculpted locks; final hair-card pass pending','cloth':'five deform bones; final physical simulation pending'}

def weapon(hero,gold,leather,ivory,cloth):
    if hero=='leonhardt':
        # Right-hand sword, left-arm convex heraldic shield, anatomically named.
        tube('Sword grip',[(-.48,-.1,.86),(-.48,-.1,1.04)],[.023,.023],leather,'Hand.R',10)
        tube('Sword guard',[(-.62,-.1,.865),(-.48,-.1,.85),(-.34,-.1,.865)],[.017,.022,.017],gold,'Hand.R',8)
        mesh('Double bevel silver blade',[(-.48,-.1,.11),(-.54,-.1,.79),(-.48,-.133,.79),(-.42,-.1,.79),(-.48,-.067,.79)],[(0,1,2),(0,2,3),(0,3,4),(0,4,1),(1,4,3,2)],mat('Sword polished steel','b8cbd4',.92,.2),'Hand.R',False)
        vs=[(.27,-.24,1.46),(.50,-.30,1.51),(.73,-.24,1.46),(.70,-.28,.99),(.50,-.34,.79),(.30,-.28,.99),(.50,-.37,1.20)]
        faces=[((i+1)%6,i,6) for i in range(6)];shield=mesh('Convex heraldic shield',vs,faces,mat('Blue enamel shield','29468b',.45,.4),'Forearm.L',False)
        solid=shield.modifiers.new('Shield plate depth','SOLIDIFY');solid.thickness=.035
        for i in range(6):tube('Shield gold rim',[vs[i],vs[(i+1)%6]],[.013,.013],gold,'Forearm.L',8)
        tube('Shield central heraldry',[(.50,-.382,1.40),(.50,-.386,.95)],[.018,.012],gold,'Forearm.L',8)
        for s in [-1,1]:tube('Shield crown',[ (.50,-.388,1.22),(.50+s*.095,-.354,1.31),(.50+s*.07,-.347,1.37)],[.010,.012,.005],gold,'Forearm.L',8)
    elif hero=='elisia':
        tube('Leaf staff shaft',[(.51,-.1,.02),(.49,-.1,1.87)],[.022,.018],gold,'Hand.L',10)
        ring=[(.50+math.cos(i*math.tau/24)*.13,-.10,1.99+math.sin(i*math.tau/24)*.16) for i in range(25)]
        tube('Staff gold crown',ring,[.012]*len(ring),gold,'Hand.L',8)
        ell('Staff green gem',(.50,-.10,1.99),(.075,.065,.10),mat('Green gem','52ce62',.3,.2,.35),'Hand.L',12,8)
        for j in range(5):ell('Staff leaf',(.40+j*.05,-.1,2.12+abs(j-2)*.03),(.023,.012,.059),mat('Staff leaf green','4b7537'), 'Hand.L',10,6)
        for s in [-1,1]:
            for i in range(5):ell('Hair flower petal',(s*.15+math.cos(i*math.tau/5)*.025,-.04,2.06+math.sin(i*math.tau/5)*.025),(.014,.009,.021),ivory,'Head',10,6)
    else:
        points=[(.47+.10*math.sin(i/16*math.pi),-.12,.66+i/16*.94) for i in range(17)]
        tube('Royal recurved bow',points,[.014+.007*math.sin(i/16*math.pi) for i in range(17)],gold,'Hand.L',10)
        tube('Bowstring',[points[0],(.465,-.12,1.09),points[-1]],[.0015,.0015,.0015],mat('Bowstring','d0bba1',0,.85),'Hand.L',6)
        tube('Quiver',[(-.16,.22,1.09),(-.27,.28,1.59)],[.067,.072],leather,'Chest',12)
        for i in range(6):
            x=-.27+(i-2.5)*.019;tube('Quiver arrow',[(x,.28,1.20),(x,.28,1.77)],[.004,.004],gold,'Chest',6)
            mesh('Arrow fletching',[(x,.28,1.69),(x+.025,.28,1.73),(x,.28,1.77),(x-.025,.28,1.73)],[(0,1,2),(0,2,3)],cloth,'Chest')

def animate(arm,hero):
    bpy.context.scene.render.fps=30
    for name,start,length in [('Idle',1,90),('Walk',110,30),('Attack',160,24)]:
        action=bpy.data.actions.new(name);arm.animation_data_create();arm.animation_data.action=action
        for f in range(0,length+1,3):
            t=f/length*math.tau
            for b in arm.pose.bones:b.rotation_mode='XYZ';b.rotation_euler=(0,0,0)
            arm.pose.bones['Chest'].rotation_euler.x=.018*math.sin(t)
            for i in range(5):arm.pose.bones['Cape'+str(i)].rotation_euler.x=.045*math.sin(t-i*.6)
            if name=='Walk':
                for s,v in [('L',1),('R',-1)]:
                    arm.pose.bones['Thigh.'+s].rotation_euler.x=.38*math.sin(t)*v
                    arm.pose.bones['Shin.'+s].rotation_euler.x=.25*max(0,-math.sin(t)*v)
                    arm.pose.bones['UpperArm.'+s].rotation_euler.x=-.22*math.sin(t)*v
            if name=='Attack':
                arm.pose.bones['Chest'].rotation_euler.z=.15*math.sin(t)
                arm.pose.bones['UpperArm.R'].rotation_euler.x=-.65*math.sin(t/2)
                arm.pose.bones['Forearm.R'].rotation_euler.x=-.25*math.sin(t/2)
            for b in arm.pose.bones:b.keyframe_insert('rotation_euler',frame=start+f,group=b.name)
        track=arm.animation_data.nla_tracks.new();track.name=name
        strip=track.strips.new(name,start,action);strip.action_frame_start=start;strip.action_frame_end=start+length
    arm.animation_data.action=None;bpy.context.scene.frame_set(1)

results=[build(hero) for hero in ['leonhardt','elisia','mira']]
(OUT/'development-manifest.json').write_text(json.dumps({'pipeline':'native Blender mesh/armature to Unity FBX; no sprite substitution','heroes':results,'quality_acceptance':'deferred; no claim of final concept equivalence'},ensure_ascii=False,indent=2),encoding='utf-8')
print('AURELIA_VOLUME_PASS_EXPORTED',json.dumps(results))
