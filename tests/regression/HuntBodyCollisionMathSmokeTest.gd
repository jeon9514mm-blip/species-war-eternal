extends SceneTree
const BODY=preload('res://scripts/hunting/HuntBodyCollision.gd')
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);push_error(note)
func reference_clear(bodies: Array[Dictionary]) -> bool:
	for a in bodies.size():
		for b in range(a+1,bodies.size()):
			if BODY.body_distance(bodies[a].position,bodies[b].position)<BODY.clearance(bodies[a],bodies[b])-BODY.EPSILON:return false
	return true
func run() -> void:
	var random:=RandomNumberGenerator.new();random.seed=2026100801
	var boundary_equal:=true
	var compared:=0
	for i in 5000:
		var left: Dictionary={'hero':i%2==0,'pixel_scale':[0.,.01,.02,.5][i%4]}
		var right: Dictionary={'hero':i%3==0,'pixel_scale':[0.,.03,.005,.25][i%4]}
		var point:=Vector2(random.randf_range(-10,10),random.randf_range(-10,10))
		var angle:=random.randf_range(-PI,PI)
		for tolerance: float in [0.,BODY.EPSILON,.01]:
			var radius:=BODY.clearance(left,right)-tolerance
			for offset: float in [-.01,-.0000001,0.,.0000001,.01]:
				var direction:=Vector2.from_angle(angle)*(radius+offset)
				direction.y/=BODY.DEPTH_SCALE
				var other:=point+direction
				boundary_equal=boundary_equal and BODY._within_radius(point,other,radius)==(BODY.body_distance(point,other)<radius)
				compared+=1
	check(boundary_equal,'squared fast predicate preserves original float32 rounded distance results across 75000 pair-boundary samples')
	for radius: float in [0.,-.1,NAN]:
		check(not BODY._within_radius(Vector2.ZERO,Vector2.ZERO,radius),'zero, negative and non-finite radius cannot create a new overlap')
	for coordinate: float in [NAN,INF,-INF]:
		check(not BODY._within_radius(Vector2(coordinate,0),Vector2.ZERO,1.),'invalid position matches the original non-overlap comparison')
	var clear_equal:=true;var radii_equal:=true
	for sample in 100:
		var bodies: Array[Dictionary]=[]
		for i in 30:
			bodies.append({'hero':i<10,'pixel_scale':[0.,.012,.015][i%3],'position':Vector2(random.randf_range(8,24),random.randf_range(6,14))})
		var radii:=BODY._pair_radii(bodies)
		for a in bodies.size():
			for b in range(a+1,bodies.size()):
				radii_equal=radii_equal and radii[a*bodies.size()+b]==BODY.clearance(bodies[a],bodies[b]) and radii[b*bodies.size()+a]==radii[a*bodies.size()+b]
		clear_equal=clear_equal and BODY.clear(bodies)==reference_clear(bodies) and BODY._clear_with_radii(bodies,radii)==reference_clear(bodies)
		# A solve changes positions while body types and scale remain fixed.
		for body in bodies:body.position+=Vector2(random.randf_range(-.3,.3),random.randf_range(-.3,.3))
		clear_equal=clear_equal and BODY._clear_with_radii(bodies,radii)==reference_clear(bodies)
	check(radii_equal,'pair cache preserves unequal actor pixel scales and both team directions exactly')
	check(clear_equal,'cached and public clearance match the original distance oracle before and after 100 body-position updates')
	var empty: Array[Dictionary]=[]
	check(BODY.clear(empty) and BODY._clear_with_radii(empty,BODY._pair_radii(empty)),'empty battle stays clear')
	print('hunt_body_collision_math_smoke_test_ok checks=%d pair_samples=%d failures=%s'%[checks,compared,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
