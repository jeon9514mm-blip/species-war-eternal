extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _unit(i: int) -> Dictionary:
	return {"id":"u%d"%i,"name":"U%d"%i,"role":"딜러","row":"중열","max_hp":800,"hp":800,"attack":120,"defense":20}

func _init() -> void:
	var world = WorldWarState.new()
	world.initialize_new(WorldWarState.FACTION_AURELIA)
	var march = WorldMarchState.new()
	var conflict = WorldConflictState.new()
	var season = WorldSeasonState.new()
	var authority = WorldAuthorityService.new()
	authority.bind_season(season)
	season.ensure_started(authority.server_now())
	var squad: Array = []
	for i in 3:
		squad.append(_unit(i))
	authority.register_trusted_party("local_player",WorldWarState.FACTION_AURELIA,squad,1800)
	# A huge client delta must not fast-forward a server-authoritative march.
	var march_command = {
		"id":"delta_guard",
		"type":"march",
		"player_id":"local_player",
		"faction":WorldWarState.FACTION_AURELIA,
		"target":[4,10],
		"issued_at":authority.server_now(),
		"expected_revision":authority.last_revision
	}
	var march_start = authority.submit_command(world,march,conflict,WorldSupplyNetwork.new(),march_command)
	if not bool(march_start.get("accepted",false)) or not march.active:
		_fail("V18: 서버시간 행군 시작 실패")
		return
	var before_progress = march.progress_ratio()
	var fake_fast_forward = authority.advance_march(world,march,conflict,WorldSupplyNetwork.new(),WorldBattleResolver.new(),"local_player",9999.0)
	if str(fake_fast_forward.get("event","")) == "arrival_completed" or march.progress_ratio() > before_progress + 0.05:
		_fail("V18: 클라이언트 delta로 행군 가속 가능")
		return
	# Return test state to a clean snapshot by completing with actual authority time offset.
	authority.server_time_offset_seconds += march.remaining_seconds() + 1.0
	authority.catch_up_march(world,march,conflict,WorldSupplyNetwork.new(),WorldBattleResolver.new(),"local_player")

	var snapshot = authority.build_snapshot(world,march,conflict)
	if not authority.verify_snapshot(snapshot):
		_fail("V18: 서버 스냅샷 무결성 검증 실패")
		return
	if typeof(snapshot.get("season",{})) != TYPE_DICTIONARY or str((snapshot["season"] as Dictionary).get("season_id","")).is_empty():
		_fail("V18: 시즌 상태 스냅샷 누락")
		return
	var tampered = snapshot.duplicate(true)
	var world_data: Dictionary = tampered["world"].duplicate(true)
	world_data["rations"] = 999999
	tampered["world"] = world_data
	if authority.verify_snapshot(tampered):
		_fail("V18: 변조된 스냅샷 허용")
		return

	# Settlement locks new conquest orders.
	season.active_end_unix = authority.server_now() - 1
	season.settlement_end_unix = authority.server_now() + 10000
	season.refresh_phase(authority.server_now())
	var command = {
		"id":"season_lock",
		"type":"march",
		"player_id":"local_player",
		"faction":WorldWarState.FACTION_AURELIA,
		"target":[5,10],
		"issued_at":authority.server_now(),
		"expected_revision":authority.last_revision
	}
	var response = authority.submit_command(world,march,conflict,WorldSupplyNetwork.new(),command)
	if bool(response.get("accepted",false)) or str(response.get("reason","")) != "시즌 정산 중":
		_fail("V18: 시즌 정산 중 신규 점령 명령 차단 실패")
		return
	print("v18_season_sync_smoke_test_ok digest=ok tamper=blocked season_sync=ok settlement_lock=ok")
	quit(0)
