extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failed = true

func _run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main._offline_checked = true
	main.selected_faction = "aurelia"
	main.idle_stage = 8
	main._restore_deployed_heroes(["leonhardt", "mira", "orwin", "darius", "caelum"])
	main._setup_hero_progress(main._hero_roster_for_faction())
	main.combat_effects_enabled = true
	main._build_combat_screen()
	await process_frame
	var before := int(main.skill_fx_sequence)
	var children := int(main.skill_fx_layer.get_child_count())
	main._emit_skill_fx({}, {"role_group":"딜러", "kind":"damage"}, 104)
	_check(main.skill_fx_sequence == before + 1, "Field skill event must remain recorded")
	_check(main.skill_fx_layer.get_child_count() == children, "Field skill must not emit a second fixed-position banner/flash")
	var projectile_before := int(main.combat_fx.projectile_sequence)
	main._emit_skill_cast_fx("mira", 0, true, {"kind":"damage"})
	_check(main.combat_fx.projectile_sequence == projectile_before, "Removed hero skill must not create a projectile")
	var ring_count := 0
	for child in main.skill_fx_layer.get_children():
		if child.name.to_lower().contains("aoeindicator"):
			ring_count += 1
			_check(child.size.x <= 100.0, "Field indicator obscures small heroes")
			_check(child.get_child_count() == 0, "Field indicator must not carry redundant AOE text")
	_check(ring_count == 0, "Removed hero skill must not create an area effect")
	main._emit_ultimate_cutin("mira", "Long skill explanation")
	main._emit_ultimate_cutin("caelum", "Another ultimate")
	await process_frame
	var notice = main.content_root.get_node_or_null("FieldUltimateNotice")
	_check(notice == null, "Removed ultimate must not create a notice")
	var notices := 0
	for child in main.content_root.get_children():
		if str(child.name).begins_with("FieldUltimateNotice"):
			notices += 1
	_check(notices == 0, "Removed ultimate notices cannot pile up")
	for index in range(14):
		main._spawn_floating_combat_text(str(index), Color.RED, Vector2(500, 300))
	_check(get_nodes_in_group("floating_combat_text").size() == 10, "Damage text must remain bounded")
	await process_frame
	print("v28_field_fx_smoke_test_ok skill_vfx_removed=ok ultimate_removed=ok bounded_damage=ok")
	main.free()
	# AudioServer releases stopped playback on its next mix, not the render frame.
	await create_timer(0.3).timeout
	quit(1 if failed else 0)
