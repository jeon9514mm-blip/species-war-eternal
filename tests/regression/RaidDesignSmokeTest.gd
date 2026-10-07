extends SceneTree
const LAB=preload("res://scripts/art/RaidDesignLab.gd")
const FIELD=preload("res://scripts/raid/RaidBattlefield.gd")
const SETTINGS=preload("res://scripts/presentation/PresentationSettings.gd")
const REPORTS=preload("res://scripts/raid/RaidReportArchive.gd")
const ORIGINAL_ATTACK={"gray_meadow":60,"forgotten_mine":120,"moonrest_forest":206}
var checks:=0
var failures: Array[String]=[]
var sentinels: Dictionary={}
func _init() -> void:run.call_deferred()
func check(value: bool,note: String) -> void:
	checks+=1
	if not value:failures.append(note);push_error(note)
func settle() -> void:
	for i in 8:await process_frame
func snapshot(game: Node) -> Dictionary:
	return {"boss":game.raid_boss_hp,"heroes":game.hero_battle_state.duplicate(true),"positions":game.raid_positions.duplicate(),"skills":game.hero_skill_runtime.duplicate(true),"elapsed":game.raid_elapsed,"wallet":game.wallet_gold,"rng":game.loot_rng.state}
func touch(point: Vector2,pressed: bool,canceled: bool=false) -> void:
	var event:=InputEventScreenTouch.new();event.position=root.get_final_transform()*point
	event.pressed=pressed;event.canceled=canceled;Input.parse_input_event(event)
func tap(point: Vector2) -> void:
	touch(point,true);touch(point,false)
	await settle()
