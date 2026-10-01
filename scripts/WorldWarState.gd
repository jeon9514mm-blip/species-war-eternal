extends RefCounted
class_name WorldWarState

const WIDTH := 40
const HEIGHT := 40
const FACTION_NEUTRAL := "neutral"
const FACTION_AURELIA := "aurelia"
const FACTION_NOXFERA := "noxfera"
const WORLD_VERSION := 5
const AURELIA_CAPITAL := Vector2i(1, 10)
const NOXFERA_CAPITAL := Vector2i(18, 10)
const SANCTUARY_RADIUS := 2
const STARTING_RATIONS := 800
const COMBAT_FATIGUE_LIMIT := 85
const MAX_LOGISTICS_SECONDS := 8 * 60 * 60

var initialized := false
var faction := ""
var cells: Dictionary = {}
var army_position := Vector2i.ZERO
var captured_count := 0
var rations := STARTING_RATIONS
var army_fatigue := 0
var battle_stance := "balanced"
var garrisons: Dictionary = {}
var battle_reports: Array = []
var campaign_honor := 0
var army_wounds: Dictionary = {}
var last_logistics_unix := 0
var ration_fraction := 0.0
var honor_fraction := 0.0
var last_logistics_report: Dictionary = {}

static func safe_int(value: Variant, fallback := 0) -> int:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)):
		return int(clampf(float(value), -100000000000.0, 100000000000.0))
	return fallback

static func safe_float(value: Variant, fallback := 0.0) -> float:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)):
		return float(value)
	return fallback


func ensure_initialized(faction_id: String) -> void:
	if initialized and not cells.is_empty():
		if faction_id in [FACTION_AURELIA, FACTION_NOXFERA] and not faction.is_empty() and faction != faction_id:
			# Never reuse another faction's live campaign state. Main.gd restores the
			# correct per-faction snapshot before this guard is reached.
			initialize_new(faction_id)
			return
		if faction.is_empty() and faction_id in [FACTION_AURELIA, FACTION_NOXFERA]:
			faction = faction_id
		_enforce_sanctuary_ownership()
		return
	initialize_new(faction_id)

func initialize_new(faction_id: String) -> void:
	var preserved_rations: int = maxi(STARTING_RATIONS, rations)
	faction = faction_id if faction_id in [FACTION_AURELIA, FACTION_NOXFERA] else FACTION_AURELIA
	cells.clear()
	captured_count = 0
	rations = preserved_rations
	army_fatigue = 0
	battle_stance = "balanced"
	army_wounds.clear()
	last_logistics_unix = 0
	ration_fraction = 0.0
	honor_fraction = 0.0
	last_logistics_report.clear()
	garrisons.clear()
	battle_reports.clear()
	for y in HEIGHT:
		for x in WIDTH:
			var pos: Vector2i = Vector2i(x, y)
			cells[_key(pos)] = {
				"owner": FACTION_NEUTRAL,
				"type": _terrain_type_for(pos),
				"level": 1,
				"guard_level": 0
			}
	_seed_starting_territory(FACTION_AURELIA, AURELIA_CAPITAL)
	_seed_starting_territory(FACTION_NOXFERA, NOXFERA_CAPITAL)
	_set_type(AURELIA_CAPITAL, "capital")
	_set_type(NOXFERA_CAPITAL, "capital")
	_seed_landmarks()
	_seed_outer_provinces()
	_enforce_sanctuary_ownership()
	army_position = Vector2i(2, 10) if faction == FACTION_AURELIA else Vector2i(17, 10)
	initialized = true

func _terrain_type_for(pos: Vector2i) -> String:
	var value: int = (pos.x * 17 + pos.y * 31 + pos.x * pos.y * 3) % 19
	if value in [0, 1]:
		return "forest"
	if value == 2:
		return "hills"
	return "plain"

func _seed_starting_territory(owner: String, capital: Vector2i) -> void:
	for y in range(capital.y - 1, capital.y + 2):
		for x in range(capital.x - 1, capital.x + 2):
			var pos: Vector2i = Vector2i(x, y)
			if in_bounds(pos):
				_set_owner(pos, owner)

