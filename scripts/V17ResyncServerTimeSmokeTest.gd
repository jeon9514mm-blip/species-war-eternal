extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _unit(index: int) -> Dictionary:
	return {"id":"u%d"%index,"name":"U%d"%index,"role":"딜러","row":"중열","max_hp":850,"hp":850,"attack":125,"defense":22}

func _init() -> void:
	var world = WorldWarState.new()
	world.initialize_new(WorldWarState.FACTION_AURELIA)
	var march = WorldMarchState.new()
	var conflict = WorldConflictState.new()
	var authority = WorldAuthorityService.new()
	var gateway = WorldServerGateway.new()
	var session = WorldWarClientSession.new()
	var squad: Array = []
	for i in 3:
		squad.append(_unit(i))
	if not authority.register_trusted_party("local_player", WorldWarState.FACTION_AURELIA, squad, 1900):
		_fail("V17: 신뢰 부대 등록 실패")
		return
	session.bind(world, march, conflict, authority, gateway, WorldWarState.FACTION_AURELIA, "local_player")
	var sync = session.resync_from_server()
	if not bool(sync.get("ok", false)) or session.sync_count != 1:
		_fail("V17: 최초 서버 스냅샷 동기화 실패")
		return

	var start = session.send("begin_march", {"target":[4,10]}, squad, 1900)
	if not bool(start.get("ok", false)) or not march.active:
		_fail("V17: 서버시간 행군 시작 실패")
		return
	if march.authority_started_unix <= 0.0 or march.authority_end_unix <= march.authority_started_unix:
		_fail("V17: 행군 서버 시작/도착 시각 미기록")
		return
	var cached_rations = world.rations
	gateway.fetch_snapshot(authority, world, march, conflict)
	gateway.simulate_disconnect()
	world.rations = maxi(1, cached_rations - 7)
	var authoritative_rations: int = world.rations
	march.elapsed_seconds = 0.0
	var reconnect = session.reconnect_and_resync()
	if not bool(reconnect.get("ok", false)) or world.rations != authoritative_rations:
		_fail("V17: 재접속이 오래된 gateway cache로 권한 상태를 롤백함")
		return
	if session.sync_count < 2 or session.desynced:
		_fail("V17: 재접속 동기화 상태 갱신 실패")
		return

	authority.server_time_offset_seconds += march.remaining_seconds() + 1.0
	var arrival = session.catch_up_server(squad, 1900)
	if not bool(arrival.get("ok", false)) or world.tile_owner(Vector2i(4,10)) != WorldWarState.FACTION_AURELIA:
		_fail("V17: 서버시간 기준 오프라인 행군 도착/점령 실패")
		return

	# Simulate a stale client revision. The command is rejected, then the client automatically resyncs.
	session.revision = maxi(0, authority.last_revision - 1)
	var stale = session.send("support", {"target":[world.army_position.x, world.army_position.y]}, squad, 1900)
	if bool(stale.get("ok", false)) or str(stale.get("error", "")) != "stale_revision" or not bool(stale.get("resynced", false)):
		_fail("V17: stale revision 자동 재동기화 실패")
		return
	if session.revision != authority.last_revision:
		_fail("V17: 재동기화 후 revision 불일치")
		return
	print("v17_resync_server_time_smoke_test_ok reconnect=ok server_clock=ok stale_resync=ok")
	quit(0)
