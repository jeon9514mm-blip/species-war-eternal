extends RefCounted
class_name LandingScreens

# v30: player-facing entry, device sign-in and expedition home.
# Authentication is deliberately limited to the existing device save flow.
const PAPER := Color("#fbf7ed")
const SAGE := Color("#e5e8dc")
const INK := Color("#254239")
const GREEN := Color("#316c56")
const GOLD := Color("#a27130")
const MUTED := Color("#67776c")
const BORDER := Color("#d2d9c9")
const FIELD_ART := preload("res://scripts/FieldArtCatalog.gd")

static func title(main) -> void:
	main._clear_screen()
	main.active_screen = "title"
	var w: float = main._layout_width()
	var h: float = main._layout_height()
	var root: Control = main.content_root
	_text(main, root, "SPECIES WAR: ETERNAL", Rect2(62, 46, 430, 28), 15, GOLD)
	_text(main, root, "서로 다른 영웅, 하나의 원정대", Rect2(64, 181, 470, 30), 18, GREEN)
	_text(main, root, "종의전쟁: 이터널", Rect2(58, 220, 560, 92), 58, INK)
	_text(main, root, "작은 영웅들의\n끝없이 이어지는 모험", Rect2(64, 322, 485, 85), 27, INK)
	_text(main, root, "당신만의 원정대를 꾸리고, 새로운 땅을 만나세요.", Rect2(64, 422, 460, 54), 16, MUTED, true)
	var start: Button = _action(main, root, "모험 시작", Rect2(64, 500, 410, 62), Callable(main, "_build_login_screen"), true)
	start.name = "StartAdventure"
	start.disabled = main._save_blocked_for_newer_version
	var notice := _save_notice(main)
	_text(main, root, notice if not notice.is_empty() else "모험의 기록은 이 기기에 자동으로 저장됩니다.", Rect2(64, 575, 458, 56), 15, MUTED, true)
	var art_rect := Rect2(w - 650.0, 72, 600, h - 154.0)
	var scene := _scene(main, root, art_rect, ["mira", "orwin", "leonhardt", "caelum", "darius"], true)
	scene.name = "TitleExpeditionArt"
	_badge(main, scene, "서른 영웅과 떠나는 여정", Rect2(28, 26, 248, 38), PAPER, GREEN)
	_text(main, root, "30명의 영웅     ·     최대 10인 원정대     ·     실시간 자동사냥", Rect2(64, h - 54.0, w - 128, 30), 15, MUTED)
	start.grab_focus.call_deferred()

static func login(main) -> void:
	main._clear_screen()
	main.active_screen = "login"
	var w: float = main._layout_width()
	var h: float = main._layout_height()
	var root: Control = main.content_root
	_action(main, root, "돌아가기", Rect2(48, 30, 124, 44), Callable(main, "_build_title_screen"))
	_text(main, root, "종의전쟁: 이터널", Rect2(w - 320, 31, 270, 44), 21, INK)
	var scene := _scene(main, root, Rect2(48, 104, w - 656, h - 174), ["mira", "leonhardt", "caelum"], true)
	scene.name = "LoginExpeditionArt"
	var story := _panel(main, scene, Rect2(24, 24, 390, 129), Color(PAPER, 0.96), Color.TRANSPARENT, 18)
	_text(main, story, "당신의 원정대가 기다려요", Rect2(22, 17, 345, 38), 25, INK)
	_text(main, story, "어제의 모험을 이어가거나,\n오늘 새로운 이야기를 시작하세요.", Rect2(22, 61, 345, 50), 17, MUTED, true)
	var panel := _panel(main, root, Rect2(w - 566, 104, 518, h - 174), PAPER, BORDER, 24)
	panel.name = "LoginPanel"
	_text(main, panel, "다시 만나 반가워요", Rect2(34, 35, 450, 30), 16, GOLD)
	_text(main, panel, "모험을 이어갈 방법", Rect2(34, 82, 450, 50), 32, INK)
	_text(main, panel, "이 기기에 남겨 둔 영웅과 모험의 기록으로\n바로 시작할 수 있어요.", Rect2(34, 145, 450, 59), 17, MUTED, true)
	var has_progress: bool = not str(main.selected_faction).is_empty()
	var local_label := "이 기기에서 계속하기" if has_progress else "이 기기에서 시작하기"
	var local: Button = _action(main, panel, local_label, Rect2(34, 234, 450, 60), Callable(main, "_build_lobby_screen"), true)
	local.name = "DeviceContinueButton"
	local.disabled = main._save_blocked_for_newer_version
	var state := "저장된 원정대가 있어요" if has_progress else "새로운 원정대를 만들어 보세요"
	_text(main, panel, state, Rect2(34, 306, 450, 29), 15, GREEN)
	var unavailable := _panel(main, panel, Rect2(34, 357, 450, 80), SAGE, Color.TRANSPARENT, 16)
	unavailable.name = "AccountLoginUnavailable"
	_text(main, unavailable, "계정 로그인", Rect2(18, 11, 300, 26), 16, INK)
	_text(main, unavailable, "다른 기기에서 이어하기는 아직 지원하지 않아요.", Rect2(18, 42, 414, 28), 15, MUTED)
	var notice := _save_notice(main)
	_text(main, panel, notice if not notice.is_empty() else "기기를 바꾸거나 앱을 삭제하면 기록을 잃을 수 있어요.", Rect2(34, 452, 450, 60), 15, MUTED, true)
	local.grab_focus.call_deferred()

