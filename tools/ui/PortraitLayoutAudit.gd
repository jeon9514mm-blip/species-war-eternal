extends SceneTree

var main: Node
var output_dir := OS.get_user_data_dir().path_join("ui-captures")
var selected_names: Array[String] = []
var captures: Array = []

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: output_dir = args[0]
	if args.size() > 1:
		for value in args[1].split(","): selected_names.append(value)
	run.call_deferred()

func capture(view: String) -> void:
	for frame in range(6): await process_frame
	var path := ""
	var error := 0
	var dimensions := [root.size.x,root.size.y]
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		path = output_dir.path_join(view + ".png")
		error = image.save_png(path)
		dimensions = [image.get_width(),image.get_height()]
	var controls: Array = []
	collect(main, controls)
	var entry := {"view":view,"path":path,"error":error,"size":dimensions,"controls":controls}
	captures.append(entry)
	print("CAPTURE ",view," ",error," ",path)

func collect(node: Node, output: Array) -> void:
	if node is Control and node.is_visible_in_tree() and (node is Button or node is Label or node is LineEdit):
		var rectangle: Rect2 = node.get_global_rect()
		var clip_rect := Rect2(Vector2.ZERO,root.size)
		var clipped_by: Array = []
		var ancestor := node.get_parent()
		while ancestor != null:
			if ancestor is Control and ancestor.clip_contents:
				clip_rect = clip_rect.intersection(ancestor.get_global_rect())
				clipped_by.append(str(ancestor.get_path()))
			ancestor = ancestor.get_parent()
		var font: Font = node.get_theme_font("font")
		var font_size: int = node.get_theme_font_size("font_size")
		var widest := 0.0
		for line in str(node.get("text")).split("\n"):
			widest = maxf(widest,font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x)
		var color: Color = node.get_theme_color("font_color")
		output.append({"name":str(node.name),"path":str(node.get_path()),"parent":str(node.get_parent().get_path()),"text":str(node.get("text")),"type":node.get_class(),"rect":[rectangle.position.x,rectangle.position.y,rectangle.size.x,rectangle.size.y],"minimum":[node.get_combined_minimum_size().x,node.get_combined_minimum_size().y],"clip_rect":[clip_rect.position.x,clip_rect.position.y,clip_rect.size.x,clip_rect.size.y],"clipped_by":clipped_by,"text_width":widest,"font_size":font_size,"text_color":color.to_html(),"scale":node.get_global_transform().get_scale().x,"lines":node.get_line_count() if node is Label else 1,"line_height":node.get_line_height() if node is Label else font.get_height(font_size),"clip_text":node.clip_text if node is Label or node is Button else false,"autowrap":node.autowrap_mode if node is Label else 0,"disabled":node.disabled if node is Button else false})
	for child in node.get_children(): collect(child,output)

func wanted(view: String) -> bool:
	return selected_names.is_empty() or selected_names.has(view)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.content_scale_size = Vector2i(720,1280)
	root.size = Vector2i(720,1280)
	main = preload("res://scenes/PortraitMain.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	main.combat_effects_enabled = false
	main.tutorial_completed = true
	main._offline_checked = true
	main.save_state_path = "user://capture_ui.json"
	if wanted("title"):
		main._build_title_screen()
		await capture("title")
	if wanted("login") and main.has_method("_build_login_screen"):
		main._build_login_screen()
		await capture("login")
	if wanted("faction"):
		main._build_faction_screen()
		await capture("faction")
	main.selected_faction = "aurelia"
	main.idle_stage = 35
	main.wallet_gold = 48250
	main.wallet_gems = 1280
	main.wallet_xp = 12340
	main.unclaimed_gold = 2160
	main.unclaimed_xp = 720
	main._restore_deployed_heroes(["leonhardt","mira","elisia","kairen","orwin","seria","astel","darius","lunea","caelum"])
	main._setup_hero_progress(main._hero_roster_for_faction())
	for hero in main._hero_roster_for_faction():
		main.hero_progress[str(hero["id"])] = {"level":15,"xp":120}
	main.loot_inventory = [{"id":"audit-sword","name":"오래된 왕국의 전설적인 수호자의 검","slot":"weapon","level":10,"rarity":"전설","set":"월광"}]
	for entry in [
		["intro","_build_intro_screen"], ["lobby","_build_lobby_screen"], ["heroes","_build_hero_select_screen"],
		["hero_detail","_build_hero_detail_screen","leonhardt"], ["growth","_build_growth_screen"],
		["inventory","_build_inventory_screen"], ["combat","_build_combat_screen"],
		["raid","_build_raid_screen"], ["activities","_build_meta_hub_screen"],
		["summon","_build_summon_screen"], ["world","_build_world_map_screen"],
		["boss","_build_boss_select_screen"], ["codex","_build_codex_screen"],
		["shop","_build_bm_screen"], ["war","_build_faction_war_screen"]
	]:
		if not wanted(str(entry[0])): continue
		if entry.size() > 2: main.call(entry[1],entry[2])
		else: main.call(entry[1])
		if entry[0] == "combat":
			for tick in range(60): main._advance_auto_hunt(0.1)
		await capture(str(entry[0]))
	main._build_combat_screen()
	await capture("combat_full")
	main._toggle_hunt_details()
	await capture("hunt_details")
	main._toggle_hunt_details()
	main._show_main_menu()
	await capture("menu")
	main._build_raid_screen()
	main._show_battle_result_popup("RAID CLEAR", "오래된 광산의 거대한 수호자 처치 완료", "골드 +123456789 · 경험치 +123456789\n획득 장비와 영웅 성장 정보를 확인하세요.", Color.GOLD)
	await capture("battle_result")
	main._build_lobby_screen()
	main.offline_reward_seconds=28800
	main.offline_reward_gold=123456789
	main._show_offline_reward_popup()
	await capture("offline_reward")
	main._build_summon_screen()
	main._show_summon_reveal({"hero_id":"leonhardt","name":"레온하르트","shards":30})
	await capture("summon_reveal")
	var result := FileAccess.open(output_dir.path_join("capture_report.json"),FileAccess.WRITE)
	result.store_string(JSON.stringify(captures,"\t"))
	main.queue_free()
	await process_frame
	quit(0)
