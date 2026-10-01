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
	main._restore_deployed_heroes(["leonhardt", "mira", "elisia"])
	main._setup_hero_progress(main._hero_roster_for_faction())
	main._setup_hero_skills()
	main._emit_v11_skill_signature(Vector2(640, 360), {"kind":"heal"}, Color("#71d7a1"))

	# Zone identities must create meaningfully different encounters.
	var zones: Dictionary = main._zone_data()
	if zones["gray_meadow"]["wave_pattern"] == zones["forgotten_mine"]["wave_pattern"]:
		_fail("V11: 지역별 웨이브 패턴 차별화 실패", main)
		return
	if str(main._boss_pattern_profile("forgotten_mine")["kind"]) == str(main._boss_pattern_profile("moonrest_forest")["kind"]):
		_fail("V11: 지역 보스 패턴 차별화 실패", main)
		return

	# Hero rarity/ascension.
	main.hero_progress["leonhardt"] = {"level": 30, "xp": 0}
	main.wallet_gold = 10000
	var grade_before = main._hero_grade("leonhardt")
	if not main._try_ascend_hero("leonhardt"):
		_fail("V11: 영웅 승급 실패", main)
		return
	if grade_before == main._hero_grade("leonhardt"):
		_fail("V11: 영웅 등급 변경 실패", main)
		return

	# Equipment set bonus + set preservation when equipping.
	main.hero_equipment_sets["leonhardt"] = {"weapon":"강철", "armor":"강철", "accessory":"강철"}
	var set_profile: Dictionary = main._equipment_set_profile("leonhardt")
	if float(set_profile["hp_mult"]) <= 1.0 or int(set_profile["defense_bonus"]) < 5:
		_fail("V11: 강철 세트 효과 실패", main)
		return
	main.loot_inventory = [{"name":"월광 테스트 검", "slot":"weapon", "rarity":"희귀", "level":2, "power":90, "set":"월광"}]
	if not main._equip_item_direct(0, "leonhardt"):
		_fail("V11: 세트 장비 장착 실패", main)
		return
	if str(main._get_hero_equipment_sets("leonhardt")["weapon"]) != "월광":
		_fail("V11: 장비 세트 정보 보존 실패", main)
		return

	# Weekly content.
	for hero in main.deployed_heroes:
		main.hero_progress[str(hero["id"])] = {"level": 50, "xp": 0}
	main.weekly_content_key = main._week_key()
	main.weekly_trial_runs = 0
	main.weekly_trial_best = 0
	if not main._run_weekly_trial():
		_fail("V11: 주간 심연 진행 실패", main)
		return
	var weekly_ticks: int = 0
	while main.challenge_session != null and weekly_ticks < 2800:
		main._advance_auto_hunt(1.0 / 30.0)
		weekly_ticks += 1
		if weekly_ticks % 30 == 0: await process_frame
	if main.weekly_trial_runs != 1 or main.weekly_trial_best <= 0:
		_fail("V11: 주간 심연 기록 실패", main)
		return

	# Automatic quest tracking.
	main.quest_claimed.clear()
	main.tracked_quest_id = ""
	main.idle_stage = 1
	main._auto_track_quest()
	if main.tracked_quest_id != "stage5":
		_fail("V11: 첫 퀘스트 자동추적 실패", main)
		return
	main.idle_stage = 5
	if not bool(main._quest_status("stage5")["complete"]):
		_fail("V11: 퀘스트 진행도 판정 실패", main)
		return

	# Onboarding should advance from faction/party setup to first hunt.
	main.tutorial_completed = false
	main.tutorial_step = 0
	main.idle_stage = 1
	main.idle_stage_kills = 0
	main.combat_kills = 0
	main._refresh_tutorial_state()
	if main.tutorial_step != 2:
		_fail("V11: 초반 온보딩 단계 판정 실패", main)
		return

	print("v11_progression_smoke_test_ok patterns=ok ascension=ok sets=ok weekly=ok tracking=ok onboarding=ok")
	main.free()
	quit(0)
