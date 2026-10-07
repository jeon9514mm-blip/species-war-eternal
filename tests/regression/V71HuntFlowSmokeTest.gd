extends SceneTree

const NAV = preload("res://scripts/hunting/MeadowNavigation.gd")
const TERRAIN = preload("res://scripts/maps/FieldTerrainCatalog.gd")
const PARTY = preload("res://scripts/hunting/PartyMovementDirector.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _enemy(index: int, elite := false) -> Dictionary:
	return {"id":"e%d" % index,"hp":1000,"max_hp":1000,"attack":50,"row":0,"archetype":["brute","ranged","support","assassin"][index % 4],"sight_radius":2.4,"leash_radius":2.9,"elite":elite}

func _state(slot: int) -> Dictionary:
	return {"hp":1000,"max_hp":1000,"alive":true,"range":3,"role_group":"딜러","ai_style":"balanced","slot":slot,"row":"middle"}

func _run() -> void:
	_test_zone_habitats()
	_test_pack_assist_and_separation()
	_test_party_target_distribution()
	print("V71HuntFlowSmokeTest: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_zone_habitats() -> void:
	for zone_id in TERRAIN.ZONE_IDS:
		var nav := NAV.new()
		nav.configure_zone(zone_id)
		var anchors := TERRAIN.hunt_pack_anchors(zone_id)
		_check(anchors.size() >= 5, "Each zone exposes at least five authored hunt habitats: " + zone_id)
		var all_walkable := true
		for point in anchors:
			all_walkable = all_walkable and nav.is_walkable(nav.clamp_to_walkable(point))
		_check(all_walkable, "Authored hunt habitats project onto navigable ground: " + zone_id)
		var director := RoamingHuntDirector.new()
		director.field_navigation = nav
		director.configure(Vector2(16,10), 7100 + zone_id.hash(), zone_id)
		var enemies: Array = []
		for index in 20:
			enemies.append(_enemy(index, index == 0))
		director.spawn_group(enemies)
		_check(director.pack_centers.size() >= 4, "Twenty monsters distribute into four or more local packs: " + zone_id)
		var separated := true
		for left in director.pack_centers.size():
			for right in range(left + 1, director.pack_centers.size()):
				separated = separated and director.pack_centers[left].distance_to(director.pack_centers[right]) >= 2.7
		_check(separated, "Habitat packs remain spatially distinct: " + zone_id)

func _test_pack_assist_and_separation() -> void:
	var director := RoamingHuntDirector.new()
	director.configure(Vector2(16,10), 71, "gray_meadow")
	director.spawn_group([_enemy(0), _enemy(1), _enemy(2)])
	for index in 3:
		director.enemy_positions[index] = Vector2(18.0 + float(index) * 0.03, 10.0)
		director.enemy_home_positions[index] = director.enemy_positions[index]
		director.enemy_sight_ranges[index] = 0.45
	director.current_target = 0
	director.aggro_active = true
	director.mode = RoamingHuntDirector.Mode.ENGAGED
	var before := director.enemy_positions.duplicate()
	director.advance(0.1, [true,true,true], [], [Vector2(16,10),Vector2(16,10),Vector2(16,10)])
	_check(director.enemy_pack_ids[0]==director.enemy_pack_ids[1] and director.enemy_pack_ids[0]!=director.enemy_pack_ids[2], "Small populations use the current two-member habitat packs")
	_check(bool(director.enemy_alerted[1]) and not bool(director.enemy_alerted[2]), "A directly engaged monster alerts its own pack without waking another habitat")
	var spread_before := Vector2(before[0]).distance_to(Vector2(before[1]))
	var spread_after := director.enemy_positions[0].distance_to(director.enemy_positions[1])
	_check(spread_after > spread_before, "Crowded monsters separate instead of occupying one point")

func _test_party_target_distribution() -> void:
	var party := PARTY.new()
	var center := Vector2(16,10)
	var ids: Array[String] = ["mira","kairen","orwin","seria","astel","darius","lunea","caelum","rokan","elisia"]
	var heroes: Array = []
	var states: Dictionary = {}
	for index in ids.size():
		heroes.append({"id":ids[index]})
		states[ids[index]] = _state(index)
	party.configure(heroes, states, center)
	var enemies: Array = []
	var enemy_positions: Array[Vector2] = []
	for index in 5:
		enemies.append(_enemy(index))
		enemy_positions.append(center + Vector2.from_angle(float(index) * TAU / 5.0) * 1.15)
	for id in ids:
		var choice := party._select_target(id, center, enemies, enemy_positions, [], states[id], states, party.positions, {})
		party.targets[id] = choice
	var max_load := 0
	var used := {}
	for id in ids:
		var target := int(party.targets[id])
		used[target] = int(used.get(target, 0)) + 1
		max_load = maxi(max_load, int(used[target]))
	_check(used.size() >= 4, "Ten ordinary damage heroes distribute across several reachable enemies")
	_check(max_load <= 3, "Ordinary targets avoid extreme hero dog-piling")
