"""Blender-authored painted relief billboards and 1024 runtime atlases.

The complete existing paintings remain the visual source. These are 2.5D
surfaces with cloth/hair geometry, not replacement spherical humanoids.
Run Blender --background --factory-startup --python tools/build_mobile25d.py.
"""
import bpy
import numpy as np
import hashlib
import json
import math
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/mobile25d'
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'source').mkdir(exist_ok=True)
(OUT/'source/.gdignore').write_text('')
floor_only='--floor-only' in sys.argv
actors_only='--actors-only' in sys.argv
if floor_only and actors_only:raise SystemExit('Choose --floor-only or --actors-only')
catalog=json.loads((OUT/'catalog.json').read_text(encoding='utf-8'))['entries'] if floor_only or actors_only else []
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)

def image_array(path):
    image=bpy.data.images.load(str(path),check_existing=False)
    image.colorspace_settings.name='Non-Color'
    w,h=image.size
    values=np.empty(w*h*4,dtype=np.float32);image.pixels.foreach_get(values)
    bpy.data.images.remove(image)
    return values.reshape(h,w,4)[::-1].copy()

def save_image(name,values,path):
    h,w=values.shape[:2]
    image=bpy.data.images.new(name,width=w,height=h,alpha=True)
    image.colorspace_settings.name='Non-Color'
    image.pixels.foreach_set(np.ascontiguousarray(values[::-1],dtype=np.float32).ravel())
    image.filepath_raw=str(path);image.file_format='PNG';image.save()
    bpy.data.images.remove(image)

def resize(values,w,h):
    old_h,old_w=values.shape[:2]
    image=bpy.data.images.new('Pack crop',width=old_w,height=old_h,alpha=True)
    image.colorspace_settings.name='Non-Color'
    image.pixels.foreach_set(np.ascontiguousarray(values[::-1],dtype=np.float32).ravel())
    image.scale(w,h)
    pixels=np.empty(w*h*4,dtype=np.float32);image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    return pixels.reshape(h,w,4)[::-1].copy()

def mesh_object(name,columns,rows,relief=True):
    vertices=[];faces=[]
    for y in range(rows+1):
        for x in range(columns+1):
            u=x/columns;v=y/rows
            depth=-math.sin(u*math.pi)*math.sin(v*math.pi)*.015 if relief else 0
            vertices.append((u,depth,1-v))
    for y in range(rows):
        for x in range(columns):
            a=y*(columns+1)+x;b=a+1;c=a+columns+1;d=c+1
            faces.extend([(a,c,b),(b,c,d)])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    uv=mesh.uv_layers.new(name='UVMap')
    for polygon in mesh.polygons:
        polygon.use_smooth=True
        for loop_index in polygon.loop_indices:
            p=vertices[mesh.loops[loop_index].vertex_index]
            uv.data[loop_index].uv=(p[0],p[2])
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    return obj

def hair_object(identity,count=600,lod=False):
    seed=int(hashlib.sha256(identity.encode()).hexdigest()[:8],16)
    rng=np.random.default_rng(seed);vertices=[];faces=[];coordinates=[]
    for index in range(count):
        u=float(rng.uniform(.04,.96));v=float(rng.uniform(.02,.95))
        width=float(rng.uniform(.006,.014));length=float(rng.uniform(.025,.065))
        n=len(vertices)
        for a,b in [(u-width,v),(u+width,v),(u+width*.25,v+length),(u-width*.25,v+length)]:
            vertices.append((a,-.006-index%3*.0003,1-b));coordinates.append((a,1-b))
        faces.extend([(n,n+2,n+1),(n,n+3,n+2)])
    name=identity+(' HairCards300LOD' if lod else ' HairCards600')
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    uv=mesh.uv_layers.new(name='UVMap')
    for loop in mesh.loops:uv.data[loop.index].uv=coordinates[loop.vertex_index]
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    return obj

