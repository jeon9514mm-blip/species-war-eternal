extends "res://tests/support/V83UpgradeTestBase.gd"
func _init() -> void: run.call_deferred()
func touch(main: Node, named: String) -> void:
	var control: Control = main.content_root.find_child(named,true,false)
	check(control != null and control.is_visible_in_tree(),"visible touch target "+named)
	if control == null: return
	var point := root.get_final_transform()*control.get_global_rect().get_center()
	for down in [true,false]:
		var event := InputEventScreenTouch.new(); event.position=point; event.pressed=down
		Input.parse_input_event(event)
	await settle()
func geometry(main: Node) -> void:
	var hud: Control = main.portrait_hud
	var strip: Control = hud.get_node("HuntHeroGaugeStrip")
	var nav: Control = hud.get_node("PortraitNavigation")
	check(main.combat_field_rect.size.x == main.get_viewport_rect().size.x-24,"battlefield spans screen without right sidebar")
	check(main.combat_field_rect.end.y <= strip.position.y-22,"battlefield ends above status and hero gauges")
	check(strip.get_rect().end.y <= nav.position.y,"hero strip is directly above navigation")
	check(nav.size.y == 58,"navigation is shorter than the former 96 pixel panel")
	for id in hud.bars:
		var row: Dictionary = hud.bars[id]
		check(strip.get_global_rect().encloses(row.slot.get_global_rect()),"hero touch card fits strip "+id)
		check(row.slot.get_global_rect().encloses(row.hp.get_global_rect()) and row.slot.get_global_rect().encloses(row.ultimate.get_global_rect()),"both gauges fit touch card "+id)
	for button in nav.get_children():
		for child in button.get_children():
			if child is Control: check(button.get_global_rect().encloses(child.get_global_rect()),"compact navigation icon/label fit")
func run() -> void:
	var main = await make_main("aurelia",10)
	main._build_combat_screen();await settle()
	main.combat_running=true;main.tutorial_completed=true
	var id: String = main._deployed_hero_ids()[0]
	main.hero_battle_state[id].hp = float(main.hero_battle_state[id].max_hp)*.37
	main.hero_battle_state[id].ultimate = 63
	main.portrait_hud.refresh();await settle()
	geometry(main)
	var speed: Button = main.portrait_hud.speed_button
	var glyphs: Vector2 = speed.get_theme_font("font").get_string_size("×2",HORIZONTAL_ALIGNMENT_LEFT,-1,speed.get_theme_font_size("font_size"))
	check(glyphs.x+speed.get_theme_stylebox("normal").get_minimum_size().x <= speed.size.x,"speed icon has room for the multiplication sign and digit")
	check(absf(main.portrait_hud.bars[id].hp.value-37)<.01 and main.portrait_hud.bars[id].ultimate.value == 63,"footer gauges reflect live HP and awakening energy")
	await touch(main,"PortraitSpeedButton")
	check(main.battle_speed == 2 and main.portrait_hud.speed_button.text == "×2","phone touch changes speed to compact ×2")
	await touch(main,"PortraitSpeedButton")
	check(main.battle_speed == 1 and main.portrait_hud.speed_button.text == "×1","second touch restores ×1")
	await touch(main,"PortraitAutoButton");check(not main.combat_running,"phone touch pauses hunt")
	await touch(main,"PortraitAutoButton");check(main.combat_running,"phone touch resumes hunt")
	await touch(main,"PortraitDetailsButton")
	check(main.portrait_hud.options_layer.visible,"compact settings opens hunt commands")
	var before: bool = main.ultimate_auto
	await touch(main,"PortraitUltimateAuto")
	check(main.ultimate_auto != before,"automatic ultimate command remains reachable")
	await touch(main,"HuntOptionsClose")
	check(not main.portrait_hud.options_layer.visible,"hunt commands close by phone touch")
	main.offline_pending_gold=42;main.portrait_hud.refresh()
	await touch(main,"PortraitDetailsButton")
	check(main.portrait_hud.offline_button.is_visible_in_tree() and not main.portrait_hud.offline_button.disabled,"pending offline rewards remain reachable in hunt commands")
	await touch(main,"HuntOptionsClose")
	var hp: float = main.hero_battle_state[id].hp
	var energy: float = main.hero_battle_state[id].ultimate
	var cycle: int = main.combat_hunt_cycle
	var rng_state: int = main.loot_rng.state
	root.size=Vector2i(1600,720);await settle();geometry(main)
	check(main.hero_battle_state[id].hp == hp and main.hero_battle_state[id].ultimate == energy and main.combat_hunt_cycle == cycle and main.loot_rng.state == rng_state,"wide resize preserves HP, energy, encounter and reward RNG")
	root.size=Vector2i(720,405);await settle();geometry(main)
	await touch(main,"PortraitSpeedButton")
	check(main.battle_speed == 2,"small phone window still accepts speed touch")
	await touch(main,"HuntHero_"+id)
	check(main.active_screen == "hero_detail","footer hero touch opens growth and equipment")
	main._open_home();await settle()
	check(main.hero_battle_state[id].hp == hp and main.hero_battle_state[id].ultimate == energy,"returning to hunt retains injured HP and awakening energy")
	main._restore_deployed_heroes([]);main._build_combat_screen();await settle()
	check(main.portrait_hud.bars.is_empty(),"empty party has no stale gauges")
	await touch(main,"HuntEmptyPartyEdit")
	check(main.active_screen == "hero_select","empty footer opens party formation")
	await dispose(main);done("HUNT_COMPACT_HUD")
