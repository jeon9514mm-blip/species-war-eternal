extends RefCounted
class_name WorldConflictState

const CONFLICT_VERSION := 2
const MAX_REPORTS := 20
const MAX_RALLY_FORCES := 5
const MAX_ATTACK_QUEUE := 8

var tile_garrisons: Dictionary = {}
var rallies: Dictionary = {}
var attack_queues: Dictionary = {}
var next_rally_id := 1
var contribution_points := 0
var total_supports := 0
var total_captures := 0
var campaign_reports: Array = []
var support_awards: Dictionary = {}

func _key(pos: Vector2i) -> String:
	return "%d:%d" % [pos.x, pos.y]

func capacity_for_tile_type(tile_type: String) -> int:
	match tile_type:
		"capital":
			return 8
		"citadel":
			return 6
		"fort":
			return 5
		"mine", "forest_resource", "ruins":
			return 3
		_:
			return 2

func capacity_at(world: WorldWarState, pos: Vector2i) -> int:
	if world == null:
		return 0
	return capacity_for_tile_type(world.tile_type(pos))

func garrisons_at(pos: Vector2i) -> Array:
	var data = tile_garrisons.get(_key(pos), [])
	if typeof(data) != TYPE_ARRAY:
		return []
	return data.duplicate(true)

func garrison_count(pos: Vector2i) -> int:
	return garrisons_at(pos).size()

func find_force(force_id: String) -> Dictionary:
	for key in tile_garrisons.keys():
		var forces = tile_garrisons[key]
		if typeof(forces) != TYPE_ARRAY:
			continue
		for force in forces:
			if typeof(force) == TYPE_DICTIONARY and str(force.get("force_id", "")) == force_id:
				return force.duplicate(true)
	return {}

func remove_force_everywhere(force_id: String) -> bool:
	var removed := false
	for key in tile_garrisons.keys():
		var forces: Array = tile_garrisons[key]
		var filtered: Array = []
		for force in forces:
			if typeof(force) == TYPE_DICTIONARY and str(force.get("force_id", "")) == force_id:
				removed = true
				continue
			filtered.append(force)
		if filtered.is_empty():
			tile_garrisons.erase(key)
		else:
			tile_garrisons[key] = filtered
	return removed

func add_garrison(world: WorldWarState, supply: WorldSupplyNetwork, pos: Vector2i, force: Dictionary) -> bool:
	if world == null or supply == null or force.is_empty() or _alive_squad(force.get("squad", [])).is_empty():
		return false
	var owner := world.tile_owner(pos)
	var force_faction := str(force.get("faction", ""))
	if owner != force_faction or not supply.can_reinforce(world, pos, owner):
		return false
	var force_id := str(force.get("force_id", ""))
	if force_id.is_empty():
		return false
	var forces := garrisons_at(pos)
	# Re-registering is idempotent; a failed transfer must retain the origin.
	for index in forces.size():
		if str(forces[index].get("force_id", "")) == force_id:
			forces[index] = force.duplicate(true)
			tile_garrisons[_key(pos)] = forces
			return true
	if forces.size() >= capacity_at(world, pos):
		return false
	remove_force_everywhere(force_id)
	forces.append(force.duplicate(true))
	tile_garrisons[_key(pos)] = forces
	var award_key := "%s|%s" % [force_id, _key(pos)]
	if not support_awards.has(award_key):
		support_awards[award_key] = true
		total_supports += 1
		contribution_points += 5
	return true

func clear_tile(pos: Vector2i) -> void:
	tile_garrisons.erase(_key(pos))

func migrate_legacy_garrison(world: WorldWarState, pos: Vector2i) -> void:
	if world == null or not garrisons_at(pos).is_empty():
		return
	var legacy := world.garrison_at(pos)
	if legacy.is_empty():
		return
	var owner := world.tile_owner(pos)
	var force := {
		"force_id": "legacy_%s" % _key(pos),
		"player_name": "기존 수비대",
		"faction": owner,
		"squad": legacy,
		"power": 0,
		"fatigue": 0,
		"is_npc": true,
		"arrived_at": 0
	}
	tile_garrisons[_key(pos)] = [force]

func _seed_count_for_tile(tile_type: String) -> int:
	match tile_type:
		"capital":
			return 5
		"citadel":
			return 4
		"fort":
			return 3
		"mine", "forest_resource", "ruins":
			return 2
		_:
			return 1

