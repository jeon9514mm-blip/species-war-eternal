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
	main._restore_deployed_heroes(["leonhardt","mira","elisia"])
	main._setup_hero_progress(main._hero_roster_for_faction())
	main._build_combat_screen()
	await process_frame
	var strip = main.content_root.get_node_or_null("CombatTacticalStrip")
	if strip == null:
		_fail("V23: 원정대 전술 HUD 스트립 누락", main)
		return
	var marker = main.combat_labels.get("target_marker")
	if marker == null:
		_fail("V23: 교전 대상 마커 누락", main)
		return
	var actor_layer = main.combat_labels.get("actor_layer")
	var actor_clip = main.combat_labels.get("actor_clip")
	if actor_layer == null or actor_clip == null or marker.get_parent() != actor_layer or not actor_clip.clip_contents:
		_fail("V28: 대상 마커가 전투 필드의 클리핑 계층에 속하지 않음", main)
		return
	var banner = main.content_root.get_node_or_null("CombatDangerBanner")
	if banner == null:
		_fail("V23: 위험 경고 배너 누락", main)
		return
	for hero in main.deployed_heroes:
		var hero_id := str(hero.get("id",""))
		if not main.combat_labels.has("hero_tactical_%s" % hero_id):
			_fail("V23: 영웅 전술 카드 누락 %s" % hero_id, main)
			return
	main.roaming_hunt.aggro_active = true
	main.roaming_hunt.current_target = 0
	main.roaming_hunt.enemy_positions[0] = main._hero_field_position("leonhardt") + Vector2(0.65, 0.0)
	main._update_roaming_enemy_motion(0.0)
	main._update_combat_target_marker()
	if not marker.visible:
		_fail("V23: 어그로 대상 마커 표시 실패", main)
		return
	var visible_position: Vector2 = main.roaming_hunt.enemy_positions[0]
	main.roaming_hunt.enemy_positions[0] = Vector2(0.5, 0.5)
	main._update_roaming_enemy_motion(0.0)
	main._update_combat_target_marker()
	if marker.visible:
		_fail("V28: 화면 밖 적의 대상 마커가 표시됨", main)
		return
	main.roaming_hunt.enemy_positions[0] = visible_position
	main._update_roaming_enemy_motion(0.0)
	var living_hp := int(main.enemy_wave[0]["hp"])
	main.enemy_wave[0]["hp"] = 0
	main._update_combat_target_marker()
	if marker.visible:
		_fail("V28: 사망한 적의 대상 마커가 표시됨", main)
		return
	main.enemy_wave[0]["hp"] = living_hp
	main.roaming_hunt.aggro_active = false
	main._update_combat_target_marker()
	if marker.visible:
		_fail("V28: 비전투 중 대상 마커가 표시됨", main)
		return
	main.roaming_hunt.aggro_active = true
	if not main.enemy_wave.is_empty():
		main.enemy_wave[0]["elite"] = true
		main.enemy_wave[0]["rage_triggered"] = true
		main._update_combat_danger_banner()
		if not banner.visible:
			_fail("V23: 정예 광폭화 경고 표시 실패", main)
			return
	main._update_combat_tactical_strip()
	print("v23_combat_readability_smoke_test_ok tactical_cards=ok target_marker=ok danger_banner=ok")
	main.free()
	quit(0)
