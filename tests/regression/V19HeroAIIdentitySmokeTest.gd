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
	# Keep this combat fixture at its original difficulty with valid legacy capacity.
	main.party_slot_legacy_cap = 10
	main.selected_faction = "aurelia"
	main._restore_deployed_heroes(["leonhardt","mira","elisia"])
	main._setup_hero_progress(main._hero_roster_for_faction())
	main._setup_hero_skills()
	if str(main.hero_battle_state["leonhardt"].get("ai_style","")) != "protector":
		_fail("V19: 레온하르트 수호 AI 정체성 미적용", main)
		return
	if str(main.hero_battle_state["mira"].get("ai_style","")) != "finisher":
		_fail("V19: 미라 처형 AI 정체성 미적용", main)
		return
	var leon_hp = int(main.hero_battle_state["leonhardt"]["max_hp"])
	var mira_hp = int(main.hero_battle_state["mira"]["max_hp"])
	if leon_hp <= mira_hp:
		_fail("V19: 탱커/사수 생존력 특징 구분 실패", main)
		return
	var before = float(main.hero_battle_state["elisia"]["ultimate"])
	main._gain_ultimate("elisia",10.0)
	if float(main.hero_battle_state["elisia"]["ultimate"]) <= before + 10.0:
		_fail("V19: 엘리시아 궁극기 충전 특성 미적용", main)
		return
	var world_snapshot = main._world_party_snapshot()
	if world_snapshot.is_empty() or not world_snapshot[0].has("identity"):
		_fail("V19: 종의전쟁 스냅샷에 영웅 정체성 누락", main)
		return
	print("v19_hero_ai_identity_smoke_test_ok ai_styles=ok stat_identity=ok ult_gain=ok world_snapshot=ok")
	main.free()
	quit(0)
