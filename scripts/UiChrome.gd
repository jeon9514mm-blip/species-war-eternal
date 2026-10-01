extends RefCounted

const NAV = preload("res://scripts/NavigationCatalog.gd")
const UI := preload("res://scripts/GameUiTheme.gd")

static func header(main, back_text: String, back_action: Callable, title_text: String, subtitle_text: String, badge_text: String, accent: Color, wallet_text: String) -> void:
	var row := HBoxContainer.new()
	row.name = "ScreenHeader"
	row.position = Vector2(55, 24)
	row.size = Vector2(1170, 44)
	main.content_root.add_child(row)
	var back := UI.button(back_text.trim_prefix("‹  "), Vector2(134, 44))
	back.pressed.connect(back_action)
	row.add_child(back)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(space)
	if not badge_text.is_empty():
		var badge := UI.label(badge_text, 14, accent)
		badge.custom_minimum_size = Vector2(160, 44)
		row.add_child(badge)
	if not wallet_text.is_empty():
		var wallet := UI.label(wallet_text, 15, UI.GOLD)
		wallet.custom_minimum_size = Vector2(245, 44)
		row.add_child(wallet)
	var menu := UI.button("메뉴", Vector2(80, 44))
	menu.pressed.connect(Callable(main, "_show_main_menu"))
	row.add_child(menu)
	var title := UI.label(title_text, 31)
	title.position = Vector2(55, 94)
	title.size = Vector2(1096, 42)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	main.content_root.add_child(title)
	var subtitle := UI.label(subtitle_text, 15, UI.MUTED)
	subtitle.position = Vector2(55, 143)
	subtitle.size = Vector2(1170, 28)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	main.content_root.add_child(subtitle)

static func navigation(main, active_id: String) -> void:
	var panel := Panel.new()
	panel.name = "BottomNav"
	panel.position = Vector2(28, 644)
	panel.size = Vector2(main._layout_width() - 56, 62)
	panel.z_index = 80
	panel.add_theme_stylebox_override("panel", UI.panel(UI.SURFACE, UI.BORDER, 16))
	main.content_root.add_child(panel)
	var row := HBoxContainer.new()
	row.position = Vector2(8, 6)
	row.size = panel.size - Vector2(16, 12)
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	var entries: Array = NAV.dock_entries()
	var selected_tab: String = NAV.active_tab(active_id)
	for entry: Dictionary in entries:
		var selected: bool = str(entry["id"]) == selected_tab
		var button := UI.button("", Vector2(0, 50), UI.SOFT if selected else UI.SURFACE)
		button.name = "Nav_" + str(entry["id"])
		button.tooltip_text = str(entry["label"])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = selected and str(entry["id"]) != "more"
		if selected:
			button.add_theme_stylebox_override("disabled", UI.panel(Color("#dbe7d4"), Color.TRANSPARENT, 11, 0))
		if not button.disabled:
			button.pressed.connect(Callable(main, str(entry["method"])))
		row.add_child(button)
		var label := UI.label(str(entry["label"]), 16, UI.PRIMARY if selected else UI.MUTED)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.offset_left = 24
		button.add_child(label)
		var icon := UI.icon(str(entry["legacy_icon"]), Vector2(22, 22), UI.PRIMARY if selected else UI.MUTED)
		icon.position = Vector2(22, 14)
		button.add_child(icon)
	if main.active_screen not in ["combat", "raid"]:
		main._add_onboarding_hint()

static func overlay(main, title: String, height: float = 492.0) -> Panel:
	var existing: Node = main.content_root.get_node_or_null("MenuOverlay")
	if is_instance_valid(existing):
		main.content_root.remove_child(existing)
		existing.queue_free()
	var layer := Control.new()
	layer.name = "MenuOverlay"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.z_index = 120
	main.content_root.add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.09, 0.18, 0.14, 0.43)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2((main._layout_width() - 620) * 0.5, (main._layout_height() - height) * 0.5)
	panel.size = Vector2(620, height)
	panel.add_theme_stylebox_override("panel", UI.panel(UI.SURFACE, UI.BORDER, 22))
	layer.add_child(panel)
	var heading := UI.label(title, 25)
	heading.position = Vector2(28, 23)
	heading.size = Vector2(486, 40)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	panel.add_child(heading)
	var close := UI.button("닫기", Vector2(70, 40))
	close.position = Vector2(522, 23)
	close.pressed.connect(layer.queue_free)
	panel.add_child(close)
	_focus_if_attached.call_deferred(weakref(close))
	layer.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed("ui_cancel"):
			layer.queue_free()
			main.get_viewport().set_input_as_handled())
	return panel

static func menu(main) -> void:
	var panel := overlay(main, "모험 메뉴", 640)
	var entries: Array = NAV.menu_entries()
	for i in entries.size():
		var button := UI.button(str(entries[i]["label"]), Vector2(274, 52))
		button.name = "Menu_" + str(entries[i]["id"])
		button.position = Vector2(28 + (i % 2) * 290, 89 + (i / 2) * 64)
		button.pressed.connect(Callable(main, str(entries[i]["method"])))
		panel.add_child(button)
	var effects := CheckButton.new()
	effects.text = "전투 효과와 스킬 소리"
	effects.button_pressed = main.combat_effects_enabled
	effects.position = Vector2(28, 412)
	effects.size = Vector2(400, 44)
	effects.toggled.connect(func(enabled: bool):
		main.combat_effects_enabled = enabled
		main.combat_fx.enabled = enabled
		if not enabled and is_instance_valid(main.skill_audio_bus):
			main.skill_audio_bus.stop()
		main._save_ui_preferences())
	panel.add_child(effects)
	var help := UI.button("원정 가이드", Vector2(146, 44))
	help.position = Vector2(446, 412)
	help.pressed.connect(func(): guide(main))
	panel.add_child(help)
	var settings := UI.button("소리 · 진동 · 성능 설정", Vector2(564, 44))
	settings.position = Vector2(28, 472)
	settings.name = "PresentationSettingsEntry"
	settings.pressed.connect(Callable(main, "_open_presentation_settings"))
	panel.add_child(settings)
	var note := UI.label("모험은 이 기기에 자동 저장됩니다.\n계정 연동과 다른 기기에서 이어하기는 준비 중입니다.", 14, UI.MUTED)
	note.position = Vector2(28, 534)
	note.size = Vector2(564, 64)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	panel.add_child(note)

static func guide(main) -> void:
	var panel := overlay(main, "원정 가이드", 274)
	var label := UI.label(main._tutorial_text(), 18)
	label.position = Vector2(28, 90)
	label.size = Vector2(564, 138)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)

static func _focus_if_attached(button_ref: WeakRef) -> void:
	var button: Button = button_ref.get_ref() as Button
	if is_instance_valid(button) and button.is_inside_tree() and not button.is_queued_for_deletion():
		button.grab_focus()
