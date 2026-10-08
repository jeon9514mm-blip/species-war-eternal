extends 'res://tests/support/V83UpgradeTestBase.gd'
## CPU service costs at the production20Hz step; never a GPU FPS claim.
const STEPS:=240
const STEP:=.05
func _init() -> void:run.call_deferred()
func p95(samples: Array[float]) -> float:
	var ordered:=samples.duplicate();ordered.sort()
	return ordered[mini(ordered.size()-1,int(ceil(ordered.size()*.95))-1)]
func run() -> void:
	var reports: Array[Dictionary]=[]
	for faction in ['aurelia','noxfera']:
		var main=await make_main(faction,10)
		root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1120,630)
		main.idle_stage=154;main.tutorial_completed=true;main.presentation_options.performance='balanced'
		main.sound_effects_enabled=false;main.combat_effects_enabled=true;main.combat_fx.enabled=true
		main.skill_auto=true;main.ultimate_auto=true;main._build_combat_screen();await settle()
		main.combat_running=true;main.set_meta('hunt_component_times',{})
		main.presentation_runtime.contact_time.enabled=false
		if is_instance_valid(main.combat_timer):main.combat_timer.stop()
		var field=main.combat_labels.terrain;field.set_process(false)
		var simulation_total:=0;var presentation_total:=0;var max_enemies:=0;var max_actors:=0
		var simulation_samples: Array[float]=[];var presentation_samples: Array[float]=[]
		var cast_total:=0;var overlay_total:=0
		for i in STEPS:
			var start:=Time.get_ticks_usec();main._advance_auto_hunt(STEP);var duration:=Time.get_ticks_usec()-start
			simulation_total+=duration;simulation_samples.append(float(duration)*.001)
			start=Time.get_ticks_usec();field._process(STEP);duration=Time.get_ticks_usec()-start
			presentation_total+=duration;presentation_samples.append(float(duration)*.001)
			start=Time.get_ticks_usec();field.skill_overlay.advance(STEP);field.hunt_overlay._process(STEP);overlay_total+=Time.get_ticks_usec()-start
			max_enemies=maxi(max_enemies,main.enemy_wave.size());max_actors=maxi(max_actors,field.actors.size());cast_total+=field.skill_overlay.casts.size()
		var record: Dictionary={'faction':faction,'steps':STEPS,'step_seconds':STEP,'simulated_seconds':STEPS*STEP,'simulation_ms_mean':float(simulation_total)/STEPS*.001,'simulation_ms_p95':p95(simulation_samples),'presentation_sync_ms_mean':float(presentation_total)/STEPS*.001,'presentation_sync_ms_p95':p95(presentation_samples),'overlay_advance_ms_mean':float(overlay_total)/STEPS*.001,'active_casts_mean':float(cast_total)/STEPS,'max_enemies':max_enemies,'max_paint_actors':max_actors,'component_total_us':main.get_meta('hunt_component_times'),'skill_casts':field.skill_overlay.accepted_casts,'render_profile':field.map_root.get_meta('ultra_render_profile',{}),'canvas_draw_included':false,'gpu_measured':false}
		reports.append(record);print('ULTRA_HUNT_CPU_BUDGET '+JSON.stringify(record))
		main.combat_running=false;await dispose(main)
	var destination:=OS.get_environment('ULTRA_CPU_OUTPUT')
	if destination.is_empty():destination='res://checks/ultra-vfx-2026-10-08/cpu-budget-before-instancing.json'
	var file:=FileAccess.open(destination,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify({'scope':'isolated headless natural20Hz simulation and manually timed3D sync; native canvas draws and GPU are excluded','engine':Engine.get_version_info().string,'profiles':reports},'  ')+'\n');file.close()
	done('ULTRA_HUNT_CPU_BUDGET_OK')
