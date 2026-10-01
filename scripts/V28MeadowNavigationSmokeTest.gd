extends SceneTree

const Navigation = preload("MeadowNavigation.gd")
var failures: Array[String] = []
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _walk_case(nav: RefCounted, key: String, start: Vector2, target: Vector2) -> void:
	var position := start
	var goal: Vector2 = nav.clamp_to_walkable(target)
	var speed_ok := true
	var walkable := true
	var segment_clear := true
	var total_distance := 0.0
	var ticks := 0
	for tick in range(1400):
		ticks = tick + 1
		var next: Vector2 = nav.move_toward(key, position, target, 0.117)
		speed_ok = speed_ok and next.distance_to(position) <= 0.11701
		walkable = walkable and nav.is_walkable(next)
		for sample in range(1, 9):
			segment_clear = segment_clear and nav.is_walkable(position.lerp(next, float(sample) / 8.0))
		total_distance += position.distance_to(next)
		position = next
		if position.distance_to(goal) < 0.02:
			break
	_check(position.distance_to(goal) < 0.02, "%s reaches target after %s ticks, remaining %.3f" % [key, ticks, position.distance_to(goal)])
	_check(speed_ok, "%s respects movement speed" % key)
	_check(walkable and segment_clear, "%s never crosses a pond or tree cluster" % key)
	_check(total_distance >= start.distance_to(goal) - 0.01, "%s has continuous world movement" % key)

func _run() -> void:
	var nav := Navigation.new()
	_check(nav.is_walkable(Vector2(16, 10)), "Spawn clearing is walkable")
	_check(not nav.is_walkable(Vector2(31.55, 0.35)), "Sealed northeast corner cannot trap a new spawn")
	_check(nav.is_walkable(nav.clamp_to_walkable(Vector2(31.55, 0.35))), "Sealed corner spawns relocate into the connected map")
	_check(not nav.is_walkable(Vector2(-1, 10)), "World bounds reject out-of-map points")
	_check(not nav.is_walkable(Vector2(17.5, 2.9)), "Observed combat position inside the eastern tree is blocked")
	_check(not nav.is_walkable(Vector2(18.25, 1.90)), "Eastern canopy center from the captured world position is blocked")
	for obstacle in Navigation.OBSTACLES:
		_check(not nav.is_walkable(obstacle[0]), "Each painted obstacle blocks its center")
		_check(nav.is_walkable(nav.clamp_to_walkable(obstacle[0])), "Obstacle spawn correction returns walkable space")
	_walk_case(nav, "pond", Vector2(6.9, 1.2), Vector2(6.9, 6.4))
	_walk_case(nav, "trees", Vector2(19.9, 4.8), Vector2(19.9, 9.3))
	_walk_case(nav, "upper_eastern_tree", Vector2(15.8, 1.6), Vector2(20.3, 1.6))
	_walk_case(nav, "east_trees", Vector2(24.9, 8.8), Vector2(24.9, 14.4))
	_walk_case(nav, "long_trip", Vector2(1, 1), Vector2(29, 19))
	_walk_case(nav, "blocked_goal", Vector2(16, 10), Vector2(27.68, 14.28))
	_check(int(nav.get_debug_stats()["astar_queries"]) <= 10, "Static destinations retain cached AStar routes")
	var from := Vector2(6.9, 3.6)
	var recovered: Vector2 = nav.move_toward("old_save", from, Vector2(16, 10), 0.10)
	_check(from.distance_to(recovered) <= 0.10001, "Legacy obstacle recovery cannot teleport")
	_check(nav.move_toward("paused", Vector2(16, 10), Vector2(20, 10), 0.0) == Vector2(16, 10), "Paused actor remains in place")
	nav.set_enabled(false)
	_check(nav.is_walkable(Vector2(6.9, 3.6)), "Other maps do not inherit meadow collisions")
	var direct: Vector2 = nav.move_toward("other_map", Vector2(6.9, 1.2), Vector2(6.9, 6.4), 0.1)
	_check(direct.distance_to(Vector2(6.9, 1.3)) < 0.0001, "Disabled navigation moves directly")
	nav.set_enabled(true)
	nav.move_toward("retired", Vector2(6.9, 1.2), Vector2(6.9, 6.4), 0.1)
	nav.forget_actor("retired")
	_check(not nav._routes.has("retired"), "Despawning actors release their cached route")
	print("V28MeadowNavigationSmokeTest: %s assertions, %s failures, %s" % [assertions, failures.size(), nav.get_debug_stats()])
	quit(0 if failures.is_empty() else 1)