func run() -> void:
	# These canaries deliberately occupy real production paths, but only inside
	# an explicit disposable test home. Refuse a developer's ordinary user://.
	if not OS.get_data_dir().contains("art-pilot-raid-validation"):
		push_error("Run with fresh XDG_DATA_HOME containing art-pilot-raid-validation")
		quit(2);return
	for path: String in [LAB.SAVE_PATH,SETTINGS.PATH,REPORTS.PATH]:
		if FileAccess.file_exists(path):
			push_error("Refusing to overwrite existing test canary: "+path)
			quit(2);return
		var file:=FileAccess.open(path,FileAccess.WRITE)
		var content: String="PLAYER_DATA_MUST_REMAIN_UNTOUCHED "+path
		file.store_string(content);file.close();sentinels[path]=content
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	Input.set_use_accumulated_input(false);Input.emulate_mouse_from_touch=true
	var game:=LAB.new();root.add_child(game);await settle()
	game.set_process(false);game.set_physics_process(false)
	check(game.save_load_status=="art_lab_no_persistence","preview never loads player progression")
	check(game.save_state_path!=game.SAVE_PATH,"preview uses isolated progress path")
	check(game.presentation_preferences_path!=SETTINGS.PATH,"preview uses isolated preferences")
	check(not FileAccess.file_exists(game.save_state_path),"preview did not write progress")
	for zone: String in ["gray_meadow","forgotten_mine","moonrest_forest"]:
		for size: Vector2i in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1920,1080)]:
			root.size=size;await settle();game.selected_raid_id=zone;game._build_raid_screen();await settle()
			var view=game.content_root.get_node("PortraitRaidView")
			var scroll: ScrollContainer=view.get_node("RaidPartyScroll")
			check(view.stage.size.x>=game.get_viewport_rect().size.x-26,"arena occupies the landscape width")
			check(view.stage.get_global_rect().end.y<view.start.get_global_rect().position.y,"commands do not overlap the viewport")
			check(scroll.get_global_rect().position.y>view.start.get_global_rect().end.y,"party dock clears commands")
			check(game.content_root.get_node_or_null("PortraitNavigation")==null,"raid replaces the crowded bottom navigation with a back button")
			check(not view.options_sheet.visible,"guide is initially collapsed")
			check(not is_instance_valid(view.battlefield_3d.ultimate_details) and is_instance_valid(view.battlefield_3d.painted_backdrop) and not bool(view.battlefield_3d.map_root.get_meta('map_design_removed',true)),"painted raid asset replaces the removed scenery builder")
			for id: String in view.hero_slots:
				check(view.hero_slots[id].size.x>=128 and view.hero_slots[id].size.y>=108,"all hero targets remain reachable and large")
			for point: Vector2 in [FIELD.FLOOR.position,FIELD.FLOOR.end,Vector2(214,486),Vector2(824,280),FIELD.ENTRY]:
				var projected: Vector2=view.battlefield_3d.project_world(view.battlefield_3d.raid_to_world(point))
				check(Rect2(Vector2.ZERO,view.stage.size).has_point(projected),"walkable corner remains visible")
				check(projected.distance_to(view.arena.position+point*view.arena.scale)<.02,"telegraph and floor projection remain aligned")
				check(projected.y<view.battle_hint.position.y-4,"floor clears the context strip")
			await tap(view.start.get_global_rect().get_center());game.combat_timer.stop()
			check(game.raid_running,"visible start button accepts a real phone tap")
			var before:=snapshot(game)
			await tap(view.get_node("RaidOptionsButton").get_global_rect().get_center())
			check(view.options_sheet.visible,"real touch opens the guide and settings")
			var close: Button=view.options_sheet.find_child("RaidOptionsClose",true,false)
			await tap(close.get_global_rect().get_center())
			check(not view.options_sheet.visible,"real touch closes the guide and settings")
			await tap(view.get_node("RaidOptionsButton").get_global_rect().get_center())
			var rally_active: bool=game.raid_rally_active
			var rally_position: Vector2=game.raid_rally_position
			await tap(view.stage.global_position+view.battlefield_3d.project_world(view.battlefield_3d.raid_to_world(Vector2(330,400))))
			check(not view.options_sheet.visible,"real outside tap dismisses the guide")
			check(game.raid_rally_active==rally_active and game.raid_rally_position==rally_position,"modal dismissal cannot send a movement command through the dimmed arena")
			check(snapshot(game)==before,"settings presentation preserves HP cooldowns wallet and RNG")
			var last: String=game._deployed_hero_ids()[-1]
			scroll.ensure_control_visible(view.hero_slots[last]);await settle()
			check(scroll.get_global_rect().encloses(view.hero_slots[last].get_global_rect()),"tenth hero is fully visible after scrolling")
			await tap(view.hero_slots[last].get_global_rect().get_center())
			check(view.selected_hero_id==last,"real touch selects tenth hero")
			check(snapshot(game)==before,"hero selection preserves live combat")
			var other: Control=view.hero_slots[game._deployed_hero_ids()[-2]]
			scroll.ensure_control_visible(other);await settle()
			var canceled_point:=other.get_global_rect().get_center()
			touch(canceled_point,true);touch(canceled_point,false,true);await settle()
			check(view.selected_hero_id==last and snapshot(game)==before,"canceled selection preserves hero and encounter")
			var point:=Vector2(420,460)
			await tap(view.stage.global_position+view.battlefield_3d.project_world(view.battlefield_3d.raid_to_world(point)))
			check(game.raid_rally_active and game.raid_rally_position.distance_to(point)<.05,"floor touch uses the intended gameplay coordinates")
			var destination: Vector2=game.raid_rally_position
			await tap(view.dodge_button.get_global_rect().get_center())
			check(game.raid_dodge_cooldown>0 and game.raid_rally_position==destination,"separate dodge button cannot accidentally order movement")
			var fallen: String=game._deployed_hero_ids()[0]
			game.hero_battle_state[fallen].hp=0
			view.refresh();view.hero_actors[fallen]._process(1.0)
			game.raid_boss_position=Vector2(700,420)
			game.raid_boss_sprite.position=game.raid_boss_position
			before=snapshot(game);game._apply_portrait_resize();await settle()
			view=game.content_root.get_node("PortraitRaidView")
			check(view.selected_hero_id==last and snapshot(game)==before,"resize preserves selected hero and live encounter")
			check(view.hero_actors[fallen].state=="death" and view.hero_actors[fallen].modulate.a<.2,"resize cannot visually revive a defeated hero")
			check(game.raid_boss_sprite.position==game.raid_boss_position,"resize keeps the live boss at its gameplay position")
			check(view.rally_marker.visible and view.rally_marker.position==destination,"resize preserves the active movement marker")
			game._finish_raid("defeat");await settle()
			check(view.start.text=="다시 도전" and not view.start.disabled,"defeat exposes a usable retry")
			await tap(view.start.get_global_rect().get_center());game.combat_timer.stop()
			check(game.raid_running,"visible retry button accepts a real phone tap")
			check(game.raid_boss_hp==game.raid_boss_max_hp,"retry resets boss HP exactly once")
			check(game.raid_boss_max_hp==int(game._raid_zone().power)*200,"retry retains tenfold strength")
			check(game.raid_boss_attack==int(ORIGINAL_ATTACK[zone])*10,"retry retains tenfold rounded attack")
			check(game._alive_hero_ids().size()==10,"retry revives the full party")
			game._finish_raid("cancelled")
	game._save_idle_state();game._queue_hunt_save();game._save_ui_preferences()
	check(not FileAccess.file_exists(game.save_state_path),"all preview save entry points remain in memory")
	check(not FileAccess.file_exists(game.presentation_preferences_path),"preview settings never create a config")
	for path: String in sentinels:
		check(FileAccess.get_file_as_string(path)==sentinels[path],"preview preserves production file byte for byte: "+path)
	game.presentation_runtime.audio.shutdown();game.free();await settle()
	print("RAID_DESIGN checks=%d failures=%s" % [checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
