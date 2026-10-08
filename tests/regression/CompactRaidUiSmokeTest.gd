extends 'res://tests/support/V83UpgradeTestBase.gd'
## UI state transitions must retain the real encounter, touch area and retry.
func _init() -> void:run.call_deferred()
func combat(main: Node) -> Dictionary:
	return {'boss':main.raid_boss_hp,'elapsed':main.raid_elapsed,'heroes':main.hero_battle_state.duplicate(true),'positions':main.raid_positions.duplicate(),'skills':main.hero_skill_runtime.duplicate(true),'wallet':main.wallet_gold,'loot_rng':main.loot_rng.state}
func run() -> void:
	var main=await make_main('aurelia',10)
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1920,1080)]:
		root.size=dimensions;await settle()
		main.selected_raid_id='gray_meadow';main._build_raid_screen();await settle();await settle()
		var view=main.content_root.get_node('PortraitRaidView')
		var installed: Vector2=view.get_meta('installed_viewport_size')
		check(view.arena_body.position==Vector2(12,86) and view.arena_body.size==Vector2(installed.x-24,installed.y-282),'premium chrome preserves exact battlefield viewport')
		check(view.time_readout.text=='04:00','time has a separate minute:second readout')
		check('100%' in view.information.text and not '단계' in view.information.text and not '남은' in view.information.text,'HP readout keeps health separate from time and phase')
		check(view.start.visible and not view.start.disabled,'preparation exposes start action')
		check(not view.options_sheet.visible,'detailed options remain collapsed')
		for id: String in view.hero_slots:
			check('Lv.60' in view.hero_state_labels[id].text,'party card exposes actual hero level')
			check(not view.hero_state_labels[id].get_global_rect().intersects(view.hero_bars[id].get_global_rect()),'hero status clears the health rail')
		main._start_raid();main.combat_timer.stop();await settle()
		view.refresh();await settle()
		check(not view.start.visible,'combat gives command space to the four usable actions')
		for button: Button in [view.follow_button,view.skill_cast_button,view.ultimate_cast_button,view.dodge_button]:
			check(button.visible and button.size.x>=130 and button.size.y>=62,'combat command retains a large touch target')
			check(button.get_global_rect().position.y>view.stage.get_global_rect().end.y,'combat command clears touch-to-move viewport')
		main.raid_elapsed=211.0;view.refresh()
		check(view.time_readout.text=='00:29','remaining time is readable in final thirty seconds')
		var before:=combat(main)
		view._open_options();view.options_sheet.hide();view.refresh();await settle()
		check(combat(main)==before,'presentation and options leave gameplay state unchanged')
		main._finish_raid('defeat');view.refresh();await settle()
		check(view.start.visible and view.start.text=='다시 도전' and not view.start.disabled,'result restores actionable retry')
		check(view.phase_readout.text=='전투 종료','phase readout reflects ended encounter')
	await dispose(main)
	done('COMPACT_RAID_UI')
