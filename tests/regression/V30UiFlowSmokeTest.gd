extends SceneTree

# Exercise player-visible navigation, save protection and actual Godot layout.
# This test deliberately does not claim to verify rendered artwork in headless mode.
var checks := 0
var failures: Array[String] = []
var screen_reports: Array = []
var main: Node

func _init() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for index in range(4): await process_frame

func descendants(node: Node) -> Array:
	var output: Array = []
	for child in node.get_children():
		output.append(child)
		output.append_array(descendants(child))
	return output

func button_containing(fragment: String) -> Button:
	for node in descendants(main.content_root):
		if node is Button and node.is_visible_in_tree() and str(node.text).contains(fragment):
			return node
	return null

func text_containing(fragment: String) -> bool:
	for node in descendants(main.content_root):
		if node is Label and node.is_visible_in_tree() and str(node.text).contains(fragment):
			return true
	return false

func clipped_by_scroll(node: Control) -> bool:
	var parent := node.get_parent()
	while parent != main.content_root and parent != null:
		if parent is ScrollContainer: return true
		parent = parent.get_parent()
	return false

func visible_area(node: Control) -> Rect2:
	var area := node.get_global_rect()
	var parent := node.get_parent()
	while parent != null:
		if parent is Control and parent.clip_contents:
			area = area.intersection(parent.get_global_rect())
		parent = parent.get_parent()
	return area.intersection(root.get_visible_rect())

func contrast(foreground: Color, background: Color) -> float:
	var a := foreground.srgb_to_linear().get_luminance()
	var b := background.srgb_to_linear().get_luminance()
	return (maxf(a,b)+0.05)/(minf(a,b)+0.05)

func check_primary(button: Button, context: String) -> void:
	check(button != null, context + " offers a visible primary action")
	if button == null: return
	check(not button.disabled, context + " action is enabled for a supported save")
	check(button.size.x >= 44 and button.size.y >= 44, context + " action has a usable touch target")
	check(button.focus_mode != Control.FOCUS_NONE, context + " action supports keyboard/controller focus")
	check(button.get_theme_font_size("font_size") >= 16, context + " action uses readable text")
	var style := button.get_theme_stylebox("normal") as StyleBoxFlat
	if style != null:
		check(contrast(button.get_theme_color("font_color"),style.bg_color) >= 4.5, context + " action text meets 4.5:1 contrast")

func inspect_layout(screen: String, require_nav := true) -> void:
	var viewport := root.get_visible_rect().grow(1.0)
	var nav := main.content_root.get_node_or_null("BottomNav") as Control
	if require_nav: check(nav != null, screen + " keeps global navigation available")
	if nav != null:
		check(viewport.encloses(nav.get_global_rect()),screen + " navigation fits the viewport")
		var nav_count := 0
		for node in descendants(nav):
			if node is Button:
				nav_count += 1
				check(node.size.x >= 44 and node.size.y >= 44,screen + " navigation touch target " + str(node.text))
		check(nav_count >= 5,screen + " exposes the five main destinations")
	var issues: Array = []
	var visible_buttons := 0
	for node in descendants(main.content_root):
		if not node is Control or not node.is_visible_in_tree(): continue
		if not (node is Button or node is Label): continue
		var area := visible_area(node)
		if not area.has_area(): continue
		var rectangle: Rect2 = node.get_global_rect()
		if node is Button: visible_buttons += 1
		if not clipped_by_scroll(node):
			var inside := viewport.encloses(rectangle)
			check(inside, "%s control fits viewport: %s" % [screen,str(node.text).substr(0,50)])
			if not inside: issues.append({"text":str(node.text),"rect":[rectangle.position.x,rectangle.position.y,rectangle.size.x,rectangle.size.y]})
		# A persistent tutorial banner must not cover the page or its navigation.
		if str(node.name) == "OnboardingHint":
			check(node is Button,screen + " onboarding is an optional action, not an obstructing banner")
	var old_hint: Node = main.content_root.get_node_or_null("OnboardingHint")
	if old_hint != null and old_hint is Control and old_hint.is_visible_in_tree():
		check(old_hint is Button,screen + " has no persistent tutorial panel over its content")
	check(visible_buttons > 0,screen + " has usable navigation/actions")
	screen_reports.append({"screen":screen,"viewport":[root.size.x,root.size.y],"visible_buttons":visible_buttons,"layout_issues":issues})

