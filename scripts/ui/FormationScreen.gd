extends RefCounted
const RULES = preload("res://scripts/combat/BattleFormation.gd")
const P = preload("res://scripts/portrait/PortraitPages.gd")
const S = preload("res://scripts/portrait/PortraitSkin.gd")

static func open(main: Node) -> void:
	if not is_instance_valid(main.content_root): return
	var old: Node = main.content_root.get_node_or_null("FormationOverlay")
	var return_focus: Control = main.get_viewport().gui_get_focus_owner()
	if old != null:
		var saved: WeakRef = old.get_meta("formation_return_focus") if old.has_meta("formation_return_focus") else null
		if saved != null: return_focus = saved.get_ref() as Control
		old.free()
	var overlay := FormationModal.new()
	overlay.close_action=_close.bind(overlay)
	overlay.name = "FormationOverlay"; overlay.z_index = 250
	if is_instance_valid(return_focus): overlay.set_meta("formation_return_focus", weakref(return_focus))
	main.content_root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new(); shade.color = Color(0, 0, 0, .72)
	overlay.add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new(); panel.name = "FormationPanel"
	var style := S.elevated(S.SURFACE)
	style.content_margin_left = 20; style.content_margin_right = 20
	style.content_margin_top = 16; style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style); overlay.add_child(panel)
	var body := P.stack(panel, 12)
	var header := HBoxContainer.new(); header.add_theme_constant_override("separation", 16); body.add_child(header)
	var heading := P.stack(header, 2)
	P.text(heading, "전투 진형", 26, S.INK)
	P.text(heading, "보너스를 비교하고 원정대에 맞는 진형을 선택하세요.", 15, S.MUTED)
	var close := S.button("닫기", _close.bind(overlay)); close.name = "FormationClose"
	close.custom_minimum_size = Vector2(76, 48); header.add_child(close)
	var scroll := ScrollContainer.new(); scroll.name = "FormationScroll"
	S.make_scroll_responsive(scroll); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var grid := P.grid(scroll, 2); grid.name = "FormationPresets"
	for id: String in RULES.PROFILES: _preset(main, grid, id)
	var note := P.text(body, "진형을 바꿔도 현재 체력은 회복되지 않습니다. 도전·레이드 중에는 변경할 수 없습니다.", 13, S.MUTED)
	note.name = "FormationSafetyNote"
	var layout := func():
		if not is_instance_valid(panel) or not is_instance_valid(overlay) or overlay.is_queued_for_deletion():return
		var available: Vector2 = overlay.size
		var width := minf(1040, available.x - 48)
		panel.position = Vector2((available.x - width) * .5, 24)
		panel.size = Vector2(width, maxf(240, available.y - 48))
		grid.columns = 2 if width >= 760 else 1
	overlay.resized.connect(layout)
	# Wrapped labels can temporarily enlarge a container before their widths settle.
	# Reapply the viewport bound after that minimum-size pass, keeping the footer fixed.
	panel.minimum_size_changed.connect(layout,CONNECT_DEFERRED)
	layout.call();layout.call_deferred()
	_focus.call_deferred(weakref(close))

static func _preset(main: Node, parent: Node, id: String) -> void:
	var data: Dictionary = RULES.profile(id)
	var chosen: bool = id == main.formation_id
	var card := PanelContainer.new(); card.name = "FormationCard_" + id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := S.box(S.SURFACE_2 if chosen else S.SURFACE, S.GOLD if chosen else S.EDGE_SOFT, 12, 2 if chosen else 1)
	style.content_margin_left = 14; style.content_margin_right = 14
	style.content_margin_top = 12; style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", style); parent.add_child(card)
	var body := P.stack(card, 8)
	var heading := HBoxContainer.new(); heading.add_theme_constant_override("separation", 8); body.add_child(heading)
	var icon := S.UI.icon({"balanced":"shield", "assault":"sword", "bulwark":"guard", "volley":"growth"}.get(id, "shield"), Vector2(24, 24), S.GOLD if chosen else S.MUTED)
	heading.add_child(icon)
	var title := S.label(str(data.name), 20); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var state := S.label("사용 중" if chosen else "", 13, S.GOLD); state.name = "FormationStatus_" + id
	heading.add_child(state)
	P.text(body, str(data.description), 16, S.GOLD)
	var preview := FormationPreview.new(); preview.name = "FormationPreview_" + id
	preview.custom_minimum_size = Vector2(0, 118); preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.tooltip_text = _diagram(main, id); preview.mouse_filter = Control.MOUSE_FILTER_PASS
	preview.configure(main, id); body.add_child(preview)
	var apply := func():
		if RULES.select(main, id): open(main)
		else: main._show_toast("진형을 적용할 수 없거나 저장 대기 중입니다.")
	var button := P.action(body, "사용 중" if chosen else "이 진형 선택", apply, not chosen)
	button.name = "Formation_" + id; button.disabled = chosen
	button.custom_minimum_size.y = 44

