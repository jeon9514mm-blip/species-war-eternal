extends SceneTree
const NAV=preload('res://scripts/hunting/MeadowNavigation.gd')
const PARTY=preload('res://scripts/hunting/PartyMovementDirector.gd')
class CountingDecisions extends CombatDecisionEngine:
	var queries:=0
	func can_attack_enemy(state: Dictionary,enemies: Array,index: int,distances: Array=[]) -> bool:
		queries+=1
		return super.can_attack_enemy(state,enemies,index,distances)
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);push_error(note)
func run() -> void:
	var nav:=NAV.new()
	var random:=RandomNumberGenerator.new();random.seed=20261008
	var exact:=true
	for i in 300:
		var from:=Vector2(random.randf_range(.35,31.65),random.randf_range(.35,19.65))
		var target:=Vector2(random.randf_range(-3,35),random.randf_range(-3,23))
		var budget: float=[0.017,.0975,.39,.5][i%4]
		var expected:=from.move_toward(target.clamp(NAV.FIELD_MIN,NAV.FIELD_MAX),budget)
		exact=exact and nav.move_toward(i,from,target,budget)==expected
	check(exact,'empty terrain keeps exact bounded, speed-limited movement')
	check(nav._grid==null and nav._segment_cache.is_empty(),'empty terrain performs no grid construction or segment-cache churn')
	for from: Vector2 in [Vector2(-1,10),Vector2(33,10),Vector2(16,-2),Vector2(16,23)]:
		check(nav.move_toward('legacy',from,Vector2(20,12),.1)==from.move_toward(from.clamp(NAV.FIELD_MIN,NAV.FIELD_MAX),.1),'legacy position first returns to the nearest field boundary')
	for budget: float in [0.,-1.,NAN,INF]:
		check(nav.move_toward('invalid',Vector2(16,10),Vector2(20,10),budget)==Vector2(16,10),'invalid or paused movement budget stays still')
	check(not nav.has_clear_path(Vector2(-1,10),Vector2(20,10)) and not nav.is_walkable(Vector2(16,23)),'empty terrain still rejects paths outside its field')
	check(not nav.has_clear_path(Vector2(NAN,10),Vector2(20,10)),'empty terrain still rejects non-finite path input')
	# Authored obstacles can return later. Exercise the full route branch with
	# an actual blocking ellipse instead of relying on the now-empty old maps.
	var obstructed:=NAV.new()
	obstructed._active_obstacles=[[Vector2(12,10),Vector2(1.3,1.0)]]
	check(not obstructed.is_walkable(Vector2(12,10)) and not obstructed.has_clear_path(Vector2(10,10),Vector2(14,10)),'obstacle layout retains blocked centers and continuous segment clearance')
	var position:=Vector2(10,10);var valid:=true
	for tick in 160:
		var next:=obstructed.move_toward('around',position,Vector2(14,10),.0975)
		valid=valid and obstructed.is_walkable(next) and obstructed.has_clear_path(position,next) and next.distance_to(position)<=.09751
		position=next
		if position.distance_to(Vector2(14,10))<.02:break
	check(valid and position.distance_to(Vector2(14,10))<.02,'obstacle navigation still routes around the ellipse within its speed budget')
	obstructed.set_enabled(false)
	check(obstructed.has_clear_path(Vector2(10,10),Vector2(14,10)) and obstructed.is_walkable(Vector2(12,10)),'disabled navigation retains direct field movement')
	obstructed.set_enabled(true)
	check(not obstructed.has_clear_path(Vector2(10,10),Vector2(14,10)),'reenabling navigation restores obstacle clearance')
	obstructed.configure_zone('forgotten_mine',true)
	check(obstructed._grid==null and obstructed._segment_cache.is_empty() and obstructed.is_walkable(Vector2(12,10)),'region changes discard stale routes and use the new empty layout')
	var director:=PARTY.new();director.independent_hunt=true
	var decisions:=CountingDecisions.new();director._decisions=decisions
	director.targets={'hero':0};director.stalled_seconds={'hero':1.0}
	var state: Dictionary={'hp':100,'range':1}
	var enemies: Array=[{'hp':100,'row':0}]
	var points: Array[Vector2]=[Vector2(12,10)]
	director._adapt_blocked_route('hero',.1,Vector2(7,10),Vector2(7.1,10),Vector2(10,10),state,enemies,points)
	check(decisions.queries==0 and director.stalled_seconds.hero==0.,'successful pursuit clears a stall without querying every enemy range')
	director.stalled_seconds.hero=1.
	director._adapt_blocked_route('hero',.1,Vector2(7,10),Vector2(7,10),Vector2(7.1,10),state,enemies,points)
	check(decisions.queries==0 and director.stalled_seconds.hero==0.,'arrival keeps the existing hold position without an enemy range query')
	points[0]=Vector2(7.5,10);director.stalled_seconds.hero=1.
	director._adapt_blocked_route('hero',.1,Vector2(7,10),Vector2(7,10),Vector2(10,10),state,enemies,points)
	check(decisions.queries==1 and director.stalled_seconds.hero==0.,'waiting in real attack reach remains intentional')
	points[0]=Vector2(12,10)
	for i in 25:director._adapt_blocked_route('hero',.1,Vector2(7,10),Vector2(7,10),Vector2(10,10),state,enemies,points)
	check(int(director.blocked_targets.hero.get('target',-1))==0 and director.target_locks.hero==0. and director.stalled_seconds.hero==0.,'failed pursuit still releases the blocked target after the existing 2.5-second delay')
	print('hunt_navigation_cost_smoke_test_ok checks=%d failures=%s'%[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
