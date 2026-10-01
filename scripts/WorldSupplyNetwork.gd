extends RefCounted
class_name WorldSupplyNetwork

func connected_keys(world: WorldWarState, owner: String) -> Dictionary:
	var result: Dictionary = {}
	if world == null or owner not in [WorldWarState.FACTION_AURELIA, WorldWarState.FACTION_NOXFERA]:
		return result
	var capital := world.capital_for(owner)
	if world.tile_owner(capital) != owner:
		return result
	var queue: Array[Vector2i] = [capital]
	result[world._key(capital)] = true
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for next in world.neighbors(current):
			var key := world._key(next)
			if result.has(key) or world.tile_owner(next) != owner:
				continue
			result[key] = true
			queue.append(next)
	return result

func is_supply_connected(world: WorldWarState, pos: Vector2i, owner: String) -> bool:
	if world == null or world.tile_owner(pos) != owner:
		return false
	return connected_keys(world, owner).has(world._key(pos))

func isolated_tiles(world: WorldWarState, owner: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if world == null:
		return result
	var connected := connected_keys(world, owner)
	for y in WorldWarState.HEIGHT:
		for x in WorldWarState.WIDTH:
			var pos := Vector2i(x, y)
			if world.tile_owner(pos) == owner and not connected.has(world._key(pos)):
				result.append(pos)
	return result

func isolated_count(world: WorldWarState, owner: String) -> int:
	return isolated_tiles(world, owner).size()

func adjacent_fort_bonus(world: WorldWarState, pos: Vector2i, owner: String) -> float:
	if world == null:
		return 1.0
	for neighbor in world.neighbors(pos):
		if world.tile_owner(neighbor) == owner and world.tile_type(neighbor) == "fort":
			return 1.06
	return 1.0

func tile_defense_multiplier(world: WorldWarState, pos: Vector2i, owner: String) -> float:
	if world == null or world.tile_owner(pos) != owner:
		return 1.0
	var result := 1.0
	match world.tile_type(pos):
		"fort":
			result *= 1.18
		"citadel":
			result *= 1.12
		"mine", "forest_resource", "ruins":
			result *= 1.05
	result *= adjacent_fort_bonus(world, pos, owner)
	if not is_supply_connected(world, pos, owner):
		result *= 0.82
	return result

func resource_efficiency(world: WorldWarState, pos: Vector2i, owner: String) -> float:
	if world == null or world.tile_owner(pos) != owner:
		return 0.0
	return 1.0 if is_supply_connected(world, pos, owner) else 0.25

func can_reinforce(world: WorldWarState, pos: Vector2i, owner: String) -> bool:
	return world != null and world.tile_owner(pos) == owner and is_supply_connected(world, pos, owner)

func supply_status_text(world: WorldWarState, pos: Vector2i, owner: String) -> String:
	if world == null or world.tile_owner(pos) != owner:
		return "보급 대상 아님"
	if is_supply_connected(world, pos, owner):
		return "보급 연결"
	return "보급 단절 · 방어 -18% · 자원 효율 25%"
