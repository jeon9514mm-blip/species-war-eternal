extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _init() -> void:
	var world = WorldWarState.new()
	world.initialize_new(WorldWarState.FACTION_AURELIA)
	var supply = WorldSupplyNetwork.new()

	# Extend a connected corridor and verify reachability.
	for x in range(3, 7):
		world._set_owner(Vector2i(x, 10), WorldWarState.FACTION_AURELIA)
	var connected = Vector2i(6, 10)
	if not supply.is_supply_connected(world, connected, WorldWarState.FACTION_AURELIA):
		_fail("V15: 연결된 보급선 판정 실패")
		return

	# Create an isolated pocket.
	var isolated = Vector2i(9, 8)
	world._set_owner(isolated, WorldWarState.FACTION_AURELIA)
	if supply.is_supply_connected(world, isolated, WorldWarState.FACTION_AURELIA):
		_fail("V15: 고립 영토 보급 단절 판정 실패")
		return
	if supply.resource_efficiency(world, isolated, WorldWarState.FACTION_AURELIA) >= 1.0:
		_fail("V15: 고립 영토 자원 패널티 실패")
		return
	if supply.tile_defense_multiplier(world, isolated, WorldWarState.FACTION_AURELIA) >= 1.0:
		_fail("V15: 고립 영토 방어 패널티 실패")
		return

	# Reconnect the pocket.
	for pos in [Vector2i(7,10), Vector2i(8,10), Vector2i(9,10), Vector2i(9,9)]:
		world._set_owner(pos, WorldWarState.FACTION_AURELIA)
	if not supply.is_supply_connected(world, isolated, WorldWarState.FACTION_AURELIA):
		_fail("V15: 보급선 재연결 실패")
		return
	if supply.isolated_count(world, WorldWarState.FACTION_AURELIA) != 0:
		_fail("V15: 재연결 후 고립 타일 잔존")
		return

	# If an army becomes stranded after a later cut, emergency retreat prevents a softlock.
	var stranded = Vector2i(12, 4)
	world._set_owner(stranded, WorldWarState.FACTION_AURELIA)
	world.army_position = stranded
	var march = WorldMarchState.new()
	if not march.plan(world, WorldWarState.AURELIA_CAPITAL).is_empty():
		_fail("V15: 고립 부대가 일반 보급 행군을 사용함")
		return
	if not march.begin_forced_retreat(world):
		_fail("V15: 고립 부대 긴급 후퇴 시작 실패")
		return
	var retreat = march.advance(march.duration_seconds + 0.1, world)
	if not bool(retreat.get("success", false)) or world.army_position != WorldWarState.AURELIA_CAPITAL:
		_fail("V15: 긴급 후퇴 도착 실패")
		return

	print("world_supply_network_smoke_test_ok connected=ok isolated=ok reconnect=ok retreat=ok")
	quit(0)