func _seed_landmarks() -> void:
	var landmarks: Dictionary = {
		Vector2i(4, 5): "mine",
		Vector2i(15, 14): "mine",
		Vector2i(4, 14): "forest_resource",
		Vector2i(15, 5): "forest_resource",
		Vector2i(7, 7): "ruins",
		Vector2i(12, 12): "ruins",
		Vector2i(7, 12): "fort",
		Vector2i(12, 7): "fort",
		Vector2i(9, 9): "citadel",
		Vector2i(10, 10): "citadel"
	}
	for pos in landmarks:
		_set_type(pos, str(landmarks[pos]))

func _seed_outer_provinces() -> void:
	# The original 20×20 heartland retains every coordinate. New provinces are
	# added without moving capitals, saved armies, routes or existing garrisons.
	for offset in [Vector2i.ZERO,Vector2i(20,0),Vector2i(0,20),Vector2i(20,20)]:
		var level:=1 if offset==Vector2i.ZERO else (3 if offset==Vector2i(20,20) else 2)
		for landmark in [[Vector2i(4,5),'mine'],[Vector2i(15,14),'mine'],[Vector2i(4,14),'forest_resource'],[Vector2i(15,5),'forest_resource'],[Vector2i(7,7),'ruins'],[Vector2i(12,12),'ruins'],[Vector2i(7,12),'fort'],[Vector2i(12,7),'fort'],[Vector2i(9,9),'citadel'],[Vector2i(10,10),'citadel']]:
			var cell: Vector2i=landmark[0]+offset
			_set_type(cell,landmark[1])
			cells[_key(cell)]['level']=level+(1 if landmark[1]=='citadel' else 0)
			cells[_key(cell)]['guard_level']=cells[_key(cell)]['level']

func province_name(pos: Vector2i) -> String:
	return ['서부 왕국','동부 변경','남부 연맹지','황혼 고원'][int(pos.x/20)+int(pos.y/20)*2] if in_bounds(pos) else ''

func neutral_guard_level(pos: Vector2i) -> int:
	return clampi(int(tile_at(pos).get('guard_level',0)),0,5) if tile_owner(pos)==FACTION_NEUTRAL else 0

func _set_type(pos: Vector2i, tile_type: String) -> void:
	if not in_bounds(pos):
		return
	var tile: Dictionary = cells[_key(pos)]
	tile["type"] = tile_type
	cells[_key(pos)] = tile

func _set_owner(pos: Vector2i, owner: String) -> void:
	if not in_bounds(pos):
		return
	var tile: Dictionary = cells[_key(pos)]
	tile["owner"] = owner
	cells[_key(pos)] = tile

func _key(pos: Vector2i) -> String:
	return "%d:%d" % [pos.x, pos.y]

func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < WIDTH and pos.y < HEIGHT

func tile_at(pos: Vector2i) -> Dictionary:
	if not in_bounds(pos):
		return {}
	return cells.get(_key(pos), {})

func tile_owner(pos: Vector2i) -> String:
	return str(tile_at(pos).get("owner", FACTION_NEUTRAL))

func tile_type(pos: Vector2i) -> String:
	return str(tile_at(pos).get("type", "plain"))

func capital_for(owner: String) -> Vector2i:
	return NOXFERA_CAPITAL if owner == FACTION_NOXFERA else AURELIA_CAPITAL

func distance_to_capital(pos: Vector2i, owner: String) -> int:
	var capital: Vector2i = capital_for(owner)
	return abs(pos.x - capital.x) + abs(pos.y - capital.y)

func is_sanctuary(pos: Vector2i, owner: String) -> bool:
	if owner not in [FACTION_AURELIA, FACTION_NOXFERA]:
		return false
	return distance_to_capital(pos, owner) <= SANCTUARY_RADIUS

func sanctuary_owner(pos: Vector2i) -> String:
	if is_sanctuary(pos, FACTION_AURELIA):
		return FACTION_AURELIA
	if is_sanctuary(pos, FACTION_NOXFERA):
		return FACTION_NOXFERA
	return FACTION_NEUTRAL

func _enforce_sanctuary_ownership() -> void:
	if cells.is_empty():
		return
	for y in HEIGHT:
		for x in WIDTH:
			var pos: Vector2i = Vector2i(x, y)
			var safe_owner: String = sanctuary_owner(pos)
			if safe_owner != FACTION_NEUTRAL:
				_set_owner(pos, safe_owner)
	_set_type(AURELIA_CAPITAL, "capital")
	_set_type(NOXFERA_CAPITAL, "capital")

