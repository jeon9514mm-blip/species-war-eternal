extends SceneTree
const PAINT=preload('res://scripts/art/MobileReliefPilot.gd')
const HERO=preload('res://scripts/art/MobilePaintActor.gd')
const MONSTER=preload('res://scripts/art/MobileMonsterActor.gd')
func _init() -> void:run.call_deferred()
func run() -> void:
	var camera:=Camera3D.new();root.add_child(camera)
	var hero:=HERO.new();hero.configure_mobile('leonhardt');root.add_child(hero);hero.set_process(false);hero.speed_scale=1
	var monster:=MONSTER.new();monster.configure_mobile('들개 무리',Vector2.ONE);root.add_child(monster);monster.set_process(false);monster.speed_scale=1
	var paints: Array=[]
	for source in [hero,monster]:
		var paint:=PAINT.new();root.add_child(paint);paint.bind(source,source==hero);paints.append(paint)
	var results: Dictionary={}
	for scenario in ['idle','walk','pause']:
		for source in [hero,monster]:source.state='walk' if scenario=='walk' else 'idle'
		var active: bool=scenario!='pause'
		for i in 100:
			for paint in paints:paint.present(camera,1.0,Color.WHITE,1.0/60,active,Vector2(i*.01 if scenario=='walk' else 0,0),{},false)
		var samples: Array[float]=[]
		for repeat in 3:
			var start:=Time.get_ticks_usec()
			for i in 2000:
				for paint in paints:paint.present(camera,1.0,Color.WHITE,1.0/60,active,Vector2(i*.01 if scenario=='walk' else 0,0),{},false)
			samples.append(float(Time.get_ticks_usec()-start)/4000.0)
		results[scenario]=samples
	print('PILOT_PRESENT_BENCH '+JSON.stringify({'iterations_per_sample':4000,'samples_usec_per_actor':results}))
	for paint in paints:paint.free()
	hero.free();monster.free();camera.free();quit()
