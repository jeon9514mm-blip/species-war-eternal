extends RefCounted
## Presentation owns fonts, projection and density; simulation owns every amount.
const STYLE = preload('res://scripts/combat/CombatNumberStyle.gd')
const POOL = preload('res://scripts/combat/DamageNumberManager.gd')
static func emit(main, amount: int, kind: String, center: Vector2, bounds: Rect2, target: String) -> void:
	if amount <= 0 or not main.combat_effects_enabled or main._application_suspended: return
	if not is_instance_valid(main.content_root): return
	if not is_instance_valid(main._damage_pool):
		main._damage_pool = POOL.new(); main._damage_pool.name = 'DamageNumberPool'
		main.content_root.add_child(main._damage_pool)
	var live: Array = []
	for label in main._damage_pool.pool:
		if is_instance_valid(label) and label.visible: live.append(label)
	var joins := false
	for label in live:
		if label.anchor_key == target and label.kind == kind and Time.get_ticks_msec()-label.burst_started_at <= 120: joins = true; break
	if not joins and live.size() >= int(main._presentation_profile().float_limit):
		live.sort_custom(func(a, b):
			var x: int = STYLE.priority(a.kind); var y: int = STYLE.priority(b.kind)
			return a.issued_at < b.issued_at if x == y else x < y)
		if STYLE.priority(live[0].kind) > STYLE.priority(kind): return
		live[0].retire()
	main._number_lane += 1
	main._damage_pool.spawn_damage('', Color.WHITE, center, kind == 'critical', main._number_lane, bounds, kind, target, amount)
static func hunt(main, data: Dictionary, origin: Vector2) -> void:
	var near_hero: bool = data.kind in ['incoming', 'heal']
	var target_foot := origin + Vector2(90, 78 if near_hero else 60)
	var source: Node2D
	var closest := INF
	var sprites: Array = main.hero_map_sprites if near_hero else main.enemy_wave_sprites
	for actor in sprites:
		if not is_instance_valid(actor): continue
		var distance: float = actor.position.distance_squared_to(target_foot)
		if distance < closest: closest = distance; source = actor
	var center := target_foot - Vector2(0, 38)
	var key := 'unknown:' + str(Vector2i(target_foot / 20))
	if is_instance_valid(source):
		center = source.position - Vector2(0, 36)
		key = str(source.get_instance_id())
	var field: Rect2 = main.combat_field_rect
	var bounds := Rect2(field.position + Vector2(12, 62), field.size - Vector2(24, 82))
	emit(main, int(data.amount), str(data.kind), center, bounds, key)
static func raid(main, amount: int, kind: String, hero_id := '') -> void:
	if not is_instance_valid(main.content_root): return
	var view = main.content_root.get_node_or_null('PortraitRaidView')
	if not is_instance_valid(view) or not is_instance_valid(view.battlefield_3d): return
	var field = view.battlefield_3d
	var point: Vector2 = main.raid_positions.get(hero_id, Vector2.ZERO) if not hero_id.is_empty() else main.raid_boss_position
	var actor: Node2D = view.hero_actors.get(hero_id) if not hero_id.is_empty() else main.raid_boss_sprite
	var height: float = field.actor_world_height(actor, not hero_id.is_empty()) if is_instance_valid(actor) else 2.0
	var offset: Vector2 = view.stage.global_position - main.content_root.global_position
	var center: Vector2 = offset + field.project_world(field.raid_to_world(point)) - Vector2(0, 36)
	if kind in ['damage','critical']:
		field.hunt_overlay.hit(field.raid_to_world(point),field.raid_to_world(point),Color('#ffd700') if kind=='critical' else Color('#d8d5cc'),kind=='critical',height)
		field.contact_feedback(kind=='critical',field.raid_to_world(point),actor)
	var bounds := Rect2(offset + Vector2(12, 62), view.stage.size - Vector2(24, 120))
	emit(main, amount, kind, center, bounds, 'raid:' + (hero_id if not hero_id.is_empty() else 'boss'))
static func legacy(main, message: String, color: Color, origin: Vector2) -> void:
	if not main.combat_effects_enabled or not is_instance_valid(main.content_root):
		return
	var visible_floats: Array = main.get_tree().get_nodes_in_group("floating_combat_text")
	while visible_floats.size() >= 10:
		var oldest: Node = visible_floats.pop_front()
		oldest.remove_from_group("floating_combat_text")
		oldest.queue_free()
	var critical_text := message.begins_with("치명!")
	var font_size := 24 if critical_text else (18 if message.length() < 14 else 16)
	var label: Label = main._label(message.replace(" HP", ""), font_size, color)
	label.add_to_group("floating_combat_text")
	label.position = origin
	label.size = Vector2(190, 34 if critical_text else 28)
	label.pivot_offset = label.size * 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 83 if critical_text else 23
	label.add_theme_color_override("font_outline_color", Color("#171b22"))
	label.add_theme_constant_override("outline_size", 5 if critical_text else 3)
	label.scale = Vector2(1.22, 1.22) if critical_text else Vector2.ONE
	main.content_root.add_child(label)
	var tween: Tween = main.content_root.create_tween().set_parallel(true)
	tween.tween_property(label, "position", origin + Vector2(0, -38 if critical_text else -28), 0.40 if critical_text else 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if critical_text:
		tween.tween_property(label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.28 if critical_text else 0.26).set_delay(0.14 if critical_text else 0.08)
	tween.chain().tween_callback(label.queue_free)
