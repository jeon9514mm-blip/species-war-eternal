extends "res://tests/support/V83UpgradeTestBase.gd"
const DOCK_LAYOUT := preload("res://scripts/portrait/LandscapeHuntLayout.gd")
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
	var screen: Vector2 = main.get_viewport_rect().size
	check(main.combat_field_rect.end.y <= strip.position.y-8,"battlefield ends above the unified dock")
	check(strip.get_global_rect().encloses(nav.get_global_rect()),"navigation is inside the unified dock")
	check(not hud.status_label.is_visible_in_tree(),"duplicate hunt-status row stays hidden")
	check(nav.get_child_count() == 5,"all five navigation destinations remain available")
	check(strip.get_global_rect().encloses(hud.party_summary.get_global_rect()),"party summary stays inside dock")
	if DOCK_LAYOUT.single_row(screen):
		check(hud.slot_row.get_global_rect().end.x <= nav.get_global_rect().position.x-8,"single-row heroes do not overlap navigation")
		check(strip.size.y == 76 and nav.size.y == 60,"wide layout uses a 76-unit single dock")
	else:
		check(hud.slot_row.get_global_rect().end.y <= nav.get_global_rect().position.y-8,"narrow layout stacks without overlapping heroes")
		check(strip.size.y == 136 and nav.size.y == 48,"narrow layout retains usable controls")
	for id in hud.bars:
		var row: Dictionary = hud.bars[id]
		check(strip.get_global_rect().encloses(row.slot.get_global_rect()),"hero touch card fits strip "+id)
		check(row.slot.size.x >= 48 and row.slot.size.y >= 48,"hero hit box is not shrunk below 48 viewport units "+id)
		check(not row.level.is_visible_in_tree(),"repeated level is removed from hunt HUD "+id)
		var portrait: TextureRect = row.slot.get_node("Portrait_"+str(id))
		check(portrait.texture != null and portrait.size == Vector2(44,44),"original hero portrait has a 44x44 display box "+id)
		check(row.slot.get_global_rect().encloses(row.hp.get_global_rect()) and row.slot.get_global_rect().encloses(row.ultimate.get_global_rect()),"both gauges fit touch card "+id)
	for entry: Dictionary in preload("res://scripts/ui/NavigationCatalog.gd").dock_entries():
		var target: Button = nav.get_node("PortraitNav_"+str(entry.id))
		check(target.pressed.is_connected(Callable(main,str(entry.method))),"navigation keeps original destination: "+str(entry.id))
	for button in nav.get_children():
		check(button.size.x >= 48 and button.size.y >= 48,"navigation keeps usable hit boxes")
		for child in button.get_children():
			if child is Control: check(button.get_global_rect().encloses(child.get_global_rect()),"compact navigation icon/label fit")
func run() -> void:
	var main = await make_main("aurelia",10)
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	await settle()
	main._build_combat_screen();await settle()
	main.combat_running=true;main.tutorial_completed=true
	var id: String = main._deployed_hero_ids()[0]
	main.hero_battle_state[id].hp = float(main.hero_battle_state[id].max_hp)*.37
	main.hero_battle_state[id].ultimate = 63
	main.portrait_hud.refresh();await settle()
	geometry(main)
	check(main.portrait_hud.party_count.text == "10/10","party summary reflects the live team")
	var row: Dictionary = main.portrait_hud.bars[id]
	var saved_runtime: Dictionary = main.hero_skill_runtime.get(id,{}).duplicate(true)
	main.hero_skill_runtime[id] = {"remaining":0.0,"secondary_remaining":0.0}
	main.portrait_hud.refresh()
	check(not row.state_badge.visible,"repeated ready label is hidden")
	main.hero_battle_state[id].ultimate=100;main.portrait_hud.refresh()
	check(row.state_badge.visible and row.skill.text == "각성","ready awakening remains visibly identified")
	main.hero_battle_state[id].hp=0;main.portrait_hud.refresh()
	check(row.state_badge.visible and row.skill.text == "쓰러짐" and main.portrait_hud.party_count.text == "9/10","KO and live count update without colour-only signalling")
	main.hero_battle_state[id].hp=float(main.hero_battle_state[id].max_hp)*.37
	main.hero_battle_state[id].ultimate=63
	main.hero_skill_runtime[id] = {"remaining":4.0,"secondary_remaining":5.0}
	main.portrait_hud.refresh()
	check(row.state_badge.visible and row.skill.text == "4초","active cooldown is not lost during simplification")
	main.hero_skill_runtime[id]=saved_runtime;main.portrait_hud.refresh()
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
	root.content_scale_size=Vector2i(960,540);root.size=Vector2i(960,540);await settle();geometry(main)
	check(not DOCK_LAYOUT.single_row(main.get_viewport_rect().size),"narrow viewport actually exercises stacked branch")
	root.content_scale_size=Vector2i(720,405);root.size=Vector2i(720,405);await settle();geometry(main)
	await touch(main,"PortraitSpeedButton")
	check(main.battle_speed == 2,"small phone window still accepts speed touch")
	await touch(main,"HuntHero_"+id)
	check(main.active_screen == "hero_detail","footer hero touch opens growth and equipment")
	main._open_home();await settle()
	check(main.hero_battle_state[id].hp == hp and main.hero_battle_state[id].ultimate == energy,"returning to hunt retains injured HP and awakening energy")
	await touch(main,"HuntPartySummary")
	check(main.active_screen == "hero_select","party summary opens existing formation screen")
	main._open_home();await settle()
	main._restore_deployed_heroes([]);main._build_combat_screen();await settle()
	check(main.portrait_hud.bars.is_empty(),"empty party has no stale gauges")
	await touch(main,"HuntEmptyPartyEdit")
	check(main.active_screen == "hero_select","empty footer opens party formation")
	await dispose(main);done("HUNT_COMPACT_HUD")
