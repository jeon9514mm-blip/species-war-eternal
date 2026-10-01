extends SceneTree

func _fail(message: String, main) -> void:
	push_error(message)
	if is_instance_valid(main): main.free()
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
	main.idle_stage = 30
	main._restore_deployed_heroes(["leonhardt", "mira", "elisia", "kairen", "orwin", "seria", "astel", "darius", "lunea", "caelum"])
	main._setup_hero_progress(main._hero_roster_for_faction())
	main._setup_hero_skills()
	main.hero_progress["mira"] = {"level": 10, "xp": 0}
	main.hero_skill_tree["mira"] = {"offense": 0, "survival": 0, "utility": 0}
	if main._skill_tree_total_points("mira") != 3:
		_fail("V8: 레벨 기반 스킬 포인트 계산 실패", main); return
	var power_before = main._calculate_party_power()
	main._upgrade_skill_tree("mira", "offense")
	if int(main._get_skill_tree("mira").get("offense", 0)) != 1 or main._calculate_party_power() <= power_before:
		_fail("V8: 스킬트리 투자/전투력 반영 실패", main); return
	main.pet_progress.clear()
	main._grant_pet_xp(5000)
	var pet_after = main._get_pet_progress()
	if int(pet_after.get("level", 1)) <= 1 or int(pet_after.get("evolution", 0)) < 1:
		_fail("V8: 동료 성장/진화 실패", main); return
	main.combat_effects_enabled = true
	main._emit_ultimate_cutin("mira", "테스트 궁극기")
	main._emit_boss_telegraph("테스트 광역기", 1.2)
	main._show_battle_result_popup("STAGE CLEAR", "테스트 스테이지", "골드 +10 · 경험치 +10", Color("#d7b25d"))
	await process_frame
	if not is_instance_valid(main.content_root.get_node_or_null("BattleResultPopup")):
		_fail("V8: 전투 결과 팝업 생성 실패", main); return
	print("v8_polish_smoke_test_ok skill_tree=ok pet_growth=ok cutin=ok telegraph=ok result=ok")
	main.free()
	quit(0)
