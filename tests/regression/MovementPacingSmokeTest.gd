extends 'res://tests/support/V83UpgradeTestBase.gd'
const SMOOTH=preload('res://scripts/maps3d/HuntRenderInterpolation.gd')
const TEXT=preload('res://scripts/presentation/CombatTextPresenter.gd')
func _init() -> void:run.call_deferred()
func run() -> void:
	var smooth:=SMOOTH.new();var a:=Vector2(16,10);var b:=a+Vector2(.15,0)
	smooth.sample({1:a},{1:false},0,true);smooth.capture({1:a},{1:b},{1:false},.05)
	var last:=a
	for i in 3:
		var point: Vector2=smooth.sample({1:b},{1:false},float(i+1)/3,true)[1]
		check(absf(point.distance_to(last)-.05)<.0001,'50ms movement progresses on each render frame '+str(i))
		last=point
	check(last.distance_to(b)<.00001,'display reaches the exact simulation endpoint')
	smooth.capture({1:b},{1:b+Vector2(.15,0)},{1:false},.05)
	var held: Vector2=smooth.sample({1:b+Vector2(.15,0)},{1:false},.3,true)[1]
	check(smooth.sample({1:b+Vector2(.15,0)},{1:false},1,false)[1]==held,'pause holds the displayed position')
	check(smooth.sample({1:b+Vector2(.15,0)},{1:false},0,true)[1]==held,'resume starts at the held foot without a jump')
	smooth.capture({1:b+Vector2(.15,0)},{1:b+Vector2(.30,0)},{1:false},.05)
	check(smooth.sample({1:b+Vector2(.30,0)},{1:false},0,true)[1]==held,'the first resumed physics step bridges from the held foot')
	smooth.capture({1:b},{1:b+Vector2(5,0),2:a},{1:false,2:false},.05)
	var teleported:=smooth.sample({1:b+Vector2(5,0),2:a},{1:false,2:false},.1,true)
	check(teleported[1]==b+Vector2(5,0) and teleported[2]==a,'teleports and new instance IDs snap immediately')
	smooth.capture({1:b+Vector2(5,0)},{1:b},{1:true},.05)
	check(smooth.sample({1:b},{1:true},0,true)[1]==b,'death clears a stale movement segment')
	smooth.sample({}, {},0,true);check(smooth.current.is_empty() and smooth.states.is_empty(),'removed wave actors release interpolation history')
	var main=await make_main('aurelia',10);main._build_combat_screen();await settle()
	main.combat_running=true;main.combat_effects_enabled=true;var field=main.combat_labels.terrain;field.set_process(false)
	if is_instance_valid(main.combat_timer):main.combat_timer.stop()
	var actor=main.hero_map_sprites[0];var id: String=str(main.deployed_heroes[0].id)
	var original: Vector2=main._hero_field_position(id);var moved:=original+Vector2(.15,0)
	field._process(0);field.begin_hunt_step();main.party_movement.positions[id]=moved;field.finish_hunt_step(.05)
	var rng: int=main.loot_rng.state;main._ordinary_hunt_accumulator=.02;field._process(1.0/60)
	var shown: Vector2=field.display_world(actor,moved);var sprite=field.actors[actor.get_instance_id()]
	check(shown.x>original.x and shown.x<moved.x,'actual battlefield samples a point between physics snapshots')
	check(Vector2(sprite.position.x,sprite.position.z).distance_to(shown)<.00001,'painted body and contact shadow share the displayed foot')
	check(actor.position.distance_to(field.position+field.project_world(shown))<.001,'source health/text anchors use the same displayed projection')
	check(main._hero_field_position(id)==moved and main.loot_rng.state==rng,'interpolation never changes simulation positions or loot RNG')
	for i in 100:field.hunt_hit(moved,original,Color.WHITE,i%3==0)
	check(is_equal_approx(Engine.time_scale,1) and field.visual_running(),'a burst of normal/critical contacts cannot stop the whole battle')
	check(field.mobile_camera.cooldown>.7,'camera impacts are bounded across simultaneous attackers')
	var impact_age: float=field.mobile_camera.shake_age
	field.mobile_camera.impact(true);check(field.mobile_camera.shake_age==impact_age,'repeated crits cannot restart an active camera impact')
	main.combat_running=false;field._process(.05);var pause_foot: Vector3=sprite.position;field._process(.1)
	check(sprite.position==pause_foot,'real battlefield remains still while paused')
	main._build_raid_screen();await settle();main._start_raid();main.combat_timer.stop()
	field=main.content_root.get_node('PortraitRaidView').battlefield_3d;field.set_process(false)
	for i in 40:TEXT.raid(main,10,'critical' if i%2==0 else 'damage')
	check(is_equal_approx(Engine.time_scale,1) and field.visual_running(),'raid contact bursts keep normal game time too')
	var elapsed: float=main.raid_elapsed
	var ticks: int=main.combat_tick_count
	for i in 15:
		var before: int=main.combat_tick_count;main._advance_realtime_raid(1.0/60)
		check(main.combat_tick_count-before<=1,'raid work is spread across physics frames '+str(i))
	check(absf(main.raid_elapsed-elapsed-.25)<.000001 and main.combat_tick_count-ticks==5,'quarter second retains five exact raid simulation steps')
	elapsed=main.raid_elapsed;main._on_raid_tick()
	check(main.raid_elapsed==elapsed,'HUD timer cannot advance a realtime encounter twice')
	main.raid_running=false;await dispose(main);done('MOVEMENT_PACING')
