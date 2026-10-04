extends "res://scripts/V83UpgradeTestBase.gd"
const FIELD=preload("res://scripts/RaidBattlefield.gd")
func _init() -> void: run.call_deferred()
func touch(point: Vector2,down: bool,canceled: bool=false) -> void:
	var event:=InputEventScreenTouch.new();event.position=root.get_final_transform()*point
	event.pressed=down;event.canceled=canceled;Input.parse_input_event(event)
func swipe(point: Vector2,delta: Vector2) -> void:
	touch(point,true)
	var event:=InputEventScreenDrag.new();event.position=root.get_final_transform()*(point+delta)
	event.relative=root.get_final_transform().basis_xform(delta);Input.parse_input_event(event)
	touch(point+delta,false);await settle()
func tap(point: Vector2) -> void:
	touch(point,true);touch(point,false);await settle()
func battle(main: Node) -> Dictionary:
	return {"hp":main.hero_battle_state.duplicate(true),"positions":main.raid_positions.duplicate(),"boss_hp":main.raid_boss_hp,"boss_position":main.raid_boss_position,"skills":main.hero_skill_runtime.duplicate(true),"gold":main.wallet_gold}
func run() -> void:
	Input.set_use_accumulated_input(false);Input.emulate_mouse_from_touch=true
	for faction in ["aurelia","noxfera"]:
		var main=await make_main(faction,10)
		for zone in ["gray_meadow","forgotten_mine","moonrest_forest"]:
			for dimensions in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1920,1080),Vector2i(720,1280)]:
				root.size=dimensions;await settle();main.selected_raid_id=zone
				main._build_raid_screen();await settle();await settle()
				var view=main.content_root.get_node("PortraitRaidView")
				var scroll: ScrollContainer=view.get_node("RaidPartyScroll")
				var nav: Control=main.content_root.get_node("PortraitNavigation")
				check(scroll.get_global_rect().end.y<=nav.get_global_rect().position.y,"party strip clears navigation "+str(dimensions))
				check(not scroll.get_global_rect().intersects(view.start.get_global_rect()),"party strip clears raid commands")
				for slot in view.hero_slots.values():check(slot.size.x>=128 and slot.size.y>=108,"raid hero retains a large touch target")
				var terrain=view.battlefield_3d
				for point in [FIELD.FLOOR.position,FIELD.FLOOR.end,Vector2(214,486),Vector2(824,280),FIELD.ENTRY]:
					var projected: Vector2=terrain.project_world(terrain.raid_to_world(point))
					check(Rect2(Vector2.ZERO,terrain.size).has_point(projected),"all reachable corners stay visible")
					check(projected.y<minf(view.dodge_button.position.y,view.follow_button.position.y)-4,"all floor points clear dodge and follow buttons")
					check(projected.distance_to(view.arena.position+point*view.arena.scale)<.02,"camera warnings and touch use the same coordinates")
				main._start_raid();main.combat_timer.stop();await settle()
				var ids: Array=main._deployed_hero_ids();var selected: String=view.selected_hero_id
				var before:=battle(main)
				if scroll.get_h_scroll_bar().max_value>scroll.size.x+1:
					var start: Vector2=view.hero_slots[ids[3]].get_global_rect().get_center()
					await swipe(start,Vector2(-180,0))
					check(scroll.scroll_horizontal>0,"phone swipe scrolls large cards")
					check(view.selected_hero_id==selected,"swipe does not change manual cast target")
				var last: Control=view.hero_slots[ids[-1]]
				scroll.ensure_control_visible(last);await settle()
				check(scroll.get_global_rect().encloses(last.get_global_rect()),"tenth hero is fully reachable")
				await tap(last.get_global_rect().get_center())
				check(view.selected_hero_id==str(ids[-1]),"real phone tap selects the tenth hero")
				check(battle(main)==before,"scroll and selection preserve HP cooldowns positions and wallet")
				var other: Control=view.hero_slots[ids[-2]]
				scroll.ensure_control_visible(other);await settle()
				var point: Vector2=other.get_global_rect().get_center()
				touch(point,true);touch(point,false,true);await settle()
				check(view.selected_hero_id==str(ids[-1]),"canceled touch cannot select a different hero")
				var move_point:=Vector2(420,460)
				var screen_point: Vector2=view.stage.global_position+terrain.project_world(terrain.raid_to_world(move_point))
				await tap(screen_point)
				check(main.raid_rally_active and main.raid_rally_position.distance_to(FIELD.clamp_to_floor(move_point))<.05,"real floor tap orders the intended destination")
				var destination: Vector2=main.raid_rally_position
				await tap(view.dodge_button.get_global_rect().get_center())
				check(main.raid_dodge_cooldown>0 and main.raid_rally_position==destination,"dodge tap activates dodge without ordering movement underneath")
				before=battle(main)
				main._apply_portrait_resize();await settle();await settle()
				view=main.content_root.get_node("PortraitRaidView")
				check(view.selected_hero_id==str(ids[-1]) and battle(main)==before,"raid resize preserves selected hero and live combat")
				main._finish_raid("defeat")
		await dispose(main)
	done("RAID_TOUCH_LAYOUT")