func neighbors(pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var cardinal_offsets: Array[Vector2i] = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN
	]
	for offset in cardinal_offsets:
		var neighbor_pos: Vector2i = pos + offset
		if in_bounds(neighbor_pos):
			result.append(neighbor_pos)
	return result

func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return abs(a.x - b.x) + abs(a.y - b.y) == 1

func can_move_to(pos: Vector2i) -> bool:
	return in_bounds(pos) and is_adjacent(army_position, pos) and tile_owner(pos) == faction

func move_army(pos: Vector2i) -> bool:
	if not can_move_to(pos):
		return false
	army_position = pos
	return true

func can_capture_neutral(pos: Vector2i) -> bool:
	if not in_bounds(pos) or tile_owner(pos) != FACTION_NEUTRAL or neutral_guard_level(pos)>0:
		return false
	if sanctuary_owner(pos) != FACTION_NEUTRAL:
		return false
	if not is_adjacent(army_position, pos):
		return false
	for neighbor in neighbors(pos):
		if tile_owner(neighbor) == faction:
			return true
	return false

func capture_neutral(pos: Vector2i) -> bool:
	if not can_capture_neutral(pos):
		return false
	var tile: Dictionary = tile_at(pos).duplicate(true)
	tile["owner"] = faction
	cells[_key(pos)] = tile
	army_position = pos
	captured_count += 1
	return true

func enemy_faction() -> String:
	return FACTION_NOXFERA if faction == FACTION_AURELIA else FACTION_AURELIA

func owned_count(owner: String) -> int:
	var count: int = 0
	for value in cells.values():
		if str(value.get("owner", FACTION_NEUTRAL)) == owner:
			count += 1
	return count

func frontier_count(owner: String) -> int:
	var count: int = 0
	for y in HEIGHT:
		for x in WIDTH:
			var pos: Vector2i = Vector2i(x, y)
			if tile_owner(pos) != owner:
				continue
			for neighbor in neighbors(pos):
				if tile_owner(neighbor) != owner:
					count += 1
					break
	return count

func faction_balance_buff(owner: String) -> Dictionary:
	var enemy: String = FACTION_NOXFERA if owner == FACTION_AURELIA else FACTION_AURELIA
	var ours: int = maxi(1, owned_count(owner))
	var theirs: int = maxi(1, owned_count(enemy))
	var ratio: float = float(ours) / float(theirs)
	var tier: int = 0
	if ratio <= 0.45:
		tier = 3
	elif ratio <= 0.65:
		tier = 2
	elif ratio <= 0.85:
		tier = 1
	var names: Array[String] = ["균형", "저항 I", "저항 II", "최후의 저항"]
	var speed_values: Array[float] = [1.0, 1.10, 1.20, 1.30]
	var ration_values: Array[float] = [1.0, 0.90, 0.80, 0.70]
	var defense_values: Array[float] = [1.0, 1.10, 1.18, 1.28]
	var resource_values: Array[float] = [1.0, 1.05, 1.10, 1.18]
	var shield_values: Array[int] = [SANCTUARY_RADIUS, SANCTUARY_RADIUS, 4, 5]
	var speed: float = speed_values[tier]
	var ration: float = ration_values[tier]
	var defense: float = defense_values[tier]
	var resource: float = resource_values[tier]
	var shield_radius: int = shield_values[tier]
	return {
		"tier": tier,
		"name": names[tier],
		"territory_ratio": ratio,
		"march_speed_multiplier": speed,
		"ration_cost_multiplier": ration,
		"defense_multiplier": defense,
		"resource_multiplier": resource,
		"protected_radius": shield_radius
	}

func is_emergency_protected(pos: Vector2i, defending_faction: String) -> bool:
	if defending_faction not in [FACTION_AURELIA, FACTION_NOXFERA]:
		return false
	var buff: Dictionary = faction_balance_buff(defending_faction)
	var radius: int = int(buff.get("protected_radius", SANCTUARY_RADIUS))
	if int(buff.get("tier", 0)) < 2:
		return false
	return distance_to_capital(pos, defending_faction) <= radius

func is_protected_from_enemy(pos: Vector2i, attacker_faction: String) -> bool:
	var defender: String = tile_owner(pos)
	if defender == FACTION_NEUTRAL or defender == attacker_faction:
		return false
	if is_sanctuary(pos, defender):
		return true
	return is_emergency_protected(pos, defender)

