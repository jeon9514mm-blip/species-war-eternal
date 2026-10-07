extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _init() -> void:
	var director = RoamingHuntDirector.new()
	director.configure(Vector2(3,2), 20260922)
	var enemies = [
		{"archetype":"brute","hp":100},
		{"archetype":"ranged","hp":100},
		{"archetype":"support","hp":100}
	]
	director.spawn_group(enemies)
	if director.enemy_positions.size() != 3:
		_fail("V20: 배회 몬스터 위치 생성 실패")
		return
	var initial_party = director.party_position
	var initial_monster = director.enemy_position(0)
	var started = false
	var engaged = false
	for _step in 300:
		var result = director.advance(0.10, [true,true,true])
		started = started or bool(result.get("encounter_started",false))
		engaged = engaged or bool(result.get("engaged",false))
		if engaged:
			break
	if director.distance_walked <= 0.1 or director.party_position == initial_party:
		_fail("V20: 원정대 자유 순찰 이동 실패")
		return
	if director.enemy_position(0) == initial_monster:
		_fail("V20: 몬스터 배회 이동 실패")
		return
	if not started or not engaged or not director.aggro_active:
		_fail("V20: 감지 → 추격 → 교전 전환 실패")
		return
	var distance_before = director.enemy_distance(1)
	for _step in 10:
		director.advance(0.10, [true,true,true])
	var distance_after = director.enemy_distance(1)
	if distance_after <= 0.0 or distance_before <= 0.0:
		_fail("V20: 실시간 거리 상태 실패")
		return
	director.advance(0.1,[false,false,false])
	if director.aggro_active or director.current_target >= 0:
		_fail("V20: 전멸 후 어그로 해제 실패")
		return
	print("roaming_hunt_director_smoke_test_ok patrol=ok wander=ok aggro=ok chase=ok engage=ok")
	quit(0)
