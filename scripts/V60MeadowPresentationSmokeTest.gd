extends SceneTree
## The illustrated field, world props and actor reactions must follow the
## same live camera and damage simulation.
var checks:=0
var failures: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:
		failures.append(detail)
		push_error('V60 meadow presentation: '+detail)

func settle() -> void:
	for i in 4:await process_frame

func run() -> void:
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
	var game:=preload('res://scenes/PortraitMain.tscn').instantiate()
	game.save_state_path='user://v60-meadow-presentation.json'
	root.add_child(game);await settle()
	game.combat_effects_enabled=false
	game.selected_faction='aurelia';game.idle_stage=8
	game._restore_deployed_heroes(['leonhardt','mira','elisia','orwin'])
	game.current_zone_id='gray_meadow'
	game._build_combat_screen();await settle()
	var terrain: Control=game.combat_labels['terrain']
	check(terrain.field_texture.resource_path.contains('/terrain-v70/'),'meadow loads the layered terrain ground artwork')
	var sky: Control=game.content_root.get_node('PortraitSky')
	check(sky.zone_id=='gray_meadow','sky uses the meadow horizon')
	var props: Node=game.content_root.get_node('PortraitMeadowProps')
	check(props.props.size()>=8 and props.actor_layer==game.combat_labels['actor_layer'],'trees share the live Y-sorted actor layer')
	for hero in game.hero_map_sprites:
		check(hero.get_node_or_null('PortraitGroundShadow')!=null,'deployed hero has a ground shadow')
	for enemy in game.enemy_wave_sprites:
		check(enemy.sheet_layout=='casual_v58' and enemy.get_node_or_null('PortraitGroundShadow')!=null,'moving monster keeps casual sprite and ground shadow')
	for monster_name in ['초원 고블린','들개 무리','가시 멧돼지']:
		var portrait: AtlasTexture=MonsterSpriteFactory.get_casual_portrait_texture(monster_name)
		check(portrait.atlas.resource_path.contains('/meadow-v60/'),'meadow monster uses its four-pose design: '+monster_name)
		var attack_frame: AtlasTexture=preload('res://scripts/portrait/CasualMonsterAtlas.gd').frame(monster_name,2)
		check(attack_frame.region.position.y>0,'meadow monster attack draws the attack pose: '+monster_name)
	var tree: Sprite2D=props.props[0]
	var world: Vector2=tree.get_meta('world_position')
	check(tree.texture!=null and tree.z_index==game._field_actor_depth(tree.position.y),'tree is visible at the depth of its trunk')
	var previous: Vector2=tree.position
	game.combat_camera_position+=Vector2(1,0)
	props.refresh()
	check(absf((tree.position.x-previous.x)+game._combat_map_scale().x)<.1,'tree and actors share camera projection')
	check(tree.position.distance_to(game._map_world_position(world))<.1,'tree stays attached to its world point')
	var hp: int=int(game.enemy_wave[0]['hp'])
	var effects_before: int=game.skill_fx_layer.get_child_count()
	game._damage_enemy(0,hp,0)
	check(int(game.enemy_wave[0]['hp'])==0 and game.skill_fx_layer.get_child_count()>effects_before,'real monster kill triggers a visible reward burst')
	game._build_world_map_screen();await settle()
	check(game.content_root.get_node_or_null('PortraitMeadowProps')==null,'decorations leave with the combat screen')
	game.free()
	print('v60_meadow_presentation ',checks-failures.size(),'/',checks,' pass')
	quit(0 if failures.is_empty() else 1)
