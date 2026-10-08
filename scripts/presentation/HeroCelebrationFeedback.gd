extends Node
## Real level changes plus rare decorative glints use a separate visual RNG.
var game: Node
var levels: Dictionary={}
var elapsed:=0.0
var glint_elapsed:=0.0
var visual_rng:=RandomNumberGenerator.new()
func bind(host: Node) -> void:
	game=host;visual_rng.seed=2026100801
	for id in game.hero_progress:levels[id]=int(game.hero_progress[id].get('level',1))
func _process(delta: float) -> void:
	if not is_instance_valid(game):return
	elapsed+=maxf(0,delta)
	if elapsed<.25:return
	var interval:=elapsed;elapsed=0
	var changed: Array[String]=[]
	for id in game.hero_progress:
		var level: int=int(game.hero_progress[id].get('level',1))
		if levels.has(id) and level>int(levels[id]):changed.append(str(id))
		levels[id]=level
	if not game.combat_effects_enabled or game._application_suspended:return
	var field: Control
	if game.active_screen=='combat':field=game.combat_labels.get('terrain')
	elif game.active_screen=='raid' and is_instance_valid(game.content_root):
		var view=game.content_root.get_node_or_null('PortraitRaidView')
		if is_instance_valid(view):field=view.battlefield_3d
	if not is_instance_valid(field) or not field.battle_clock_running():return
	glint_elapsed+=interval
	var deployed: Array=game._deployed_hero_ids()
	for id in changed:
		if id in deployed:_emit(field,id,true)
	if glint_elapsed>=4.0:
		glint_elapsed=0
		for id in game._alive_hero_ids():
			if visual_rng.randf()<.01:_emit(field,id,false)
func _emit(field: Control,id: String,level_up: bool) -> void:
	var point: Vector2
	if field.raid_mode:point=field.raid_to_world(game.raid_positions.get(id,Vector2.ZERO))
	else:
		point=game._hero_field_position(id)
		var index: int=game._deployed_hero_ids().find(id)
		if index>=0 and index<game.hero_map_sprites.size():point=field.display_world(game.hero_map_sprites[index],point)
	field.hunt_overlay.celebrate(point,level_up)