static func lobby(main) -> void:
	main._clear_screen()
	main.active_screen = "lobby"
	var root: Control = main.content_root
	var w: float = main._layout_width()
	var left_w := w - 468.0
	var side_x := w - 404.0
	var zone: Dictionary = main._current_zone()
	_text(main, root, "원정대", Rect2(42, 24, 350, 44), 31, INK)
	var faction: String = main._faction_name() if not str(main.selected_faction).is_empty() else "깃발을 고르고 첫 모험을 시작하세요"
	_text(main, root, faction, Rect2(44, 68, 580, 25), 15, MUTED)
	_badge(main, root, "골드  %s" % _number(main.wallet_gold), Rect2(w - 477, 30, 170, 45), PAPER, GOLD)
	_badge(main, root, "젬  %s" % _number(main.wallet_gems), Rect2(w - 295, 30, 145, 45), PAPER, GREEN)
	_action(main, root, "메뉴", Rect2(w - 138, 30, 94, 45), Callable(main, "_show_main_menu"))
	var party: Array = main.deployed_heroes
	var scene_ids: Array = []
	for hero in party.slice(0, 5):
		scene_ids.append(str(hero.get("id", "leonhardt")))
	if scene_ids.is_empty():
		scene_ids = ["mira", "leonhardt", "orwin"]
	var expedition := _scene(main, root, Rect2(40, 110, left_w, 302), scene_ids, false)
	expedition.name = "CurrentExpedition"
	var overlay := _panel(main, expedition, Rect2(0, 0, 382, 302), Color(PAPER, 0.95), Color.TRANSPARENT, 0)
	_badge(main, overlay, "STAGE  %02d" % main.idle_stage, Rect2(24, 22, 120, 30), SAGE, GREEN)
	_text(main, overlay, str(zone.get("name", "회색 초원")), Rect2(24, 67, 330, 45), 34, INK)
	_text(main, overlay, str(zone.get("description", "새로운 모험이 기다립니다.")), Rect2(24, 122, 324, 49), 16, MUTED, true)
	_text(main, overlay, "권장 전투력 %s" % _number(int(zone.get("power", 0))), Rect2(24, 181, 320, 27), 15, GREEN)
	var hunt_text := "사냥 이어하기" if not party.is_empty() else "첫 원정대 만들기"
	var hunt := _action(main, overlay, hunt_text, Rect2(24, 225, 334, 54), Callable(main, "_lobby_start_hunt"), true)
	hunt.name = "LobbyHuntButton"
	var status := _panel(main, root, Rect2(side_x, 110, 364, 302), PAPER, BORDER, 20)
	status.name = "StatusDashboard"
	_text(main, status, "모험의 발자취", Rect2(22, 18, 320, 32), 21, INK)
	_text(main, status, "원정대 전투력", Rect2(22, 66, 160, 26), 15, MUTED)
	_text(main, status, _number(main._calculate_party_power()), Rect2(190, 63, 150, 30), 24, GREEN)
	_text(main, status, "스테이지 %d" % main.idle_stage, Rect2(22, 109, 190, 26), 16, INK)
	var target: int = maxi(1, int(main.idle_stage_target))
	_text(main, status, "%d / %d 무리" % [main.idle_stage_kills, target], Rect2(217, 109, 126, 26), 15, MUTED)
	var progress := ProgressBar.new()
	progress.position = Vector2(22, 148)
	progress.size = Vector2(320, 7)
	progress.max_value = target
	progress.value = main.idle_stage_kills
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_theme_stylebox_override("background", main._panel_style(SAGE, Color.TRANSPARENT, 4))
	progress.add_theme_stylebox_override("fill", main._panel_style(GREEN, Color.TRANSPARENT, 4))
	status.add_child(progress)
	var reward_gold: int = main.unclaimed_gold + main.idle_chest_gold
	var reward_xp: int = main.unclaimed_xp + main.idle_chest_xp
	_text(main, status, "원정대가 모아 온 보상", Rect2(22, 177, 320, 25), 15, MUTED)
	_text(main, status, "골드 %s  ·  경험치 %s" % [_number(reward_gold), _number(reward_xp)], Rect2(22, 204, 320, 27), 17, GOLD)
	var claim := _action(main, status, "보상 받기" if reward_gold + reward_xp > 0 else "모험하며 보상을 모아 보세요", Rect2(22, 246, 320, 40), func():
		main._claim_rewards()
		main._build_lobby_screen()
	)
	claim.name = "LobbyClaimRewards"
	claim.disabled = reward_gold + reward_xp <= 0
	_build_party_card(main, root, Rect2(40, 432, left_w, 166), party)
	_build_shortcuts(main, root, Rect2(side_x, 432, 364, 166))
	main._add_bottom_nav("lobby")

