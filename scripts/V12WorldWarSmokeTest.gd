extends SceneTree

func _fail(message: String, main) -> void:
	push_error(message)
	if is_instance_valid(main):
		main.free()
	quit(1)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
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
		_fail("V12: 종의전쟁 화면 진입 실패", main)
		return
	if not main.faction_war_state.initialized or main.faction_war_state.cells.size() != WorldWarState.WIDTH * WorldWarState.HEIGHT:
		_fail("V12: Main 월드전 상태 초기화 실패", main)
		return
	var war_screen: WorldWarScreen = null
	for child in main.content_root.get_children():
		if child is WorldWarScreen:
			war_screen = child
			break
	if war_screen == null:
		_fail("V12: WorldWarScreen 생성 실패", main)
		return
	if main.content_root.get_node_or_null("BottomNav") == null:
		_fail("V12: 종의전쟁 하단 내비게이션 실패", main)
		return
	var safe_step = Vector2i(3, 10)
	if not main.faction_war_state.move_army(safe_step):
		_fail("V13 regression: Main 안전지대 내부 이동 실패", main)
		return
	var target = Vector2i(4, 10)
	if not main.faction_war_state.capture_neutral(target):
		_fail("V12: Main 연결 상태 중립 점령 실패", main)
		return
	var saved = main.faction_war_state.export_state()
	if str(saved.get("faction", "")) != "aurelia" or int(saved.get("captured_count", 0)) != 1:
		_fail("V12: Main 저장용 전쟁 상태 export 실패", main)
		return
	print("v12_world_war_smoke_test_ok screen=ok nav=ok capture=ok export=ok")
	main.free()
	quit(0)
