"""Verify native GLB counts and unchanged hero pose atlases/anchors without rendering."""
from pathlib import Path
import hashlib
import json
import struct
import subprocess

ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/'checks/ultra-vfx-2026-10-08/actor-assets.json'
catalog=json.loads((ROOT/'assets/mobile25d/catalog.json').read_text(encoding='utf-8'))
rows=[]
for item in catalog['entries']:
    if not item['hero']:continue
    folder=ROOT/'assets/mobile25d'/item['id']
    frame=json.loads((folder/'frames.json').read_text(encoding='utf-8'))
    baseline=json.loads(subprocess.check_output(['git','show','HEAD:'+str((folder/'frames.json').relative_to(ROOT)).replace('\\','/')],cwd=ROOT))
    blob=(folder/'billboard.glb').read_bytes()
    magic,version,total=struct.unpack_from('<III',blob)
    assert magic==0x46546c67 and version==2 and total==len(blob)
    length,chunk=struct.unpack_from('<II',blob,12)
    assert chunk==0x4e4f534a
    gltf=json.loads(blob[20:20+length])
    geometry={}
    for mesh in gltf['meshes']:
        geometry[mesh['name']]=sum(gltf['accessors'][p['indices']]['count']//3 for p in mesh['primitives'])
    expected={'HairCards600':1200,'HairCards300LOD':600,'PaintedRelief':6000,'PaintedReliefLOD3000':3000}
    for suffix,triangles in expected.items():
        assert geometry[item['id']+' '+suffix]==triangles,(item['id'],suffix,geometry)
    for kind in ['attack','motion']:assert frame[kind]==baseline[kind],(item['id'],kind,'changed painting/anchor/pose')
    digest=hashlib.sha256((folder/'poses_1024.png').read_bytes()).hexdigest()
    assert digest==frame['attack']['image_sha256']==frame['motion']['image_sha256']
    assert frame['hair_cards']==600 and frame['cape_control_points']==5
    assert item['triangles']==7200 and item['lod_triangles']==3600
    rows.append({'id':item['id'],'actual_glb_geometry':geometry,'runtime_full_triangles':7200,'runtime_lod_triangles':3600,'atlas_sha256':digest,'pose_data_identical_to_head':True,'glb_bytes':len(blob)})
assert len(rows)==30 and len({r['id'] for r in rows})==30
report={'heroes':len(rows),'actual_hair_cards_per_hero':600,'actual_hair_triangles_per_hero':1200,'cape_controls':5,'unchanged_pose_atlases_and_anchors':True,'shader_or_runtime_tested':False,'full_surface_cloth_simulation':False,'native_renderer_fps_tested':False,'rows':rows}
OUTPUT.parent.mkdir(parents=True,exist_ok=True)
OUTPUT.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('ULTRA_ACTOR_ASSETS_OK heroes=30 hair_cards=600 hair_triangles=1200 lod_triangles=3600 original_pose_data_unchanged=true')
