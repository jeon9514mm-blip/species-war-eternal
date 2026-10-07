extends SceneTree

func _fail(message: String, main) -> void:
	push_error(message)
	if is_instance_valid(main):
		main.free()
	quit(1)

func _equipment_level_sum(main) -> int:
	var total = 0
	for hero in main.deployed_heroes:
		var equipment: Dictionary = main._get_hero_equipment(str(hero["id"]))
		total += int(equipment["weapon"]) + int(equipment["armor"]) + int(equipment["accessory"])
	return total

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene = preload("res://scenes/Main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.selected_faction = "aurelia"
	main.idle_stage = 8
	main.wallet_gems = 1000
	main.wallet_gold = 1000000
	main._restore_deployed_heroes(["leonhardt", "mira", "elisia"])
	main._setup_hero_progress(main._hero_roster_for_faction())
	main._setup_hero_skills()

	main._build_lobby_screen()
	await process_frame
	if not is_instance_valid(main.content_root.get_node_or_null("BottomNav")):
		_fail("V10: 로비 하단 내비게이션 생성 실패", main)
		return

	main._build_world_map_screen()
	await process_frame
	if main.active_screen != "world_map":
		_fail("V10: 월드맵 화면 전환 실패", main)
		return

	main._build_hero_detail_screen("mira")
	await process_frame
	if main.active_screen != "hero_detail":
		_fail("V10: 영웅 상세 화면 전환 실패", main)
		return

	main._build_codex_screen()
	await process_frame
	if main.active_screen != "codex":
		_fail("V10: 영웅 도감 화면 전환 실패", main)
		return

	main.loot_inventory = [{"name":"검증용 전설검", "slot":"weapon", "rarity":"전설", "level":5, "power":242}]
	var before_power = main._calculate_party_power()
	main._recommend_equip_all()
	await process_frame
	if main._calculate_party_power() <= before_power:
		_fail("V10: 추천장착 전투력 상승 실패", main)
		return

	var before_levels = _equipment_level_sum(main)
	main.wallet_gold = 1000000
	main._bulk_enhance_equipped()
	await process_frame
	if _equipment_level_sum(main) <= before_levels:
		_fail("V10: 장착장비 일괄강화 실패", main)
		return

	var summon = main._summon_once()
	if summon.is_empty():
		_fail("V10: 소환 결과 생성 실패", main)
		return
	main._show_summon_reveal(summon)
	await process_frame
	if not is_instance_valid(main.content_root.get_node_or_null("SummonRevealPanel")):
		_fail("V10: 소환 결과 연출 생성 실패", main)
		return

	main.quest_claimed.clear()
	main.idle_stage = 8
	if main._quest_ready_count() < 1:
		_fail("V10: 퀘스트 알림 배지 계산 실패", main)
		return

	main.auto_salvage_min_rarity = "희귀"
	main.loot_inventory.clear()
	var old_gold = main.wallet_gold
	var result: String = main._store_or_salvage_loot({"name":"일반 검", "slot":"weapon", "rarity":"일반", "level":1, "power":22})
	if not main.loot_inventory.is_empty() or main.wallet_gold <= old_gold or not "자동 분해" in result:
		_fail("V10: 한국어 장비 등급 자동분해 실패", main)
		return

	print("v10_ui_ux_smoke_test_ok nav=ok world=ok detail=ok codex=ok equip=ok summon_fx=ok badges=ok salvage=ok")
	main.free()
	quit(0)