def export_geometry(identity,folder,hero):
    body=mesh_object(identity+' PaintedRelief',50 if hero else 30,60 if hero else 50)
    body['identity']=identity;body['representation']='Original painted 2.5D relief billboard';body['cape_points']=5 if hero else 0
    objects=[body]
    if hero:
        objects.extend([hair_object(identity),mesh_object(identity+' PaintedReliefLOD3000',30,50),hair_object(identity,300,True)])
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=body
    bpy.ops.export_scene.gltf(filepath=str(folder/'billboard.glb'),export_format='GLB',use_selection=True,export_animations=False,export_materials='NONE',export_cameras=False,export_lights=False)
    for obj in objects:obj.hide_set(True)
    return sum(len(obj.data.polygons) for obj in objects)

def rebuild_hero_geometry(item):
    identity=item['id'];folder=OUT/identity
    entry=json.loads((folder/'frames.json').read_text(encoding='utf-8'))
    texture_hash=hashlib.sha256((folder/'poses_1024.png').read_bytes()).hexdigest()
    entry.update({'body_triangles':6000,'hair_cards':600,'hair_triangles':1200,'cape_control_points':5,'lod_body_triangles':3000,'lod_hair_cards':300,'lod_hair_triangles':600,'hair_wind':.15,'hair_clump':.3,'hair_frizz':.1,'cloth_stiffness':.12,'cloth_damping':.88,'cloth_wind':.12,'secondary_collision':'analytic five-point strip; torso capsule and nonadjacent-point separation'})
    exported=export_geometry(identity,folder,True)
    assert hashlib.sha256((folder/'poses_1024.png').read_bytes()).hexdigest()==texture_hash
    (folder/'frames.json').write_text(json.dumps(entry,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    item.update({'triangles':7200,'hair_cards':600,'cape_points':5,'lod_triangles':3600,'exported_triangles_including_lods':exported,'glb_bytes':(folder/'billboard.glb').stat().st_size})
    print('MOBILE25D_ACTOR_ONLY',identity,item['triangles'],item['hair_cards'],flush=True)

def pack(identity,path,hero):
    source=json.loads(path.read_text(encoding='utf-8'))
    folder=OUT/identity;folder.mkdir(exist_ok=True)
    frames=source['attack']['frames']+source['motion']['frames']
    factor=244/max(max(frame['region'][2:]) for frame in frames)
    atlas=np.zeros((1024,1024,4),dtype=np.float32)
    arrays={}
    packed=[]
    for index,frame in enumerate(frames):
        kind='attack' if index<8 else 'motion'
        original=ROOT/source[kind]['atlas'].removeprefix('res://')
        if original not in arrays:arrays[original]=image_array(original)
        x,y,w,h=frame['region'];nw=max(1,round(w*factor));nh=max(1,round(h*factor))
        crop=resize(arrays[original][y:y+h,x:x+w],nw,nh)
        px=(index%4)*256+6;py=(index//4)*256+6
        atlas[py:py+nh,px:px+nw]=crop
        value=dict(frame);value['region']=[px,py,nw,nh]
        value['anchor']=[frame['anchor'][0]*nw/w,frame['anchor'][1]*nh/h]
        # Tight top paint bounds locate the auxiliary hair surface; the original
        # texture is sampled again in its shader, preserving facial paint.
        mask=crop[:max(1,int(nh*.26)),:,3]>.3
        yy,xx=np.where(mask)
        value['hair_rect']=[float(xx.min()/nw),float(yy.min()/nh),float((xx.max()-xx.min()+1)/nw),float((yy.max()-yy.min()+1)/nh)] if len(xx) else [.3,.02,.4,.23]
        packed.append(value)
    save_image(identity+' 1024 poses',atlas,folder/'poses_1024.png')
    entry=dict(source);entry['optimized_mobile25d']=True
    entry['source_frames']=str(path.relative_to(ROOT));entry['source_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
    for kind,start in [('attack',0),('motion',8)]:
        entry[kind]=dict(source[kind]);entry[kind]['atlas']='res://'+str((folder/'poses_1024.png').relative_to(ROOT)).replace('\\','/')
        entry[kind]['atlas_size']=[1024,1024];entry[kind]['native_height']=float(source[kind]['native_height'])*factor
        entry[kind]['frames']=packed[start:start+8];entry[kind]['image_sha256']=hashlib.sha256((folder/'poses_1024.png').read_bytes()).hexdigest()
    entry['mesh']='res://'+str((folder/'billboard.glb').relative_to(ROOT)).replace('\\','/')
    entry['base_px']=48 if hero else 40;entry['scale']=1.8 if hero else 1.0
    entry['requested_extra_scale']=1.2 if hero else 1.0
    entry['body_triangles']=6000 if hero else 3000;entry['hair_cards']=600 if hero else 0
    entry['hair_triangles']=1200 if hero else 0;entry['cape_control_points']=5 if hero else 0
    if hero:entry.update({'lod_body_triangles':3000,'lod_hair_cards':300,'lod_hair_triangles':600,'hair_wind':.15,'hair_clump':.3,'hair_frizz':.1,'cloth_stiffness':.12,'cloth_damping':.88,'cloth_wind':.12})
    entry['runtime_texture_format_target']='BPTC/ASTC 4x4 RGBA with mipmaps; verify engine imports'
    (folder/'frames.json').write_text(json.dumps(entry,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    exported=export_geometry(identity,folder,hero)
    model_bytes=(folder/'billboard.glb').stat().st_size
    catalog.append({'id':identity,'hero':hero,'triangles':7200 if hero else 3000,'hair_cards':600 if hero else 0,'cape_points':5 if hero else 0,'lod_triangles':3600 if hero else 3000,'exported_triangles_including_lods':exported,'texture_size':[1024,1024],'png_bytes':(folder/'poses_1024.png').stat().st_size,'glb_bytes':model_bytes,'mesh':entry['mesh']})
    print('MOBILE25D_ASSET',identity,catalog[-1]['triangles'],flush=True)

original=ROOT/'assets/art-direction/full-body-v2'
roster=json.loads((ROOT/'assets/heroes/sd-v36/roster-reference.json').read_text(encoding='utf-8'))
hero_ids=set(roster) if isinstance(roster,dict) else set(row['id'] for row in roster)
if actors_only:
    heroes=[item for item in catalog if item['hero']]
    assert len(heroes)==30
    for item in heroes:rebuild_hero_geometry(item)
    # Read the latest catalog again so a concurrent floor authoring change is retained.
    latest=json.loads((OUT/'catalog.json').read_text(encoding='utf-8'))
    by_id={item['id']:item for item in catalog}
    latest['entries']=[by_id[item['id']] if item['hero'] else item for item in latest['entries']]
    (OUT/'catalog.json').write_text(json.dumps(latest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/mobile25d-ultra-heroes.blend'),compress=True)
    print('MOBILE25D_ACTORS_BUILD_OK',len(heroes),flush=True)
    raise SystemExit(0)
for path in ([] if floor_only else sorted(original.glob('*/frames.json'))):
    pack(path.parent.name,path,path.parent.name in hero_ids)
fallback=ROOT/'assets/art-direction/hunt-frame-pilot/goblin/frames.json'
if not floor_only and fallback.exists() and not (original/'goblin/frames.json').exists():pack('goblin',fallback,False)

# Seamless broad slabs, fine normal relief, edge wear and packed crack AO.
size=1024;y,x=np.mgrid[:size,:size];u=x/size;v=y/size
rng=np.random.default_rng(20261007)
hash_noise=rng.random((size,size),dtype=np.float32)
# Jittered, seamless stone polygons replace aligned rectangular brick courses.
seeds=[((a+.5+rng.uniform(-.22,.22))/3,(b+.5+rng.uniform(-.22,.22))/3) for a in range(3) for b in range(3)]
nearest=np.full((size,size),10.,dtype=np.float32);second=nearest.copy()
for sx,sy in seeds:
    dx=np.mod(u-sx+.5,1)-.5;dy=np.mod(v-sy+.5,1)-.5
    distance=np.sqrt(dx*dx+dy*dy).astype(np.float32)
    second=np.minimum(second,np.maximum(nearest,distance));nearest=np.minimum(nearest,distance)
edge=(second-nearest)*size*.55
crack=np.clip(1-edge/8,0,1);wear=np.clip(1-edge/16,0,1)-crack
coarse=(np.sin(u*math.tau*11+np.cos(v*math.tau*7))+np.sin(v*math.tau*13))*.5
height=.35+coarse*.015+(hash_noise-.5)*.018-crack*.19+wear*.035
stone=np.stack([.31+coarse*.012,.34+coarse*.014,.33+coarse*.01],axis=-1)+(hash_noise-.5)[...,None]*.025
detail_path=OUT/'source/stone_detail.png'
if detail_path.exists():
    detail=resize(image_array(detail_path),size,size)[...,:3]
    stone=(detail*.86+stone*.14)*.78
    height+=(detail.mean(axis=-1)-.5)*.025
stone*=1-crack[...,None]*.35;stone+=wear[...,None]*.6*.18
cracks=crack>.2;patina=np.zeros((size,size),dtype=bool)
locations=np.flatnonzero(cracks);order=locations[np.argsort(hash_noise.ravel()[locations])]
patina.ravel()[order[:round(len(order)*.20)]]=True
stone[patina]=stone[patina]*.60+np.array([107,138,122])/255*.40
moss_score=hash_noise*.30+np.sin(u*math.tau*7)*.20+np.cos(v*math.tau*11)*.15+crack*.60
# Coverage is 15% of the floor, strictly selected inside the crack band.
moss_band=edge<32;locations=np.flatnonzero(moss_band);order=locations[np.argsort(moss_score.ravel()[locations])[::-1]]
moss=np.zeros((size,size),dtype=bool);moss.ravel()[order[:round(size*size*.15)]]=True
stone[moss]=stone[moss]*.56+np.array([168,184,158])/255*.44
dust=(.5+.5*np.sin(u*math.tau*3)*np.cos(v*math.tau*5))*.15*(1-crack)
stone=stone*(1-dust[...,None])+np.array([216,213,204])/255*dust[...,None]*.45
ao=1-crack*.5
albedo=np.dstack([np.clip(stone,0,1),ao]).astype(np.float32)
gx=(np.roll(height,-1,1)-np.roll(height,1,1))*7;gy=(np.roll(height,-1,0)-np.roll(height,1,0))*7
normal=np.stack([-gx,-gy,np.ones_like(gx)],axis=-1);normal/=np.linalg.norm(normal,axis=-1)[...,None]
normal=np.dstack([normal*.5+.5,np.ones((size,size))]).astype(np.float32)
floor=OUT/'floor';floor.mkdir(exist_ok=True)
save_image('StoneSlab1024 AlbedoAO',albedo,floor/'stone_1024_albedo_ao.png')
save_image('StoneSlab1024 Normal',normal,floor/'stone_1024_normal.png')
save_image('StoneSlab1024 AO authoring',np.dstack([ao,ao,ao,np.ones_like(ao)]).astype(np.float32),floor/'stone_1024_ao.png')
material={'texture_size':[1024,1024],'roughness':.58,'metallic':.32,'patina_fraction_in_cracks':float(patina.sum()/cracks.sum()),'moss_fraction':float(moss.mean()),'moss_outside_crack_band':int((moss & ~moss_band).sum()),'moss_color':'#A8B89E','patina_color':'#6B8A7A','edge_wear':.6,'crack_dark':.35,'dust':.15,'ao_strength':.5,'moss_glow':.15,'runtime_ao_channel':'albedo alpha','runtime_textures':2,'runtime_bc7_bc5_bytes_with_mipmaps':2796202,'ao_separate_image':'authoring reference; packed in albedo alpha at runtime'}
(floor/'material.json').write_text(json.dumps(material,indent=2)+'\n')
if not floor_only:bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'source/mobile25d-library.blend'),compress=True)
(OUT/'catalog.json').write_text(json.dumps({'schema':1,'representation':'painted 2.5D relief billboards with separate hair geometry','entries':catalog,'floor':material},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('MOBILE25D_BUILD_OK',len(catalog),flush=True)
