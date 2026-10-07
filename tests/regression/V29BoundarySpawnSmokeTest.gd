extends SceneTree

func _init() -> void:
	var nav = preload("res://scripts/hunting/MeadowNavigation.gd").new()
	var pocket := Vector2(31.65,1.499524)
	if nav.is_walkable(pocket):
		push_error("Sealed eastern tree pocket is not connected to the hunting field")
		quit(1)
		return
	var spawn: Vector2 = nav.clamp_to_walkable(pocket)
	var hero := Vector2(29.95,1.05)
	if not nav.is_walkable(spawn):
		push_error("Boundary spawn must project into the connected field")
		quit(1)
		return
	for tick in 300:
		var before := hero
		hero = nav.move_toward("boundary_hunter",hero,spawn,.10)
		if before.distance_to(hero) > .10001 or not nav.is_walkable(hero):
			push_error("Boundary approach must remain walkable and speed-bounded")
			quit(1)
			return
		if hero.distance_to(spawn) < .8: break
	if hero.distance_to(spawn) >= .8:
		push_error("A melee hero must reach a monster projected out of the pocket")
		quit(1)
		return
	print("v29_boundary_spawn_smoke_test_ok spawn=",spawn," melee_distance=",hero.distance_to(spawn))
	quit(0)
