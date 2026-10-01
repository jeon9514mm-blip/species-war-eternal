extends SceneTree

func _fail(message: String, main = null) -> void:
	push_error(message)
	if is_instance_valid(main):
		main.free()
	quit(1)

func _init() -> void:
	var nav = AutoHuntController.new()
	nav.configure([Vector2(6,4)], Vector2(0,0))
	if not nav.acquire_target():
		_fail("V17: 사냥 타깃 획득 실패")
		return
	var failure_before = nav.failures[0]
	nav.retreat_target()
	if nav.failures[0] != failure_before:
		_fail("V17: 체력 회복 후퇴가 길찾기 실패로 누적됨")
		return
	nav.advance_time(AutoHuntController.MAX_MOVEMENT_SECONDS + 0.1)
	nav.acquire_target()
	nav.advance_time(AutoHuntController.MAX_MOVEMENT_SECONDS + 0.1)
	nav.advance_movement(0.01)
	if nav.state != AutoHuntController.State.SEARCHING:
		_fail("V17: 장시간 이동 정체 자동 재탐색 실패")
		return

	var main = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.selected_faction = "aurelia"
	main.party_slot_legacy_cap = 0
	main.idle_stage = 1
	if main._party_slot_cap() != 1:
		_fail("V17: 신규 원정대 1인 시작 한도 실패", main)
		return
	main.idle_stage = 3
	if main._party_slot_cap() != 3:
		_fail("V17: 3인 원정대 확장 실패", main)
		return
	main.idle_stage = 8
	if main._party_slot_cap() != 5:
		_fail("V17: 5인 원정대 확장 실패", main)
		return
	main.idle_stage = 15
	if main._party_slot_cap() != 7:
		_fail("V17: 7인 원정대 확장 실패", main)
		return
	main.idle_stage = 25
	if main._party_slot_cap() != 10:
		_fail("V17: 10인 원정대 확장 실패", main)
		return
	main.idle_stage = 1
	main.party_slot_legacy_cap = 3
	if main._party_slot_cap() != 3:
		_fail("V17: 기존 v16 3인 편성 마이그레이션 보호 실패", main)
		return
	print("v17_hunt_progression_smoke_test_ok retreat=ok stuck=ok party_caps=1-3-5-7-10 legacy=ok")
	main.free()
	quit(0)
