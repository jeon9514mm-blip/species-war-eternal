extends SceneTree

const NAV = preload("res://scripts/MeadowNavigation.gd")
const PARTY = preload("res://scripts/PartyMovementDirector.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _chase(nav: RefCounted, start: Vector2, target: Vector2, hero_id := "leonhardt", attack_range := 1) -> Dictionary:
	var party := PARTY.new()
	party.field_navigation = nav
	var heroes: Array = [{"id":hero_id}]
	var states := {hero_id:{"hp":100,"max_hp":100,"range":attack_range,"role_group":"딜러","ai_style":"balanced"}}
	var enemies: Array = [{"hp":1000,"max_hp":1000,"row":0}]
	var enemy_positions: Array[Vector2] = [target]
	party.configure(heroes, states, start)
	party.positions[hero_id] = start
	var previous := start
	var safe := true
	var reached := false
	var ticks := 0
	for tick in 300:
		var delta: float = [.025, .06, .12][tick % 3]
		party.advance(delta, heroes, states, {}, start, enemies, enemy_positions, [], true)
		var current: Vector2 = party.positions[hero_id]
		safe = safe and nav.is_walkable(current) and nav.has_clear_path(previous, current) and current.distance_to(previous) <= PARTY.WALK_SPEED * delta + .00001
		previous = current
		ticks = tick + 1
		if current.distance_to(target) <= CombatDecisionEngine.new().spatial_range(attack_range):
			reached = true
			break
	return {"safe":safe,"reached":reached,"end":previous,"ticks":ticks}

func _run() -> void:
	var nav := NAV.new()
	var target := Vector2(7.920615, 13.505)
	for start in [Vector2(6.05,11.84), Vector2(7.13,11.98871), Vector2(7.920615,12.395)]:
		var result := _chase(nav, start, target)
		check(bool(result["reached"]), "Melee can round the tree into attack range from %s; end %s" % [start, result["end"]])
		check(bool(result["safe"]), "Melee tree approach stays walkable and speed limited from %s" % start)
	# Check the approach/standoff integration at many sides of every painted
	# obstacle, rather than only asking navigation to reach an exact point.
	var cases := 0
	var stalled: Array[String] = []
	var safe := true
	for obstacle in NAV.OBSTACLES:
		for angle in 12:
			for gap in [2,3,4]:
				var center: Vector2 = obstacle[0]
				var radius: Vector2 = obstacle[1] + Vector2.ONE * .3
				var start: Vector2 = center + Vector2.from_angle(float(angle) * TAU / 12.0) * radius
				var goal: Vector2 = center + Vector2.from_angle(float(angle + gap) * TAU / 12.0) * radius
				if not nav.is_walkable(start) or not nav.is_walkable(goal) or start.distance_to(goal) < .95:
					continue
				var result := _chase(nav, start, goal)
				cases += 1
				safe = safe and bool(result["safe"])
				if not bool(result["reached"]):
					stalled.append("%s -> %s stops at %s" % [start, goal, result["end"]])
	check(cases >= 500, "Obstacle coverage includes at least five hundred approach directions")
	check(stalled.is_empty(), "Melee approach/standoff never stalls around the obstacle map: %s" % str(stalled))
	check(safe, "All obstacle approaches retain terrain clearance and variable-frame speed limits")
	for start in [Vector2(6.9,1.2),Vector2(24.9,8.8),Vector2(19.9,4.8)]:
		var goal: Vector2 = start + Vector2(0,5.2)
		var result := _chase(nav,start,goal,"mira",3)
		check(bool(result["reached"]) and bool(result["safe"]), "Ranged approach still reaches firing range after terrain detour %s" % start)
	print("V53HuntNavigationSmokeTest: %d checks, %d failures, %d terrain approach cases" % [checks,failures.size(),cases])
	quit(0 if failures.is_empty() else 1)
