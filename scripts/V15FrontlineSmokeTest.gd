extends SceneTree

func _fail(message: String, main = null) -> void:
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
	main._restore_deployed_heroes(["leonhardt", "mira", "elisia"])
	main._setup_hero_progress(main._hero_roster_for_faction())
	main._build_faction_war_screen()
	await process_frame

	var war_screen: WorldWarScreen = null
	for child in main.content_root.get_children():
		if child is WorldWarScreen:
			war_screen = child
			break
	if war_screen == null:
		_fail("V15: 종의전쟁 화면 생성 실패", main)
		return
	if war_screen.conflict_state != main.faction_conflict_state:
		_fail("V15: 다중 전선 상태 Main 연결 실패", main)
		return
	if war_screen.supply_network == null:
		_fail("V15: 보급망 모듈 연결 실패", main)
		return
	if war_screen.support_button == null or war_screen.rally_button == null:
		_fail("V15: 지원/집결 UI 생성 실패", main)
		return

	main.faction_war_state.army_fatigue = WorldWarState.COMBAT_FATIGUE_LIMIT
	if main.faction_war_state.can_launch_combat():
		_fail("V15: 피로도 공격 제한 실패", main)
		return
	main.faction_war_state.recover_fatigue(35)
	if not main.faction_war_state.can_launch_combat():
		_fail("V15: 피로 회복 후 공격 해제 실패", main)
		return

	var exported = main.faction_conflict_state.export_state()
	var restored = WorldConflictState.new()
	restored.import_state(exported)
	if restored.contribution_points != main.faction_conflict_state.contribution_points:
		_fail("V15: 전선 상태 저장 복원 실패", main)
		return

	print("v15_frontline_smoke_test_ok ui=ok supply=ok conflict_save=ok")
	main.free()
	quit(0)
