extends 'res://tests/support/V83UpgradeTestBase.gd'
const MOTION=preload('res://scripts/maps3d/HuntMotionPresentation.gd')
const ATTACK=preload('res://scripts/hunting/HuntAttackDirector.gd')
func _init() -> void:run.call_deferred()
func run() -> void:
	var main=await make_main('aurelia',3)
	main._build_combat_screen();await settle()
	main.combat_running=false
	var field: Control=main.combat_labels.terrain
	var before: Dictionary=economic(main);var rng: int=main.loot_rng.state
	var source: AnimatedSprite2D=main.hero_map_sprites[0]
	for state: String in ['idle','walk','attack','hit','death']:
		source.state=state
		for t in [0.0,.05,.10,.20,.40,1.0]:
			source.visual_state_time=t
			var pose: Dictionary=MOTION.pose(source,true,Vector2.RIGHT,t)
			check(pose.offset.is_finite() and pose.offset.length()<.50,'bounded visual motion '+state)
			check(pose.shape.x>.7 and pose.shape.y>.7,'whole-body squash keeps joints connected '+state)
	check(economic(main)==before and main.loot_rng.state==rng,'motion leaves stats, economy and loot RNG intact')
	main.combat_effects_enabled=true
	field.hunt_overlay.afterimage(source,Vector2(16,10),Vector2.RIGHT)
	check(field.hunt_overlay.echoes.size()==3,'critical/skill trail has three echoes')
	for i in 40:field.hunt_overlay.afterimage(source,Vector2(16,10),Vector2.RIGHT)
	check(field.hunt_overlay.echoes.size()==24,'afterimage pool remains bounded')
	for i in 100:field.hunt_overlay.footstep(Vector2(16,10));field.hunt_overlay.soul(Vector2(16,10),true)
	check(field.hunt_overlay.dust.size()==48 and field.hunt_overlay.souls.size()==16,'dust and death pools remain bounded')
	var sizes: Vector3i=Vector3i(field.hunt_overlay.echoes.size(),field.hunt_overlay.dust.size(),field.hunt_overlay.souls.size())
	field.hunt_overlay._process(1)
	check(sizes==Vector3i(field.hunt_overlay.echoes.size(),field.hunt_overlay.dust.size(),field.hunt_overlay.souls.size()),'paused effect clocks do not advance')
	main.combat_effects_enabled=false;field.hunt_overlay._process(0)
	check(field.hunt_overlay.echoes.is_empty() and field.hunt_overlay.dust.is_empty() and field.hunt_overlay.souls.is_empty(),'effects setting clears optional visuals')
	var director=main.roaming_hunt
	var position: Vector2=director.enemy_position(0)
	director.hero_presence.assign([position+Vector2(-.3,0),position+Vector2(.3,0),position+Vector2(0,.4)])
	director.fear_remaining[0]=.70;director.fear_cooldowns[0]=4.0
	var hp: int=main.enemy_wave[0].hp
	check(not ATTACK.advance_enemy(main,0,.1).ready,'fleeing monster cannot release a hit')
	var targets: Array[Vector2]=[]
	for i in director.enemy_positions.size():targets.append(position+Vector2(0,.2))
	var live: Array=main._alive_enemy_mask()
	director.advance(.1,live,[],targets)
	check(director.enemy_position(0).distance_to(position)>.01,'fear moves the real monster briefly away')
	check(float(director.fear_remaining[0])<.70 and main.enemy_wave[0].hp==hp,'fear uses simulation clock and preserves HP')
	check(main.loot_rng.state==rng,'fear uses separate RNG, preserving loot stream')
	var snapshot: Array[Vector2]=director.enemy_positions.duplicate()
	var clock: float=director.fear_remaining[0]
	director.advance(0,live,[],targets)
	check(director.enemy_positions==snapshot and is_equal_approx(clock,director.fear_remaining[0]),'zero delta freezes fear and positions')
	director.fear_remaining[2]=.30;director.fear_cooldowns[2]=3.0
	director.remap_temporary_states({2:0})
	check(director.fear_remaining.size()==1 and is_equal_approx(director.fear_remaining[0],.30),'corps retirement remaps fear to the surviving enemy')
	check(director.fear_cooldowns.size()==1 and is_equal_approx(director.fear_cooldowns[0],3.0),'corps retirement removes stale cooldowns')
	director.clear_enemies()
	check(director.fear_remaining.is_empty() and director.fear_cooldowns.is_empty(),'new waves clear temporary fear state')
	await dispose(main)
	var parent:=Node3D.new();root.add_child(parent)
	for zone: String in ['gray_meadow','forgotten_mine','moonrest_forest']:
		var preview: Node3D=preload('res://scripts/maps/GeneratedMapScene.gd').build(zone,parent,false)
		check(preview.get_node_or_null('Arena/RuneStoneGround/ArtistStoneSurface')!=null,'gallery uses new stone '+zone)
		preview.queue_free();await settle()
	parent.queue_free();await settle();done('V16_INTEGRATION')
