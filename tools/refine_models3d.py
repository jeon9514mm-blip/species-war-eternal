"""Apply the art review to the editable library and re-export genuine GLBs.

Run after build_models3d.py with Blender --background --python this file.
"""
import bpy, bmesh, json, sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
out=root/'assets/models3d-v1'
bpy.ops.wm.open_mainfile(filepath=str(out/'source/eternal-model-library.blend'))
bpy.context.preferences.filepaths.save_version=0
catalog=json.loads((out/'catalog.json').read_text(encoding='utf-8'))
# The grid positions are for authoring only; GLBs always export at the foot origin.
for id,entry in catalog['entries'].items():
 rig=bpy.data.objects[id+' Rig'];body=bpy.data.objects[id+' Geometry'];location=rig.location.copy();rig.location=(0,0,0)
 hair_slots={i for i,m in enumerate(body.data.materials) if m and m.name.startswith(id+' hair')}
 hair_vertices={v for polygon in body.data.polygons if polygon.material_index in hair_slots for v in polygon.vertices}
 for index in hair_vertices:
  v=body.data.vertices[index]
  if v.co.y<-.085 and abs(v.co.x)<.18 and 1.42<v.co.z<1.69:v.co.z=1.69+(v.co.z-1.53)*.08
 if id in ['leonhardt','orwin','adrien','caelum','darius','valeria','lucien','ulric','sael']:
  # A flatter, faceted breastplate replaces the glossy egg-shaped placeholder.
  slots={i for i,m in enumerate(body.data.materials) if m and m.name.startswith(id+' armor')}
  chest_vertices={v for p in body.data.polygons if p.material_index in slots for v in p.vertices}
  for index in chest_vertices:
   v=body.data.vertices[index]
   if abs(v.co.x)<.23 and v.co.y<-.065 and 1.01<v.co.z<1.41:v.co.y=-.145+.12*abs(v.co.x)
  for m in body.data.materials:
   if m and m.name.startswith(id+' armor'):m.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.70
 bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);body.select_set(True);bpy.context.view_layer.objects.active=rig
 bpy.ops.export_scene.gltf(filepath=str(out/'characters'/f'{id}.glb'),export_format='GLB',use_selection=True,export_animation_mode='NLA_TRACKS',export_animations=True,export_skins=True,export_rest_position_armature=True,export_cameras=False,export_lights=False)
 rig.location=location
for entry in catalog['environments']:
 body=bpy.data.objects[entry['id']+' Geometry']
 # Blender -Y is Godot +Z. Preserve the exact game floor coordinates.
 body.scale.y=-1;bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 mesh=bmesh.new();mesh.from_mesh(body.data);bmesh.ops.recalc_face_normals(mesh,faces=mesh.faces);mesh.to_mesh(body.data);mesh.free()
 bpy.ops.export_scene.gltf(filepath=str(out/'environments'/(entry['id']+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
 body['coordinate_contract']='Godot x,z = simulation x,y'
bpy.ops.wm.save_as_mainfile(filepath=str(out/'source/eternal-model-library.blend'),compress=True)
print('MODELS3D_REFINED',len(catalog['entries']),flush=True)
