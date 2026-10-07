extends "res://tests/support/V83UpgradeTestBase.gd"
class FailedStore extends SaveStore:
	func write_save(_path: String, _data: Dictionary) -> Dictionary: return {"ok":false,"status":"injected_menu_save_failure"}
func _init() -> void: run.call_deferred()
func phone(main: Node, named: String) -> void:
	var target: Control = main.find_child(named,true,false)
	check(target != null,"phone control exists "+named)
	if target == null: return
	var point := root.get_final_transform() * target.get_global_rect().get_center()
	for down in [true,false]:
		var event := InputEventScreenTouch.new(); event.position=point; event.pressed=down
		Input.parse_input_event(event)
	await settle()
func run() -> void:
	Input.set_use_accumulated_input(false); Input.emulate_mouse_from_touch=true
	for faction in ["aurelia","noxfera"]:
		var main = await make_main(faction,3)
		root.size=Vector2i(1280,720);await settle();main._open_home();await settle()
		var hunt_root: int=main.content_root.get_instance_id()
		main.enemy_wave[0].hp=maxi(1,int(main.enemy_wave[0].max_hp)/2)
		var enemy_hp: int=main.enemy_wave[0].hp
		var hero_id: String=main._deployed_hero_ids()[0]
		main.hero_battle_state[hero_id].hp=int(main.hero_battle_state[hero_id].max_hp)/2
		var hero_hp: int=main.hero_battle_state[hero_id].hp
		main._build_inventory_screen();await settle()
		check(main.background_hunt.active() and main.enemy_wave.size()>0,faction+" inventory retains the actual hunt")
		main._open_home();await settle()
		check(main.content_root.get_instance_id()==hunt_root and main.enemy_wave[0].hp==enemy_hp and main.hero_battle_state[hero_id].hp==hero_hp,faction+" inventory return preserves screen and injured actors")
		main._toggle_hunt_details()
		main._open_hero_menu();await settle()
		var clock: float=main.invasion.clock
		var wallet_before: int=main.wallet_gold
		for i in 220:
			main._advance_auto_hunt(.1)
			if i%40==0:await process_frame
		var layers_hidden := true
		for layer in main.background_hunt.root.find_children("*","CanvasLayer",true,false): layers_hidden = layers_hidden and not layer.visible
		check(layers_hidden,faction+" retained hunt layers cannot cover menu controls")
		check(main.active_screen=="hero_detail" and main.invasion.clock>clock+21.9,faction+" hero menu advances one live simulation")
		check(main.combat_hunt_cycle>0 and main.wallet_gold>wallet_before,faction+" hidden hunt clears a corps and deposits actual rewards")
		check(main.content_root.find_child("HeroShowcaseView",true,false)!=null,faction+" background ticks keep the hero presenter intact")
		main._open_home();await settle()
		check(main.content_root.get_instance_id()==hunt_root,faction+" hero return restores the same field")
		main._toggle_hunt_details()
		for route in ["_build_world_map_screen","_build_boss_select_screen","_build_growth_screen","_build_meta_hub_screen"]:
			main.call(route);await settle();clock=main.invasion.clock
			main._advance_auto_hunt(.1);main._open_home();await settle()
			check(main.content_root.get_instance_id()==hunt_root and main.invasion.clock>clock,faction+" menu retains live hunt "+route)
		main._toggle_combat(main.combat_labels.toggle)
		main._build_inventory_screen();await settle();clock=main.invasion.clock
		for i in 10:main._advance_auto_hunt(.1)
		main._open_home();await settle()
		check(main.invasion.clock==clock and not main.combat_running,faction+" background menu preserves manual pause")
		main._toggle_combat(main.combat_labels.toggle)
		main._open_presentation_settings();await settle();main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST);await settle()
		check(not main.content_root.has_node("PresentationSettingsOverlay") and main.active_screen=="combat",faction+" Android back closes settings first")
		main._build_inventory_screen();await settle();main.content_root.find_child("GearSettingsToggle",true,false).pressed.emit();await settle()
		main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST);await settle()
		check(main.active_screen=="inventory" and main.content_root.find_child("EquipmentOverlay",true,false)==null,faction+" first Android back closes equipment modal")
		main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST);await settle()
		check(main.active_screen=="combat",faction+" next Android back returns home")
		main.save_store=FailedStore.new();main._save_idle_state();await settle();main.save_store=SaveStore.new()
		await phone(main,"RetryPendingSave")
		check(main.last_save_status=="saved" and not main.has_node("SaveSafetyLayer"),faction+" phone retry completes without a detached target")
		var writes: int=main.hunt_autosave.queued_writes
		for i in 20:main._queue_hunt_save()
		main.hunt_autosave._process(1.0)
		check(main.hunt_autosave.queued_writes==writes+1,faction+" many hunt settlements share one worker save")
		main._save_idle_state()
		check(main.hunt_autosave.worker==null and main.last_save_status=="saved",faction+" critical save flushes worker before writing latest snapshot")
		main._open_hero_menu();await settle();main._restore_deployed_heroes(main._deployed_hero_ids()+[str(main._hero_roster_for_faction()[3].id)])
		main._advance_auto_hunt(.1);main._open_home();await settle()
		check(main.hero_battle_state.size()==main.deployed_heroes.size() and main.hero_map_sprites.size()==main.deployed_heroes.size(),faction+" party edits reconcile actors and live state")
		await dispose(main)
	done("MENU_HUNT_RELIABILITY")
