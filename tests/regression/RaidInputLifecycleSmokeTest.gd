extends 'res://tests/support/V83UpgradeTestBase.gd'
## Real production pointer and keyboard routing. Each fixture has its own save.
func _init() -> void:run.call_deferred()

func key(code: Key,shift: bool=false) -> void:
	for down: bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code
		event.pressed=down;event.shift_pressed=shift;root.push_input(event,true)
	await settle()

func mouse(point: Vector2,down: bool) -> void:
	var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
	var event:=InputEventMouseButton.new();event.position=point
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true)
	await settle()

func hover(point: Vector2) -> void:
	var event:=InputEventMouseMotion.new();event.position=point;event.button_mask=0
	root.push_input(event,true);await settle()

func touch(point: Vector2,down: bool,index: int,canceled: bool=false) -> void:
	var event:=InputEventScreenTouch.new();event.position=point
	event.pressed=down;event.index=index;event.canceled=canceled;root.push_input(event,true)
	await settle()

func battle(main: Node) -> Dictionary:
	return {'hp':main.hero_battle_state.duplicate(true),'positions':main.raid_positions.duplicate(),'boss_hp':main.raid_boss_hp,'skills':main.hero_skill_runtime.duplicate(true),'wallet':main.wallet_gold,'gems':main.wallet_gems,'loot_rng':main.loot_rng.state}

func run() -> void:
	Input.set_use_accumulated_input(false);Input.emulate_mouse_from_touch=false
	for faction: String in ['aurelia','noxfera']:
		var main=await make_main(faction,3);root.size=Vector2i(1280,720);await settle()
		main.selected_raid_id='gray_meadow';main._build_raid_screen();await settle();await settle()
		var view=main.content_root.get_node('PortraitRaidView')
		var options: Button=view.get_node('RaidOptionsButton')
		var close: Button=view.options_sheet.find_child('RaidOptionsClose',true,false)
		view.start.grab_focus();view._open_options();await settle()
		check(root.gui_get_focus_owner()==close,'opening raid guide moves keyboard focus to its close control '+faction)
		await key(KEY_SPACE)
		check(not main.raid_running,'accepting the guide cannot start the raid underneath '+faction)
		view.options_sheet.hide();await settle()
		options.grab_focus();view._open_options();await settle()
		view.start.grab_focus();await key(KEY_SPACE)
		check(not main.raid_running and view.options_sheet.visible and root.gui_get_focus_owner()==close,'guide consumes accept if a live presenter assigns focus outside the modal '+faction)
		for index in 12:
			await key(KEY_TAB,index>=6)
			var focus: Control=root.gui_get_focus_owner()
			check(is_instance_valid(focus) and view.options_sheet.is_ancestor_of(focus),'raid guide owns forward/backward Tab navigation '+faction+' '+str(index))
		await key(KEY_ESCAPE)
		check(not view.options_sheet.visible and root.gui_get_focus_owner()==options,'Escape closes raid guide and restores opener focus '+faction)
		main._start_raid();main.combat_timer.stop();await settle()
		var point: Vector2=view.stage.get_global_rect().get_center()
		await mouse(point,true)
		check(view._dragging and main.raid_rally_active,'held floor pointer orders real raid movement '+faction)
		await mouse(options.get_global_rect().get_center(),false)
		check(not view._dragging and view._stage_pointer==-2,'release outside the arena retires the stage mouse pointer '+faction)
		var destination: Vector2=main.raid_rally_position
		await hover(point+Vector2(70,25))
		check(main.raid_rally_position==destination,'hovering after release cannot issue another movement order '+faction)
		await touch(point,true,2)
		check(view._stage_pointer==2 and view._dragging,'raid floor admits one owned touch pointer '+faction)
		await touch(point+Vector2(50,0),true,3)
		check(view._stage_pointer==2,'second finger cannot replace the held stage pointer '+faction)
		await touch(options.get_global_rect().get_center(),false,2,true)
		check(not view._dragging and view._stage_pointer==-2,'canceled touch outside the arena clears held state '+faction)
		await touch(point,true,4)
		view._open_options();await settle()
		check(not view._dragging and view._stage_pointer==-2,'opening raid guide cancels a held floor touch '+faction)
		view.options_sheet.hide();await settle()
		await touch(point,true,5);view.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
		check(not view._dragging and view._stage_pointer==-2,'window focus loss cancels owned raid pointers '+faction)
		view.dodge_button.grab_focus();view._open_options();await settle()
		var snapshot:=battle(main)
		await key(KEY_TAB);await key(KEY_TAB,true)
		await key(KEY_ESCAPE)
		check(battle(main)==snapshot and root.gui_get_focus_owner()==view.dodge_button,'guide keyboard routing preserves live HP cooldowns positions and wallet '+faction)
		main._finish_raid('defeat');view.refresh();await settle()
		var wallet: int=main.wallet_gold;var crystals: int=main.raid_crystals
		var result: Dictionary=main.raid_reward_receipt.duplicate(true)
		main._finish_raid('victory')
		check(not main.raid_running and main.wallet_gold==wallet and main.raid_crystals==crystals and main.raid_reward_receipt==result,'duplicate result callbacks cannot award a settled raid twice '+faction)
		main._save_blocked_for_newer_version=true;main.set_meta('game_save_pending',false)
		snapshot=battle(main);var serial: int=main.raid_encounter_serial
		main._start_raid()
		check(not main.raid_running and main.raid_encounter_serial==serial and battle(main)==snapshot,'newer-version save blocks raid entry before combat and rewards '+faction)
		main._save_blocked_for_newer_version=false
		await dispose(main)
	done('RAID_INPUT_LIFECYCLE')
