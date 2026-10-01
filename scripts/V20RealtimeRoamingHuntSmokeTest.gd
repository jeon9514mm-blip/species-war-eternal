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
	if main.enemy_wave.is_empty():
		_fail("V20: 필드 진입 시 배회 몬스터 생성 실패",main)
		return
	if main.roaming_hunt.enemy_positions.size() != main.enemy_wave.size():
		_fail("V20: 몬스터 전투 데이터/필드 위치 수 불일치",main)
		return
	var initial_party: Vector2 = main.roaming_hunt.party_position
	var initial_enemy: Vector2 = main.roaming_hunt.enemy_position(0)
	for _step in 120:
		main._advance_auto_hunt(0.10)
	if main.roaming_hunt.distance_walked <= 0.05:
		_fail("V20: 자동사냥 중 원정대가 이동하지 않음",main)
		return
	if main.roaming_hunt.party_position == initial_party and main.roaming_hunt.enemy_position(0) == initial_enemy:
		_fail("V20: 파티/몬스터 모두 고정된 상태",main)
		return
	if main.hunt_ai.target_index >= 0:
		_fail("V20: 실시간 사냥이 고정 스폰 target_index에 다시 의존함",main)
		return
	if main.enemy_wave_sprites.size() != main.enemy_wave.size():
		_fail("V20: 배회 몬스터 스프라이트 수 불일치",main)
		return
	var monster = main.enemy_wave_sprites[0]
	if not monster.has_method("play_walk") or not monster.has_method("set_world_position"):
		_fail("V20: 몬스터 이동 애니메이션/월드좌표 API 누락",main)
		return
	print("v20_realtime_roaming_hunt_smoke_test_ok field=live party=mobile monsters=mobile fixed_nodes=removed")
	main.free()
	quit(0)
