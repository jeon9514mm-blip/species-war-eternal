extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _init() -> void:
	var season = WorldSeasonState.new()
	var start = 100000
	season.ensure_started(start)
	if season.season_id != "S001" or season.phase != "active":
		_fail("V18: 시즌 초기화 실패")
		return
	var neutral_points = season.record_capture(WorldWarState.FACTION_AURELIA, "plain", "p1", false, start + 1)
	var fort_points = season.record_capture(WorldWarState.FACTION_AURELIA, "fort", "p1", true, start + 2)
	if neutral_points != 3 or fort_points != 30:
		_fail("V18: 타일 시즌 점수 규칙 실패")
		return
	if season.score_for(WorldWarState.FACTION_AURELIA) != 33 or season.contribution_for("p1") != 33:
		_fail("V18: 진영/개인 공헌 집계 실패")
		return
	if season.refresh_phase(season.active_end_unix + 1) != "settlement":
		_fail("V18: 시즌 정산 전환 실패")
		return
	if season.record_capture(WorldWarState.FACTION_AURELIA, "citadel", "p1", true, season.active_end_unix + 2) != 0:
		_fail("V18: 정산 중 점령 점수 허용됨")
		return
	season.refresh_phase(season.settlement_end_unix + 1)
	var world = WorldWarState.new()
	world.initialize_new(WorldWarState.FACTION_AURELIA)
	world._set_owner(Vector2i(10,10), WorldWarState.FACTION_AURELIA)
	world.rations = 9999
	world.army_fatigue = 73
	var conflict = WorldConflictState.new()
	var march = WorldMarchState.new()
	if not season.begin_next_season(world, conflict, march, WorldWarState.FACTION_AURELIA, season.settlement_end_unix + 1):
		_fail("V18: 다음 시즌 초기화 실패")
		return
	if season.season_id != "S002" or season.score_for(WorldWarState.FACTION_AURELIA) != 0:
		_fail("V18: 시즌 번호/점수 리셋 실패")
		return
	if world.tile_owner(Vector2i(10,10)) == WorldWarState.FACTION_AURELIA:
		_fail("V18: 시즌 전쟁맵 리셋 실패")
		return
	if world.rations != WorldWarState.STARTING_RATIONS or world.army_fatigue != 0:
		_fail("V18: 시즌 군량/피로 리셋 실패")
		return
	print("world_season_state_smoke_test_ok score=ok settlement=ok rollover=ok")
	quit(0)