func ensure_defenders(world: WorldWarState, resolver: WorldBattleResolver, pos: Vector2i, power_hint: int) -> void:
	if world == null or resolver == null:
		return
	if not garrisons_at(pos).is_empty():
		return
	migrate_legacy_garrison(world, pos)
	if not garrisons_at(pos).is_empty():
		return
	var owner := world.tile_owner(pos)
	if owner not in [WorldWarState.FACTION_AURELIA, WorldWarState.FACTION_NOXFERA]:
		return
	var count := mini(capacity_at(world, pos), _seed_count_for_tile(world.tile_type(pos)))
	var forces: Array = []
	for index in count:
		var power_scale := 0.82 + float(index) * 0.08
		var squad := resolver.make_garrison(owner, pos + Vector2i(index, index * 2), world.tile_type(pos), int(float(power_hint) * power_scale))
		forces.append({
			"force_id": "npc_%s_%d" % [_key(pos), index],
			"player_name": "전선 수비대 %d" % (index + 1),
			"faction": owner,
			"squad": squad,
			"power": int(float(power_hint) * power_scale),
			"fatigue": 0,
			"is_npc": true,
			"arrived_at": 0
		})
	tile_garrisons[_key(pos)] = forces

func _alive_squad(squad: Array) -> Array:
	var result: Array = []
	for unit in squad:
		if typeof(unit) == TYPE_DICTIONARY and int(unit.get("hp", 0)) > 0:
			result.append(unit.duplicate(true))
	return result

func attack_queue_at(pos: Vector2i) -> Array:
	var data = attack_queues.get(_key(pos), [])
	if typeof(data) != TYPE_ARRAY:
		return []
	return data.duplicate(true)

func attack_queue_count(pos: Vector2i) -> int:
	return attack_queue_at(pos).size()

func enqueue_attack(pos: Vector2i, force: Dictionary) -> bool:
	if force.is_empty():
		return false
	var force_id := str(force.get("force_id", ""))
	if force_id.is_empty():
		return false
	var queue := attack_queue_at(pos)
	for queued in queue:
		if typeof(queued) == TYPE_DICTIONARY and str(queued.get("force_id", "")) == force_id:
			return false
	if queue.size() >= MAX_ATTACK_QUEUE:
		return false
	queue.append(force.duplicate(true))
	attack_queues[_key(pos)] = queue
	return true

func pop_next_attack(pos: Vector2i) -> Dictionary:
	var queue := attack_queue_at(pos)
	if queue.is_empty():
		return {}
	var force: Dictionary = queue.pop_front()
	if queue.is_empty():
		attack_queues.erase(_key(pos))
	else:
		attack_queues[_key(pos)] = queue
	return force

func process_next_attack(world: WorldWarState, supply: WorldSupplyNetwork, resolver: WorldBattleResolver, pos: Vector2i, seed: int) -> Dictionary:
	var force := pop_next_attack(pos)
	if force.is_empty():
		return {}
	var award := str(force.get("force_id", "")) == "player_local"
	var report := resolve_attack_queue(world, supply, resolver, pos, force, seed, award)
	report["attacker_force_id"] = str(force.get("force_id", ""))
	report["attacker_name"] = str(force.get("player_name", "공격대"))
	return report

