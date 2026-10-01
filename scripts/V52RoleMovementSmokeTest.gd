extends SceneTree

const PARTY = preload("res://scripts/PartyMovementDirector.gd")
const NAV = preload("res://scripts/MeadowNavigation.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _state(role := "딜러", style := "balanced", reach := 3) -> Dictionary:
	return {"hp":1000,"max_hp":1000,"range":reach,"role_group":role,"ai_style":style,"slot":0,"row":"middle"}

func _enemy(hp := 1000, archetype := "brute", attack := 30) -> Dictionary:
	return {"hp":hp,"max_hp":1000,"row":0,"archetype":archetype,"attack":attack}

func _run() -> void:
	_test_role_targets()
	_test_melee_and_support()
	_test_ranged_edge_and_hold()
	_test_movement_kit()
	_test_crowded_navigation()
	print("V52RoleMovementSmokeTest: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_role_targets() -> void:
	var party := PARTY.new()
	var center := Vector2(16, 10)
	var heroes: Array = [{"id":"mira"},{"id":"kairen"},{"id":"leonhardt"},{"id":"elisia"}]
	var states := {"mira":_state("딜러","finisher"),"kairen":_state("컨트롤러","controller"),"leonhardt":_state("탱커","protector",1),"elisia":_state("서포터","support")}
	party.configure(heroes, states, center)
	var enemies: Array = [_enemy(),_enemy(80)]
	var positions: Array[Vector2] = [center + Vector2(1.0,0),center+Vector2(1.2,0.3)]
	check(party._select_target("mira",center,enemies,positions,[],states["mira"])==1,"Finisher moves for the same wounded target as the attack decision")
	enemies = [_enemy(300,"brute",20),_enemy(1000,"support",90)]
	check(party._select_target("kairen",center,enemies,positions,[],states["kairen"])==1,"Controller approaches the nearby dangerous support rather than the lowest distance")
	party.positions={"leonhardt":center,"elisia":center+Vector2(0,1.5)}
	positions=[center+Vector2(0.6,0),center+Vector2(0,2)]
	enemies=[_enemy(),_enemy(1000,"assassin",45)]
	check(party._select_target("leonhardt",center,enemies,positions,[],states["leonhardt"],states,party.positions)==1,"Tank intercepts a nearby assassin threatening its healer")
	enemies[1]["stun_seconds"]=2.0
	check(party._select_target("leonhardt",center,enemies,positions,[],states["leonhardt"],states,party.positions)==0,"Tank keeps attacking instead of chasing a disabled back-line threat")
	party.targets["mira"]=0
	party.target_locks["mira"]=0.4
	enemies=[_enemy(),_enemy(50)]
	positions=[center+Vector2(5,0),center+Vector2(1,0)]
	check(party._select_target("mira",center,enemies,positions,[],states["mira"])==1,"An available attack prevents pursuing a distant locked target")
	check(party._select_target("mira",center,enemies,positions,[true,true],states["mira"])==-1,"Returning enemies never become movement targets")
	enemies[0]["hp"]=0
	check(party._select_target("mira",center,enemies,positions,[false,false],states["mira"])==1,"A dead locked target is replaced immediately")
	positions=[center+Vector2(4,0),center+Vector2(4.1,0)]
	enemies=[_enemy(),_enemy()]
	party.targets["mira"]=1
	party.target_locks["mira"]=0.4
	check(party._select_target("mira",center,enemies,positions,[],states["mira"])==1,"Minor approach-distance changes respect the target lock")

	# A tracker keeps its real attack target through small HP fluctuations.
	party.configure([{"id":"rokan"}],{"rokan":_state("딜러","aggressive",3)},center)
	positions=[center+Vector2(1.1,0),center+Vector2(1.2,0)]
	enemies=[_enemy(800),_enemy(950)]
	party.targets["rokan"]=0
	check(party._select_target("rokan",center,enemies,positions,[],_state("딜러","aggressive",3),{}, {}, {"target_index":1})==1,"Tracker movement preserves the same actual attack target as its combo mechanic")

func _test_melee_and_support() -> void:
	var party := PARTY.new()
	var center := Vector2(16,10)
	var heroes: Array = [{"id":"valeria"}]
	var states := {"valeria":_state("딜러","sustain",2)}
	party.configure(heroes,states,center)
	party.positions["valeria"]=center-Vector2(1,0)
	var enemies: Array = [_enemy()]
	var positions: Array[Vector2] = [center]
	for tick in 20:
		party.advance(.05,heroes,states,{},center,enemies,positions,[],true)
	check(Vector2(party.positions["valeria"]).distance_to(center)<.72,"A middle-row melee lifestealer closes to melee instead of kiting as an archer")
	check(Vector2(party.positions["valeria"]).distance_to(center)>.45,"Melee preserves readable separation from the enemy")
	heroes=[{"id":"leonhardt"},{"id":"elisia"}]
	states={"leonhardt":_state("탱커","protector",1),"elisia":_state("서포터","support",3)}
	party.configure(heroes,states,center)
	party.positions={"leonhardt":center,"elisia":center-Vector2(1,0)}
	# The tank is casting, so the healer must not independently rush a distant pack.
	var runtimes := {"leonhardt":{"windup":2.0}}
	positions=[center+Vector2(8,0)]
	for tick in 80:
		party.advance(.05,heroes,states,runtimes,center,enemies,positions,[],true)
	check(Vector2(party.positions["elisia"]).distance_to(center)<=PARTY.SUPPORT_COHESION_RADIUS+.08,"Healer stays within its living party's support formation")
	states["leonhardt"]["hp"]=0
	var before: Vector2=party.positions["elisia"]
	for tick in 30:
		party.advance(.05,heroes,states,{},center,enemies,positions,[],true)
	check(Vector2(party.positions["elisia"]).distance_to(before)>1.0,"Solo surviving healer can approach enemies instead of waiting on a dead ally")

func _test_ranged_edge_and_hold() -> void:
	var party := PARTY.new()
	var center := Vector2(.5,10)
	var heroes: Array = [{"id":"mira"}]
	var states := {"mira":_state("딜러","finisher",3)}
	party.configure(heroes,states,center)
	party.positions["mira"]=center
	var enemies: Array=[_enemy(),_enemy()]
	var positions: Array[Vector2]=[Vector2(.9,10),Vector2(1.1,10.15)]
	var valid:=true
	for tick in 35:
		var before: Vector2=party.positions["mira"]
		party.advance(.05,heroes,states,{},center,enemies,positions,[],true)
		var after: Vector2=party.positions["mira"]
		valid=valid and after.x>=RoamingHuntDirector.FIELD_MIN.x and after.distance_to(before)<=PARTY.WALK_SPEED*.05+.00001
	var after: Vector2=party.positions["mira"]
	check(valid,"Edge retreat remains in bounds and respects speed")
	check(absf(after.y-center.y)>.5,"Ranged hero escapes sideways when a boundary blocks retreat")
	check(after.distance_to(positions[0])>.9 and after.distance_to(positions[0])<=1.75,"Side retreat retains usable shooting distance")
	party.positions["mira"]=Vector2(16,10)
	positions=[Vector2(17.5,10)]
	enemies=[_enemy()]
	var stationary: Vector2=party.positions["mira"]
	for tick in 60:
		party.advance(.05,heroes,states,{},stationary,enemies,positions,[],true)
	check(Vector2(party.positions["mira"]).distance_to(stationary)<.01,"Safe ranged firing position does not oscillate between attacks")
	party.positions["mira"]=Vector2(6.9,1.5)
	party.field_navigation=NAV.new()
	positions=[Vector2(6.9,1.75)]
	var clear:=true
	for tick in 45:
		var before: Vector2=party.positions["mira"]
		party.advance(.05,heroes,states,{},before,enemies,positions,[],true)
		var next: Vector2=party.positions["mira"]
		clear=clear and party.field_navigation.is_walkable(next) and party.field_navigation.has_clear_path(before,next)
	check(clear,"Close retreat beside a pond never crosses the painted obstacle")
	check(Vector2(party.positions["mira"]).distance_to(positions[0])>.8,"Ranged hero finds room beside pond terrain")

func _test_movement_kit() -> void:
	var party := PARTY.new()
	var center:=Vector2(16,10)
	var heroes: Array=[{"id":"sael"}]
	var states: Dictionary={"sael":_state("딜러","aggressive",1)}
	party.configure(heroes,states,center)
	var original:=center-Vector2(.6,0)
	party.positions["sael"]=original
	var runtimes: Dictionary={"sael":{"kit_last_move_position":original,"passive_remaining":0.0,"windup":-1.0}}
	var enemies: Array=[_enemy()]
	var positions: Array[Vector2]=[center]
	var stayed_in_range:=true
	var moved_for_kit:=false
	for tick in 40:
		party.advance(.05,heroes,states,runtimes,center,enemies,positions,[],true)
		var current: Vector2=party.positions["sael"]
		stayed_in_range=stayed_in_range and current.distance_to(center)<=.95
		moved_for_kit=moved_for_kit or current.distance_to(original)>=.6
	check(stayed_in_range,"Movement-triggered melee kit repositions inside attack range")
	check(moved_for_kit,"Movement-triggered kit reaches its existing 0.6-cell passive condition")
	runtimes["sael"]["windup"]=.2
	var before: Vector2=party.positions["sael"]
	party.advance(.1,heroes,states,runtimes,center,enemies,positions,[],true)
	check(party.positions["sael"]==before,"Skill windup prevents lateral movement from interrupting the cast")

func _test_crowded_navigation() -> void:
	var party:=PARTY.new()
	var nav:=NAV.new()
	party.field_navigation=nav
	var heroes: Array=[]
	var states: Dictionary={}
	var ids: Array[String]=["leonhardt","mira","elisia","kairen","orwin","seria","astel","darius","lunea","caelum"]
	for index in ids.size():
		var id:=ids[index]
		heroes.append({"id":id})
		var roster: Dictionary=PARTY.ROSTER.HEROES[id]
		var identity:=HeroIdentityCatalog.new().profile(id)
		states[id]=_state(str(roster["role_group"]),str(identity["ai_style"]),1 if str(roster["reach"])=="melee" else 3)
		states[id]["slot"]=index
	var center:=Vector2(16,10)
	party.configure(heroes,states,center)
	var enemies: Array=[]
	var positions: Array[Vector2]=[]
	var returning: Array[bool]=[]
	for index in 14:
		enemies.append(_enemy(1000,["brute","ranged","assassin","support"][index%4]))
		positions.append(nav.clamp_to_walkable(center+Vector2.from_angle(float(index)*TAU/14.0)*2.2))
		returning.append(false)
	var valid:=true
	var contact:=false
	for tick in 120:
		var before: Dictionary=party.positions.duplicate()
		party.advance(.05,heroes,states,{},center,enemies,positions,returning,true)
		for id in ids:
			var current: Vector2=party.positions[id]
			valid=valid and current.is_finite() and nav.is_walkable(current) and current.distance_to(before[id])<=PARTY.WALK_SPEED*.05+.00001 and nav.has_clear_path(before[id],current)
			var target:=int(party.targets[id])
			contact=contact or (target>=0 and current.distance_to(positions[target])<.95)
	check(valid,"Ten heroes remain navigable with speed-limited steps among fourteen enemies")
	check(contact,"Crowded steering still puts melee fighters in contact")
	var frozen:=party.positions.duplicate()
	party.advance(.1,heroes,states,{},center,enemies,positions,returning,true,true)
	check(party.positions==frozen,"Paused crowded encounter preserves all hero positions")
	for invalid in [NAN,INF,-1.0]:
		party.advance(invalid,heroes,states,{},center,enemies,positions,returning,true)
		check(party.positions==frozen,"Invalid movement frame leaves state unchanged")