static func _build_party_card(main, parent: Control, rect: Rect2, party: Array) -> void:
	var panel := _panel(main, parent, rect, PAPER, BORDER, 20)
	panel.name = "LobbyPartyCard"
	_text(main, panel, "나의 원정대", Rect2(22, 14, 260, 29), 20, INK)
	_text(main, panel, "%d / %d명" % [party.size(), main._party_slot_cap()], Rect2(171, 17, 180, 26), 15, MUTED)
	_action(main, panel, "편성하기", Rect2(rect.size.x - 130, 7, 108, 44), Callable(main, "_lobby_deploy"))
	if party.is_empty():
		for index in range(3):
			var ids := ["leonhardt", "mira", "elisia"]
			_portrait(main, panel, ids[index], Rect2(22 + index * 80, 62, 66, 80), Color("#dce6d8"))
		_text(main, panel, "모험을 함께할 첫 동료를 만나세요.", Rect2(278, 72, rect.size.x - 300, 33), 18, INK)
		_text(main, panel, "진영을 선택하면 영웅을 편성할 수 있어요.", Rect2(278, 109, rect.size.x - 300, 28), 15, MUTED)
		return
	var slot_w: float = minf(69.0, (rect.size.x - 44.0 - 9.0 * 8.0) / 10.0)
	for index in range(10):
		var cell := Rect2(22 + float(index) * (slot_w + 8.0), 63, slot_w, 81)
		if index < party.size():
			var hero: Dictionary = party[index]
			var hero_id := str(hero.get("id", ""))
			var color: Color = hero.get("color", GREEN)
			var holder := _portrait(main, panel, hero_id, cell, PAPER.lerp(color, 0.17))
			holder.tooltip_text = "%s · %s" % [hero.get("name", ""), hero.get("class", "")]
			var level: int = int(main._get_hero_progress(hero_id).get("level", 1))
			var level_label := _text(main, holder, "Lv.%d" % level, Rect2(0, 58, slot_w, 23), 13, INK)
			level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			var empty := _panel(main, panel, cell, SAGE, Color.TRANSPARENT, 12)
			var mark := "·" if index < main._party_slot_cap() else "—"
			var label := _text(main, empty, mark, Rect2(0, 18, slot_w, 40), 22, MUTED)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.tooltip_text = "빈 편성 슬롯" if index < main._party_slot_cap() else "사냥을 진행하면 개방됩니다"

static func _build_shortcuts(main, parent: Control, rect: Rect2) -> void:
	var panel := _panel(main, parent, rect, SAGE, Color.TRANSPARENT, 20)
	_text(main, panel, "다음 모험을 위한 준비", Rect2(20, 12, 326, 30), 18, INK)
	var items := [
		["영웅 성장", "_build_growth_screen"], ["장비 가방", "_build_inventory_screen"],
		["영웅 소환", "_build_summon_screen"], ["세계 지도", "_build_world_map_screen"]
	]
	for index in range(items.size()):
		var item: Array = items[index]
		var position := Vector2(18 + (index % 2) * 169, 54 + floori(float(index) / 2.0) * 49)
		_action(main, panel, item[0], Rect2(position, Vector2(159, 43)), Callable(main, item[1]))

