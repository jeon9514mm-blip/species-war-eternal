extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _unit(index: int) -> Dictionary:
	return {"id":"u%d"%index,"name":"U%d"%index,"role":"딜러","row":"중열","max_hp":900,"hp":900,"attack":150,"defense":24}

func _init() -> void:
	var world = WorldWarState.new()
	world.initialize_new(WorldWarState.FACTION_AURELIA)
	var march = WorldMarchState.new()
	var conflict = WorldConflictState.new()
	var authority = WorldAuthorityService.new()
	var gateway = WorldServerGateway.new()
	var session = WorldWarClientSession.new()
	var squad: Array = []
	for i in 10:
		squad.append(_unit(i))
	if not authority.register_trusted_party("local_player", WorldWarState.FACTION_AURELIA, squad, 2500):
		_fail("V16: ClientSession 신뢰 부대 등록 실패")
		return
	session.bind(world, march, conflict, authority, gateway, WorldWarState.FACTION_AURELIA, "local_player")

	# Deliberately pass fake weak stats. Authority must still use its trusted snapshot.
	var fake_client_squad: Array = [{"id":"fake","name":"fake","role":"딜러","row":"중열","max_hp":1,"hp":1,"attack":1,"defense":0}]
	var result = session.send("begin_march", {"target":[4,10]}, fake_client_squad, 1)
	if not bool(result.get("ok", false)) or not march.active:
		_fail("V16: ClientSession 권한 행군 시작 실패")
		return
	var snapshot = authority.trusted_force("local_player", world)
	if int(snapshot.get("power", 0)) != 2500 or (snapshot.get("squad", []) as Array).size() != 10:
		_fail("V16: 클라이언트 위조 스탯 대신 서버 신뢰 스냅샷 사용 실패")
		return
	authority.server_time_offset_seconds += march.duration_seconds + 0.1
	var arrival = session.catch_up_server(fake_client_squad, 1)
	if not bool(arrival.get("ok", false)) or world.army_position != Vector2i(4,10):
		_fail("V16: ClientSession 서버 도착 처리 실패")
		return
	if conflict.find_force("player_local").is_empty():
		_fail("V16: 도착 후 권한 서버 주둔 등록 실패")
		return
	if session.revision != authority.last_revision:
		_fail("V16: ClientSession revision 동기화 실패")
		return
	print("v16_client_session_smoke_test_ok trusted_stats=ok command=ok arrival=ok revision=ok")
	quit(0)
