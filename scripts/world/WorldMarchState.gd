extends RefCounted
class_name WorldMarchState

const BASE_SECONDS_PER_TILE := 4.0
const BASE_RATIONS_PER_TILE := 8

var active := false
var faction := ""
var path: Array[Vector2i] = []
var target := Vector2i(-1, -1)
var origin := Vector2i(-1, -1)
var context_id := ""
var action := ""
var duration_seconds := 0.0
var elapsed_seconds := 0.0
var ration_cost := 0
var last_system_unix := 0
var authority_started_unix := 0.0
var authority_end_unix := 0.0
var last_authority_unix := 0.0
var last_result := ""

func reset() -> void:
	active = false
	path.clear()
	target = Vector2i(-1, -1)
	origin = Vector2i(-1, -1)
	context_id = ""
	action = ""
	duration_seconds = 0.0
	elapsed_seconds = 0.0
	ration_cost = 0
	last_system_unix = int(Time.get_unix_time_from_system())
	authority_started_unix = 0.0
	authority_end_unix = 0.0
	last_authority_unix = 0.0

func plan(world: WorldWarState, target_cell: Vector2i, requested_action := "") -> Dictionary:
	if world == null or active:
		return {}
	var route: Array[Vector2i] = world.find_march_path(target_cell)
	if route.size() < 2:
		return {}
	var target_owner: String = world.tile_owner(target_cell)
	var planned_action: String = "move"
	if requested_action == "support":
		if target_owner != world.faction:
			return {}
		planned_action = "support"
	elif target_owner == WorldWarState.FACTION_NEUTRAL:
		planned_action = "capture_neutral"
	elif target_owner == world.enemy_faction():
		if not world.can_attack_enemy_tile(world.faction, target_cell):
			return {}
		planned_action = "attack_enemy"
	elif target_owner != world.faction:
		return {}
	var distance: int = route.size() - 1
	var buff: Dictionary = world.faction_balance_buff(world.faction)
	var speed: float = maxf(0.1, float(buff.get("march_speed_multiplier", 1.0)))
	var ration_multiplier: float = clampf(float(buff.get("ration_cost_multiplier", 1.0)), 0.1, 1.0)
	var duration: float = maxf(1.0, float(distance) * BASE_SECONDS_PER_TILE / speed)
	var cost: int = maxi(1, int(ceil(float(distance * BASE_RATIONS_PER_TILE) * ration_multiplier)))
	return {
		"path": route,
		"target": target_cell,
		"action": planned_action,
		"distance": distance,
		"duration_seconds": duration,
		"ration_cost": cost
	}

func begin(world: WorldWarState, target_cell: Vector2i, requested_action := "", requested_context_id := "", authority_now := -1.0) -> bool:
	var data: Dictionary = plan(world, target_cell, requested_action)
	if data.is_empty():
		return false
	var cost: int = int(data["ration_cost"])
	if not world.consume_rations(cost):
		last_result = "군량 부족"
		return false
	faction = world.faction
	origin = world.army_position
	context_id = requested_context_id
	path.clear()
	var planned_path: Array = data["path"]
	for cell in planned_path:
		path.append(Vector2i(cell))
	target = Vector2i(data["target"])
	action = str(data["action"])
	duration_seconds = float(data["duration_seconds"])
	elapsed_seconds = 0.0
	ration_cost = cost
	last_system_unix = int(Time.get_unix_time_from_system())
	var start_time: float = authority_now if authority_now >= 0.0 else Time.get_unix_time_from_system()
	authority_started_unix = start_time
	authority_end_unix = start_time + duration_seconds
	last_authority_unix = start_time
	last_result = "행군 시작"
	active = true
	return true