func can_attack_enemy_tile(attacker_faction: String, pos: Vector2i) -> bool:
	if not in_bounds(pos) or attacker_faction not in [FACTION_AURELIA, FACTION_NOXFERA]:
		return false
	if attacker_faction == faction and army_fatigue >= COMBAT_FATIGUE_LIMIT:
		return false
	var defender: String = tile_owner(pos)
	if defender == FACTION_NEUTRAL or defender == attacker_faction:
		return false
	return not is_protected_from_enemy(pos, attacker_faction)

func can_launch_combat() -> bool:
	return army_fatigue < COMBAT_FATIGUE_LIMIT

func _march_tile_allowed(pos: Vector2i, target: Vector2i) -> bool:
	var owner: String = tile_owner(pos)
	if pos == target:
		if owner == faction or owner == FACTION_NEUTRAL:
			return true
		if owner == enemy_faction():
			return can_attack_enemy_tile(faction, pos)
		return false
	return owner == faction

func find_march_path(target: Vector2i) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if not in_bounds(target):
		return empty
	var target_owner: String = tile_owner(target)
	if target_owner == enemy_faction() and not can_attack_enemy_tile(faction, target):
		return empty
	if sanctuary_owner(target) != FACTION_NEUTRAL and sanctuary_owner(target) != faction:
		return empty
	if target == army_position:
		var stationary: Array[Vector2i] = [army_position]
		return stationary
	var queue: Array[Vector2i] = [army_position]
	var visited: Dictionary = {_key(army_position): true}
	var previous: Dictionary = {}
	var found: bool = false
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for next in neighbors(current):
			var key: String = _key(next)
			if visited.has(key) or not _march_tile_allowed(next, target):
				continue
			visited[key] = true
			previous[key] = current
			if next == target:
				found = true
				queue.clear()
				break
			queue.append(next)
	if not found:
		return empty
	var reversed_path: Array[Vector2i] = [target]
	var cursor: Vector2i = target
	while cursor != army_position:
		var prev = previous.get(_key(cursor), null)
		if prev == null:
			return empty
		cursor = prev
		reversed_path.append(cursor)
	reversed_path.reverse()
	return reversed_path

func garrison_at(pos: Vector2i) -> Array:
	var data = garrisons.get(_key(pos), [])
	if typeof(data) != TYPE_ARRAY:
		return []
	return data.duplicate(true)

func set_garrison(pos: Vector2i, squad: Array) -> void:
	if not in_bounds(pos):
		return
	garrisons[_key(pos)] = squad.duplicate(true)

func clear_garrison(pos: Vector2i) -> void:
	garrisons.erase(_key(pos))

func capture_enemy_after_battle(pos: Vector2i, attacker_faction: String) -> bool:
	if attacker_faction != faction or not can_attack_enemy_tile(attacker_faction, pos):
		return false
	_set_owner(pos, attacker_faction)
	clear_garrison(pos)
	army_position = pos
	captured_count += 1
	return true

func add_fatigue(amount: int) -> void:
	army_fatigue = clampi(army_fatigue + amount, 0, 100)

func recover_fatigue(amount: int) -> void:
	army_fatigue = clampi(army_fatigue - amount, 0, 100)

func fatigue_multiplier() -> float:
	return 1.0 - minf(0.30, float(army_fatigue) * 0.003)

func record_battle_report(report: Dictionary) -> void:
	if report.is_empty():
		return
	battle_reports.push_front(report.duplicate(true))
	while battle_reports.size() > 10:
		battle_reports.pop_back()

func latest_battle_report() -> Dictionary:
	if battle_reports.is_empty():
		return {}
	return battle_reports[0].duplicate(true)

func apply_march_arrival(target: Vector2i, action: String, guardians_defeated: bool = false) -> bool:
	if not in_bounds(target):
		return false
	if action == "move":
		if tile_owner(target) != faction:
			return false
		army_position = target
		if target == capital_for(faction):
			recover_fatigue(35)
			army_wounds.clear()
		return true
	if action == "attack_enemy":
		return can_attack_enemy_tile(faction, target)
	if action == "capture_neutral":
		if neutral_guard_level(target)>0 and not guardians_defeated:return false
		if tile_owner(target) != FACTION_NEUTRAL or sanctuary_owner(target) != FACTION_NEUTRAL:
			return false
		var valid_border: bool = false
		for neighbor in neighbors(target):
			if tile_owner(neighbor) == faction:
				valid_border = true
				break
		if not valid_border:
			return false
		_set_owner(target, faction)
		army_position = target
		captured_count += 1
		return true
	return false

