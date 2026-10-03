extends "res://scripts/V83UpgradeTestBase.gd"
## Real touchscreen events through Input, including Godot's mouse emulation order.
const SCROLLER = preload("res://scripts/TouchScrollController.gd")
var taps: int = 0
var fixture: Control
var list: ScrollContainer
var button: Button
var column: VBoxContainer

func _init() -> void: _run.call_deferred()

func touch(point: Vector2, down: bool, index: int = 0, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = root.get_final_transform() * point; event.pressed = down; event.index = index; event.canceled = canceled
	Input.parse_input_event(event)

func drag(point: Vector2, relative: Vector2, index: int = 0) -> void:
	var event := InputEventScreenDrag.new()
	event.position = root.get_final_transform() * point; event.relative = root.get_final_transform().basis_xform(relative); event.index = index
	Input.parse_input_event(event)

func swipe(point: Vector2, delta: Vector2) -> void:
	touch(point, true)
	drag(point + delta, delta)
	touch(point + delta, false)
	await settle()

func build_fixture() -> void:
	fixture = Control.new(); root.add_child(fixture)
	fixture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fixture.add_child(SCROLLER.new())
	list = ScrollContainer.new(); list.position = Vector2(40, 40); list.size = Vector2(300, 240)
	list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fixture.add_child(list)
	column = VBoxContainer.new(); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_child(column)
	for i in 16:
		var entry := Button.new(); entry.text = "Touch row " + str(i); entry.custom_minimum_size.y = 64
		entry.mouse_filter = Control.MOUSE_FILTER_STOP
		entry.pressed.connect(func(): taps += 1)
		column.add_child(entry)
		if i == 0: button = entry
	await settle()

func _run() -> void:
	Input.set_use_accumulated_input(false)
	Input.emulate_mouse_from_touch = true
	root.size = Vector2i(1280, 720); root.content_scale_size = Vector2i(1280, 720)
	await build_fixture()
	var start := button.get_global_rect().get_center()
	touch(start, true); touch(start, false); await settle()
	check(taps == 1, "short phone tap executes exactly once")
	touch(start, true); drag(start + Vector2(2, -3), Vector2(2, -3)); touch(start + Vector2(2, -3), false); await settle()
	check(taps == 2 and list.scroll_vertical == 0, "finger jitter remains a tap")
	await swipe(start, Vector2(0, -100))
	check(list.scroll_vertical == 100, "swipe beginning on a STOP button scrolls exactly once")
	check(taps == 2, "drag release never activates a list action")
	await swipe(list.get_global_rect().get_center(), Vector2(0, 200))
	check(list.scroll_vertical == 0 and taps == 2, "reverse drag clamps at top without activation")
	touch(start, true); touch(start, false, 0, true); await settle()
	check(taps == 2, "OS canceled touch cannot activate a button")
	touch(start, true); touch(start + Vector2(20, 0), true, 1)
	drag(start + Vector2(0, -80), Vector2(0, -80)); touch(start, false)
	drag(start + Vector2(0, -120), Vector2(0, -120), 1); touch(start, false, 1); await settle()
	check(list.scroll_vertical == 0 and taps == 2, "second finger cancels gesture until all fingers release")
	touch(start, true); touch(start, false); await settle()
	check(taps == 3, "tap recovers after canceled multitouch")
	touch(start, true); fixture.get_child(0).notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	touch(start, false); await settle()
	check(taps == 3, "focus loss cancels pending action")
	touch(start, true); touch(start, false); await settle()
	check(taps == 4, "input recovers after focus loss")
	touch(start, true); touch(start + Vector2(0, 40), false); await settle()
	check(taps == 4, "displaced release with a dropped drag event cannot activate")
	touch(start, true); list.hide(); await settle(); touch(start, false); list.show(); await settle()
	check(taps == 4, "hidden list cancels pending action")
	touch(start, true); root.size = Vector2i(1200, 720); await settle(); touch(start, false)
	check(taps == 4, "viewport resize cancels pending action")
	root.size = Vector2i(1280, 720); await settle()
	await swipe(start, Vector2(0, -1500))
	var maximum := list.get_v_scroll_bar().max_value - list.get_v_scroll_bar().page
	check(list.scroll_vertical == int(maximum), "long drag clamps at list bottom")
	check(taps == 4, "release outside viewport does not activate any action")
	list.scroll_vertical = 0; await settle()
	# A GUI shade above the list must block both taps and swipes behind it.
	var shade := ColorRect.new(); shade.mouse_filter = Control.MOUSE_FILTER_STOP
	fixture.add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await swipe(start, Vector2(0, -100))
	touch(start, true); touch(start, false); await settle()
	check(list.scroll_vertical == 0 and taps == 4, "modal shade blocks underlying touch and scrolling")
	shade.free()
	# Existing wheel and scrollbar routes remain native.
	var wheel := InputEventMouseButton.new(); wheel.position = start; wheel.pressed = true; wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	Input.parse_input_event(wheel)
	var wheel_up: InputEventMouseButton = wheel.duplicate(); wheel_up.pressed = false
	Input.parse_input_event(wheel_up); await settle()
	check(list.scroll_vertical > 0, "mouse wheel remains usable")
	list.scroll_vertical = 0; await settle()
	# Native slider dragging is exempt from list ownership.
	var slider := HSlider.new(); slider.custom_minimum_size = Vector2(200, 48)
	column.add_child(slider); column.move_child(slider, 0); await settle()
	var slider_start := slider.get_global_rect().position + Vector2(20, 24)
	await swipe(slider_start, Vector2(150, 0))
	check(slider.value > 30 and list.scroll_vertical == 0, "slider receives touch without scrolling its parent")
	slider.free(); await settle()
	# A nested horizontal list is the sole owner of its gesture.
	var inner := ScrollContainer.new(); inner.custom_minimum_size = Vector2(200, 90)
	inner.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(inner); column.move_child(inner, 0)
	var row := HBoxContainer.new(); inner.add_child(row)
	for i in 8:
		var tile := Button.new(); tile.custom_minimum_size = Vector2(120, 64)
		tile.pressed.connect(func(): taps += 1); row.add_child(tile)
	await settle()
	await swipe(inner.get_global_rect().position + Vector2(100, 30), Vector2(-80, 0))
	check(inner.scroll_horizontal == 80 and list.scroll_vertical == 0, "nested horizontal list captures its own axis exactly once")
	check(taps == 4, "horizontal party-style swipe does not activate cards")
	inner.free(); await settle()
	touch(list.get_global_rect().get_center(), true); list.free(); await settle()
	touch(start, false); await settle()
	check(taps == 4, "freed screen safely cancels an active gesture")
	fixture.free()
	for faction in ["aurelia", "noxfera"]: await production_touch(faction)
	done("TOUCH_SCROLL_SMOKE")

func phone_tap(main: Node, named: String) -> void:
	var target: Control = main.content_root.find_child(named, true, false)
	check(target != null, "phone target exists " + named)
	if target == null: return
	var parent: Node = target.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(target)
		parent = parent.get_parent()
	await settle()
	var point := target.get_global_rect().get_center()
	touch(point, true); touch(point, false); await settle()

func production_touch(faction: String) -> void:
	var main = await make_main(faction, 3)
	root.size = Vector2i(1280, 720); await settle()
	main._open_hero_menu(); await settle()
	var hero_list: ScrollContainer = main.content_root.find_child("HeroRosterScroll", true, false)
	check(hero_list != null, faction + " production hero list exists")
	if hero_list != null:
		hero_list.scroll_vertical = 0; await settle()
		var selected: String = str(main.get_meta("hero_showcase_id", ""))
		var before := economic(main)
		await swipe(hero_list.get_global_rect().position + Vector2(55, 50), Vector2(0, -120))
		check(hero_list.scroll_vertical == 120, faction + " phone scroll works over real hero cards")
		check(str(main.get_meta("hero_showcase_id", "")) == selected and economic(main) == before, faction + " hero swipe preserves selection and progression")
		var hero_id: String = str(main._hero_roster_for_faction()[1].id)
		await phone_tap(main, "HeroRoster_" + hero_id)
		check(str(main.get_meta("hero_showcase_id", "")) == hero_id, faction + " phone tap selects the intended hero")
	main.loot_inventory.clear()
	for i in 40:
		main.loot_inventory.append(main.GEAR.normalize({"id":"touch-item-" + str(i),"slot":"weapon","level":3,"rarity":"희귀","origin":"hunt","source_id":"gray_meadow"}))
	main.set_meta("gear_bag_filters", {}); main._build_inventory_screen(); await settle()
	var bag_scroll: ScrollContainer = main.content_root.find_child("PortraitContentScroll", true, false)
	var bag: Array = main.loot_inventory.duplicate(true)
	var gold: int = main.wallet_gold
	var selected_item: String = str(main.get_meta("gear_bag_selected_id", ""))
	await swipe(bag_scroll.get_global_rect().position + Vector2(35, 35), Vector2(0, -120))
	check(bag_scroll.scroll_vertical > 0, faction + " phone scroll works over production equipment tiles")
	check(main.loot_inventory == bag and main.wallet_gold == gold and str(main.get_meta("gear_bag_selected_id", "")) == selected_item, faction + " equipment swipe cannot select, equip or spend")
	await phone_tap(main, "GearSettingsToggle")
	check(main.content_root.find_child("EquipmentOverlay", true, false) != null, faction + " phone opens equipment settings")
	await phone_tap(main, "PortraitNav_home")
	check(main.active_screen == "inventory", faction + " phone modal blocks background navigation")
	await phone_tap(main, "EquipmentOverlayClose")
	check(main.content_root.find_child("EquipmentOverlay", true, false) == null, faction + " phone closes settings")
	await phone_tap(main, "PortraitNav_home")
	check(main.active_screen == "combat", faction + " phone navigation resumes at hunting home after modal closes")
	await dispose(main)
