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
	main.idle_stage = 8
	main._restore_deployed_heroes(["leonhardt", "mira", "elisia"])
	main._setup_hero_progress(main._hero_roster_for_faction())
	main._build_combat_screen()
	await process_frame
	if main.enemy_wave.is_empty():
		_fail("V25: 적 웨이브 생성 실패", main)
		return
	var p0 := int(main.combat_fx.projectile_sequence)
	main._emit_basic_attack_fx("mira", 0)
	if int(main.combat_fx.projectile_sequence) <= p0:
		_fail("V25: 원거리 실제 투사체 생성 실패", main)
		return
	var a0 := int(main.combat_fx.aoe_sequence)
	main._emit_skill_cast_fx("mira", 0, true, {"kind":"damage"}, false)
	if int(main.combat_fx.aoe_sequence) <= a0:
		_fail("V25: 범위공격 인디케이터 생성 실패", main)
		return
	var b0 := int(main.combat_fx.boss_telegraph_sequence)
	main._emit_boss_telegraph("검증용 광역기", 0.6)
	if int(main.combat_fx.boss_telegraph_sequence) <= b0:
		_fail("V25: 보스 범위 예고 생성 실패", main)
		return
	var d0 := int(main.combat_fx.dodge_sequence)
	main.combat_fx.dodge(main._combat_hero_screen_position("mira"))
	if int(main.combat_fx.dodge_sequence) <= d0:
		_fail("V25: 회피 연출 생성 실패", main)
		return
	var c0 := int(main.combat_fx.camera_sequence)
	main.combat_fx.camera_impact(4.0, 0.12, 0.008)
	if int(main.combat_fx.camera_sequence) <= c0:
		_fail("V25: 전투 카메라 임팩트 생성 실패", main)
		return
	var enemy_sprite = main.enemy_wave_sprites[0]
	var old_modulate: Color = enemy_sprite.modulate
	main._damage_enemy(0, 5, 0)
	if enemy_sprite.modulate == old_modulate:
		_fail("V25: 피격 플래시 적용 실패", main)
		return
	print("v25_combat_fx_smoke_test_ok projectile=ok aoe=ok boss_range=ok hit=ok dodge=ok camera=ok")
	main.free()
	quit(0)
