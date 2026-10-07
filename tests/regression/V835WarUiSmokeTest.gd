extends "res://tests/support/V83UpgradeTestBase.gd"
func _init() -> void: _run.call_deferred()
func _capture(name: String) -> void:
	var directory: String = OS.get_environment("V835_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(directory.path_join(name + ".png"))
	check(error == OK, "actual viewport capture " + name)
func _run() -> void:
	var main = await make_main("aurelia",10)
	main._build_faction_war_screen();await settle()
	var war: WorldWarScreen
	for child in main.content_root.get_children():
		if child is WorldWarScreen:war=child
	check(war!=null,"actual faction screen opens")
	if war==null:await dispose(main);done("v835_war_ui");return
	war.set_process(false)
	war.world_state.rations=10000;war.world_state.army_fatigue=0;war.world_state.army_wounds.clear()
	war._recommend_target();await settle();war._show_campaign_preparation();await settle()
	var confirm: Button=war._active_modal.find_child("WarConfirmMarch",true,false)
	check(confirm!=null and not confirm.disabled,"scout confirmation available")
	var calls: Array=confirm.get_signal_connection_list("pressed")
	var old_callback: Callable=calls[0]["callable"]
	var funds: int=war.world_state.rations
	# Server-side tactic changes while old confirmation is open, same route.
	war.world_state.battle_stance="assault"
	old_callback.call();await settle()
	check(not war.march_state.active and war.world_state.rations==funds,"changed tactic requires fresh review")
	check(war._active_modal.find_child("WarPreparationMessage",true,false).text.contains("바뀌"),"stale review explained")
	var current_confirm: Button=war._active_modal.find_child("WarConfirmMarch",true,false)
	var latest_plan: Dictionary=war.march_state.plan(war.world_state,war.selected_cell)
	current_confirm.pressed.emit();await settle()
	check(war.march_state.active and war.world_state.rations==funds-int(latest_plan["ration_cost"]),"one confirmation charges exact cost")
	var sequence: int=war.client_session.command_sequence
	old_callback.call();await settle()
	check(war.client_session.command_sequence==sequence,"old callback cannot issue second march")
	war._cancel_march();await settle()
	old_callback.call();await settle()
	check(not war.march_state.active,"old callback invalid after cancel")
	war._recommend_target();war._show_campaign_preparation();await settle()
	for goal: String in ["resources","supply","forts"]:
		var button: Button=war._active_modal.find_child("WarGoal_"+goal,true,false)
		check(button!=null and button.size.y>=44,"purpose button touch target "+goal)
	var scroll: ScrollContainer=war._active_modal.find_child("WarCampaignScroll",true,false)
	check(scroll!=null and scroll.get_child_count()==1,"scout info shares existing scroll")
	await _capture("v83-5-scout")
	funds=war.world_state.rations;sequence=war.client_session.command_sequence
	war._active_modal.find_child("WarGoal_resources",true,false).pressed.emit();await settle()
	check(war.world_state.rations==funds and war.client_session.command_sequence==sequence and not war.march_state.active,"recommendation only selects, never dispatches")
	# Real resolver report shown through actual screen, not a painted mockup.
	var result: Dictionary=WorldBattleResolver.new().resolve(war.attacker_squad,WorldBattleResolver.new().make_garrison("neutral",Vector2i(4,10),"fort",600),0,1.18,835,"assault")
	result["tile_name"]="진영전 시험 보고서"
	war._show_battle_report(result);await settle()
	for action: String in ["garrison","return","target"]:
		var button: Button=war._active_modal.find_child("WarAfterBattle_"+action,true,false)
		check(button!=null and button.size.y>=44,"post battle action "+action)
	await _capture("v83-5-war-report")
	var report_scroll: ScrollContainer=war._active_modal.find_child("WarBattleReportScroll",true,false)
	report_scroll.scroll_vertical=int(report_scroll.get_v_scroll_bar().max_value);await settle()
	await _capture("v83-5-war-actions")
	var next: Button=war._active_modal.find_child("WarAfterBattle_target",true,false)
	next.pressed.emit();await settle()
	check(not war.march_state.active and war.world_state.rations==funds,"next target does not start combat")
	main.tower_floor = 12
	main._open_practice_screen(); await settle()
	var practice_floor: SpinBox = main.content_root.find_child("PracticeTowerFloor", true, false)
	var tower_hint: Label = main.content_root.find_child("PracticeTowerPattern", true, false)
	check(tower_hint != null and tower_hint.text.contains("분산"), "practice shows selected floor counterplay")
	practice_floor.value = 10; await settle()
	check(tower_hint.text.contains("회복 지원"), "practice counterplay updates with floor")
	var weekly_hint: Label = main.content_root.find_child("PracticeWeeklyPattern", true, false)
	check(weekly_hint != null and weekly_hint.text.contains("두 번째"), "weekly pattern gate explained before practice")
	main.set_meta("content_meta_tab", "weekly"); main._build_meta_hub_screen(); await settle()
	weekly_hint = main.content_root.find_child("WeeklyPatternObjective", true, false)
	check(weekly_hint != null and weekly_hint.text.contains("최고"), "weekly real entry explains unchanged prior best")
	await _capture("v83-5-weekly-hints")
	await dispose(main)
	done("v835_war_ui")
