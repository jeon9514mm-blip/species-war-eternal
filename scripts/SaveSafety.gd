extends RefCounted
## One in-memory write barrier shared by challenge entries, loads and loadouts.
## Retain awarded state on IO failure; retry the snapshot, never the reward.
static func pending(main: Node) -> bool:
	return bool(main.get_meta("game_save_pending", false))

static func entry_error(main: Node) -> String:
	return "기록 저장 대기 중이에요. 먼저 다시 저장해 주세요." if pending(main) else ""

static func mutation_error(main: Node) -> String:
	if main._save_blocked_for_newer_version:
		return "최신 버전의 저장 기록을 먼저 확인해 주세요."
	if bool(main.get_meta("practice_active", false)):
		return "연습을 마친 뒤 성장과 재화를 변경하세요."
	return entry_error(main)

static func allow_mutation(main: Node) -> bool:
	var error := mutation_error(main)
	if error.is_empty(): return true
	main._show_toast(error)
	return false

static func observe(main: Node) -> void:
	main.set_meta("game_save_pending", str(main.last_save_status) != "saved")
	refresh_banner(main)

static func retry(main: Node) -> bool:
	if not pending(main) or main._save_blocked_for_newer_version: return false
	main._save_idle_state()
	observe(main)
	return not pending(main)

static func refresh_banner(main: Node) -> void:
	if not main is Control or not main.is_inside_tree(): return
	var old: Node = main.get_node_or_null("SaveSafetyLayer")
	if not pending(main):
		if old != null:
			main.remove_child(old)
			old.queue_free()
		return
	if old != null: return
	var skin = load("res://scripts/portrait/PortraitSkin.gd")
	var layer := CanvasLayer.new()
	layer.name = "SaveSafetyLayer"
	layer.layer = 100
	main.add_child(layer)
	var panel := PanelContainer.new()
	layer.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 18; panel.offset_right = -18
	panel.offset_top = -212; panel.offset_bottom = -108
	panel.add_theme_stylebox_override("panel", skin.box(skin.DARK, skin.GOLD, 12, 2))
	var row := HBoxContainer.new()
	panel.add_child(row)
	var label: Label = skin.label("저장 대기 · 현재 기록은 메모리에 있어요.\n저장 성공 전 앱을 종료하지 마세요.", 16, skin.GOLD)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button: Button = skin.button("다시 저장", Callable(main, "_retry_pending_save"))
	button.name = "RetryPendingSave"
	button.custom_minimum_size = Vector2(154, 60)
	row.add_child(button)
