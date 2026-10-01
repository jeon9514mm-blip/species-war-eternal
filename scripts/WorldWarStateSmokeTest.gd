extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _init() -> void:
	var world = WorldWarState.new()
	world.initialize_new(WorldWarState.FACTION_AURELIA)
	if world.cells.size() != WorldWarState.WIDTH * WorldWarState.HEIGHT:
		_fail("V12: 40x40 월드맵 생성 실패")
		return
	if world.tile_owner(Vector2i(1, 10)) != WorldWarState.FACTION_AURELIA:
		_fail("V12: 아우렐리아 수도 소유권 실패")
		return
	if world.tile_owner(Vector2i(18, 10)) != WorldWarState.FACTION_NOXFERA:
		_fail("V12: 녹스페라 수도 소유권 실패")
		return
	if world.tile_type(Vector2i(9, 9)) != "citadel":
		_fail("V12: 중앙 대성 배치 실패")
		return
	var safe_step = Vector2i(3, 10)
	if not world.move_army(safe_step):
		_fail("V13 regression: 안전지대 내부 이동 실패")
		return
	var frontier = Vector2i(4, 10)
	if not world.can_capture_neutral(frontier):
		_fail("V12: 시작 전선 인접 중립 타일 점령 판정 실패")
		return
	if not world.capture_neutral(frontier):
		_fail("V12: 중립 타일 점령 실패")
		return
	if world.tile_owner(frontier) != WorldWarState.FACTION_AURELIA or world.army_position != frontier:
		_fail("V12: 점령 후 소유권/부대 위치 갱신 실패")
		return
	var exported = world.export_state()
	var restored = WorldWarState.new()
	restored.import_state(exported)
	if not restored.initialized or restored.cells.size() != WorldWarState.WIDTH * WorldWarState.HEIGHT:
		_fail("V12: 월드맵 저장 복원 실패")
		return
	if restored.army_position != frontier or restored.tile_owner(frontier) != WorldWarState.FACTION_AURELIA:
		_fail("V12: 점령 상태 저장 복원 실패")
		return
	if restored.tile_type(Vector2i(4, 5)) != "mine" or restored.tile_type(Vector2i(15, 5)) != "forest_resource":
		_fail("V12: 대칭 자원지 배치 실패")
		return
	print("world_war_state_smoke_test_ok tiles=1600 capture=ok save=ok landmarks=ok")
	quit(0)