func begin_forced_retreat(world: WorldWarState, authority_now := -1.0) -> bool:
	if world == null or active:
		return false
	var capital: Vector2i = world.capital_for(world.faction)
	if world.army_position == capital:
		return false
	faction = world.faction
	origin = world.army_position
	target = capital
	context_id = ""
	action = "forced_retreat"
	path.clear()
	path.append(origin)
	path.append(target)
	var distance: int = abs(origin.x - target.x) + abs(origin.y - target.y)
	duration_seconds = maxf(2.0, float(maxi(1, distance)) * BASE_SECONDS_PER_TILE * 1.5)
	elapsed_seconds = 0.0
	ration_cost = 0
	last_system_unix = int(Time.get_unix_time_from_system())
	var start_time: float = authority_now if authority_now >= 0.0 else Time.get_unix_time_from_system()
	authority_started_unix = start_time
	authority_end_unix = start_time + duration_seconds
	last_authority_unix = start_time
	last_result = "긴급 후퇴 시작"
	active = true
	return true

func progress_ratio() -> float:
	if not active or duration_seconds <= 0.0:
		return 0.0
	return clampf(elapsed_seconds / duration_seconds, 0.0, 1.0)

func remaining_seconds() -> float:
	return maxf(0.0, duration_seconds - elapsed_seconds)

func advance(delta: float, world: WorldWarState) -> Dictionary:
	if not active or world == null or not is_finite(delta) or delta < 0.0:
		return {"arrived": false, "success": false}
	elapsed_seconds = minf(duration_seconds, elapsed_seconds + maxf(0.0, delta))
	last_system_unix = int(Time.get_unix_time_from_system())
	if elapsed_seconds + 0.0001 < duration_seconds:
		return {"arrived": false, "success": false}
	var completed_action: String = action
	var completed_target: Vector2i = target
	var success: bool = false
	var battle_required: bool = completed_action == "attack_enemy"
	var route_valid := faction == world.faction
	if completed_action != "forced_retreat":
		for cell in path.slice(0, -1):
			if world.tile_owner(cell) != world.faction:
				route_valid = false
	if not route_valid:
		active = false
		last_result = "행군 경로 단절"
		return {"arrived": true, "success": false, "target": completed_target, "origin": origin, "action": completed_action, "context_id": context_id}
	if battle_required:
		success = world.can_attack_enemy_tile(world.faction, completed_target)
	elif completed_action == "support":
		# Destination capacity/supply may change during travel. The authority
		# commits movement (and capital healing) after those checks succeed.
		success = world.tile_owner(completed_target) == world.faction
	elif completed_action == "forced_retreat":
		success = world.apply_march_arrival(completed_target, "move")
	elif completed_action == "capture_neutral":
		# The march reports arrival only; authoritative ownership is committed by
		# WorldAuthorityService after validating the final world revision.
		success = world.tile_owner(completed_target) == WorldWarState.FACTION_NEUTRAL and world.sanctuary_owner(completed_target) == WorldWarState.FACTION_NEUTRAL
	else:
		success = world.apply_march_arrival(completed_target, completed_action)
	active = false
	last_result = "전투 대기" if battle_required and success else ("도착 완료" if success else "도착 처리 실패")
	return {
		"arrived": true,
		"success": success,
		"battle_required": battle_required and success,
		"action": completed_action,
		"target": completed_target,
		"origin": origin,
		"context_id": context_id
	}

func advance_authoritative(authority_now: float, world: WorldWarState) -> Dictionary:
	if not active or world == null or not is_finite(authority_now):
		return {"arrived": false, "success": false}
	if authority_started_unix <= 0.0:
		authority_started_unix = authority_now - elapsed_seconds
		authority_end_unix = authority_started_unix + duration_seconds
	last_authority_unix = maxf(last_authority_unix, authority_now)
	elapsed_seconds = clampf(last_authority_unix - authority_started_unix, 0.0, duration_seconds)
	return advance(0.0, world)

func catch_up_authoritative(authority_now: float, world: WorldWarState) -> Dictionary:
	return advance_authoritative(authority_now, world)

func catch_up(world: WorldWarState) -> Dictionary:
	if not active:
		return {"arrived": false, "success": false}
	var now: int = int(Time.get_unix_time_from_system())
	var delta: int = maxi(0, now - last_system_unix)
	if delta <= 0:
		return {"arrived": false, "success": false}
	return advance(float(delta), world)

