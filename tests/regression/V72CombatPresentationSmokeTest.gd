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
	main.combat_effects_enabled = true
	main.selected_faction = "aurelia"
	main.idle_stage = 9
	main._restore_deployed_heroes(["leonhardt", "mira", "elisia", "kairen"])
	main._setup_hero_progress(main._hero_roster_for_faction())
	main._build_combat_screen()
	await process_frame
	for key in ["field_state_chip", "field_party_chip", "field_enemy_chip", "field_stage_chip"]:
		if not is_instance_valid(main.combat_labels.get(key)):
			_fail("V72: 필드 HUD 누락: " + key, main)
			return
	if main.enemy_wave.is_empty():
		_fail("V72: 적 웨이브 생성 실패", main)
		return
	var spark_before := int(main.combat_fx.hit_spark_sequence)
	main._emit_basic_attack_fx("leonhardt", 0)
	if int(main.combat_fx.hit_spark_sequence) <= spark_before:
		_fail("V72: 근접 평타 스파크 생성 실패", main)
		return
	var death_before := int(main.combat_fx.death_burst_sequence)
	main._damage_enemy(0, int(main.enemy_wave[0]["hp"]), 0)
	if int(main.combat_fx.death_burst_sequence) <= death_before:
		_fail("V72: 몬스터 사망 버스트 생성 실패", main)
		return
	var loot_before := int(main.combat_fx.loot_burst_sequence)
	main.combat_fx.loot_burst(main.combat_field_rect.position + Vector2(260, 180), 120, 45, 1, true)
	if int(main.combat_fx.loot_burst_sequence) <= loot_before:
		_fail("V72: 보상 버스트 생성 실패", main)
		return
	var boss_before := int(main.combat_fx.boss_arrival_sequence)
	main.combat_fx.boss_arrival(main.combat_field_rect.position + Vector2(420, 180), Color("#ffb84d"))
	if int(main.combat_fx.boss_arrival_sequence) <= boss_before:
		_fail("V72: 보스 등장 임팩트 생성 실패", main)
		return
	print("V72CombatPresentationSmokeTest: hud=ok melee=ok death=ok loot=ok boss=ok")
	main.free()
	quit(0)
