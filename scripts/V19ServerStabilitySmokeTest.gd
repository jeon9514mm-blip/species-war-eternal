extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _unit(i: int) -> Dictionary:
	return {"id":"u%d"%i,"name":"U%d"%i,"role":"딜러","row":"중열","max_hp":800,"hp":800,"attack":110,"defense":20}

func _init() -> void:
	var guard = WorldSyncGuard.new()
	if guard.snapshot_revision_valid(10, 9):
		_fail("V19: 오래된 snapshot revision 허용")
		return
	if not guard.snapshot_revision_valid(10, 10):
		_fail("V19: 동일 revision snapshot 거부")
		return
	var smoothed = guard.smooth_clock_offset(0.0, 20.0, false)
	if smoothed > WorldSyncGuard.MAX_CLOCK_CORRECTION_PER_SAMPLE + 0.001:
		_fail("V19: 서버시간 보정이 한 번에 과도하게 이동")
		return
	if guard.retry_delay_seconds(10) > WorldSyncGuard.MAX_RETRY_SECONDS:
		_fail("V19: 재접속 backoff 상한 실패")
		return

	var world = WorldWarState.new()
	world.initialize_new(WorldWarState.FACTION_AURELIA)
	var march = WorldMarchState.new()
	var conflict = WorldConflictState.new()
	var season = WorldSeasonState.new()
	var authority = WorldAuthorityService.new()
	var gateway = WorldServerGateway.new()
	var session = WorldWarClientSession.new()
	authority.bind_season(season)
	season.ensure_started(authority.server_now())
	var squad: Array = []
	for i in 3:
		squad.append(_unit(i))
	authority.register_trusted_party("local_player", WorldWarState.FACTION_AURELIA, squad, 1600)
	session.bind(world,march,conflict,authority,gateway,WorldWarState.FACTION_AURELIA,"local_player",season)
	var first = session.resync_from_server()
	if not bool(first.get("ok",false)):
		_fail("V19: 최초 동기화 실패")
		return
	var cached_revision = session.revision
	authority.last_revision += 2
	var beat = session.heartbeat_server()
	if not bool(beat.get("ok",false)) or session.revision != authority.last_revision:
		_fail("V19: heartbeat revision 차이 자동 재동기화 실패")
		return
	if session.sync_count < 2:
		_fail("V19: heartbeat resync 카운트 실패")
		return

	# Reconnect must fetch a fresh authority snapshot, not restore an older cache.
	gateway.fetch_snapshot(authority,world,march,conflict)
	gateway.simulate_disconnect()
	world.rations = 4321
	var reconnect = session.reconnect_and_resync()
	if not bool(reconnect.get("ok",false)) or world.rations != 4321:
		_fail("V19: 재접속 시 오래된 snapshot cache로 롤백")
		return

	# Idempotency cache is bounded.
	for i in range(WorldAuthorityService.MAX_PROCESSED_COMMANDS + 20):
		authority._remember({"id":"fake_%d"%i,"type":"test","player_id":"local_player","faction":WorldWarState.FACTION_AURELIA}, {"accepted":true})
	if authority.processed_commands.size() > WorldAuthorityService.MAX_PROCESSED_COMMANDS:
		_fail("V19: 처리 명령 캐시 무제한 증가")
		return
	print("v19_server_stability_smoke_test_ok stale=blocked clock=smooth heartbeat=resync reconnect=fresh cache=bounded")
	quit(0)