func resolve_attack_queue(world: WorldWarState, supply: WorldSupplyNetwork, resolver: WorldBattleResolver, pos: Vector2i, attacker_force: Dictionary, seed: int, award_contribution := true) -> Dictionary:
	if world == null or supply == null or resolver == null or attacker_force.is_empty():
		return {}
	var attacker_faction := str(attacker_force.get("faction", ""))
	if not world.can_attack_enemy_tile(attacker_faction, pos):
		return {}
	ensure_defenders(world, resolver, pos, maxi(700, int(attacker_force.get("power", 1000))))
	var defenders := garrisons_at(pos)
	if defenders.is_empty():
		return {}
	var current_squad: Array = attacker_force.get("squad", []).duplicate(true)
	var original_count := current_squad.size()
	var aggregate_logs: Array[String] = []
	var battle_summaries: Array = []
	var defeated_forces := 0
	var remaining_defenders: Array = []
	var queue_stopped := false
	for index in defenders.size():
		var force: Dictionary = defenders[index]
		if queue_stopped:
			remaining_defenders.append(force)
			continue
		var defender_squad: Array = force.get("squad", [])
		var defender_faction := str(force.get("faction", world.tile_owner(pos)))
		var faction_buff := world.faction_balance_buff(defender_faction)
		var defense_mult := float(faction_buff.get("defense_multiplier", 1.0)) * supply.tile_defense_multiplier(world, pos, defender_faction)
		var fatigue := int(attacker_force.get("fatigue", 0))
		var report := resolver.resolve(current_squad, defender_squad, fatigue, defense_mult, maxi(1, seed + index * 97),str(attacker_force.get("stance","balanced")))
		var summary := {
			"defender_force_id": str(force.get("force_id", "")),
			"defender_name": str(force.get("player_name", "수비대")),
			"victory": bool(report.get("victory", false)),
			"rounds": int(report.get("rounds", 0)),
			"timeline": report.get("timeline",[]),
			"stance": report.get("stance","balanced"),
			"attacker_alive": int(report.get("attacker_alive", 0)),
			"defender_alive": int(report.get("defender_alive", 0))
		}
		battle_summaries.append(summary)
		var report_logs = report.get("logs", [])
		if typeof(report_logs) == TYPE_ARRAY:
			for line in report_logs:
				if aggregate_logs.size() >= 24:
					break
				aggregate_logs.append(str(line))
		current_squad = _alive_squad(report.get("attacker_units", []))
		if bool(report.get("victory", false)):
			defeated_forces += 1
			if award_contribution:
				contribution_points += 25
			continue
		var damaged_force := force.duplicate(true)
		damaged_force["squad"] = _alive_squad(report.get("defender_units", []))
		remaining_defenders.append(damaged_force)
		queue_stopped = true
	if queue_stopped:
		tile_garrisons[_key(pos)] = remaining_defenders
		var failure := {
			"victory": false,
			"captured": false,
			"defeated_forces": defeated_forces,
			"remaining_defenders": remaining_defenders.size(),
			"attacker_start_count": original_count,
			"attacker_survivors": current_squad.size(),
			"attacker_units": current_squad,
			"battle_summaries": battle_summaries,
			"logs": aggregate_logs
		}
		_record_campaign(failure)
		return failure

	clear_tile(pos)
	var captured := world.capture_enemy_after_battle(pos, attacker_faction)
	var survivor_force := attacker_force.duplicate(true)
	survivor_force["squad"] = current_squad
	survivor_force["fatigue"] = clampi(int(attacker_force.get("fatigue", 0)) + 12 + defeated_forces * 3, 0, 100)
	if captured and not current_squad.is_empty():
		var forces: Array = [survivor_force]
		tile_garrisons[_key(pos)] = forces
		if award_contribution:
			total_captures += 1
			contribution_points += 100
	var success := {
		"victory": captured,
		"captured": captured,
		"defeated_forces": defeated_forces,
		"remaining_defenders": 0,
		"attacker_start_count": original_count,
		"attacker_survivors": current_squad.size(),
		"attacker_units": current_squad,
		"battle_summaries": battle_summaries,
		"logs": aggregate_logs
	}
	_record_campaign(success)
	return success

func _record_campaign(report: Dictionary) -> void:
	campaign_reports.push_front(report.duplicate(true))
	while campaign_reports.size() > MAX_REPORTS:
		campaign_reports.pop_back()

func create_rally(world: WorldWarState, target: Vector2i, leader_force: Dictionary) -> String:
	if world == null or leader_force.is_empty():
		return ""
	var faction := str(leader_force.get("faction", ""))
	if not world.can_attack_enemy_tile(faction, target):
		return ""
	var id := "rally_%d" % next_rally_id
	next_rally_id += 1
	rallies[id] = {
		"id": id,
		"target": [target.x, target.y],
		"faction": faction,
		"leader_force_id": str(leader_force.get("force_id", "")),
		"participants": [leader_force.duplicate(true)],
		"created_at": int(Time.get_unix_time_from_system())
	}
	return id

func join_rally(rally_id: String, force: Dictionary) -> bool:
	if not rallies.has(rally_id) or force.is_empty():
		return false
	var rally: Dictionary = rallies[rally_id]
	var participants: Array = rally.get("participants", [])
	if participants.size() >= MAX_RALLY_FORCES:
		return false
	if str(force.get("faction", "")) != str(rally.get("faction", "")):
		return false
	var force_id := str(force.get("force_id", ""))
	for participant in participants:
		if str(participant.get("force_id", "")) == force_id:
			return false
	participants.append(force.duplicate(true))
	rally["participants"] = participants
	rallies[rally_id] = rally
	return true

