extends SceneTree
const NAV=preload("res://scripts/NavigationCatalog.gd")
const CHROME=preload("res://scripts/UiChrome.gd")
const HUD=preload("res://scripts/portrait/PortraitHud.gd")
var checks: int=0
var failures: Array[String]=[]
var main: Node
func _init() -> void: run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func settle() -> void:
	for frame in 8:await process_frame
func node(key:String) -> Node: return main.content_root.find_child(key,true,false)
func press(key: String) -> void:
	var button: Button=node(key)
	check(button!=null,'navigation control exists '+key)
	if button==null:return
	check(button.is_visible_in_tree() and not button.disabled,'navigation control is usable '+key)
	check(main.get_viewport_rect().encloses(button.get_global_rect()),'navigation control fits landscape viewport '+key)
	var point:=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point;root.push_input(event,true)
	await settle()
func run() -> void:
	var dock:Array=NAV.dock_entries();dock[0]["method"]="broken";dock.clear()
	check(NAV.dock_entries().size()==5 and NAV.dock_entries()[0]["method"]=="_build_lobby_screen","catalog reads cannot corrupt canonical dock")
	var menu:Array=NAV.menu_entries();menu[0]["label"]="broken"
	check(NAV.menu_entries()[0]["label"]=="원정 캠프","menu data independent")
	var cases:Dictionary={"lobby":"home","home":"home","heroes":"heroes","hero_detail":"heroes","combat":"battle","raid":"battle","world":"battle","inventory":"bag","bag":"bag","equipment_detail":"bag","growth":"more","war":"more","content":"more","unknown":"more"}
	for key in cases:check(NAV.active_tab(key)==cases[key],"active tab "+key)
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	main=preload("res://scenes/PortraitMain.tscn").instantiate();main.save_state_path="user://v83-nav.json"
	root.add_child(main);await settle();main.set_physics_process(false);main.set_process(false);main._offline_checked=true
	main.selected_faction="aurelia";main.idle_stage=25;main._restore_deployed_heroes(["leonhardt","seraphina","aelion"])
	main._build_inventory_screen();await settle()
	var dock_node:Node=node("PortraitNavigation")
	check(dock_node!=null and dock_node.get_child_count()==5,"portrait five tabs")
	for entry:Dictionary in NAV.dock_entries():
		var button:Button=node("PortraitNav_"+entry["id"])
		check(button!=null,"portrait button "+entry["id"])
		check(main.has_method(str(entry["method"])),"dock command exists "+entry["id"])
		if button!=null:
			var connections:Array=button.pressed.get_connections()
			var found:bool=false
			for c:Dictionary in connections:
				if c["callable"].get_method()==str(entry["method"]):found=true
			check(found,"portrait command binding "+entry["id"])
	# Repeated open, including while dispatching a menu button, leaves one live sheet.
	main._show_main_menu();main._show_main_menu();await settle()
	var sheets:int=0
	for child:Node in main.content_root.get_children():
		if child.name=="PortraitActionSheet":sheets+=1
	check(sheets==1,"repeated menu open singleton")
	for entry:Dictionary in NAV.menu_entries():
		check(node("PortraitMenu_"+str(entry["id"]))!=null,"portrait secondary reachable "+str(entry["id"]))
		check(main.has_method(str(entry["method"])),"secondary command exists "+str(entry["id"]))
	var first:Button=node("PortraitMenu_camp")
	first.pressed.emit();await settle()
	check(main.active_screen=="lobby","menu camp real signal routes to lobby")
	main._show_main_menu();await settle();var training:Button=node("PortraitMenu_training")
	training.pressed.emit();await settle();check(main.active_screen=="growth","preserved training route")
	# Use the real legacy host, not PortraitMain's overridden menu dispatcher.
	var portrait_host: Node = main
	main=preload("res://scenes/Main.tscn").instantiate();main.save_state_path="user://v83-nav-legacy.json"
	root.add_child(main);await settle();main.set_process(false);main.set_physics_process(false)
	main.selected_faction="aurelia";main._offline_checked=true;main._restore_deployed_heroes(["leonhardt","seraphina","aelion"])
	# Compatibility view consumes the same entries without becoming a second authority.
	main._clear_screen();main.active_screen="inventory"
	CHROME.navigation(main,"inventory");await settle()
	var legacy:Node=node("BottomNav")
	check(legacy!=null,"compatibility dock exists")
	for entry:Dictionary in NAV.dock_entries():
		var button:Button=node("Nav_"+str(entry["id"]))
		check(button!=null,"compatibility same dock key "+str(entry["id"]))
		if button!=null:check(button.disabled==(entry["id"]=="bag"),"compatibility selected alias "+str(entry["id"]))
	check(node("Nav_war")==null and node("Nav_growth")==null,"old six-tab definition removed")
	main._clear_screen();main.active_screen="growth"
	CHROME.navigation(main,"growth");await settle()
	var more:Button=node("Nav_more")
	check(more!=null and not more.disabled,"selected menu remains actionable on secondary pages")
	more.pressed.emit();await settle()
	check(node("MenuOverlay")!=null,"selected menu opens actual overlay")
	CHROME.menu(main);CHROME.menu(main);await settle()
	var overlays:int=0
	for child:Node in main.content_root.get_children():
		if child.name=="MenuOverlay":overlays+=1
	check(overlays==1,"compatibility overlay singleton")
	for entry:Dictionary in NAV.menu_entries():check(node("Menu_"+str(entry["id"]))!=null,"compatibility secondary "+str(entry["id"]))
	check(node("PresentationSettingsEntry")!=null,"presentation settings remains reachable")
	if main.presentation_runtime!=null:main.presentation_runtime.audio.shutdown()
	await create_timer(0.35).timeout
	main.queue_free();await settle()
	main=portrait_host
	main._build_inventory_screen();await settle()
	check(node("EquipmentWorkbench")!=null and node("EquipmentComparisons")!=null and node("GearInventoryGrid")!=null,"landscape bag workbench stays alive after compatibility menu")
	await press("GearCategory_weapon")
	check(main.active_screen=="inventory" and main.get_meta("gear_bag_filters",{}).get("slot")=="weapon","bag category input remains functional after compatibility menu")
	await press("PortraitNav_home")
	check(main.active_screen=="lobby","real home dock input exits restored bag")
	await press("PortraitNav_bag")
	check(main.active_screen=="inventory" and node("EquipmentWorkbench")!=null,"real bag dock input returns to landscape workbench")
	await press("GearCategory_all")
	check(main.get_meta("gear_bag_filters",{}).get("slot")=="all","restored workbench accepts another category input")
	if main.presentation_runtime!=null:main.presentation_runtime.audio.shutdown()
	await create_timer(0.5).timeout
	main.queue_free();await settle();await create_timer(0.3).timeout
	print("v83_navigation checks=%d failures=%s"%[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
