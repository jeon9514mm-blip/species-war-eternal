extends SceneTree
const NAV = preload('res://scripts/hunting/MeadowNavigation.gd')
const PARTY = preload('res://scripts/hunting/PartyMovementDirector.gd')
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(condition: bool, label: String) -> void:
	checks+=1
	if not condition:
		failures.append(label)
		push_error(label)
func run() -> void:
	var nav:=NAV.new()
	var origin:=Vector2(6.9,1.2)
	var across:=Vector2(6.9,6.4)
	var clear:=Vector2(12.5,1.2)
	check(origin.distance_to(across)<origin.distance_to(clear),'fixture: straight-line nearest is across the pond')
	check(nav.travel_distance(origin,across)>nav.travel_distance(origin,clear),'target ranking accounts for the pond detour')
	var queries: int=nav.get_debug_stats()['distance_queries']
	for i in 50: nav.travel_distance(origin,across)
	check(nav.get_debug_stats()['distance_queries']==queries,'unchanged path distance reuses its cache')
	var party:=PARTY.new()
	party.field_navigation=nav
	var heroes: Array=[{'id':'one'},{'id':'two'}]
	var states: Dictionary={'one':{'hp':10,'slot':0},'two':{'hp':10,'slot':1}}
	party.configure(heroes,states,origin)
	var enemies: Array=[{'hp':10},{'hp':10}]
	var enemy_positions: Array[Vector2]=[across,clear]
	check(party._select_target('one',origin,enemies,enemy_positions,[])==1,'hero prefers the reachable target')
	var roaming:=RoamingHuntDirector.new()
	roaming.field_navigation=nav
	roaming.configure(origin,47)
	roaming.enemy_positions=enemy_positions
	check(roaming.nearest_alive_enemy([true,true])==1,'party anchor uses the same terrain-aware choice')
	party.positions={'one':Vector2(16,10),'two':Vector2(16,10)}
	party.travel_offsets={'one':Vector2.ZERO,'two':Vector2.ZERO}
	party.target_locks={'one':.45,'two':.45}
	var before: Dictionary=party.positions.duplicate()
	party.advance(.1,heroes,states,{},Vector2(16,10),[],[],[],false,true)
	check(party.positions==before and is_equal_approx(party.target_locks['one'],.45),'pause freezes movement and target lock timers')
	party.advance(.1,heroes,states,{},Vector2(16,10),[],[],[],false)
	check(Vector2(party.positions['one']).distance_to(party.positions['two'])>.01,'coincident heroes separate without a random teleport')
	for id in party.positions:
		check(Vector2(party.positions[id]).distance_to(before[id])<=PARTY.WALK_SPEED*.1+.00001,'separation respects hero speed '+id)
	for invalid in [NAN,INF,-INF]:
		check(nav.move_toward('invalid',origin,clear,invalid)==origin,'invalid frame budget leaves position intact')
		check(nav.move_toward('invalid',origin,Vector2(invalid,1),.1)==origin,'invalid destination leaves position intact')
	var rng:=RandomNumberGenerator.new()
	rng.seed=47047
	var total_steps:=0
	for route in 24:
		var position: Vector2=nav.clamp_to_walkable(Vector2(rng.randf_range(1,31),rng.randf_range(1,19)))
		var goal: Vector2=nav.clamp_to_walkable(Vector2(rng.randf_range(1,31),rng.randf_range(1,19)))
		var valid:=true
		for tick in 1800:
			var budget: float=[.025,.117,.26,.5][tick%4]
			var next: Vector2=nav.move_toward('route_%d'%route,position,goal,budget)
			valid=valid and next.is_finite() and position.distance_to(next)<=budget+.00001 and nav.is_walkable(next)
			for sample in range(1,13):
				valid=valid and nav.is_walkable(position.lerp(next,float(sample)/12.0))
			position=next
			total_steps+=1
			if position.distance_to(goal)<.02: break
		check(valid,'variable-frame route stays outside terrain and within speed %d'%route)
		check(position.distance_to(goal)<.02,'variable-frame route reaches destination %d'%route)
	# A moving target that rounds both sides of the large pond must remain reachable.
	var position:=origin
	for goal: Vector2 in [Vector2(6.9,6.4),Vector2(7.3,6.5),Vector2(10.5,6.5),Vector2(9.9,1.1),origin]:
		for tick in 500:
			var next: Vector2=nav.move_toward('moving',position,goal,.117)
			check(nav.has_clear_path(position,next),'moving pursuit cannot cut an obstacle')
			position=next
			if position.distance_to(goal)<.02: break
		check(position.distance_to(goal)<.02,'pursuit reconnects after destination changes')
	nav.clear_routes()
	check(nav.route_preview('moving',position).is_empty(),'map route disappears when the encounter clears')
	nav.set_enabled(false)
	check(is_equal_approx(nav.travel_distance(origin,across),origin.distance_to(across)),'other maps retain direct travel distance')
	print('V47NavigationSmokeTest: ',checks,' checks, ',failures.size(),' failures; variable-frame steps=',total_steps,'; ',nav.get_debug_stats())
	quit(0 if failures.is_empty() else 1)
