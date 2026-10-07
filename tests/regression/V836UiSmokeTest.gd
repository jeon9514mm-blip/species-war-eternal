extends "res://tests/support/V83UpgradeTestBase.gd"
func _init()->void:_run.call_deferred()
func capture(name: String)->void:
	var dir: String=OS.get_environment("V836_CAPTURE_DIR")
	if dir.is_empty() or DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(dir.path_join(name+".png"))==OK,"real viewport capture "+name)
func _run()->void:
	var main=await make_main("aurelia",10)
	main.selected_raid_id="gray_meadow";main._build_raid_screen();await settle()
	var open: Button=main.content_root.find_child("RaidContributionOpen",true,false)
	check(open!=null and open.size.y>=42,"raid analysis entry visible touch size")
	await capture("raid-entry")
	main._start_raid();main.combat_timer.stop();main._advance_raid_encounter(.1);main._finish_raid("cancelled")
	main._open_raid_report();await settle()
	check(main.active_screen=="raid_report" and main.content_root.find_child("RaidReportSummary",true,false)!=null,"actual raid report opens")
	await capture("raid-report")
	main._build_faction_war_screen();await settle()
	var war: WorldWarScreen
	for child in main.content_root.get_children():
		if child is WorldWarScreen:war=child
	check(war!=null,"war actual view")
	if war!=null:
		war.set_process(false);war.world_state.rations=10000
		war._recommend_target();war._show_campaign_preparation();await settle()
		check(war._active_modal.find_child("WarReturnReserve",true,false)!=null,"return reserve pre-march")
		check(war._active_modal.find_child("WarRestOpen",true,false)!=null,"frontline actions in scout")
		await capture("war-scout")
		var pos: Vector2i=war.world_state.army_position
		war.world_state.cells[war.world_state._key(pos)].type="fort"
		war.world_state.army_fatigue=45;war._show_frontline_rest();await settle()
		var confirm: Button=war._active_modal.find_child("WarRestConfirm",true,false)
		check(confirm!=null and not confirm.disabled and confirm.size.y>=44,"paid rest confirmation")
		await capture("war-rest")
		var callback: Callable=confirm.get_signal_connection_list("pressed")[0].callable
		var funds: int=war.world_state.rations
		war.world_state.army_fatigue=44
		callback.call();await settle()
		check(war.world_state.army_fatigue==44 and war.world_state.rations>=funds,"stale modal cannot charge")
		var commands: int=war.client_session.command_sequence
		callback.call();await settle()
		check(war.client_session.command_sequence==commands,"closed modal callback ignored")
	await dispose(main);done("v836_ui")
