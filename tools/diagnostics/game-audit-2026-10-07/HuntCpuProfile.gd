extends 'res://tests/support/V83UpgradeTestBase.gd'
func _init() -> void:run.call_deferred()
func run() -> void:
	var main=await make_main('aurelia',10);main.idle_stage=154;main._build_combat_screen();await settle()
	main.combat_running=true;main.set_meta('hunt_component_times',{})
	if is_instance_valid(main.combat_timer):main.combat_timer.stop()
	var field=main.combat_labels.terrain;field.set_process(false)
	var total:=0;var drawing:=0;var max_tick:=0
	for i in 360:
		var start:=Time.get_ticks_usec();main._advance_auto_hunt(1./60);var duration:=Time.get_ticks_usec()-start;total+=duration;max_tick=maxi(max_tick,duration)
		start=Time.get_ticks_usec();field._process(1./60);drawing+=Time.get_ticks_usec()-start
	print('HUNT_CPU_PROFILE '+JSON.stringify({'steps':360,'step_ms_mean':total/360000.,'step_ms_max':max_tick/1000.,'presentation_ms_mean':drawing/360000.,'component_total_us':main.get_meta('hunt_component_times')}))
	await dispose(main);done('HUNT_CPU_PROFILE_OK')
