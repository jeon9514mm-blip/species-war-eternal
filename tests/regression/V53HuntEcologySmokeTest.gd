extends SceneTree

const Navigation = preload("res://scripts/hunting/MeadowNavigation.gd")
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _defender(archetype: String, leash: float, navigation: RefCounted = null) -> RoamingHuntDirector:
	var director := RoamingHuntDirector.new()
	director.field_navigation = navigation
	director.configure(Vector2(18.05, 10), 53)
	director.spawn_group([{"archetype":archetype, "leash_radius":leash, "sight_radius":2.8}])
	director.enemy_home_positions[0] = Vector2(16, 10)
	director.enemy_positions[0] = Vector2(16 + leash - 0.05, 10)
	director.enemy_alerted[0] = true
	director.current_target = 0
	director.aggro_active = true
	director.mode = RoamingHuntDirector.Mode.ENGAGED
	return director

func _test_defensive_retreat() -> void:
	# Keep a melee pursuer on the same side of the monster. Previously the
	# monster crossed its own leash while retreating, healed on return, and
	# repeated the cycle even though the player never pulled it out of habitat.
	for archetype in ["ranged", "support"]:
		for leash in [2.75, 3.05]:
			for delta in [0.03, 0.12, 0.36]:
				var director := _defender(archetype, leash)
				var resets := 0
				var bounded := true
				var no_snap := true
				for tick in ceili(60.0 / delta):
					var before := director.enemy_position(0)
					var hero := before - Vector2(0.65, 0)
					director.party_position = hero
					var result := director.advance(delta, [true], [], [hero])
					resets += result["returned_indices"].size()
					bounded = bounded and director.enemy_position(0).distance_to(director.enemy_home_positions[0]) <= leash + 0.00001
					no_snap = no_snap and before.distance_to(director.enemy_position(0)) <= RoamingHuntDirector.MONSTER_CHASE_SPEED * 1.5 * delta + 0.00001
				_check(resets == 0, "Defensive retreat cannot manufacture health resets %s leash=%.2f delta=%.2f" % [archetype, leash, delta])
				_check(bounded and no_snap, "Defensive retreat remains in its habitat with bounded movement")
	# Ranged defenders must still make space while there is room inside home.
	for archetype in ["ranged", "support"]:
		var director := _defender(archetype, 2.75)
		director.enemy_positions[0] = director.enemy_home_positions[0]
		director.party_position = director.enemy_position(0) - Vector2(0.65, 0)
		var before := director.enemy_position(0)
		director.advance(0.1, [true], [], [director.party_position])
		_check(director.enemy_position(0).x > before.x, "Defender still retreats when its habitat has room: " + archetype)

func _test_return_budget_and_events() -> void:
	for delta in [0.001, 0.01, 1.0 / 60.0, 0.12, 0.36]:
		var director := _defender("ranged", 2.75)
		director.enemy_positions[0] = director.enemy_home_positions[0] + Vector2(0.085, 0)
		director.enemy_returning[0] = true
		var events := 0
		var bounded := true
		for tick in 200:
			var before := director.enemy_position(0)
			var result := director.advance(delta, [true])
			bounded = bounded and before.distance_to(director.enemy_position(0)) <= RoamingHuntDirector.MONSTER_CHASE_SPEED * 1.5 * delta + 0.00001
			events += result["returned_indices"].size()
			if events > 0:
				break
		_check(bounded, "Return cannot snap over its movement budget delta=%.3f" % delta)
		_check(events == 1 and director.enemy_position(0).distance_to(director.enemy_home_positions[0]) <= 0.00001 and not director.is_returning(0), "Return reaches home and emits exactly one completion")
		# A zero-time or following short update cannot award another reset.
		var result := director.advance(0.0, [true])
		_check(result["returned_indices"].is_empty(), "Completed return is consumed once")
	# Deliberate pulling still releases combat and genuinely returns home.
	var pulled := _defender("brute", 2.75)
	pulled.enemy_positions[0] = Vector2(19.1, 10)
	pulled.party_position = Vector2(20, 10)
	var first := pulled.advance(0.1, [true])
	_check(pulled.is_returning(0) and int(first["target_index"]) == -1 and not bool(first["engaged"]), "An actual pull still resets combat and makes its returning target ineligible")
	var completions := 0
	for tick in 100:
		var result := pulled.advance(0.1, [true])
		completions += result["returned_indices"].size()
		if completions > 0:
			break
	_check(completions == 1, "An actual pull still reaches home")

func _test_terrain_and_pause() -> void:
	var nav := Navigation.new()
	for archetype in ["ranged", "support"]:
		var director := _defender(archetype, 2.75, nav)
		var valid := true
		for tick in 180:
			var before := director.enemy_position(0)
			var hero := nav.clamp_to_walkable(before - Vector2(0.65, 0))
			director.party_position = hero
			director.advance(0.12, [true], [], [hero])
			valid = valid and nav.is_walkable(director.enemy_position(0)) and nav.has_clear_path(before, director.enemy_position(0)) and not director.is_returning(0)
		_check(valid, "Navigation keeps defensive retreat traversable and inside habitat: " + archetype)
		director.mode = RoamingHuntDirector.Mode.RECOVER
		var frozen := director.enemy_position(0)
		for tick in 10:
			director.advance(0.36, [true])
		_check(director.enemy_position(0) == frozen, "Recovery still freezes enemy movement at accelerated game speed")

func _run() -> void:
	_test_defensive_retreat()
	_test_return_budget_and_events()
	_test_terrain_and_pause()
	print("V53HuntEcologySmokeTest: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
