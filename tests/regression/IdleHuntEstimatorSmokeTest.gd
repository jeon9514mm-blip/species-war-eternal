extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _init() -> void:
	var estimator = IdleHuntEstimator.new()
	var zone = {"power": 180, "difficulty": 1, "gold": 35, "xp": 22}
	var weak = estimator.estimate(3600, 90, 1, zone, 1, 0, 10)
	var strong = estimator.estimate(3600, 900, 5, zone, 1, 0, 10)
	if int(weak.get("kills", 0)) <= 0:
		_fail("V17: 약한 1인 파티 오프라인 진행이 0으로 고정됨")
		return
	if int(strong.get("kills", 0)) <= int(weak.get("kills", 0)):
		_fail("V17: 파티 전투력/인원 증가가 오프라인 효율에 반영되지 않음")
		return
	if int(strong.get("stage_clears", 0)) > IdleHuntEstimator.MAX_OFFLINE_STAGE_CLEARS:
		_fail("V17: 오프라인 스테이지 자동 진행 상한 실패")
		return
	if int(strong.get("gear_rolls", 0)) > IdleHuntEstimator.MAX_OFFLINE_GEAR_ROLLS:
		_fail("V17: 오프라인 장비 롤 성능 상한 실패")
		return
	if int(strong.get("rations", 0)) <= 0 or int(strong.get("gold", 0)) <= 0:
		_fail("V17: 오프라인 군량/재화 계산 실패")
		return
	var empty = estimator.estimate(3600, 500, 0, zone, 1, 0, 10)
	if int(empty.get("kills", 0)) != 0:
		_fail("V17: 빈 파티가 오프라인 사냥 보상을 생성함")
		return
	print("idle_hunt_estimator_smoke_test_ok scaling=ok stage_cap=ok loot_cap=ok empty_party=ok")
	quit(0)
