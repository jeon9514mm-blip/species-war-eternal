extends "res://tests/support/V83UpgradeTestBase.gd"
const FIELD_ART=preload('res://scripts/maps/FieldArtCatalog.gd')
func _init() -> void:run.call_deferred()
func run() -> void:
 var main=await make_main('aurelia',3)
 root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
 for zone: String in ['gray_meadow','forgotten_mine','moonrest_forest']:
  main.current_zone_id=zone;main._build_combat_screen();await settle()
  var field: Control=main.combat_labels.terrain
  check(not is_instance_valid(field.ultimate_details) and not is_instance_valid(field.diorama),'no map builder or scenery '+zone)
  var scenery_meshes: Array=[]
  for mesh in field.map_root.find_children('*','MeshInstance3D',true,false):
   var actor_part:=false
   for actor in field.actors.values():
    if actor==mesh or actor.is_ancestor_of(mesh):actor_part=true;break
   if not actor_part:scenery_meshes.append(mesh)
  check(scenery_meshes.size()==1 and scenery_meshes[0]==field.rune_ground.surface,'only new artist floor; no old props '+zone)
  check(field.map_root.find_children('*','CollisionObject3D',true,false).is_empty(),'no invisible scenery barriers '+zone)
  var material: ShaderMaterial=field.rune_ground.stone_material
  check(material.get_shader_parameter('stone_art').resource_path==FIELD_ART.texture_path(zone),'game and menus share new stone asset '+zone)
  check(not field.actors.is_empty(),'heroes and monsters remain visible '+zone)
  for point in [Vector2(.6,.6),Vector2(16,10),Vector2(31.2,19.4)]:
   check(field.local_to_world(field.project_world(point)).distance_to(point)<.02,'ground preserves touch projection '+zone)
  check(field.rune_ground.surface.mesh.size==Vector2(70,60),'floor fills moving combat camera '+zone)
  check(not material.shader.code.contains('WORLD_MATRIX'),'Godot 4 shader uses MODEL_MATRIX '+zone)
  for mode: String in ['balanced','battery']:
   main.presentation_options.performance=mode;field.apply_render_profile()
   for point in [Vector2(8,6),Vector2(24,15)]:
    field._set_focus(point)
    check(field.local_to_world(field.project_world(point)).distance_to(point)<.02,'camera tracking projection '+zone+' '+mode)
  main.presentation_options.performance='balanced';field.apply_render_profile();field._resize_world()
  check(field.find_child('CombatViewToggle',true,false)==null and not field.has_method('_toggle_overview'),'battle overview removed '+zone)
  var old_clock: float=field.rune_ground.elapsed
  main.combat_running=false;field.rune_ground._process(.1)
  check(is_equal_approx(field.rune_ground.elapsed,old_clock),'rune pulse freezes during pause '+zone)
  for actor in field.actors.values():
   check(actor.get_node('ContactShadow').material_override.shader!=null,'soft contact shading '+zone)
  var state: Dictionary=economic(main);var rng_state: int=main.loot_rng.state
  field._process(0)
  check(economic(main)==state and main.loot_rng.state==rng_state,'ground rendering preserves economy and RNG '+zone)
 await dispose(main);done('RUNE_STONE_APPLIED')
