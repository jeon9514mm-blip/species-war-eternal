extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _strong_squad(prefix: String) -> Array:
	var squad: Array = []
	for i in 10:
		squad.append({
			"id": "%s_%d" % [prefix, i],
			"name": "%s %d" % [prefix, i],
			"role": "탱커" if i < 2 else ("서포터" if i in [8,9] else "딜러"),
			"row": "전열" if i < 3 else ("후열" if i >= 7 else "중열"),
			"max_hp": 1100,
			"hp": 1100,
			"attack": 220,
			"defense": 35
		})
	return squad

func _force(id: String, faction: String, power: int) -> Dictionary:
	return {
		"force_id": id,
		"player_name": id,
		"faction": faction,
		"squad": _strong_squad(id),
		"power": power,
		"fatigue": 0,
		"is_npc": false,
		"arrived_at": 0
	}

func _init() -> void:
	var world = WorldWarState.new()
	world.initialize_new(WorldWarState.FACTION_AURELIA)
	var supply = WorldSupplyNetwork.new()
	var conflict = WorldConflictState.new()
	var resolver = WorldBattleResolver.new()

	# Friendly garrison stack is capped by tile type.
	for x in range(3, 6):
		world._set_owner(Vector2i(x, 10), WorldWarState.FACTION_AURELIA)
	var friendly = Vector2i(5, 10)
	var cap = conflict.capacity_at(world, friendly)
	for i in cap:
		if not conflict.add_garrison(world, supply, friendly, _force("ally_%d" % i, WorldWarState.FACTION_AURELIA, 1600)):
			_fail("V15: 수비대 %d 등록 실패" % i)
			return
	if conflict.add_garrison(world, supply, friendly, _force("overflow", WorldWarState.FACTION_AURELIA, 1600)):
		_fail("V15: 주둔 한도 초과 허용됨")
		return
	if conflict.garrison_count(friendly) != cap:
		_fail("V15: 주둔 수 카운트 실패")
		return

	# Create a supplied front next to a fort target and seed multiple defenders.
	for pos in [Vector2i(6,10), Vector2i(6,11), Vector2i(6,12)]:
		world._set_owner(pos, WorldWarState.FACTION_AURELIA)
	world.army_position = Vector2i(6,12)
	var target = Vector2i(7,12)
	world._set_owner(target, WorldWarState.FACTION_NOXFERA)
	conflict.ensure_defenders(world, resolver, target, 1200)
	if conflict.garrison_count(target) < 2:
		_fail("V15: 요새 다중 수비대 생성 실패")
		return
	var result = conflict.resolve_attack_queue(
		world, supply, resolver, target,
		_force("player_local", WorldWarState.FACTION_AURELIA, 4000), 4242
	)
	if not bool(result.get("captured", false)):
		_fail("V15: 다중 수비대 연속 돌파 실패")
		return
	if int(result.get("defeated_forces", 0)) < 2:
		_fail("V15: 연속 전투 큐 격파 수 집계 실패")
		return
	if world.tile_owner(target) != WorldWarState.FACTION_AURELIA:
		_fail("V15: 연속 전투 후 영토 점령 실패")
		return

	# Rally max stack prevents unlimited zerg.
	var next_target = Vector2i(8,12)
	world._set_owner(next_target, WorldWarState.FACTION_NOXFERA)
	var rally_id = conflict.create_rally(world, next_target, _force("leader", WorldWarState.FACTION_AURELIA, 3000))
	if rally_id.is_empty():
		_fail("V15: 집결 생성 실패")
		return
	for i in range(1, WorldConflictState.MAX_RALLY_FORCES):
		if not conflict.join_rally(rally_id, _force("join_%d" % i, WorldWarState.FACTION_AURELIA, 2500)):
			_fail("V15: 집결 참여 실패 %d" % i)
			return
	if conflict.join_rally(rally_id, _force("too_many", WorldWarState.FACTION_AURELIA, 2500)):
		_fail("V15: 집결 최대 부대 수 제한 실패")
		return

	# FIFO attack queue and max size.
	var queue_target = Vector2i(8, 11)
	world._set_owner(queue_target, WorldWarState.FACTION_NOXFERA)
	if not conflict.enqueue_attack(queue_target, _force("q1", WorldWarState.FACTION_AURELIA, 2000)):
		_fail("V15: 공격대기열 첫 등록 실패")
		return
	if not conflict.enqueue_attack(queue_target, _force("q2", WorldWarState.FACTION_AURELIA, 2000)):
		_fail("V15: 공격대기열 둘째 등록 실패")
		return
	if conflict.attack_queue_count(queue_target) != 2:
		_fail("V15: 공격대기열 카운트 실패")
		return
	var popped = conflict.pop_next_attack(queue_target)
	if str(popped.get("force_id", "")) != "q1":
		_fail("V15: 공격대기열 FIFO 실패")
		return

	print("world_conflict_state_smoke_test_ok cap=ok defenders=ok capture=ok rally_limit=ok attack_queue=ok")
	quit(0)
