extends "res://tests/support/V83UpgradeTestBase.gd"
const BODY=preload('res://scripts/hunting/HuntBodyCollision.gd')
const FORMATION=preload('res://scripts/combat/BattleFormation.gd')
const LAYOUT=preload('res://scripts/maps3d/HeroCircleFormation.gd')
const MOVEMENT=preload('res://scripts/hunting/PartyMovementDirector.gd')
func _init() -> void:run.call_deferred()
func minimum_gap(layout: Dictionary) -> float:
	var ids: Array=layout.keys();var result:=INF
	for a in ids.size():
		for b in range(a+1,ids.size()):result=minf(result,Vector2(layout[ids[a]]).distance_to(layout[ids[b]]))
	return result
func centered(layout: Dictionary) -> bool:
	var values: Array=layout.values()
	if values.is_empty():return true
	var low: Vector2=values[0];var high:=low
	for point: Vector2 in values:low=low.min(point);high=high.max(point)
	return (low+high).length()<.001
func run() -> void:
	# A legal native-size firing stance must not be rejected by obsolete world
	# spacing. These actors are within .95 real melee reach and 91px apart.
	var movement:=MOVEMENT.new();movement.independent_hunt=true;movement.body_pixel_scale=.0085
	var heroes: Array=[{'id':'spacing_front'},{'id':'spacing_side'}]
	var states: Dictionary={}
	for hero in heroes:states[hero.id]={'hp':100,'range':1,'row':'front','role_group':'딜러'}
	movement.configure(heroes,states,Vector2(16,10.5))
	movement.positions={'spacing_front':Vector2(16,10),'spacing_side':Vector2(16,11.1)}
	var points: Array[Vector2]=[Vector2(16.5,10.55)]
	var enemies: Array=[{'hp':1000,'max_hp':1000,'row':0}]
	var bodies: Dictionary=movement.positions.duplicate()
	for hero in heroes:
		var start: Vector2=bodies[hero.id]
		var goal: Vector2=preload('res://scripts/hunting/HuntPositionPlanner.gd').choose(movement,hero.id,start,0,points[0]+Vector2(.7,0),states[hero.id],states,bodies,bodies,enemies,points,{})
		check(goal==start,'legal 66px body gap holds firing stance '+hero.id)
		check(goal.distance_to(points[0])<=CombatDecisionEngine.new().spatial_range(1),'stationary stance retains real melee reach '+hero.id)
	check(is_equal_approx(movement.hero_clearance(),BODY.radius(true,true,.0085)) and is_equal_approx(movement.contact_clearance(),BODY.radius(true,false,.0085)),'planner and collision use one native pixel clearance')
	# Exercise the real director too: a station well behind a legal firing pose
	# must not override that pose, nor may its cached slot orbit a moving target.
	movement.travel_offsets={'spacing_front':Vector2(-1.5,0),'spacing_side':Vector2(-1.5,1.1)}
	var firing: Dictionary=movement.positions.duplicate()
	var no_returns: Array[bool]=[false]
	movement.advance(.02,heroes,states,{},Vector2(16,10.5),enemies,points,no_returns,true)
	check(movement.positions==firing,'actual advance retains legal firing stance outside the home lane')
	points[0]+=Vector2(.01,0)
	movement.advance(.02,heroes,states,{},Vector2(16,10.5),enemies,points,no_returns,true)
	check(movement.positions==firing,'cached legal firing stance does not orbit a slightly moving target')
	for hero in heroes:
		check(Vector2(movement.combat_goals[hero.id].goal)==firing[hero.id] and Vector2(movement.hunt_slots[hero.id].offset)+points[0]==firing[hero.id],'final goal and target-relative reservation match the actual held pose '+hero.id)
	for faction: String in ['aurelia','noxfera']:
		var main=await make_main(faction,10)
		main.idle_stage=154;main._build_combat_screen();await settle()
		var field: Control=main.combat_labels.terrain
		var initial_hp: Dictionary=main.hero_battle_state.duplicate(true)
		var rng_state: int=main.loot_rng.state;var wallet: int=main.wallet_gold
		var shapes: Array=[]
		var no_enemies: Array=[];var no_points: Array[Vector2]=[];var no_returning: Array[bool]=[]
		for choice: String in FORMATION.PROFILES:
			main.formation_id=choice;main.party_movement.apply_formation(main.deployed_heroes,choice)
			LAYOUT.hunt(main,field,true)
			var projected: Dictionary=FORMATION.projected_offsets(main.deployed_heroes,choice)
			shapes.append(projected)
			check(centered(projected),'ten-member formation centers '+faction+choice)
			check(minimum_gap(projected)>=BODY.HERO_PIXELS+5.99,'preset leaves native body clearance '+faction+choice)
			var origin: Vector2=field.project_world(main.expedition_position)
			for id in projected:
				var actual: Vector2=field.project_world(main._hero_field_position(id))-origin
				check(actual.distance_to(projected[id])<.05,'actual feet match canonical menu diagram '+faction+choice+id)
				check(main.field_navigation.is_walkable(main._hero_field_position(id)),'preset stays navigable '+faction+choice+id)
			check(BODY.clear(BODY.actors(main).filter(func(body: Dictionary) -> bool:return body.hero)),'all ten initial bodies are clear '+faction+choice)
			var placed: Dictionary=main.party_movement.positions.duplicate()
			for tick in 20:main.party_movement.advance(.05,main.deployed_heroes,main.hero_battle_state,{},main.expedition_position,no_enemies,no_points,no_returning,false)
			check(main.party_movement.positions==placed,'resting preset has no idle steering jitter '+faction+choice)
		check(shapes[0]!=shapes[1] and shapes[0]!=shapes[2] and shapes[0]!=shapes[3] and shapes[1]!=shapes[2] and shapes[1]!=shapes[3] and shapes[2]!=shapes[3],'four selected layouts remain distinct '+faction)
		var live: Dictionary=main.party_movement.positions.duplicate()
		main.formation_id='balanced';main.party_movement.apply_formation(main.deployed_heroes,'balanced');LAYOUT.hunt(main,field,false)
		check(main.party_movement.positions==live,'live formation selection changes goals without teleporting '+faction)
		check(main.hero_battle_state==initial_hp and main.wallet_gold==wallet and main.loot_rng.state==rng_state,'layout never changes HP wallet or reward RNG '+faction)
		# A west entrance must turn the defensive front, while rotation itself
		# changes stations only and preserves every pair's body-space gap.
		var stations: Dictionary={}
		for id in main._deployed_hero_ids():stations[id]=main.party_movement.formation_station(id,main.expedition_position)
		var west_enemies: Array=[{'hp':100,'max_hp':100,'row':0}]
		var west_points: Array[Vector2]=[main.expedition_position+Vector2(-4,0)]
		var west_returning: Array[bool]=[false]
		for tick in 80:main.party_movement._face_threat(.1,main.expedition_position,west_enemies,west_points,west_returning)
		check(main.party_movement.formation_facing.x<-.99,'west pressure turns the defensive front '+faction)
		check(main.party_movement.positions==live,'changing defensive heading never teleports living actors '+faction)
		var ids: Array=stations.keys();var invariant:=true
		for a in ids.size():
			for b in range(a+1,ids.size()):
				var before_gap:=BODY.body_distance(stations[ids[a]],stations[ids[b]])
				var after_gap:=BODY.body_distance(main.party_movement.formation_station(ids[a],main.expedition_position),main.party_movement.formation_station(ids[b],main.expedition_position))
				invariant=invariant and absf(before_gap-after_gap)<.0001
		check(invariant,'rotating defensive front preserves elliptical body clearance '+faction)
		var ordered: Array=main.deployed_heroes.duplicate();ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return FORMATION._rank(a)<FORMATION._rank(b))
		check(main.party_movement.formation_station(ordered[0].id,main.expedition_position).x<main.party_movement.formation_station(ordered[-1].id,main.expedition_position).x,'frontline stays before support toward the west '+faction)
		# Resizing updates stations and pixel scale without relocating live bodies.
		for physical_size: Vector2i in [Vector2i(960,540),Vector2i(1440,900),Vector2i(720,1280)]:
			root.size=physical_size;await settle();main._apply_portrait_resize();await settle()
			check(main.party_movement.positions==live,'resize retains actual combat coordinates '+faction+str(physical_size))
			check(main.party_movement.body_pixel_scale>0,'resize supplies native pixel scale '+faction+str(physical_size))
		await dispose(main)
	for count: int in [0,1,3,10]:
		var subset: Array=ROSTER.roster('aurelia').slice(0,count)
		for choice: String in FORMATION.PROFILES:
			var projected: Dictionary=FORMATION.projected_offsets(subset,choice)
			check(projected.size()==count and centered(projected),'partial party centers '+str(count)+choice)
			check(count<2 or minimum_gap(projected)>=71.99,'partial party preserves clearance '+str(count)+choice)
	done('HUNT_FORMATION_SPACING')
