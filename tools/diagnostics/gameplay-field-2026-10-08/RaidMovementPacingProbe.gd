extends 'res://tests/support/V83UpgradeTestBase.gd'
## Actual raid movement/camera geometry. No combat reward or player save used.
func _init() -> void:run.call_deferred()
func run() -> void:
	var results: Array[Dictionary]=[]
	for faction: String in ['aurelia','noxfera']:
		var main=await make_main(faction,10);root.size=Vector2i(1280,720);await settle()
		for zone: String in ['gray_meadow','forgotten_mine','moonrest_forest']:
			main.selected_raid_id=zone;main._build_raid_screen();await settle();await settle()
			main._start_raid();main.combat_timer.stop();await settle()
			var view=main.content_root.get_node('PortraitRaidView');var field=view.battlefield_3d
			view.set_process(false);field.set_process(false)
			var maximum:=0.0;var steady_maximum:=0.0;var pixel_maximum:=0.0;var oversized:=0;var largest: Dictionary={}
			for step in 120:
				var before: Dictionary=main.raid_positions.duplicate()
				main.raid_elapsed+=.05;main._raid_move_actors(.05)
				for id: String in before:
					var distance: float=(Vector2(main.raid_positions[id])-Vector2(before[id])).length()
					var pixel_distance: float=field.project_world(field.raid_to_world(main.raid_positions[id])).distance_to(field.project_world(field.raid_to_world(before[id])))
					if distance>10.25+.01:oversized+=1
					if step>=60:steady_maximum=maxf(steady_maximum,distance)
					pixel_maximum=maxf(pixel_maximum,pixel_distance)
					if distance>maximum:
						maximum=distance;largest={'id':id,'step':step,'before':[before[id].x,before[id].y],'after':[main.raid_positions[id].x,main.raid_positions[id].y],'logical_pixels':pixel_distance}
			var minimum:=INF;var ids: Array=main.raid_positions.keys();var final_positions: Dictionary={}
			for id: String in ids:final_positions[id]={'position':[main.raid_positions[id].x,main.raid_positions[id].y],'attack_distance':Vector2(main.raid_positions[id]).distance_to(main.raid_boss_position)}
			for i in ids.size():
				for j in range(i+1,ids.size()):
					minimum=minf(minimum,field.project_world(field.raid_to_world(main.raid_positions[ids[i]])).distance_to(field.project_world(field.raid_to_world(main.raid_positions[ids[j]]))))
			var clearance: Vector2=field.raid_clearances()
			results.append({'faction':faction,'zone':zone,'seconds':6.0,'max_combat_coordinate_step':maximum,'max_step_after_3_seconds':steady_maximum,'max_logical_pixel_step':pixel_maximum,'steps_above_fastest_205px_per_second':oversized,'largest':largest,'final_min_logical_gap':minimum,'hero_clearance':clearance.x,'boss_clearance':clearance.y,'factor':field.raid_projection_factor(),'final_positions':final_positions,'final_boss':[main.raid_boss_position.x,main.raid_boss_position.y]})
			main._finish_raid('defeat')
		await dispose(main)
	var report: Dictionary={'renderer':'headless_dummy','gpu_fps_measurement':false,'real_production_raid_geometry':true,'step_seconds':.05,'normal_role_speed':128,'maximum_rally_speed':205,'fastest_allowed_combat_coordinate_step':10.25,'results':results}
	var output: String=OS.get_environment('RAID_PACING_OUTPUT')
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,'\t'));file.close()
	print('RAID_MOVEMENT_PACING '+JSON.stringify(report));quit(0)
