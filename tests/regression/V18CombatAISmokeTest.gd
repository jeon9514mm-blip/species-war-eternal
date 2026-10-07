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
	# Combat fixture keeps its original stage difficulty with a valid legacy party capacity.
	main.party_slot_legacy_cap = 10
	main.selected_faction = "aurelia"
	main._restore_deployed_heroes(["leonhardt","mira","elisia"])
	main._setup_hero_progress(main._hero_roster_for_faction())
	main._setup_hero_battle_state()
	main._setup_hero_skills()
	main.active_screen = "combat"
	main.enemy_wave = [
		{"name":"일반 전열","hp":500,"max_hp":500,"attack":20,"row":0,"archetype":"brute","elite":false}
	]
	main.hero_skill_runtime["leonhardt"]["remaining"] = 0.0
	if main._should_use_skill("leonhardt"):
		_fail("V18: 일반 잡몹 1기에 탱커 방어기 과소비", main)
		return
	main.enemy_wave = [
		{"name":"일반 전열","hp":500,"max_hp":500,"attack":20,"row":0,"archetype":"brute","elite":false},
		{"name":"정예 지원","hp":600,"max_hp":600,"attack":30,"row":1,"archetype":"support","elite":true}
	]
	var target = main._select_enemy_target("mira")
	if target != 1:
		_fail("V18: 딜러가 도달 가능한 정예 지원을 우선하지 않음", main)
		return
	if not main._should_use_skill("leonhardt"):
		_fail("V19 regression: 수호 AI가 정예 다수전에서 방어기를 보존함", main)
		return
	main.active_screen = "raid"
	main.raid_boss_hp = 5000
	main.raid_boss_max_hp = 5000
	main.boss_telegraph_pending = true
	main.boss_telegraph_remaining = 0.8
	if not main._should_use_skill("leonhardt"):
		_fail("V18: 레이드 위험 예고에서 탱커 방어기 미사용", main)
		return

	main.hero_battle_state["elisia"]["ultimate"] = 100.0
	for hero_id in main.hero_battle_state.keys():
		var state: Dictionary = main.hero_battle_state[hero_id]
		state["hp"] = state["max_hp"]
	if main._should_use_ultimate("elisia"):
		_fail("V18: 전원 만피에서 힐러 궁극기 낭비", main)
		return
	var tank: Dictionary = main.hero_battle_state["leonhardt"]
	tank["hp"] = int(tank["max_hp"] * 0.35)
	if not main._should_use_ultimate("elisia"):
		_fail("V18: 위기 체력에서 힐러 궁극기 미사용", main)
		return

	print("v18_combat_ai_smoke_test_ok elite_target=ok guard_hold=ok telegraph=ok support_ultimate=ok")
	main.free()
	quit(0)
