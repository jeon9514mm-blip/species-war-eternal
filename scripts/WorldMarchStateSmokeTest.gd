extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _init() -> void:
	var world = WorldWarState.new()
	world.initialize_new(WorldWarState.FACTION_AURELIA)
	var march = WorldMarchState.new()

	if not world.is_sanctuary(WorldWarState.AURELIA_CAPITAL, WorldWarState.FACTION_AURELIA):
		_fail("V13: 수도 안전지대 판정 실패")
		return
	if world.can_attack_enemy_tile(WorldWarState.FACTION_NOXFERA, WorldWarState.AURELIA_CAPITAL):
		_fail("V13: 적이 수도 안전지대를 공격할 수 있음")
		return

	# Safe-zone ownership creates a friendly route to the first neutral frontier.
	var target = Vector2i(4, 10)
	var plan = march.plan(world, target)
	if plan.is_empty() or int(plan.get("distance", 0)) != 2:
		_fail("V13: 전선 행군 경로 계산 실패")
		return
	var rations_before = world.rations
	if not march.begin(world, target):
		_fail("V13: 행군 시작 실패")
		return
	if world.rations >= rations_before:
		_fail("V13: 군량 소비 실패")
		return
	var result = march.advance(march.duration_seconds + 0.1, world)
	if not bool(result.get("arrived", false)) or not bool(result.get("success", false)):
		_fail("V13: 행군 도착 처리 실패")
		return
	if world.tile_owner(target) != WorldWarState.FACTION_NEUTRAL:
		_fail("V17: 행군 레이어가 권한 승인 전에 중립 소유권을 변경함")
		return
	if not world.apply_march_arrival(target, "capture_neutral"):
		_fail("V17: 권한 호스트의 중립 점령 최종 처리 실패")
		return
	if world.army_position != target or world.tile_owner(target) != WorldWarState.FACTION_AURELIA:
		_fail("V17: 중립 점령 후 소유권/주둔 실패")
		return

	# Active march survives serialization.
	var capital = WorldWarState.AURELIA_CAPITAL
	if not march.begin(world, capital):
		_fail("V13: 수도 귀환 행군 시작 실패")
		return
	var saved = march.export_state()
	var restored = WorldMarchState.new()
	restored.import_state(saved)
	if not restored.active or restored.target != capital or restored.path.size() < 2:
		_fail("V13: 행군 저장 복원 실패")
		return

	print("world_march_state_smoke_test_ok route=ok rations=ok arrival=ok save=ok")
	quit(0)