func consume_rations(amount: int) -> bool:
	var safe_amount: int = maxi(0, amount)
	if rations < safe_amount:
		return false
	rations -= safe_amount
	return true

func add_rations(amount: int) -> void:
	rations = maxi(0, rations + amount)

func tile_display_name(pos: Vector2i) -> String:
	var names: Dictionary = {
		"plain": "평원",
		"forest": "숲",
		"hills": "구릉",
		"mine": "수정 광산",
		"forest_resource": "마력 숲",
		"ruins": "고대 유적",
		"fort": "전선 요새",
		"capital": "진영 수도",
		"citadel": "중앙 대성"
	}
	return str(names.get(tile_type(pos), "미개척지"))

func tile_resource_text(pos: Vector2i) -> String:
	match tile_type(pos):
		"mine":
			return "군량 +5/분 · 보급 단절 시 25%"
		"forest_resource":
			return "군량 +8/분 · 보급 단절 시 25%"
		"ruins":
			return "전쟁 명예 +1/분 · 보급 단절 시 25%"
		"fort":
			return "요새 방어 +18% · 인접 아군 방어 +6%"
		"capital":
			return "점령 불가 · 군량 +2/분 · 귀환 시 부상 회복"
		"citadel":
			return "시즌 핵심 점령지"
		_:
			return "일반 영토"

func protection_text(pos: Vector2i) -> String:
	var owner: String = tile_owner(pos)
	if owner == FACTION_NEUTRAL:
		var safe_owner: String = sanctuary_owner(pos)
		if safe_owner != FACTION_NEUTRAL:
			return "진영 안전지대"
		return ""
	if is_sanctuary(pos, owner):
		return "수도 안전지대 · 적 점령 불가"
	if is_emergency_protected(pos, owner):
		return "최후 방어선 활성 · 적 점령 불가"
	return ""

func logistics_rates(supply: WorldSupplyNetwork) -> Dictionary:
	var ration_rate := 2.0
	var honor_rate := 0.0
	var connected := supply.connected_keys(self, faction)
	for key in cells:
		var tile: Dictionary = cells[key]
		if str(tile.get("owner", "")) != faction:
			continue
		var efficiency := 1.0 if connected.has(key) else 0.25
		match str(tile.get("type", "")):
			"mine": ration_rate += 5.0 * efficiency
			"forest_resource": ration_rate += 8.0 * efficiency
			"ruins": honor_rate += efficiency
	var multiplier := float(faction_balance_buff(faction).get("resource_multiplier", 1.0))
	return {"rations_per_minute": ration_rate * multiplier, "honor_per_minute": honor_rate * multiplier}

func advance_logistics(now_unix: int, supply: WorldSupplyNetwork, production_active := true) -> Dictionary:
	if last_logistics_unix <= 0:
		last_logistics_unix = maxi(1, now_unix)
		return {}
	if now_unix <= last_logistics_unix or supply == null:
		return {}
	var elapsed := mini(MAX_LOGISTICS_SECONDS, now_unix - last_logistics_unix)
	# Consume the complete interval even above the offline cap or during settlement.
	last_logistics_unix = now_unix
	if not production_active:
		return {}
	var rates := logistics_rates(supply)
	ration_fraction += float(elapsed) / 60.0 * float(rates["rations_per_minute"])
	honor_fraction += float(elapsed) / 60.0 * float(rates["honor_per_minute"])
	var earned_rations := int(floor(ration_fraction))
	var earned_honor := int(floor(honor_fraction))
	ration_fraction -= earned_rations
	honor_fraction -= earned_honor
	add_rations(earned_rations)
	campaign_honor += earned_honor
	last_logistics_report = {"seconds": elapsed, "rations": earned_rations, "honor": earned_honor}
	return last_logistics_report.duplicate(true)

func record_army_wounds(original_squad: Array, survivor_squad: Array) -> void:
	for unit in original_squad:
		if typeof(unit) == TYPE_DICTIONARY:
			army_wounds[str(unit.get("id", ""))] = 0.0
	for unit in survivor_squad:
		if typeof(unit) == TYPE_DICTIONARY:
			army_wounds[str(unit.get("id", ""))] = clampf(float(unit.get("hp", 0)) / maxf(1.0, float(unit.get("max_hp", 1))), 0.0, 1.0)

