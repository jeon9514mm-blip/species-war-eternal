extends "res://tools/diagnostics/game-audit-2026-10-07/Mobile25dBenchmark.gd"

func bars(label: String) -> Dictionary:
	var rows: Array = []
	for id: String in game.hero_hp_bars:
		var bar: ProgressBar = game.hero_hp_bars[id]
		var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
		var bg := bar.get_theme_stylebox("background") as StyleBoxFlat
		rows.append({"id":id,"hp":game.hero_battle_state[id].hp,"max_hp":game.hero_battle_state[id].max_hp,"value":bar.value,"min_value":bar.min_value,"max_value":bar.max_value,"visible":bar.visible,"tree_visible":bar.is_visible_in_tree(),"size":[bar.size.x,bar.size.y],"min_size":[bar.get_combined_minimum_size().x,bar.get_combined_minimum_size().y],"fill":fill.bg_color.to_html(),"fill_draw_center":fill.draw_center,"fill_min_size":[fill.get_minimum_size().x,fill.get_minimum_size().y],"bg":bg.bg_color.to_html(),"modulate":bar.modulate.to_html(),"self_modulate":bar.self_modulate.to_html(),"position":[bar.global_position.x,bar.global_position.y]})
	return {"label":label,"physics_frame":Engine.get_physics_frames(),"process_frame":Engine.get_process_frames(),"health_entries":game.combat_labels.terrain._health_entries.size(),"bars":rows}

func run() -> void:
	game=load("res://scenes/PortraitMain.tscn").instantiate();game.save_state_path="user://hunt-native-health-probe.json";game._offline_checked=true;root.add_child(game);await settle()
	game.sound_effects_enabled=false;game.combat_effects_enabled=true;game.combat_fx.enabled=true;game.tutorial_completed=true;game._set_presentation_option("music_enabled",false,false)
	game._set_presentation_option("performance","balanced",false)
	var snapshots: Array=[]
	for faction: String in ["aurelia","noxfera"]:
		game.combat_running=false;game.formation_id="balanced";await fixture(faction);game.combat_running=false;await settle()
		for index in 4:
			await process_frame
			if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
			snapshots.append(bars(faction+"-ready-"+str(index)))
		game.combat_running=true
		await create_timer(1.0).timeout
		if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
		snapshots.append(bars(faction+"-hunt"))
	game.combat_running=false
	var result: Dictionary={"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"snapshots":snapshots}
	var destination:=OS.get_environment("HUNT_HEALTH_OUTPUT")
	if not destination.is_empty():FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	game.presentation_runtime.audio.shutdown();game.background_hunt.discard();game.queue_free();await settle()
	print("HUNT_NATIVE_HEALTH_PROBE "+JSON.stringify(result));quit()
