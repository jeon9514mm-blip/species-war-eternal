extends SceneTree

func _fail(message: String, main = null) -> void:
	push_error(message)
	if is_instance_valid(main):
		main.free()
	quit(1)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.selected_faction = "aurelia"
	main.idle_stage = 15
	main.wallet_gold = 50000
	main.wallet_gems = 500
	main._restore_deployed_heroes(["leonhardt","mira","elisia","kairen","orwin"])
	main._setup_hero_progress(main._hero_roster_for_faction())

	main._build_lobby_screen()
	await process_frame
	if not is_instance_valid(main.content_root.get_node_or_null("StatusDashboard")):
		_fail("V22: 로비 상태 대시보드 생성 실패", main)
		return

	main.hero_roster_filter = "전체"
	main.hero_roster_sort = "등급"
	var all_roster: Array = main._filtered_sorted_roster(main._hero_roster_for_faction())
	if all_roster.size() != 15:
		_fail("V22: 전체 영웅 필터 수량 오류", main)
		return
	main.hero_roster_filter = "탱커"
	var tank_roster: Array = main._filtered_sorted_roster(main._hero_roster_for_faction())
	if tank_roster.is_empty():
		_fail("V22: 탱커 필터 결과 없음", main)
		return
	for hero in tank_roster:
		if main._hero_role_group(str(hero.get("id",""))) != "탱커":
			_fail("V22: 역할 필터에 다른 역할 혼입", main)
			return
	main.hero_roster_filter = "전체"
	main.hero_roster_sort = "레벨"
	var sorted_roster: Array = main._filtered_sorted_roster(main._hero_roster_for_faction())
	if sorted_roster.size() != 15:
		_fail("V22: 레벨 정렬 결과 손실", main)
		return

	main._build_hero_select_screen()
	await process_frame
	if not is_instance_valid(main.content_root.get_node_or_null("StatusDashboard")):
		_fail("V22: 영웅 편성 대시보드 생성 실패", main)
		return

	main._build_combat_screen()
	await process_frame
	if not main.combat_labels.has("combat_state_chip") or not main.combat_labels.has("combat_party_chip") or not main.combat_labels.has("combat_enemy_chip") or not main.combat_labels.has("combat_stage_chip"):
		_fail("V22: 실시간 사냥 HUD 칩 누락", main)
		return
	main._update_hunt_hud()
	if str(main.combat_labels["combat_party_chip"].text).is_empty():
		_fail("V22: 전투 HUD 파티 정보 갱신 실패", main)
		return

	main._build_world_map_screen()
	await process_frame
	if not is_instance_valid(main.content_root.get_node_or_null("StatusDashboard")):
		_fail("V22: 월드맵 대시보드 생성 실패", main)
		return

	main._build_faction_war_screen()
	await process_frame
	var war_screen: WorldWarScreen = null
	for child in main.content_root.get_children():
		if child is WorldWarScreen:
			war_screen = child
			break
	if war_screen == null:
		_fail("V22: 종의전쟁 화면 생성 실패", main)
		return
	if war_screen.war_metric_labels.size() != 4:
		_fail("V22: 종의전쟁 지휘 대시보드 4개 지표 누락", main)
		return
	for key in ["score","territory","logistics","server"]:
		if not war_screen.war_metric_labels.has(key) or str(war_screen.war_metric_labels[key].text).is_empty():
			_fail("V22: 종의전쟁 지표 갱신 실패 %s" % key, main)
			return

	print("v22_ui_upgrade_smoke_test_ok lobby=dashboard heroes=filter_sort combat=chips world=dashboard war=command_dashboard")
	main.free()
	quit(0)
