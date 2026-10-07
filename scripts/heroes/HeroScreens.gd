extends RefCounted
class_name HeroScreens

const UI = preload("res://scripts/ui/GameUiTheme.gd")
const ROSTER = preload("res://scripts/heroes/HeroRosterCatalog.gd")
const CHROME = preload("res://scripts/ui/UiChrome.gd")
const VISUALS = preload("res://scripts/heroes/HeroVisualCatalog.gd")

static func _label(main, text: String, font_size: int = 16, color: Color = UI.INK, wrap: bool = false) -> Label:
	var result: Label = main._label(text, font_size, color)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap:
		result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		result.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return result

static func _panel(rect: Rect2, color: Color = UI.SURFACE, border: Color = UI.BORDER) -> Panel:
	var result := Panel.new()
	result.position = rect.position
	result.size = rect.size
	result.add_theme_stylebox_override("panel", UI.panel(color, border, 16))
	return result

static func _place(parent: Node, control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
	parent.add_child(control)

static func _button(main, text: String, width: float, height: float, action: Callable, primary: bool = false) -> Button:
	var result: Button = main._button(text, Vector2(width, height), UI.PRIMARY if primary else UI.SOFT)
	result.add_theme_font_size_override("font_size", 14)
	result.pressed.connect(action)
	return result

static func _portrait(main, hero: Dictionary, rect: Rect2, large: bool = false) -> Control:
	var hero_id := str(hero["id"])
	var accent := UI.text_color(Color(hero["color"]))
	var result := Panel.new()
	result.position = rect.position
	result.size = rect.size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_stylebox_override("panel", UI.panel(UI.SOFT.lerp(Color(hero["color"]), 0.10), UI.BORDER, 20 if large else 12))
	if VISUALS.has_hero(hero_id) or HeroSpriteFactory.BRIGHT_SPRITES.has(hero_id):
		var texture := TextureRect.new()
		texture.name = "HeroPortrait_%s" % hero_id
		texture.texture = VISUALS.portrait_texture(hero_id) if VISUALS.has_hero(hero_id) else HeroSpriteFactory.portrait_texture(hero_id)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture.position = Vector2(12, 10) if large else Vector2(5, 4)
		texture.size = rect.size - texture.position * 2
		texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		result.add_child(texture)
	else:
		var role: String = main._hero_role_group(hero_id)
		var symbol_name: String = {"탱커": "shield", "딜러": "sword", "서포터": "leaf", "컨트롤러": "moon"}.get(role, "hero")
		var extent: float = minf(rect.size.x, rect.size.y) * (0.36 if large else 0.46)
		var symbol: Control = UI.icon(str(symbol_name), Vector2(extent, extent), accent)
		symbol.position = Vector2((rect.size.x - extent) / 2, (rect.size.y - extent) / 2 - (10 if large else 0))
		result.add_child(symbol)
		if large:
			var title := _label(main, "%s의 문장" % str(hero["race"]), 13, UI.MUTED)
			title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_place(result, title, Rect2(14, rect.size.y - 44, rect.size.x - 28, 22))
	return result

static func roster(main) -> void:
	main._clear_screen()
	main.active_screen = "hero_select"
	main.hero_slot_labels.clear()
	main.hero_select_buttons.clear()
	main.equipment_labels.clear()
	var heroes: Array = main._hero_roster_for_faction()
	main._setup_hero_progress(heroes)
	var visible: Array = main._filtered_sorted_roster(heroes)
	var accent := UI.PRIMARY if main.selected_faction == "aurelia" else UI.LAVENDER
	main._add_screen_header("‹  원정 캠프", Callable(main, "_build_lobby_screen"), "함께 떠날 영웅들", "%s · 서로 다른 재능으로 하나의 원정대를 만드세요." % main._faction_name(), "영웅 · 30명의 이야기", accent, "골드 %s · 보석 %s" % [main.wallet_gold, main.wallet_gems])

	var summary := HBoxContainer.new()
	summary.name = "StatusDashboard"
	summary.add_theme_constant_override("separation", 12)
	_place(main.content_root, summary, Rect2(55, 188, 775, 56))
	for item in [["원정대 전투력", str(main._calculate_party_power())], ["진영 영웅", "%d명" % heroes.size()], ["성장 구성", "딜러 8 · 수호/지원 4 · 약화 3"]]:
		var summary_card := PanelContainer.new()
		summary_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := UI.panel(UI.SURFACE, UI.BORDER, 12)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		summary_card.add_theme_stylebox_override("panel", style)
		summary.add_child(summary_card)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		summary_card.add_child(vbox)
		vbox.add_child(_label(main, str(item[0]), 11, UI.MUTED))
		var value_label := _label(main, str(item[1]), 16 if item[0] != "성장 구성" else 13, UI.INK)
		if item[0] == "원정대 전투력":
			value_label.name = "PartyPowerValue"
		vbox.add_child(value_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_place(main.content_root, actions, Rect2(55, 250, 775, 44))
	actions.add_child(_button(main, "역할 · %s" % main.hero_roster_filter, 142, 44, Callable(main, "_cycle_hero_filter")))
	actions.add_child(_button(main, "정렬 · %s" % main.hero_roster_sort, 136, 44, Callable(main, "_cycle_hero_sort")))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	actions.add_child(_button(main, "영웅 도감", 112, 44, Callable(main, "_build_codex_screen")))
	actions.add_child(_button(main, "성장 연구", 112, 44, Callable(main, "_build_growth_screen")))

	var scroll := ScrollContainer.new()
	scroll.name = "HeroRosterScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(main.content_root, scroll, Rect2(55, 302, 775, 286))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	for hero: Dictionary in visible:
		grid.add_child(card(main, hero, accent))
	main.hero_hint = _label(main, "영웅의 상세 정보를 살펴보고 원정대에 배치하세요.", 13, UI.MUTED, true)
	_place(main.content_root, main.hero_hint, Rect2(55, 600, 775, 30))

	var party := _panel(Rect2(854, 188, 372, 442))
	party.name = "PartyFormationPanel"
	main.content_root.add_child(party)
	_place(party, _label(main, "나의 원정대", 21), Rect2(16, 12, 220, 30))
	var cap := _label(main, "%d / %d명" % [main.deployed_heroes.size(), main._party_slot_cap()], 13, accent)
	cap.name = "PartyCountValue"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(party, cap, Rect2(242, 14, 112, 26))
	_place(party, _label(main, main._party_next_unlock_text(), 12, UI.MUTED), Rect2(16, 45, 338, 20))
	main.party_composition_label = _label(main, "", 11, UI.MUTED, true)
	main.party_composition_label.max_lines_visible = 2
	_place(party, main.party_composition_label, Rect2(16, 71, 338, 35))
	var slots := GridContainer.new()
	slots.columns = 2
	slots.add_theme_constant_override("h_separation", 6)
	slots.add_theme_constant_override("v_separation", 4)
	_place(party, slots, Rect2(16, 115, 340, 196))
	for slot_index in range(10):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(167, 36)
		slot.add_theme_stylebox_override("panel", UI.panel(UI.SOFT, UI.BORDER, 8))
		var text := _label(main, main._party_slot_name(slot_index), 11, UI.MUTED)
		text.name = "HeroSlotLabel"
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.max_lines_visible = 2
		text.custom_minimum_size = Vector2(157, 32)
		slot.add_child(text)
		slots.add_child(slot)
		main.hero_slot_labels.append(text)
	for index in range(3):
		var preset := _button(main, "편성 %d" % (index + 1), 110, 44, func(): _preset(main, index, accent))
		preset.tooltip_text = "저장된 원정대를 불러오거나 현재 편성을 저장합니다."
		_place(party, preset, Rect2(16 + index * 114, 324, 110, 44))
	var confirm := _button(main, "이 원정대로 출발", 340, 44, Callable(main, "_confirm_party"), true)
	_place(party, confirm, Rect2(16, 386, 340, 44))
	main._refresh_party_slots(accent)
	main._add_bottom_nav("heroes")

static func card(main, hero: Dictionary, accent: Color) -> PanelContainer:
	var result := PanelContainer.new()
	result.custom_minimum_size = Vector2(375, 188)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hero_id := str(hero["id"])
	var locked: bool = main.idle_stage < int(hero.get("unlock_stage", 1))
	var selected: bool = main._is_hero_deployed(hero_id)
	var grade_color: Color = UI.text_color(main._hero_grade_color(hero_id))
	result.add_theme_stylebox_override("panel", UI.panel(UI.SURFACE, accent if selected else UI.BORDER, 14, 2 if selected else 1))
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(370, 184)
	result.add_child(canvas)
	canvas.add_child(_portrait(main, hero, Rect2(12, 12, 72, 82)))
	_place(canvas, _label(main, str(hero["name"]), 18), Rect2(96, 11, 264, 27))
	_place(canvas, _label(main, "%s · %s" % [hero["race"], hero["class"]], 12, UI.MUTED), Rect2(96, 39, 264, 21))
	_place(canvas, _label(main, "%s  ·  %s" % [main._hero_grade(hero_id), main._hero_role_group(hero_id)], 12, grade_color), Rect2(96, 62, 250, 21))
	var progress: Dictionary = main._get_hero_progress(hero_id)
	var growth_text := "스테이지 %d에서 합류" % int(hero.get("unlock_stage", 1)) if locked else "Lv.%d   ·   %s" % [int(progress.get("level", 1)), str(hero.get("identity", hero["role"]))]
	var growth := _label(main, growth_text, 12, UI.MUTED if locked else UI.PRIMARY)
	growth.tooltip_text = str(hero.get("identity", hero["role"]))
	_place(canvas, growth, Rect2(12, 100, 348, 21))
	var details := _button(main, "상세 보기", 110, 44, Callable(main, "_build_hero_detail_screen").bind(hero_id))
	_place(canvas, details, Rect2(12, 130, 110, 44))
	var select := _button(main, "영웅 배치", 228, 44, func():
		main._deploy_hero(hero)
		_refresh_roster_view(main, accent)
	, not locked)
	select.disabled = locked
	select.add_theme_font_size_override("font_size", 13)
	_place(canvas, select, Rect2(132, 130, 228, 44))
	main.hero_select_buttons[hero_id] = select
	return result

static func _preset(main, index: int, accent: Color) -> void:
	var saved_ids: Array = []
	if index < main.party_presets.size() and main.party_presets[index] is Array:
		saved_ids = main.party_presets[index]
	var names: Array[String] = []
	for hero_id in saved_ids:
		names.append(str(ROSTER.HEROES.get(str(hero_id), {}).get("name", "미확인 영웅")))
	var modal: Panel = CHROME.overlay(main, "편성 %d" % (index + 1), 274)
	for child in modal.get_children():
		if child is Button:
			child.custom_minimum_size.y = maxf(child.custom_minimum_size.y, 44.0)
	var description := "저장된 원정대가 없습니다. 현재 편성을 저장해 보세요." if names.is_empty() else "저장된 영웅 %d명  ·  %s" % [names.size(), " / ".join(names)]
	_place(modal, _label(main, description, 14, UI.INK, true), Rect2(28, 82, 564, 66))
	var apply := _button(main, "저장된 편성 적용", 274, 48, func():
		main._preview_party_preset(index)
	, true)
	apply.disabled = saved_ids.is_empty()
	_place(modal, apply, Rect2(28, 168, 274, 48))
	var save := _button(main, "현재 편성 저장", 274, 48, func():
		main._save_party_preset(index)
		modal.get_parent().queue_free()
	)
	_place(modal, save, Rect2(318, 168, 274, 48))
	_place(modal, _label(main, "저장하면 현재 원정대 %d명으로 이 편성을 바꿉니다." % main.deployed_heroes.size(), 12, UI.MUTED), Rect2(28, 228, 564, 22))

static func _refresh_roster_view(main, accent: Color) -> void:
	var power_label: Node = main.content_root.find_child("PartyPowerValue", true, false)
	if power_label is Label:
		power_label.text = str(main._calculate_party_power())
	var count_label: Node = main.content_root.find_child("PartyCountValue", true, false)
	if count_label is Label:
		count_label.text = "%d / %d명" % [main.deployed_heroes.size(), main._party_slot_cap()]
	for hero_id in main.hero_select_buttons:
		var button: Button = main.hero_select_buttons[hero_id]
		if is_instance_valid(button):
			var selected: bool = main._is_hero_deployed(str(hero_id))
			var hero_card: PanelContainer = button.get_parent().get_parent()
			hero_card.add_theme_stylebox_override("panel", UI.panel(UI.SURFACE, accent if selected else UI.BORDER, 14, 2 if selected else 1))

static func detail(main, hero_id: String, scroll_position: int = 0) -> void:
	var hero: Dictionary = {}
	for candidate: Dictionary in main._hero_roster_for_faction():
		if str(candidate.get("id", "")) == hero_id:
			hero = candidate
			break
	if hero.is_empty():
		main._build_hero_select_screen()
		return
	main._clear_screen()
	main.active_screen = "hero_detail"
	main.hero_slot_labels.clear()
	main.hero_select_buttons.clear()
	main.party_composition_label = null
	main.hero_hint = null
	var accent := UI.text_color(Color(hero["color"]))
	var progress: Dictionary = main._get_hero_progress(hero_id)
	var locked: bool = main.idle_stage < int(hero.get("unlock_stage", 1))
	var grade_color: Color = UI.text_color(main._hero_grade_color(hero_id))
	main._add_screen_header("‹  영웅 목록", Callable(main, "_build_hero_select_screen"), str(hero["name"]), "%s · %s · %s" % [hero["race"], hero["class"], hero["role"]], "%s · %d돌파" % [main._hero_grade(hero_id), main._hero_breakthrough_rank(hero_id)], accent, "골드 %s · 보석 %s" % [main.wallet_gold, main.wallet_gems])

	var art := _panel(Rect2(55, 188, 364, 442))
	art.name = "HeroIdentityPanel"
	main.content_root.add_child(art)
	_place(art, _label(main, "%s  %s" % [main._hero_grade(hero_id), main._hero_role_group(hero_id)], 15, grade_color), Rect2(18, 15, 245, 25))
	var level := _label(main, "Lv.%d" % int(progress.get("level", 1)), 18)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(art, level, Rect2(266, 14, 80, 28))
	art.add_child(_portrait(main, hero, Rect2(48, 51, 268, 200), true))
	var identity := _label(main, str(hero.get("identity", hero["role"])), 19, UI.INK)
	identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(art, identity, Rect2(18, 264, 328, 30))
	var stats := _label(main, str(hero.get("stats", "")), 13, UI.MUTED)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(art, stats, Rect2(18, 297, 328, 26))
	var xp := ProgressBar.new()
	xp.show_percentage = false
	xp.max_value = main._hero_xp_to_next(int(progress.get("level", 1)))
	xp.value = int(progress.get("xp", 0))
	xp.add_theme_stylebox_override("background", UI.panel(UI.SOFT, UI.BORDER, 4, 0))
	xp.add_theme_stylebox_override("fill", UI.panel(UI.PRIMARY, UI.PRIMARY, 4, 0))
	_place(art, xp, Rect2(24, 337, 316, 7))
	var xp_text := _label(main, "경험치 %d / %d" % [int(progress.get("xp", 0)), int(xp.max_value)], 11, UI.MUTED)
	xp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(art, xp_text, Rect2(20, 348, 324, 22))
	var select_text := "배치 해제" if main._is_hero_deployed(hero_id) else "원정대에 배치"
	if locked:
		select_text = "스테이지 %d에서 합류" % int(hero.get("unlock_stage", 1))
	var select := _button(main, select_text, 324, 44, func():
		main._deploy_hero(hero)
		detail(main, hero_id)
	, true)
	select.disabled = locked or (not main._is_hero_deployed(hero_id) and main.deployed_heroes.size() >= main._party_slot_cap())
	select.tooltip_text = "현재 편성 한도 %d명" % main._party_slot_cap()
	_place(art, select, Rect2(20, 383, 324, 44))

	var info := _panel(Rect2(443, 188, 782, 442))
	main.content_root.add_child(info)
	var scroll := ScrollContainer.new()
	scroll.name = "HeroDetailScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(info, scroll, Rect2(18, 16, 746, 410))
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	box.add_child(_label(main, "전투 기술", 21))
	box.add_child(_label(main, "액티브 2 · 패시브 1 · 궁극기 1", 12, UI.MUTED))
	for kit: Dictionary in ROSTER.HEROES[hero_id]["skills"]:
		var skill_panel := PanelContainer.new()
		skill_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var is_ultimate: bool = str(kit["slot"]) == "ultimate"
		var skill_style := UI.panel(Color("#f5efdd") if is_ultimate else UI.SOFT, Color("#d6c69d") if is_ultimate else UI.BORDER, 12)
		skill_style.content_margin_left = 15
		skill_style.content_margin_right = 15
		skill_style.content_margin_top = 12
		skill_style.content_margin_bottom = 12
		skill_panel.add_theme_stylebox_override("panel", skill_style)
		box.add_child(skill_panel)
		var skill_row := HBoxContainer.new()
		skill_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_row.add_theme_constant_override("separation", 14)
		skill_panel.add_child(skill_row)
		var skill_icon := TextureRect.new()
		skill_icon.name = "SkillIcon_%s_%s" % [hero_id, str(kit["slot"])]
		skill_icon.texture = VISUALS.skill_texture(hero_id, str(kit["slot"]))
		skill_icon.custom_minimum_size = Vector2(72, 80)
		skill_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		skill_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		skill_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		skill_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var skill_art: Dictionary = VISUALS.skill_design(hero_id, str(kit["slot"]))
		skill_icon.tooltip_text = "%s\n%s" % [str(kit["skill"]), str(skill_art.get("vfx_ko", ""))]
		skill_row.add_child(skill_icon)
		var skill_box := VBoxContainer.new()
		skill_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_box.add_theme_constant_override("separation", 5)
		skill_row.add_child(skill_box)
		var slot_name: String = {"a1": "액티브 1", "a2": "액티브 2", "passive": "패시브", "ultimate": "궁극기"}[str(kit["slot"])]
		var cooldown: String = "게이지 100" if is_ultimate else ("내부 재사용 %.1f초" if str(kit["slot"]) == "passive" else "재사용 %.1f초") % float(kit.get("cooldown", 0))
		skill_box.add_child(_label(main, "%s  ·  %s" % [slot_name, cooldown], 11, UI.GOLD if is_ultimate else UI.MUTED))
		skill_box.add_child(_label(main, str(kit["skill"]), 18, UI.GOLD if is_ultimate else accent, true))
		skill_box.add_child(_label(main, str(kit["effect"]), 14, UI.INK, true))
	var identity_profile: Dictionary = main.hero_identity_catalog.profile(hero_id)
	box.add_child(_label(main, "전투 성향", 19))
	box.add_child(_label(main, "%s · %s" % [main.hero_identity_catalog.ai_style_name(str(identity_profile.get("ai_style", "balanced"))), str(identity_profile.get("trait", "상황에 맞춘 균형 행동"))], 14, UI.MUTED, true))
	box.add_child(_label(main, "장비와 성장", 19))
	var equipment := _label(main, main._equipment_summary(hero_id), 13, UI.MUTED, true)
	box.add_child(equipment)
	main.equipment_labels[hero_id] = equipment
	var equipment_row := HBoxContainer.new()
	equipment_row.add_theme_constant_override("separation", 8)
	box.add_child(equipment_row)
	var equipment_levels: Dictionary = main._get_hero_equipment(hero_id)
	for slot: String in ["weapon", "armor", "accessory"]:
		var current_level := int(equipment_levels[slot])
		var cost: int = main._equipment_upgrade_cost(slot, current_level)
		var text := "%s 강화 · %dG" % [main._equipment_slot_name(slot), cost] if current_level < 10 else "%s 최대 강화" % main._equipment_slot_name(slot)
		var enhance := _button(main, text, 0, 44, func():
			main._enhance_equipment(hero, slot)
			detail(main, hero_id, scroll.scroll_vertical)
		)
		enhance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		enhance.add_theme_font_size_override("font_size", 12)
		enhance.disabled = locked or current_level >= 10 or main.wallet_gold < cost
		enhance.tooltip_text = "현재 +%d · 강화 비용 %dG" % [current_level, cost]
		equipment_row.add_child(enhance)
	main.hero_hint = _label(main, "강화 비용과 보유 골드를 확인하세요.", 12, UI.MUTED, true)
	box.add_child(main.hero_hint)
	var tree: Dictionary = main._get_skill_tree(hero_id)
	box.add_child(_label(main, "연구 · 공격 %d / 생존 %d / 기능 %d   ·   남은 포인트 %d" % [int(tree.get("offense", 0)), int(tree.get("survival", 0)), int(tree.get("utility", 0)), main._skill_tree_available_points(hero_id)], 13, UI.MUTED, true))
	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	box.add_child(actions)
	for item in [["성장 연구", "_build_growth_screen"], ["장비 관리", "_build_inventory_screen"], ["영웅 조각 · 돌파", "_build_summon_screen"]]:
		var action := _button(main, str(item[0]), 335, 44, Callable(main, str(item[1])))
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(action)
	var requirement: Dictionary = main._ascension_requirement(hero_id)
	var ascend := _button(main, "승급 · %dG" % int(requirement["gold"]) if main._hero_grade(hero_id) != "UR" else "최고 등급 UR", 335, 44, func():
		if main._try_ascend_hero(hero_id):
			detail(main, hero_id, scroll.scroll_vertical)
	)
	ascend.disabled = locked or main._hero_grade(hero_id) == "UR"
	ascend.tooltip_text = "승급 조건 · Lv.%d · %dG" % [int(requirement["level"]), int(requirement["gold"])]
	actions.add_child(ascend)
	box.add_child(_label(main, "영웅 조각 %d개 · 돌파 %d / 5" % [main._hero_shard_count(hero_id), main._hero_breakthrough_rank(hero_id)], 12, UI.MUTED))
	scroll.set_deferred("scroll_vertical", scroll_position)
	main._add_bottom_nav("heroes")