func _run() -> void:
	root.size = Vector2i(1280,720)
	main = preload("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.save_state_path = "user://v30-ui-flow-smoke.json"
	main._offline_checked = true
	main.selected_faction = ""
	main.deployed_heroes.clear()
	main.save_load_status = "missing"
	main._save_blocked_for_newer_version = false
	main._build_title_screen()
	await settle()
	check(main.active_screen == "title","fresh launch presents the title screen")
	check(main.theme.default_font.has_char(0xC601) and main.theme.default_font.has_char(0xC6C5),"bundled UI font supports Korean hero labels")
	var start := button_containing("모험 시작")
	check_primary(start,"title")
	if start != null: start.pressed.emit()
	await settle()
	check(main.active_screen == "login","title primary callback opens login")
	var guest := button_containing("이 기기에서")
	check_primary(guest,"device login")
	check(text_containing("기기"),"login explains local device persistence")
	for node in descendants(main.content_root):
		if node is Button:
			for provider in ["Google","Apple","Facebook","Kakao","구글","애플","카카오"]:
				if str(node.text).contains(provider):
					check(node.disabled,"unsupported provider must not appear to authenticate: " + provider)
	if guest != null: guest.pressed.emit()
	await settle()
	check(main.active_screen == "lobby","device login callback opens the lobby")
	var first_party := button_containing("첫 원정대")
	check(first_party != null,"new player's lobby exposes party creation")
	if first_party != null: first_party.pressed.emit()
	await settle()
	check(button_containing("아우렐리아") != null or text_containing("아우렐리아"),"first party action opens faction choice")
	var choose_faction := button_containing("이 진영 선택")
	check(choose_faction != null,"faction screen exposes a selection action")
	if choose_faction != null: choose_faction.pressed.emit()
	await settle()
	check(not str(main.selected_faction).is_empty(),"faction selection callback updates the chosen faction")
	if is_instance_valid(main.confirm_button):
		check(not main.confirm_button.disabled,"selected faction can be confirmed")
		main.confirm_button.pressed.emit()
	await settle()
	var first_hero := button_containing("첫 영웅")
	check(first_hero != null,"faction confirmation opens the introduction")
	if first_hero != null: first_hero.pressed.emit()
	await settle()
	check(main.active_screen == "hero_select","intro primary action opens hero selection")

	# The read-only guard must survive the new entry screen.
	main._save_blocked_for_newer_version = true
	main.save_load_status = "unsupported_version"
	main._build_title_screen()
	await settle()
	start = button_containing("모험 시작")
	check(start != null and start.disabled,"newer save disables title entry")
	main._build_login_screen()
	await settle()
	guest = button_containing("이 기기에서")
	check(guest != null and guest.disabled,"newer save disables device entry")
	check(text_containing("업데이트"),"blocked entry explains how to continue safely")
	main._save_blocked_for_newer_version = false
	main.save_load_status = "loaded"

	# Populate the late-game case that previously overflowed the party panel.
	main.idle_stage = 60
	main.wallet_gold = 9876543210123
	main.wallet_gems = 1234567890
	for faction in ["aurelia","noxfera"]:
		main.selected_faction = faction
		check(main._hero_roster_for_faction().size() == 15,faction + " preserves all fifteen heroes")
	main.selected_faction = "aurelia"
	main._restore_deployed_heroes(["leonhardt","mira","elisia","kairen","orwin","seria","astel","darius","lunea","caelum"])
	main._setup_hero_progress(main._hero_roster_for_faction())
	check(main.deployed_heroes.size() == 10,"layout fixture uses a complete ten-hero party")
	for hero in main._hero_roster_for_faction():
		main.hero_progress[str(hero["id"])] = {"level":30,"xp":120}
	main.tutorial_completed = false
	for entry in [
		["lobby","_build_lobby_screen"], ["heroes","_build_hero_select_screen"],
		["hero_detail","_build_hero_detail_screen","leonhardt"], ["growth","_build_growth_screen"],
		["inventory","_build_inventory_screen"], ["combat","_build_combat_screen"],
		["raid","_build_raid_screen"], ["activities","_build_meta_hub_screen"],
		["summon","_build_summon_screen"], ["world","_build_world_map_screen"],
		["boss","_build_boss_select_screen"], ["codex","_build_codex_screen"],
		["shop","_build_bm_screen"], ["war","_build_faction_war_screen"]
	]:
		check(main.has_method(entry[1]),"screen remains callable: " + str(entry[1]))
		if not main.has_method(entry[1]): continue
		if entry.size() > 2: main.call(entry[1],entry[2])
		else: main.call(entry[1])
		await settle()
		inspect_layout(str(entry[0]),str(entry[0]) not in ["raid","shop"])
	# Menu/guide overlays must close without rebuilding the page or combat state.
	main._build_lobby_screen()
	await settle()
	var menu_action := button_containing("메뉴")
	check(menu_action != null,"lobby exposes the complete menu")
	if menu_action != null: menu_action.pressed.emit()
	await settle()
	check(main.content_root.get_node_or_null("MenuOverlay") != null,"menu button opens an overlay")
	check(main.active_screen == "lobby","opening the menu preserves the underlying page")
	inspect_layout("main_menu")
	var close_action := button_containing("닫기")
	check(close_action != null,"menu has a visible close action")
	if close_action != null: close_action.pressed.emit()
	await settle()
	check(main.content_root.get_node_or_null("MenuOverlay") == null,"close action dismisses the menu")
	var guide_action := button_containing("?")
	check(guide_action != null,"new player can explicitly request onboarding guidance")
	if guide_action != null: guide_action.pressed.emit()
	await settle()
	check(main.content_root.get_node_or_null("MenuOverlay") != null,"guidance opens only after the help action")
	inspect_layout("guide_overlay")
	close_action = button_containing("닫기")
	if close_action != null: close_action.pressed.emit()
	await settle()
	main._build_combat_screen()
	await settle()
	if is_instance_valid(main.combat_timer): main.combat_timer.stop()
	var battle_before: Dictionary = main.hero_battle_state.duplicate(true)
	var running_before: bool = main.combat_running
	main._show_main_menu()
	await settle()
	check(main.active_screen == "combat" and main.combat_running == running_before,"menu overlay preserves the running hunt")
	check(main.hero_battle_state == battle_before,"menu overlay does not reset live hero health or charges")
	var effects_toggle: CheckButton
	for node in descendants(main.content_root):
		if node is CheckButton and str(node.text).contains("전투 효과"):
			effects_toggle = node
	check(effects_toggle != null,"menu offers the real combat effects setting")
	if effects_toggle != null:
		var old_value := effects_toggle.button_pressed
		effects_toggle.button_pressed = not old_value
		check(main.combat_effects_enabled == (not old_value) and main.combat_fx.enabled == (not old_value),"effects toggle updates the live combat renderer")
		for saved_setting in [false,true]:
			effects_toggle.button_pressed = saved_setting
			main.combat_effects_enabled = not saved_setting
			main._load_ui_preferences()
			check(main.combat_effects_enabled == saved_setting,"effects setting survives a preference reload: " + str(saved_setting))
		effects_toggle.button_pressed = old_value
	close_action = button_containing("닫기")
	if close_action != null: close_action.pressed.emit()
	await settle()
	check(main.hero_battle_state == battle_before,"closing the menu preserves live battle state")
	# Item and reward actions rebuild their screen immediately; feedback must survive.
	main._show_toast("장비 작업 결과 확인")
	main._build_inventory_screen()
	await settle()
	check(text_containing("장비 작업 결과 확인"),"action feedback survives an immediate screen rebuild")
	var visible_toasts := 0
	for node in descendants(main.content_root):
		if node is Label and str(node.text) == "장비 작업 결과 확인":
			visible_toasts += 1
			check(root.get_visible_rect().encloses(node.get_global_rect()),"action feedback stays inside the viewport")
			check(node.mouse_filter == Control.MOUSE_FILTER_IGNORE,"action feedback does not block menu input")
	check(visible_toasts == 1,"action feedback is displayed once")
	# Confirm real bottom-navigation callbacks, rather than directly invoking pages.
	main._build_lobby_screen()
	await settle()
	for destination in [["장비","inventory"],["영웅","hero_select"]]:
		var navigation: Node = main.content_root.get_node_or_null("BottomNav")
		var target: Button
		if navigation != null:
			for node in descendants(navigation):
				if node is Button and (str(node.text) + str(node.tooltip_text)).contains(destination[0]): target = node
		check(target != null and not target.disabled,"navigation action exists: " + str(destination[0]))
		if target != null and not target.disabled: target.pressed.emit()
		await settle()
		check(main.active_screen == destination[1],"navigation callback reaches " + str(destination[1]))
	root.size = Vector2i(1600,720)
	main._build_lobby_screen()
	await settle()
	inspect_layout("lobby_wide")
	main._build_hero_select_screen()
	await settle()
	inspect_layout("heroes_wide")
	var report := {"checks":checks,"failures":failures,"rendered":false,"screens":screen_reports}
	var output := FileAccess.open("user://v30-ui-flow-report.json",FileAccess.WRITE)
	if output != null: output.store_string(JSON.stringify(report,"\t"))
	print("v30_ui_flow checks=%d failures=%d screens=%d report=%s" % [checks,failures.size(),screen_reports.size(),ProjectSettings.globalize_path("user://v30-ui-flow-report.json")])
	main.free()
	quit(0 if failures.is_empty() else 1)
