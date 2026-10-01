extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _party() -> Array:
	var result: Array = []
	for i in 3:
		result.append({"id":"u%d"%i,"name":"U%d"%i,"role":"딜러","row":"중열","max_hp":800,"hp":800,"attack":100,"defense":20})
	return result

func _init() -> void:
	var world = WorldWarState.new()
	world.initialize_new(WorldWarState.FACTION_AURELIA)
	var march = WorldMarchState.new()
	var conflict = WorldConflictState.new()
	var supply = WorldSupplyNetwork.new()
	var authority = WorldAuthorityService.new()
	var gateway = WorldServerGateway.new()
	if not authority.register_trusted_party("player_a", WorldWarState.FACTION_AURELIA, _party(), 1800):
		_fail("V16: 서버 신뢰 부대 등록 실패")
		return

	var target = Vector2i(4, 10)
	var command = {
		"id": "test_command_1",
		"type": "march",
		"player_id": "player_a",
		"faction": WorldWarState.FACTION_AURELIA,
		"target": [target.x, target.y],
		"issued_at": authority.server_now(),
		"expected_revision": 0
	}
	var first = gateway.submit(authority, world, march, conflict, supply, command)
	if not bool(first.get("accepted", false)) or authority.last_revision != 1:
		_fail("V16: 권한 명령 승인/revision 증가 실패")
		return
	var rations_after_first = world.rations
	var duplicate = gateway.submit(authority, world, march, conflict, supply, command)
	if not bool(duplicate.get("accepted", false)) or not bool(duplicate.get("duplicate", false)) or authority.last_revision != 1:
		_fail("V16: 동일 명령 재전송 idempotency 실패")
		return
	if world.rations != rations_after_first:
		_fail("V16: 중복 명령 군량 이중 차감")
		return

	march.advance(march.duration_seconds + 0.1, world)
	var stale = {
		"id": "stale_command",
		"type": "march",
		"player_id": "player_a",
		"faction": WorldWarState.FACTION_AURELIA,
		"target": [3, 10],
		"issued_at": authority.server_now(),
		"expected_revision": 0
	}
	var stale_result = gateway.submit(authority, world, march, conflict, supply, stale)
	if bool(stale_result.get("accepted", false)) or str(stale_result.get("reason", "")) != "월드 리비전 충돌":
		_fail("V16: stale revision 차단 실패")
		return

	var intruder = stale.duplicate(true)
	intruder["id"] = "intruder"
	intruder["player_id"] = "unknown"
	intruder["expected_revision"] = authority.last_revision
	var intruder_result = gateway.submit(authority, world, march, conflict, supply, intruder)
	if bool(intruder_result.get("accepted", false)) or str(intruder_result.get("reason", "")) != "인증되지 않은 플레이어":
		_fail("V16: 미등록 플레이어 명령 차단 실패")
		return

	var saved = authority.export_state()
	var restored = WorldAuthorityService.new()
	restored.import_state(saved)
	if restored.last_revision != authority.last_revision or not restored.processed_commands.has("test_command_1"):
		_fail("V16: 권한 상태 저장/복원 실패")
		return

	print("v16_authority_smoke_test_ok trusted=ok idempotency=ok revision=ok auth=ok save=ok")
	quit(0)