static func _close(overlay: Control) -> void:
	if not is_instance_valid(overlay): return
	var saved: WeakRef = overlay.get_meta("formation_return_focus") if overlay.has_meta("formation_return_focus") else null
	var previous: Control = saved.get_ref() as Control if saved != null else null
	overlay.hide(); overlay.queue_free()
	if is_instance_valid(previous) and previous.is_visible_in_tree(): previous.grab_focus()

static func _focus(button_ref: WeakRef) -> void:
	var button: Button = button_ref.get_ref() as Button
	if is_instance_valid(button) and button.is_inside_tree() and not button.is_queued_for_deletion(): button.grab_focus()

static func _diagram(main: Node, id: String) -> String:
	var layout: Dictionary = RULES.offsets(main.deployed_heroes, id)
	var rows: Array[String] = []
	for hero in main.deployed_heroes:
		var point: Vector2 = layout.get(str(hero.id), Vector2.ZERO)
		rows.append("%s · %s" % [main._hero_short_name(str(hero.id)), "전열" if point.x >= .3 else "후열"])
	return " / ".join(rows) if not rows.is_empty() else "영웅을 편성하면 전열·후열이 표시됩니다."

class FormationModal extends Control:
	var close_action: Callable
	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree():return
		if event.is_action_pressed('ui_cancel'):
			get_viewport().set_input_as_handled();close_action.call();return
		if event is InputEventKey and event.pressed and event.keycode==KEY_TAB:
			var choices: Array[Button]=[]
			for button in find_children('*','Button',true,false):
				if button.is_visible_in_tree() and not button.disabled:choices.append(button)
			if choices.is_empty():return
			var index:=choices.find(get_viewport().gui_get_focus_owner())
			var next: Button=choices[posmod(index+(-1 if event.shift_pressed else 1),choices.size())]
			next.grab_focus()
			var scroll: ScrollContainer=get_node('FormationPanel').find_child('FormationScroll',true,false)
			if scroll!=null and scroll.is_ancestor_of(next):scroll.ensure_control_visible(next)
			get_viewport().set_input_as_handled()

class FormationPreview extends Control:
	var portraits: Array[Dictionary] = []
	var front := 0
	var back := 0
	var background := StyleBoxFlat.new()

	func configure(main: Node, id: String) -> void:
		portraits.clear(); front = 0; back = 0
		var positions: Dictionary = RULES.offsets(main.deployed_heroes, id)
		for hero in main.deployed_heroes:
			var point: Vector2 = positions.get(str(hero.id), Vector2.ZERO)
			if point.x >= .3: front += 1
			else: back += 1
			portraits.append({"point":point, "texture":main._combat_portrait_texture(str(hero.id))})

	func _ready() -> void:
		background.bg_color = S.DARK; background.set_corner_radius_all(8)
		resized.connect(queue_redraw)

	func _draw() -> void:
		draw_style_box(background, Rect2(Vector2.ZERO, size))
		var font: Font = S.font()
		if portraits.is_empty():
			draw_string(font, Vector2(14, size.y * .5 + 5), "영웅을 편성하면 배치를 미리 볼 수 있어요.", HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 14, S.MUTED)
			return
		var field := Rect2(24, 16, maxf(1, size.x - 80), size.y - 48)
		var divider := field.position.x + field.size.x * (.3 + 4.6) / 7.9
		draw_line(Vector2(divider, 10), Vector2(divider, size.y - 30), Color(S.EDGE_SOFT, .6), 1, true)
		for portrait: Dictionary in portraits:
			var point: Vector2 = portrait.point
			var center := field.position + Vector2((point.x + 4.6) / 7.9, (point.y + 3.9) / 7.8) * field.size
			draw_circle(center, 8, S.SURFACE_2, true, -1, true)
			draw_circle(center, 8, S.GOLD if point.x >= .3 else S.BLUE, false, 1, true)
			var texture: Texture2D = portrait.texture as Texture2D
			if texture != null: draw_texture_rect(texture, Rect2(center - Vector2(7, 7), Vector2(14, 14)), false)
		var label_y := size.y - 9
		draw_string(font, Vector2(12, label_y), "후열 %d" % back, HORIZONTAL_ALIGNMENT_LEFT, divider - 18, 13, S.BLUE)
		draw_string(font, Vector2(divider + 10, label_y), "전열 %d" % front, HORIZONTAL_ALIGNMENT_LEFT, size.x - divider - 48, 13, S.GOLD)
		var arrow_x := size.x - 26
		draw_line(Vector2(arrow_x - 8, 46), Vector2(arrow_x + 7, 46), S.MUTED, 1.5, true)
		draw_polyline(PackedVector2Array([Vector2(arrow_x + 2, 41), Vector2(arrow_x + 7, 46), Vector2(arrow_x + 2, 51)]), S.MUTED, 1.5, true)
