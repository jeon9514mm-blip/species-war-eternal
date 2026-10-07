extends 'res://tests/support/V83UpgradeTestBase.gd'
const PAINT=preload('res://scripts/art/HuntFramePilot.gd')
func _init() -> void:run.call_deferred()
func run() -> void:
	var camera:=Camera3D.new();root.add_child(camera)
	var sources:=Node2D.new();root.add_child(sources)
	for id in ROSTER.HEROES:
		var source=HeroSpriteFactory.create_hero(id);sources.add_child(source)
		source.set_process(false);source.observe_game=false;source.hold_demo=true;source.speed_scale=1
		var pilot=PAINT.new();root.add_child(pilot);check(pilot.bind(source,true),str(id)+' original art binds')
		pilot.effects_enabled=true;pilot.echo_layers=1;source.play_walk(Vector2.RIGHT)
		for tick in 12:pilot.present(camera,1.55,Color.WHITE,1.0/30,true,Vector2(tick*.06,0),{},false)
		check(pilot.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==187,str(id)+' uses one dense original painting surface')
		check(pilot.material_override.get_shader_parameter('secondary_amount')>0 and pilot._locomotion_weight>0,str(id)+' walking drives cloth momentum')
		var frame: int=pilot.debug_snapshot().frame;var distance: float=pilot._distance
		for tick in 8:pilot.present(camera,1.55,Color.WHITE,1.0/30,true,Vector2(.66,0),{},false)
		check(pilot._distance==distance and pilot.debug_snapshot().frame==frame,str(id)+' stationary feet cannot slide through walk frames')
		var clock: float=pilot._visual_time;var locomotion: float=pilot._locomotion_weight
		for tick in 8:pilot.present(camera,1.55,Color.WHITE,.1,false,Vector2(.66,0),{},false)
		check(pilot._visual_time==clock and pilot._locomotion_weight==locomotion,str(id)+' pause freezes secondary motion')
		pilot.timeline.release('skill',.15);pilot.present(camera,1.55,Color.WHITE,0,true,Vector2(.66,0),{},false)
		check(is_equal_approx(pilot.debug_snapshot().phase,.44),str(id)+' contact remains on the real release')
		check(pilot._echoes.layers.size()==1 and pilot._echoes.layers[0].visible,str(id)+' mobile uses one bounded contact afterimage')
		check(is_equal_approx(pilot.basis.x.length(),pilot.basis.y.length()),str(id)+' body proportions remain uniform')
		pilot.effects_enabled=false;pilot.present(camera,1.55,Color.WHITE,0,true,Vector2(.66,0),{},false)
		check(pilot.material_override.get_shader_parameter('secondary_amount')==0 and not pilot._echoes.layers[0].visible,str(id)+' effects-off disables cloth and afterimages')
		pilot.free();source.free()
	camera.free();sources.free();done('painted_25d_motion')