func refresh_rally_participant(rally_id: String, force: Dictionary) -> bool:
	if not rallies.has(rally_id) or force.is_empty():
		return false
	var rally: Dictionary = rallies[rally_id]
	if str(force.get("faction", "")) != str(rally.get("faction", "")):
		return false
	var participants: Array = rally.get("participants", [])
	for index in participants.size():
		if str(participants[index].get("force_id", "")) == str(force.get("force_id", "")):
			participants[index] = force.duplicate(true)
			rally["participants"] = participants
			return true
	return false

func rally_at_target(target: Vector2i, faction: String) -> Dictionary:
	for rally in rallies.values():
		if typeof(rally) != TYPE_DICTIONARY or str(rally.get("faction", "")) != faction:
			continue
		var raw = rally.get("target", [])
		if typeof(raw) == TYPE_ARRAY and raw.size() >= 2 and Vector2i(int(raw[0]), int(raw[1])) == target:
			return rally.duplicate(true)
	return {}

func remove_rally_participant(rally_id: String, force_id: String) -> bool:
	if not rallies.has(rally_id) or force_id.is_empty():
		return false
	var rally: Dictionary = rallies[rally_id]
	var participants: Array = rally.get("participants", [])
	var filtered: Array = []
	var removed := false
	for participant in participants:
		if typeof(participant) == TYPE_DICTIONARY and str(participant.get("force_id", "")) == force_id:
			removed = true
			continue
		filtered.append(participant)
	if not removed:
		return false
	if filtered.is_empty():
		rallies.erase(rally_id)
		return true
	rally["participants"] = filtered
	if str(rally.get("leader_force_id", "")) == force_id:
		rally["leader_force_id"] = str(filtered[0].get("force_id", ""))
	rallies[rally_id] = rally
	return true

func cancel_rally(rally_id: String) -> bool:
	if not rallies.has(rally_id):
		return false
	rallies.erase(rally_id)
	return true

func resolve_rally(world: WorldWarState, supply: WorldSupplyNetwork, resolver: WorldBattleResolver, rally_id: String, seed: int) -> Dictionary:
	if not rallies.has(rally_id):
		return {}
	var rally: Dictionary = rallies[rally_id]
	var raw = rally.get("target", [])
	if typeof(raw) != TYPE_ARRAY or raw.size() < 2:
		return {}
	var target := Vector2i(int(raw[0]), int(raw[1]))
	var participants: Array = rally.get("participants", [])
	var participant_reports: Array = []
	var captured := false
	var winner_force: Dictionary = {}
	for index in participants.size():
		if world.tile_owner(target) == str(rally.get("faction", "")):
			captured = true
			break
		var force: Dictionary = participants[index]
		var is_local_force := str(force.get("force_id", "")) == "player_local"
		var report := resolve_attack_queue(world, supply, resolver, target, force, seed + index * 1009, is_local_force)
		report["attacker_force_id"] = str(force.get("force_id", ""))
		report["attacker_name"] = str(force.get("player_name", "공격대"))
		participant_reports.append(report)
		if bool(report.get("captured", false)):
			captured = true
			winner_force = force
			break
	rallies.erase(rally_id)
	return {
		"victory": captured,
		"captured": captured,
		"participant_reports": participant_reports,
		"participants_used": participant_reports.size(),
		"winner_force_id": str(winner_force.get("force_id", ""))
	}

func reset_for_new_season() -> void:
	tile_garrisons.clear()
	rallies.clear()
	attack_queues.clear()
	next_rally_id = 1
	contribution_points = 0
	total_supports = 0
	total_captures = 0
	campaign_reports.clear()
	support_awards.clear()

func export_state() -> Dictionary:
	return {
		"conflict_version": CONFLICT_VERSION,
		"tile_garrisons": tile_garrisons.duplicate(true),
		"rallies": rallies.duplicate(true),
		"attack_queues": attack_queues.duplicate(true),
		"next_rally_id": next_rally_id,
		"contribution_points": contribution_points,
		"total_supports": total_supports,
		"total_captures": total_captures,
		"campaign_reports": campaign_reports.duplicate(true),
		"support_awards": support_awards.duplicate(true)
	}

