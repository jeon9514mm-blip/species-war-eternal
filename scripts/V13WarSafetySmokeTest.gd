extends SceneTree

func _fail(message: String, main = null) -> void:
	push_error(message)
	if is_instance_valid(main):
		main.free()
	quit(1)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var world = WorldWarState.new()
	world.initialize_new(WorldWarState.FACTION_AURELIA)

	# Artificially push Aurelia back to validate the comeback system.
	for y in WorldWarState.HEIGHT:
		for x in range(7, WorldWarState.WIDTH):
			var pos = Vector2i(x, y)
			if world.sanctuary_owner(pos) == WorldWarState.FACTION_NEUTRAL:
				world._set_owner(pos, WorldWarState.FACTION_NOXFERA)
	var fallback_tile = Vector2i(5, 10)
	world._set_owner(fallback_tile, WorldWarState.FACTION_AURELIA)
	var buff = world.faction_balance_buff(WorldWarState.FACTION_AURELIA)
	if int(buff.get("tier", 0)) < 2:
		_fail("V13: 열세 진영 저항 버프 발동 실패")
		return
	if float(buff.get("march_speed_multiplier", 1.0)) <= 1.0:
		_fail("V13: 열세 진영 행군 속도 버프 실패")
		return
	if float(buff.get("ration_cost_multiplier", 1.0)) >= 1.0:
		_fail("V13: 열세 진영 군량 할인 실패")
		return
	if not world.is_emergency_protected(fallback_tile, WorldWarState.FACTION_AURELIA):
		_fail("V13: 최후 방어선 확장 실패")
		return
	if world.can_attack_enemy_tile(WorldWarState.FACTION_NOXFERA, fallback_tile):
		_fail("V13: 최후 방어선 침범 차단 실패")
		return

	var scene = preload("res://scenes/Main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.selected_faction = "aurelia"
	main._restore_deployed_heroes(["leonhardt"])
	main._setup_hero_progress(main._hero_roster_for_faction())
	main._build_faction_war_screen()
	await process_frame
	if main.active_screen != "faction_war":
		_fail("V13: 종의전쟁 화면 진입 실패", main)
		return
	var war_screen: WorldWarScreen = null
	for child in main.content_root.get_children():
		if child is WorldWarScreen:
			war_screen = child
			break
	if war_screen == null or war_screen.march_state != main.faction_march_state:
		_fail("V13: 행군 상태 UI 연결 실패", main)
		return
	if main.faction_war_state.rations <= 0:
		_fail("V13: 군량 초기화 실패", main)
		return

	print("v13_war_safety_smoke_test_ok sanctuary=ok comeback=ok defense=ok ui=ok")
	main.free()
	quit(0)