func cancel_and_refund(world: WorldWarState, refund_ratio := 0.5) -> int:
	if not active or world == null:
		return 0
	var refund: int = int(round(float(ration_cost) * clampf(refund_ratio, 0.0, 1.0)))
	world.add_rations(refund)
	reset()
	last_result = "행군 취소 · 군량 %d 환급" % refund
	return refund

func export_state() -> Dictionary:
	var serialized_path: Array = []
	for cell in path:
		serialized_path.append([cell.x, cell.y])
	return {
		"active": active,
		"faction": faction,
		"path": serialized_path,
		"target": [target.x, target.y],
		"origin": [origin.x, origin.y],
		"context_id": context_id,
		"action": action,
		"duration_seconds": duration_seconds,
		"elapsed_seconds": elapsed_seconds,
		"ration_cost": ration_cost,
		"last_system_unix": last_system_unix,
		"authority_started_unix": authority_started_unix,
		"authority_end_unix": authority_end_unix,
		"last_authority_unix": last_authority_unix,
		"last_result": last_result
	}

func import_state(data: Dictionary) -> void:
	reset()
	if data.is_empty():
		return
	faction = str(data.get("faction", ""))
	context_id = str(data.get("context_id", ""))
	action = str(data.get("action", ""))
	duration_seconds = clampf(WorldWarState.safe_float(data.get("duration_seconds", 0.0)), 0.0, 86400.0)
	elapsed_seconds = clampf(WorldWarState.safe_float(data.get("elapsed_seconds", 0.0)), 0.0, duration_seconds)
	ration_cost = maxi(0, WorldWarState.safe_int(data.get("ration_cost", 0)))
	last_system_unix = WorldWarState.safe_int(data.get("last_system_unix", Time.get_unix_time_from_system()))
	authority_started_unix = WorldWarState.safe_float(data.get("authority_started_unix", 0.0))
	authority_end_unix = WorldWarState.safe_float(data.get("authority_end_unix", 0.0))
	last_authority_unix = WorldWarState.safe_float(data.get("last_authority_unix", authority_started_unix))
	if authority_started_unix <= 0.0 and duration_seconds > 0.0:
		authority_started_unix = WorldWarState.safe_float(last_system_unix) - elapsed_seconds
		authority_end_unix = authority_started_unix + duration_seconds
		last_authority_unix = authority_started_unix + elapsed_seconds
	last_result = str(data.get("last_result", ""))
	var target_data = data.get("target", [-1, -1])
	if typeof(target_data) == TYPE_ARRAY and target_data.size() >= 2:
		target = Vector2i(WorldWarState.safe_int(target_data[0]), WorldWarState.safe_int(target_data[1]))
	var origin_data = data.get("origin", [-1, -1])
	if typeof(origin_data) == TYPE_ARRAY and origin_data.size() >= 2:
		origin = Vector2i(WorldWarState.safe_int(origin_data[0]), WorldWarState.safe_int(origin_data[1]))
	var saved_path = data.get("path", [])
	if typeof(saved_path) == TYPE_ARRAY:
		for pair in saved_path.slice(0, WorldWarState.WIDTH * WorldWarState.HEIGHT):
			if typeof(pair) == TYPE_ARRAY and pair.size() >= 2:
				path.append(Vector2i(WorldWarState.safe_int(pair[0]), WorldWarState.safe_int(pair[1])))
	active = data.get("active", false) == true and duration_seconds > 0.0 and path.size() >= 2
	if faction not in [WorldWarState.FACTION_AURELIA, WorldWarState.FACTION_NOXFERA] or action not in ["move", "support", "capture_neutral", "attack_enemy", "forced_retreat"]:
		active = false
	if active and (path[0] != origin or path[-1] != target):
		active = false
	for index in path.size():
		var cell := path[index]
		if cell.x < 0 or cell.y < 0 or cell.x >= WorldWarState.WIDTH or cell.y >= WorldWarState.HEIGHT:
			active = false
		if action != "forced_retreat" and index > 0 and abs(cell.x - path[index - 1].x) + abs(cell.y - path[index - 1].y) != 1:
			active = false
	last_authority_unix = maxf(last_authority_unix, authority_started_unix + elapsed_seconds)