func _sanitize_force(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var force: Dictionary = raw.duplicate(true)
	var force_id := str(force.get("force_id", ""))
	var faction := str(force.get("faction", ""))
	var squad = force.get("squad", [])
	if force_id.is_empty() or faction not in [WorldWarState.FACTION_AURELIA, WorldWarState.FACTION_NOXFERA] or typeof(squad) != TYPE_ARRAY:
		return {}
	force["force_id"] = force_id
	force["faction"] = faction
	force["squad"] = WorldBattleResolver.new()._clone_squad(squad.slice(0, 10))
	if force["squad"].is_empty():
		return {}
	force["power"] = clampi(WorldWarState.safe_int(force.get("power", 0)), 0, 1000000000)
	force["fatigue"] = clampi(WorldWarState.safe_int(force.get("fatigue", 0)), 0, 100)
	force["stance"] = str(force.get("stance","balanced"))
	if force["stance"] not in WorldCampaignRules.STANCES:force["stance"]="balanced"
	force["arrived_at"] = maxi(0, WorldWarState.safe_int(force.get("arrived_at", 0)))
	return force

func _sanitize_force_map(raw: Variant, limit: int) -> Dictionary:
	var result: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return result
	var seen: Dictionary = {}
	for y in WorldWarState.HEIGHT:
		for x in WorldWarState.WIDTH:
			var key := _key(Vector2i(x, y))
			var list = raw.get(key, [])
			if typeof(list) != TYPE_ARRAY:
				continue
			var valid: Array = []
			for entry in list.slice(0, limit):
				var force := _sanitize_force(entry)
				if force.is_empty() or seen.has(force["force_id"]):
					continue
				seen[force["force_id"]] = true
				valid.append(force)
			if not valid.is_empty():
				result[key] = valid
	return result

func import_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	reset_for_new_season()
	tile_garrisons = _sanitize_force_map(data.get("tile_garrisons", {}), 8)
	attack_queues = _sanitize_force_map(data.get("attack_queues", {}), MAX_ATTACK_QUEUE)
	var loaded_rallies = data.get("rallies", {})
	if typeof(loaded_rallies) == TYPE_DICTIONARY:
		for key in loaded_rallies.keys().slice(0, 100):
			var raw = loaded_rallies[key]
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var target = raw.get("target", [])
			var participants = raw.get("participants", [])
			if typeof(target) != TYPE_ARRAY or target.size() < 2 or typeof(participants) != TYPE_ARRAY:
				continue
			var cell := Vector2i(WorldWarState.safe_int(target[0], -1), WorldWarState.safe_int(target[1], -1))
			if cell.x < 0 or cell.y < 0 or cell.x >= WorldWarState.WIDTH or cell.y >= WorldWarState.HEIGHT:
				continue
			var valid: Array = []
			var seen: Dictionary = {}
			for entry in participants.slice(0, MAX_RALLY_FORCES):
				var force := _sanitize_force(entry)
				if not force.is_empty() and str(force.get("faction", "")) == str(raw.get("faction", "")) and not seen.has(force["force_id"]):
					valid.append(force)
					seen[force["force_id"]] = true
			if valid.is_empty():
				continue
			var rally: Dictionary = raw.duplicate(true)
			rally["id"] = str(key)
			rally["target"] = [cell.x, cell.y]
			rally["participants"] = valid
			rallies[str(key)] = rally
	next_rally_id = maxi(1, WorldWarState.safe_int(data.get("next_rally_id", 1), 1))
	contribution_points = maxi(0, WorldWarState.safe_int(data.get("contribution_points", 0)))
	total_supports = maxi(0, WorldWarState.safe_int(data.get("total_supports", 0)))
	total_captures = maxi(0, WorldWarState.safe_int(data.get("total_captures", 0)))
	var awards = data.get("support_awards", {})
	if typeof(awards) == TYPE_DICTIONARY:
		for key in awards.keys().slice(0, 10000):
			support_awards[str(key)] = true
	var loaded_reports = data.get("campaign_reports", [])
	if typeof(loaded_reports) == TYPE_ARRAY:
		for report in loaded_reports.slice(0, MAX_REPORTS):
			if typeof(report) == TYPE_DICTIONARY:
				campaign_reports.append(report.duplicate(true))