static func _scene(main, parent: Control, rect: Rect2, hero_ids: Array, use_title_art: bool) -> Panel:
	var panel := _panel(main, parent, rect, SAGE, BORDER, 25)
	panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var has_title_art: bool = use_title_art
	art.texture = FIELD_ART.camp_texture() if use_title_art else FIELD_ART.texture_for(str(main.current_zone_id))
	art.modulate = Color(0.9, 0.92, 0.9, 1.0)
	panel.add_child(art)
	var count := hero_ids.size()
	for index in count:
		var x: float = rect.size.x * (0.20 + float(index) * 0.14) if use_title_art else rect.size.x * (0.59 + float(index) * 0.073)
		var y: float = rect.size.y * (0.87 if has_title_art else 0.61) + (16.0 if index % 2 == 0 else -4.0)
		var visual_scale := 0.17 if use_title_art else 0.105
		var shadow := _panel(main, panel, Rect2(x - 30, y - 6, 60, 14), Color(INK, 0.16), Color.TRANSPARENT, 12)
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hero := HeroSpriteFactory.create_hero(str(hero_ids[index]), Vector2(visual_scale, visual_scale))
		hero.position = Vector2(x, y)
		panel.add_child(hero)
		hero.play_idle("down")
	return panel

static func _portrait(main, parent: Control, hero_id: String, rect: Rect2, color: Color) -> Panel:
	var panel := _panel(main, parent, rect, color, BORDER, 12)
	var texture: Texture2D = HeroSpriteFactory.portrait_texture(hero_id)
	if texture != null:
		var portrait := TextureRect.new()
		portrait.texture = texture
		portrait.position = Vector2(6, 4)
		portrait.size = Vector2(rect.size.x - 12, 55)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(portrait)
	else:
		var hero: Dictionary = preload("res://scripts/HeroRosterCatalog.gd").HEROES.get(hero_id, {})
		var first := str(hero.get("name", "영웅")).substr(0, 1)
		var letter := _text(main, panel, first, Rect2(0, 8, rect.size.x, 42), 28, INK)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return panel

static func _save_notice(main) -> String:
	match str(main.save_load_status):
		"backup", "temporary":
			return "저장된 복구 기록에서 원정대를 안전하게 불러왔어요."
		"unsupported_version":
			return "더 최신 버전의 저장 기록이에요. 게임을 업데이트해 주세요."
		"corrupt":
			return "저장 기록을 읽지 못했어요. 기존 파일은 보존되어 있어요."
	return ""

static func _number(value: int) -> String:
	if value >= 100000000:
		return "%.1f억" % (float(value) / 100000000.0)
	if value >= 10000:
		return "%.1f만" % (float(value) / 10000.0)
	return str(value)

static func _text(main, parent: Control, value: String, rect: Rect2, font_size: int, color: Color, wrap := false) -> Label:
	var label: Label = main._label(value, font_size, color)
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

static func _panel(main, parent: Control, rect: Rect2, color: Color, border: Color, radius: int) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", main._panel_style(color, border, radius, 1 if border.a > 0.0 else 0))
	parent.add_child(panel)
	return panel

static func _badge(main, parent: Control, value: String, rect: Rect2, color: Color, ink: Color) -> Panel:
	var panel := _panel(main, parent, rect, color, BORDER, 12)
	var label := _text(main, panel, value, Rect2(Vector2.ZERO, rect.size), 15, ink)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return panel

static func _action(main, parent: Control, value: String, rect: Rect2, action: Callable, primary := false) -> Button:
	var button: Button = main._button(value, rect.size, GREEN if primary else PAPER)
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 20 if primary else 16)
	if primary:
		button.add_theme_color_override("font_color", PAPER)
		button.add_theme_color_override("font_hover_color", PAPER)
		button.add_theme_color_override("font_pressed_color", PAPER)
		button.add_theme_stylebox_override("normal", main._panel_style(GREEN, Color.TRANSPARENT, 14))
		button.add_theme_stylebox_override("hover", main._panel_style(GREEN.lightened(0.09), Color.TRANSPARENT, 14))
		button.add_theme_stylebox_override("pressed", main._panel_style(GREEN.darkened(0.08), Color.TRANSPARENT, 14))
	button.pressed.connect(action)
	parent.add_child(button)
	return button
