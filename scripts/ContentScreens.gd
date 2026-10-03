extends RefCounted
class_name ContentScreens

## Presentation-only builders. Progression, rewards and encounters remain in Main.
const UI := preload("res://scripts/GameUiTheme.gd")
const HERO := preload("res://scripts/HeroSpriteFactory.gd")
const ZONES := ["gray_meadow", "forgotten_mine", "moonrest_forest"]
const BOSS_ART := ["res://assets/monsters/gray-meadow-boss.png", "res://assets/monsters/forgotten-mine-boss.png", "res://assets/monsters/moonrest-boss.png"]

static func _place(node: Control, parent: Node, rect: Rect2) -> Control:
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node

static func _card(main, parent: Node, rect: Rect2, tint: Color = UI.SURFACE, border: Color = UI.BORDER) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", main._panel_style(tint, border, 16, 1))
	_place(panel, parent, rect)
	return panel

static func _text(main, parent: Node, value: String, rect: Rect2, size: int = 16, color: Color = UI.INK) -> Label:
	var label: Label = main._label(value, size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	_place(label, parent, rect)
	return label

static func _button(main, parent: Node, title: String, rect: Rect2, action: Callable, primary: bool = false, accent: Color = UI.PRIMARY) -> Button:
	rect.size.y = maxf(44.0, rect.size.y)
	var button: Button = main._button(title, rect.size, accent if primary else UI.SOFT)
	button.add_theme_font_size_override("font_size", 16)
	_place(button, parent, rect)
	button.pressed.connect(action)
	return button

static func _icon(parent: Node, name_value: String, pos: Vector2, color: Color, extent: float = 26.0) -> void:
	var icon: Control = UI.icon(name_value, Vector2(extent, extent), color)
	_place(icon, parent, Rect2(pos, Vector2(extent, extent)))

static func _pill(main, parent: Node, value: String, rect: Rect2, accent: Color = UI.PRIMARY) -> void:
	var panel := _card(main, parent, rect, UI.SURFACE.lerp(accent, 0.10), Color.TRANSPARENT)
	var label := _text(main, panel, value, Rect2(8, 0, rect.size.x - 16, rect.size.y), 12, accent)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

static func _progress(main, parent: Node, rect: Rect2, value: float, maximum: float, accent: Color = UI.PRIMARY) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = maxf(1.0, maximum)
	bar.value = value
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", main._panel_style(Color("#dde3d4"), Color.TRANSPARENT, 5, 0))
	bar.add_theme_stylebox_override("fill", main._panel_style(accent, Color.TRANSPARENT, 5, 0))
	_place(bar, parent, rect)
	return bar

static func _scroll(main, rect: Rect2, content_height: float) -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(scroll, main.content_root, rect)
	var content := Control.new()
	content.custom_minimum_size = Vector2(rect.size.x - 20, content_height)
	scroll.add_child(content)
	return content

static func _portrait(main, parent: Node, hero: Dictionary, rect: Rect2, discovered: bool = true) -> void:
	var accent := Color(hero.get("color", UI.PRIMARY))
	var frame := _card(main, parent, rect, UI.SURFACE.lerp(accent, 0.14), Color.TRANSPARENT)
	var texture: Texture2D = HERO.portrait_texture(str(hero["id"])) if discovered else null
	if texture != null:
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(image, frame, Rect2(6, 4, rect.size.x - 12, rect.size.y - 8))
	else:
		var icon_name := "lock"
		if discovered:
			var role: String = main._hero_role_group(str(hero["id"]))
			icon_name = "shield" if role in ["탱커", "힐러", "서포터"] else "sword"
		_icon(frame, icon_name, (rect.size - Vector2(30, 30)) * 0.5, UI.MUTED if not discovered else UI.text_color(accent), 30)

static func meta(main) -> void:
	if str(main.get_meta("content_meta_tab", "")) == "quests":
		_legacy_long_term_goals(main)
		return
	main._clear_screen()
	main.active_screen = "meta_hub"
	main._reset_daily_dungeon_if_needed()
	main._reset_weekly_if_needed()
	main._auto_track_quest()
	main._add_screen_header("‹  로비", Callable(main, "_build_lobby_screen"), "원정대의 다음 도전", "매일 한 걸음씩, 더 강한 원정대로 성장하세요.", "도전 · 성장", UI.GOLD, "골드 %d  ·  젬 %d" % [main.wallet_gold, main.wallet_gems])
	var report: Dictionary = main.get_meta("last_challenge_report", {})
	if not report.is_empty() and str(report.get("entry", {}).get("faction", "")) == str(main.selected_faction):
		_button(main, main.content_root, ("최근 연습 분석" if report.get("practice", false) else "최근 실전 분석"), Rect2(1045, 144, 172, 34), Callable(main, "_open_challenge_report").bind(int(report["serial"]))).name = "ChallengeReportOpen"
	var canvas := _scroll(main, Rect2(55, 186, 1170, 444), 568)
	var daily := _card(main, canvas, Rect2(0, 0, 376, 242))
	_icon(daily, "sword", Vector2(22, 21), UI.PRIMARY)
	_pill(main, daily, "매일 3회", Rect2(266, 20, 88, 26))
	_text(main, daily, "일일 던전", Rect2(22, 60, 320, 34), 23)
	var daily_rules = preload("res://scripts/DailyDungeonBattleRules.gd")
	var daily_variant: String = str(main.get_meta("daily_dungeon_variant", "gold_rush"))
	if daily_variant not in daily_rules.VARIANTS:
		daily_variant = "gold_rush"
	var mode_picker := OptionButton.new()
	mode_picker.name = "LegacyDailyModePicker"
	mode_picker.position = Vector2(22, 98)
	mode_picker.size = Vector2(332, 30)
	for variant in daily_rules.VARIANTS:
		mode_picker.add_item(str(daily_rules.plan(variant)["title"]))
	mode_picker.select(daily_rules.VARIANTS.find(daily_variant))
	mode_picker.item_selected.connect(func(index: int):
		main.set_meta("daily_dungeon_variant", daily_rules.VARIANTS[index])
		main._build_meta_hub_screen())
	daily.add_child(mode_picker)
	_text(main, daily, "오늘 %d / 3회  ·  권장 전투력 %d" % [main.daily_dungeon_runs, 650 + main.daily_dungeon_runs * 250], Rect2(22, 134, 330, 25), 14, UI.PRIMARY)
	_progress(main, daily, Rect2(22, 170, 332, 5), main.daily_dungeon_runs, 3)
	var daily_btn := _button(main, daily, "전투 시작", Rect2(22, 190, 160, 40), func():
		main._run_daily_dungeon(daily_variant), true)
	daily_btn.disabled = main.daily_dungeon_runs >= 3 or main.deployed_heroes.is_empty()
	var sweep_context: Dictionary = main._daily_dungeon_entry_context()
	var sweep_reason: String = main._daily_sweep_error(daily_variant)
	var sweep_btn := _button(main, daily, "소탕 1회", Rect2(194, 190, 160, 40), func():
		main._sweep_daily_dungeon(daily_variant, sweep_context))
	sweep_btn.name = "LegacyDailySweepButton"
	sweep_btn.disabled = not sweep_reason.is_empty()
	sweep_btn.tooltip_text = sweep_reason if not sweep_reason.is_empty() else "전투와 동일 보상 · 하루 3회 한도 공유"
	var tower := _card(main, canvas, Rect2(388, 0, 376, 242))
	_icon(tower, "compass", Vector2(22, 21), UI.LAVENDER)
	_pill(main, tower, "최고 %d층" % main.tower_best_floor, Rect2(252, 20, 102, 26), UI.LAVENDER)
	_text(main, tower, "무한탑", Rect2(22, 60, 320, 34), 23)
	_text(main, tower, "더 높은 곳에서 기다리는 새로운 기록", Rect2(22, 99, 330, 25), 14, UI.MUTED)
	_text(main, tower, "%d층 도전" % main.tower_floor, Rect2(22, 134, 144, 34), 24, UI.LAVENDER)
	_text(main, tower, "권장 %d" % (500 + main.tower_floor * 180), Rect2(182, 137, 172, 28), 14, UI.MUTED)
	var tower_context: Dictionary = main._tower_entry_context()
	var tower_error: String = main._tower_entry_error()
	var tower_button := _button(main, tower, "전투 시작 · 90초", Rect2(22, 190, 332, 40), func():
		main._challenge_tower(tower_context), true, UI.LAVENDER)
	tower_button.name = "LegacyTowerEnterButton"
	tower_button.disabled = not tower_error.is_empty()
	tower_button.tooltip_text = tower_error if not tower_error.is_empty() else str(preload("res://scripts/TowerBattleRules.gd").plan(int(main.tower_floor)).get("description", ""))
	var growth := _card(main, canvas, Rect2(776, 0, 374, 242), Color("#f3eedf"))
	_icon(growth, "growth", Vector2(22, 21), UI.GOLD)
	_text(main, growth, "성장의 시간", Rect2(22, 60, 326, 34), 23)
	_text(main, growth, "스킬과 동료, 장비를 다듬어 보세요.", Rect2(22, 99, 326, 25), 14, UI.MUTED)
	_button(main, growth, "스킬트리 · 동료", Rect2(22, 146, 330, 38), Callable(main, "_build_growth_screen"))
	_button(main, growth, "장비 관리", Rect2(22, 192, 330, 38), Callable(main, "_build_inventory_screen"))
	var weekly := _card(main, canvas, Rect2(0, 256, 1150, 104), Color("#eeebf2"))
	_icon(weekly, "moon", Vector2(23, 34), UI.LAVENDER, 32)
	_text(main, weekly, "주간 심연 원정", Rect2(76, 19, 440, 31), 21)
	_text(main, weekly, "90초 실전 · 이번 주 %d / 5회 · 최고 피해 %d" % [main.weekly_trial_runs, main.weekly_trial_best], Rect2(76, 57, 650, 25), 14, UI.MUTED)
	var weekly_context: Dictionary = main._weekly_entry_context()
	var weekly_error: String = main._weekly_entry_error()
	var weekly_btn := _button(main, weekly, "전투 시작 · 90초", Rect2(905, 30, 221, 44), func():
		main._run_weekly_trial(weekly_context), true, UI.LAVENDER)
	weekly_btn.name = "LegacyWeeklyEnterButton"
	weekly_btn.disabled = not weekly_error.is_empty()
	weekly_btn.tooltip_text = weekly_error if not weekly_error.is_empty() else str(preload("res://scripts/WeeklyAbyssBattleRules.gd").plan(str(main._week_key())).get("description", ""))
	_button(main, weekly, "레이드 3종", Rect2(704, 30, 188, 44), Callable(main, "_build_boss_select_screen"), true, UI.GOLD)
	_text(main, canvas, "여정의 기록", Rect2(0, 378, 740, 29), 21)
	_text(main, canvas, "달성한 목표의 보상을 받아보세요.", Rect2(720, 379, 420, 27), 13, UI.MUTED)
	var raid_count := 0
	for count in main.raid_clears.values():
		raid_count += int(count)
	var quests := [["stage5", "스테이지 5 도달", main.idle_stage >= 5, "500 골드 · 20 젬"], ["raid1", "레이드 첫 승리", raid_count >= 1, "800 골드 · 30 젬"], ["tower5", "무한탑 5층 돌파", main.tower_best_floor >= 5, "1,000 골드 · 40 젬"]]
	for index in quests.size():
		var quest: Array = quests[index]
		var card := _card(main, canvas, Rect2(index * 388, 420, 374, 144))
		_text(main, card, str(quest[1]), Rect2(18, 15, 338, 26), 16)
		_text(main, card, str(quest[3]), Rect2(18, 45, 338, 24), 13, UI.GOLD)
		var claimed := bool(main.quest_claimed.get(quest[0], false))
		var button := _button(main, card, "수령 완료" if claimed else ("보상 받기" if quest[2] else "진행 중"), Rect2(18, 87, 338, 38), func():
			if main._claim_quest(str(quest[0])):
				main._build_meta_hub_screen())
		button.disabled = claimed or not quest[2]
	main._add_bottom_nav("growth")

static func summon(main) -> void:
	main._clear_screen()
	main.active_screen = "summon"
	main._add_screen_header("‹  로비", Callable(main, "_build_lobby_screen"), "별빛의 소환", "영웅의 조각을 모아 잠재된 힘을 깨우세요.", "영웅 조각", UI.GOLD, "보유 젬 %d" % main.wallet_gems)
	var banner := _card(main, main.content_root, Rect2(55, 188, 440, 430), Color("#eee9da"))
	_icon(banner, "summon", Vector2(175, 36), UI.GOLD, 90)
	_pill(main, banner, "영웅 조각 소환", Rect2(140, 145, 160, 28), UI.GOLD)
	_text(main, banner, "새로운 인연의 빛", Rect2(38, 187, 364, 38), 28).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text(main, banner, "1회 소환 시 영웅 조각 12개\n10번째 소환은 조각 30개 보장", Rect2(38, 232, 364, 52), 16, UI.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress(main, banner, Rect2(40, 304, 360, 8), main.summon_pity, 10, UI.GOLD)
	_text(main, banner, "보장 소환까지 %d회" % maxi(1, 10 - main.summon_pity), Rect2(40, 318, 360, 24), 13, UI.GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var summon_btn := _button(main, banner, "소환하기  ·  100 젬", Rect2(40, 365, 360, 46), func():
		var result: Dictionary = main._summon_once()
		if not result.is_empty():
			main._build_summon_screen()
			main._show_summon_reveal(result), true, UI.GOLD)
	summon_btn.disabled = main.wallet_gems < 100
	if summon_btn.disabled:
		summon_btn.tooltip_text = "소환하려면 젬 100개가 필요합니다."
	_text(main, main.content_root, "영웅 돌파", Rect2(519, 188, 380, 32), 23)
	_text(main, main.content_root, "조각으로 최대 5단계까지 성장", Rect2(519, 224, 468, 25), 14, UI.MUTED)
	_button(main, main.content_root, "영웅 도감", Rect2(1083, 191, 142, 40), Callable(main, "_build_codex_screen"))
	var roster: Array = main._hero_roster_for_faction()
	var content := _scroll(main, Rect2(519, 266, 706, 352), roster.size() * 84)
	for index in roster.size():
		var hero: Dictionary = roster[index]
		var hero_id := str(hero["id"])
		var rank: int = main._hero_breakthrough_rank(hero_id)
		var count: int = main._hero_shard_count(hero_id)
		var cost: int = main._breakthrough_cost(rank)
		var row := _card(main, content, Rect2(0, index * 84, 680, 74))
		_portrait(main, row, hero, Rect2(11, 10, 54, 54))
		_text(main, row, str(hero["name"]), Rect2(80, 12, 310, 25), 16)
		_text(main, row, "돌파 %d / 5  ·  보유 조각 %d" % [rank, count], Rect2(80, 41, 360, 21), 13, UI.MUTED)
		var button := _button(main, row, "돌파 완료" if rank >= 5 else "돌파 · %d조각" % cost, Rect2(476, 15, 188, 44), func():
			if main._try_breakthrough(hero_id):
				main._build_summon_screen())
		button.disabled = rank >= 5 or count < cost
	main._add_bottom_nav("summon")

static func bm(main) -> void:
	main._clear_screen()
	main.active_screen = "rewards"
	main._add_screen_header("‹  로비", Callable(main, "_build_lobby_screen"), "원정대를 위한 선물", "오늘의 작은 선물을 챙기고 모험을 이어가세요.", "보상 센터", UI.GOLD, "골드 %d  ·  젬 %d" % [main.wallet_gold, main.wallet_gems])
	var daily := _card(main, main.content_root, Rect2(55, 190, 378, 361))
	_icon(daily, "mail", Vector2(27, 27), UI.GOLD, 36)
	_pill(main, daily, "매일 1회", Rect2(248, 31, 104, 26), UI.GOLD)
	_text(main, daily, "매일의 선물", Rect2(27, 85, 324, 36), 25)
	_text(main, daily, "젬 30", Rect2(27, 145, 320, 44), 31, UI.GOLD)
	_text(main, daily, "골드 100 함께 지급", Rect2(27, 194, 324, 25), 16, UI.MUTED)
	var daily_status := _text(main, daily, "접속 보상을 받아보세요.", Rect2(27, 242, 324, 39), 14, UI.MUTED)
	var claim: Button
	claim = _button(main, daily, "오늘의 선물 받기", Rect2(27, 300, 324, 44), func():
		main._claim_daily_reward(daily.get_node("DailyClaim"), daily_status)
		main._build_bm_screen(), true, UI.GOLD)
	claim.name = "DailyClaim"
	if main._today_key() <= main.daily_reward_claimed_day:
		claim.text = "오늘의 선물 수령 완료"
		claim.disabled = true
		daily_status.text = "내일 새로운 선물이 기다려요."
	var support := _card(main, main.content_root, Rect2(449, 190, 378, 361))
	_icon(support, "leaf", Vector2(27, 27), UI.PRIMARY, 36)
	var support_count: int = main.rewarded_ad_claimed_count if main._today_key() <= main.rewarded_ad_day else 0
	_pill(main, support, "%d / 3회" % support_count, Rect2(248, 31, 104, 26))
	_text(main, support, "원정 지원 보상", Rect2(27, 85, 324, 36), 25)
	_text(main, support, "젬 5", Rect2(27, 145, 320, 44), 31, UI.PRIMARY)
	_text(main, support, "골드 50 함께 지급", Rect2(27, 194, 324, 25), 16, UI.MUTED)
	var support_status := _text(main, support, "하루 3회, 무료로 받을 수 있어요.", Rect2(27, 242, 324, 39), 14, UI.MUTED)
	var support_btn: Button
	support_btn = _button(main, support, "지원 보상 받기", Rect2(27, 300, 324, 44), func():
		main._claim_rewarded_ad(support.get_node("SupportClaim"), support_status)
		main._build_bm_screen(), true)
	support_btn.name = "SupportClaim"
	support_btn.disabled = support_count >= 3
	if support_btn.disabled:
		support_btn.text = "오늘의 지원 수령 완료"
	var shop := _card(main, main.content_root, Rect2(843, 190, 382, 361), Color("#eeebf2"))
	_icon(shop, "bag", Vector2(27, 27), UI.LAVENDER, 36)
	_pill(main, shop, "준비 중", Rect2(252, 31, 104, 26), UI.LAVENDER)
	_text(main, shop, "원정대 상점", Rect2(27, 85, 328, 36), 25)
	_text(main, shop, "모험을 꾸미는 즐거움", Rect2(27, 150, 328, 29), 19, UI.LAVENDER)
	_text(main, shop, "외형 스킨과 원정대 패스를\n준비하고 있어요.", Rect2(27, 193, 328, 52), 16, UI.MUTED)
	_button(main, shop, "상점 오픈 예정", Rect2(27, 300, 328, 44), func(): pass).disabled = true
	var note := _card(main, main.content_root, Rect2(55, 568, 1170, 50), UI.SOFT)
	_icon(note, "check", Vector2(17, 14), UI.PRIMARY, 22)
	_text(main, note, "모든 사냥터와 진영 콘텐츠는 무료로 즐길 수 있어요.  ·  보상 골드는 사냥 누적 보상에 합산됩니다.", Rect2(53, 8, 1098, 34), 14, UI.MUTED)
	main._add_bottom_nav("rewards")

static func world(main) -> void:
	main._clear_screen()
	main.active_screen = "world_map"
	var zone: Dictionary = main._current_zone()
	main._add_screen_header("‹  로비", Callable(main, "_build_lobby_screen"), "모험이 펼쳐지는 대륙", "원정대를 보내 새로운 사냥터를 만나보세요.", "월드맵", UI.PRIMARY, "스테이지 %d  ·  전투력 %d" % [main.idle_stage, main._calculate_party_power()])
	var count := 0
	for zone_id in ZONES:
		if main._is_zone_unlocked(zone_id):
			count += 1
	var metrics: Array = [main._create_metric_card("탐험한 지역", "%d / 3" % count, "스테이지 진행으로 새로운 지역 해금", UI.PRIMARY, Vector2(0, 74)), main._create_metric_card("현재 사냥터", str(zone["name"]), "난이도 %d" % int(zone["difficulty"]), UI.GOLD, Vector2(0, 74)), main._create_metric_card("원정대", "%d명 편성" % main.deployed_heroes.size(), main._party_composition_summary(), UI.BLUE, Vector2(0, 74))]
	main._add_status_dashboard(Vector2(55, 185), metrics, 3, Vector2(1170, 78))
	for index in ZONES.size():
		var zone_id: String = ZONES[index]
		var info: Dictionary = main._zone_data()[zone_id]
		var unlocked: bool = main._is_zone_unlocked(zone_id)
		var selected: bool = main.current_zone_id == zone_id
		var accent: Color = UI.text_color(info["color"])
		var card := _card(main, main.content_root, Rect2(55 + index * 394, 280, 382, 338), UI.SURFACE, UI.PRIMARY if selected else UI.BORDER)
		var scene := Control.new()
		scene.clip_contents = true
		_place(scene, card, Rect2(12, 12, 358, 99))
		var landscape := TextureRect.new()
		landscape.texture = preload("res://scripts/FieldArtCatalog.gd").texture_for(zone_id)
		landscape.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		landscape.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		landscape.modulate = Color(0.92, 0.94, 0.92) if unlocked else Color(0.55, 0.58, 0.60)
		_place(landscape, scene, Rect2(0, 0, 358, 99))
		_pill(main, scene, "현재 사냥터" if selected else ("해금 완료" if unlocked else "스테이지 %d" % info["unlock_stage"]), Rect2(10, 11, 105, 25), UI.PRIMARY if unlocked else UI.MUTED)
		_text(main, card, str(info["name"]), Rect2(23, 124, 330, 30), 23)
		_text(main, card, str(info["description"]), Rect2(23, 164, 336, 43), 14, UI.MUTED)
		_text(main, card, "권장 전투력 %d  ·  %s 세트" % [info["power"], info["equipment_set"]], Rect2(23, 214, 336, 23), 13, accent)
		var hunt := _button(main, card, "사냥 시작" if unlocked else "아직 닿지 않은 곳", Rect2(23, 255, 336, 44), Callable(main, "_select_zone_for_hunt").bind(zone_id), true)
		hunt.disabled = not unlocked
	main._add_bottom_nav("world")

static func bosses(main) -> void:
	main._clear_screen()
	main.active_screen = "boss_select"
	main._add_screen_header("‹  콘텐츠", Callable(main, "_build_meta_hub_screen"), "세 개의 레이드", "공격의 전조를 읽고 원정대의 힘으로 보스를 쓰러뜨리세요.", "레이드", UI.LAVENDER, "원정대 전투력 %d" % main._calculate_party_power())
	for index in ZONES.size():
		var zone_id: String = ZONES[index]
		var zone: Dictionary = main._zone_data()[zone_id]
		var unlocked: bool = main._is_zone_unlocked(zone_id)
		var accent: Color = UI.text_color(zone["color"])
		var card := _card(main, main.content_root, Rect2(55, 185 + index * 149, 1170, 138))
		var art := TextureRect.new()
		art.texture = main._boss_texture(str(zone['boss']))
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_place(art, card, Rect2(12, 9, 140, 118))
		_text(main, card, str(zone["boss_title"]), Rect2(177, 17, 548, 22), 12, accent)
		_text(main, card, str(zone["boss"]), Rect2(177, 43, 548, 32), 24)
		_text(main, card, "%s  ·  고유기 %s" % [zone["name"], zone["boss_skill"]], Rect2(177, 85, 548, 29), 14, UI.MUTED)
		_text(main, card, "권장 전투력", Rect2(748, 26, 196, 24), 12, UI.MUTED)
		_text(main, card, "%d" % int(preload("res://scripts/RaidBalance.gd").stats(zone).recommended_power), Rect2(748, 51, 196, 30), 24, accent)
		_text(main, card, "토벌 %d회" % main.raid_clears.get(zone_id, 0), Rect2(748, 90, 196, 24), 13, UI.MUTED)
		var button := _button(main, card, "도전하기" if unlocked else "스테이지 %d 해금" % zone["unlock_stage"], Rect2(954, 46, 192, 46), Callable(main, "_select_zone_for_raid").bind(zone_id), true, UI.LAVENDER)
		button.disabled = not unlocked
	main._add_bottom_nav("growth")

static func codex(main) -> void:
	main._clear_screen()
	main.active_screen = "codex"
	var roster: Array = main._hero_roster_for_faction()
	var found := 0
	for hero in roster:
		if bool(main.codex_seen.get(str(hero["id"]), false)) or main.idle_stage >= int(hero.get("unlock_stage", 1)):
			found += 1
	main._add_screen_header("‹  소환", Callable(main, "_build_summon_screen"), "우리의 영웅 이야기", "다양한 종족과 고유한 능력, 함께할 영웅을 살펴보세요.", main._faction_name(), UI.GOLD, "발견 %d / %d" % [found, roster.size()])
	var canvas := _scroll(main, Rect2(55, 186, 1170, 444), ceilf(roster.size() / 4.0) * 207)
	for index in roster.size():
		var hero: Dictionary = roster[index]
		var hero_id := str(hero["id"])
		var discovered: bool = bool(main.codex_seen.get(hero_id, false)) or main.idle_stage >= int(hero.get("unlock_stage", 1))
		var card := _card(main, canvas, Rect2((index % 4) * 289, (index / 4) * 207, 277, 195))
		_portrait(main, card, hero, Rect2(16, 16, 66, 66), discovered)
		_text(main, card, str(hero["name"]) if discovered else "미발견 영웅", Rect2(96, 18, 166, 29), 17)
		_text(main, card, str(hero["race"]) if discovered else "발견을 기다리는 중", Rect2(96, 49, 166, 24), 12, UI.MUTED)
		var progress: Dictionary = main._get_hero_progress(hero_id)
		_text(main, card, "%s  ·  Lv.%d  ·  %d돌파" % [main._hero_grade(hero_id), progress["level"], main._hero_breakthrough_rank(hero_id)] if discovered else "스테이지 %d에서 만날 수 있어요." % hero.get("unlock_stage", 1), Rect2(16, 98, 245, 30), 12, UI.GOLD if discovered else UI.MUTED)
		var button := _button(main, card, "영웅 이야기" if discovered else "아직 만나지 못했어요", Rect2(16, 142, 245, 37), Callable(main, "_build_hero_detail_screen").bind(hero_id))
		button.disabled = not discovered
	main._add_bottom_nav("heroes")


static func _legacy_long_term_goals(main: Node) -> void:
	main._clear_screen()
	main.active_screen = "meta_hub"
	main._add_screen_header("‹  로비", Callable(main, "_build_lobby_screen"), "장기 목표", "가이드 · 일일/주간 · 업적 · 칭호", "목표", UI.GOLD, "골드 %d · 젬 %d" % [main.wallet_gold, main.wallet_gems])
	var scroll: ScrollContainer = ScrollContainer.new()
	_place(scroll, main.content_root, Rect2(55, 186, 1170, 434))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	preload("res://scripts/LongTermGoalScreens.gd").build(main, box, load("res://scripts/portrait/PortraitPages.gd"))
	main._add_bottom_nav("growth")
