extends SceneTree

const ROSTER = preload("res://scripts/heroes/HeroRosterCatalog.gd")
const VISUALS = preload("res://scripts/heroes/HeroVisualCatalog.gd")
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for index in 4:
		await process_frame

func _run() -> void:
	var main = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main._offline_checked = true
	main.tutorial_completed = true
	main.idle_stage = 1000
	for faction in ["aurelia", "noxfera"]:
		main.selected_faction = faction
		main._setup_hero_progress(main._hero_roster_for_faction())
		main._build_hero_select_screen()
		await settle()
		var list: ScrollContainer = main.content_root.find_child("HeroRosterScroll", true, false)
		var grid: GridContainer = list.get_child(0)
		check(grid.get_child_count() == 15, "%s lists all 15 heroes" % faction)
		check(grid.size.x <= list.size.x, "%s roster cards fit horizontally" % faction)
		for card in grid.get_children():
			var portraits := card.find_children("HeroPortrait_*", "TextureRect", true, false)
			check(portraits.size() == 1, "%s card has exactly one portrait" % faction)
			if portraits.size() == 1:
				check(card.get_global_rect().encloses(portraits[0].get_global_rect()), "%s portrait fits card" % portraits[0].name)
		for hero: Dictionary in main._hero_roster_for_faction():
			var id: String = hero["id"]
			main._build_hero_detail_screen(id)
			await settle()
			var portrait: TextureRect = main.content_root.find_child("HeroPortrait_%s" % id, true, false)
			check(portrait != null and portrait.texture == VISUALS.portrait_texture(id), "%s detailed portrait mapping" % id)
			var scroll: ScrollContainer = main.content_root.find_child("HeroDetailScroll", true, false)
			check(root.get_visible_rect().encloses(scroll.get_global_rect()), "%s details fit viewport" % id)
			var box: Control = scroll.get_child(0)
			check(box.size.x <= scroll.size.x, "%s details fit horizontally" % id)
			var icons: Array = main.content_root.find_children("SkillIcon_*", "TextureRect", true, false)
			check(icons.size() == 4, "%s has four skill icons" % id)
			var previous_panel: Control = null
			for slot in ["a1", "a2", "passive", "ultimate"]:
				var icon: TextureRect = main.content_root.find_child("SkillIcon_%s_%s" % [id, slot], true, false)
				check(icon != null, "%s/%s icon exists" % [id, slot])
				if icon == null:
					continue
				check(icon.texture == VISUALS.skill_texture(id, slot), "%s/%s texture mapping" % [id, slot])
				var row: Control = icon.get_parent()
				var panel: Control = row.get_parent()
				var text_box: Control = row.get_child(1)
				check(not icon.get_global_rect().intersects(text_box.get_global_rect()), "%s/%s icon does not overlap text" % [id, slot])
				check(panel.get_global_rect().encloses(icon.get_global_rect()), "%s/%s icon stays inside panel" % [id, slot])
				check(panel.get_global_rect().encloses(text_box.get_global_rect()), "%s/%s text stays inside panel" % [id, slot])
				if previous_panel != null:
					check(not panel.get_global_rect().intersects(previous_panel.get_global_rect()), "%s/%s cards do not overlap" % [id, slot])
				previous_panel = panel
				scroll.ensure_control_visible(icon)
				await settle()
				check(scroll.get_global_rect().grow(1).encloses(icon.get_global_rect()), "%s/%s icon is scroll reachable" % [id, slot])
	main.free()
	await process_frame
	print("v31_readonly_ui_layout_probe checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
