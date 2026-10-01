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
	# This fixture checks combat rules; dedicated FX tests cover presentation.
	# Avoid racing asynchronous AudioServer teardown during parallel test exit.
	main.combat_effects_enabled = false
	main.combat_fx.enabled = false
	# Combat fixture keeps its original stage difficulty with a valid legacy party capacity.
	main.party_slot_legacy_cap = 10
	main.selected_faction = "aurelia"
	main.idle_stage = 30
	main._restore_deployed_heroes(["leonhardt", "mira", "elisia", "kairen", "orwin", "seria", "astel", "darius", "lunea", "caelum"])
	main.party_power = main._calculate_party_power()
	main._setup_hero_skills()

	if main.hero_battle_state.size() != 10:
		_fail("V7: 10인 개별 전투 상태 생성 실패", main)
		return
	if str(main.hero_battle_state["leonhardt"].get("row", "")) != "front":
		_fail("V7: 전열 대형 판정 실패", main)
		return
	if str(main.hero_battle_state["astel"].get("row", "")) != "middle":
		_fail("V7: 중열 대형 판정 실패", main)
		return
	if str(main.hero_battle_state["darius"].get("row", "")) != "rear":
		_fail("V7: 후열 대형 판정 실패", main)
		return

	main._gain_ultimate("mira", 100.0)
	if not main._ultimate_ready("mira"):
		_fail("V7: 궁극기 게이지 준비 판정 실패", main)
		return

	main.party_presets = [[], [], []]
	main._save_party_preset(0)
	main._restore_deployed_heroes(["leonhardt"])
	main._apply_party_preset(0)
	if main.deployed_heroes.size() != 10:
		_fail("V7: 편성 프리셋 복원 실패", main)
		return

	main.battle_speed = 1.0
	main._cycle_battle_speed()
	if main.battle_speed != 2.0:
		_fail("V7: 2배속 전환 실패", main)
		return
	main._cycle_battle_speed()
	if main.battle_speed != 1.0:
		_fail("V7: 3배속 없이 1배속 복귀 실패", main)
		return

	var pet = main._pet_profile()
	if str(pet.get("kind", "")) != "support":
		_fail("V7: 아우렐리아 동료 프로필 실패", main)
		return

	# Raid heal AI must react to one critical hero even when aggregate party HP is high.
	main.active_screen = "raid"
	main.raid_boss_hp = 5000
	main.raid_boss_max_hp = 5000
	main._setup_hero_skills()
	var mira: Dictionary = main.hero_battle_state["mira"]
	mira["hp"] = maxi(1, int(mira["max_hp"] * 0.20))
	main._sync_party_hp_from_heroes()
	main.hero_skill_runtime["elisia"]["remaining"] = 0.0
	if not main._should_use_skill("elisia"):
		_fail("V7: 레이드 위기 영웅 힐 판단 실패", main)
		return
	var before_heal = int(mira["hp"])
	main._cast_hero_skill("elisia")
	if int(main.hero_battle_state["mira"]["hp"]) <= before_heal:
		_fail("V7: 레이드 개별 힐 적용 실패", main)
		return

	# Enemy stun is an action lock, not a global immunity inside the damage helper.
	main._stun_seconds = 1.0
	var before_damage = int(main.hero_battle_state["leonhardt"]["hp"])
	main._incoming_damage_to_hero("leonhardt", 80)
	if int(main.hero_battle_state["leonhardt"]["hp"]) >= before_damage:
		_fail("V7: 피격 함수가 적 기절 상태에 잘못 종속됨", main)
		return

	# Front-line melee must not skip a living front-row enemy to hit the rear row.
	main.enemy_wave = [
		{"hp": 100, "max_hp": 100, "attack": 10, "row": 0, "archetype": "brute"},
		{"hp": 20, "max_hp": 100, "attack": 30, "row": 2, "archetype": "ranged"}
	]
	if main._select_enemy_target("leonhardt") != 0:
		_fail("V7: 근접 영웅 사거리/전열 우선 판정 실패", main)
		return

	# Assassin AI should prefer a living support hero when no taunt is active.
	for hero_id in main.hero_battle_state.keys():
		main.hero_battle_state[hero_id]["taunt"] = 0.0
	main.enemy_wave = [{"hp": 100, "max_hp": 100, "attack": 10, "row": 1, "archetype": "assassin"}]
	var assassin_target = main._select_hero_target_for_enemy(0)
	if str(main.hero_battle_state[assassin_target].get("role_group", "")) != "서포터":
		_fail("V7: 암살형 몬스터의 서포터 우선 타깃 실패", main)
		return

	# Taunt must override monster role targeting.
	main.hero_battle_state["leonhardt"]["taunt"] = 2.0
	if main._select_hero_target_for_enemy(0) != "leonhardt":
		_fail("V7: 도발 우선 타깃 실패", main)
		return

	# Noxfera companion keeps its lifesteal-style party sustain in raid too.
	# Combat fixture keeps its original stage difficulty with a valid legacy party capacity.
	main.party_slot_legacy_cap = 10
	main.selected_faction = "noxfera"
	main._setup_pet_runtime()
	main.hero_battle_state["mira"]["hp"] = maxi(1, int(main.hero_battle_state["mira"]["max_hp"] * 0.35))
	var before_pet_heal = int(main.hero_battle_state["mira"]["hp"])
	main.pet_runtime["remaining"] = 0.0
	var pet_damage = main._advance_raid_pet(1.0)
	if pet_damage <= 0 or int(main.hero_battle_state["mira"]["hp"]) <= before_pet_heal:
		_fail("V7: 녹스페라 동료 레이드 흡혈 지원 실패", main)
		return

	print("v7_systems_smoke_test_ok heroes=10 presets=3 speed=x1/x2/x3 raid_heal=ok range=ok ai=ok pets=ok")
	main.free()
	# AudioServer releases stopped playback on its next mix, not the render frame.
	await create_timer(0.3).timeout
	quit(0)