func export_state() -> Dictionary:
	return {
		"world_version": WORLD_VERSION,
		"initialized": initialized,
		"faction": faction,
		"army_position": [army_position.x, army_position.y],
		"captured_count": captured_count,
		"rations": rations,
		"army_fatigue": army_fatigue,
		"battle_stance": battle_stance,
		"garrisons": garrisons.duplicate(true),
		"battle_reports": battle_reports.duplicate(true),
		"cells": cells.duplicate(true),
		"campaign_honor": campaign_honor,
		"army_wounds": army_wounds.duplicate(true),
		"last_logistics_unix": last_logistics_unix,
		"ration_fraction": ration_fraction,
		"honor_fraction": honor_fraction
	}

func import_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	var loaded_cells = data.get("cells", {})
	if typeof(loaded_cells) != TYPE_DICTIONARY or loaded_cells.is_empty():
		return
	var loaded_faction := str(data.get("faction", FACTION_AURELIA))
	initialize_new(loaded_faction)
	# Reconstruct the complete grid before overlaying known, validated cells.
	var terrain_types := ["plain", "forest", "hills", "mine", "forest_resource", "ruins", "fort", "capital", "citadel"]
	for key in cells:
		if not loaded_cells.has(key):continue
		var raw = loaded_cells.get(key, {})
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var tile: Dictionary = cells[key]
		var owner := str(raw.get("owner", FACTION_NEUTRAL))
		tile["owner"] = owner if owner in [FACTION_AURELIA, FACTION_NOXFERA, FACTION_NEUTRAL] else FACTION_NEUTRAL
		var terrain := str(raw.get("type", tile["type"]))
		if terrain in terrain_types:
			tile["type"] = terrain
		tile["level"] = clampi(safe_int(raw.get("level", 1), 1), 1, 100)
		tile["guard_level"] = clampi(safe_int(raw.get("guard_level",0)),0,5)
	captured_count = maxi(0, safe_int(data.get("captured_count", 0)))
	rations = clampi(safe_int(data.get("rations", STARTING_RATIONS), STARTING_RATIONS), 0, 1000000000)
	army_fatigue = clampi(safe_int(data.get("army_fatigue", 0)), 0, 100)
	battle_stance = str(data.get("battle_stance","balanced"))
	if battle_stance not in ["balanced","assault","guard"]:battle_stance="balanced"
	campaign_honor = clampi(safe_int(data.get("campaign_honor", 0)), 0, 1000000000)
	last_logistics_unix = maxi(0, safe_int(data.get("last_logistics_unix", 0)))
	ration_fraction = clampf(safe_float(data.get("ration_fraction", 0.0)), 0.0, 0.999999)
	honor_fraction = clampf(safe_float(data.get("honor_fraction", 0.0)), 0.0, 0.999999)
	var wounds = data.get("army_wounds", {})
	if typeof(wounds) == TYPE_DICTIONARY:
		for hero_id in wounds.keys().slice(0, 100):
			army_wounds[str(hero_id)] = clampf(safe_float(wounds[hero_id], 1.0), 0.0, 1.0)
	var loaded_garrisons = data.get("garrisons", {})
	if typeof(loaded_garrisons) == TYPE_DICTIONARY:
		for key in cells:
			var raw = loaded_garrisons.get(key, [])
			if typeof(raw) == TYPE_ARRAY and not raw.is_empty():
				garrisons[key] = WorldBattleResolver.new()._clone_squad(raw.slice(0, 10))
	var loaded_reports = data.get("battle_reports", [])
	if typeof(loaded_reports) == TYPE_ARRAY:
		for report in loaded_reports.slice(0, 10):
			if typeof(report) == TYPE_DICTIONARY:
				battle_reports.append(report.duplicate(true))
	var pos = data.get("army_position", [0, 0])
	if typeof(pos) == TYPE_ARRAY and pos.size() >= 2:
		army_position = Vector2i(safe_int(pos[0]), safe_int(pos[1]))
	_enforce_sanctuary_ownership()
	if not in_bounds(army_position) or tile_owner(army_position) != faction:
		army_position = Vector2i(2, 10) if faction == FACTION_AURELIA else Vector2i(17, 10)
