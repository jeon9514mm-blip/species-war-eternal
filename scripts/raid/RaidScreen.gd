extends RefCounted
class_name RaidScreen

const UI := preload("res://scripts/ui/GameUiTheme.gd")
const BALANCE := preload("res://scripts/raid/RaidBalance.gd")
const BOSS_FEET := Vector2(535, 365)

static func _label(parent: Control, text: String, rect: Rect2, font_size: int = 16, color: Color = UI.INK, lines: int = 0) -> Label:
	var result := UI.label(text, font_size, color)
	result.position = rect.position
	result.size = rect.size
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if lines > 0:
		result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result.max_lines_visible = lines
		result.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(result)
	return result

static func _panel(parent: Control, node_name: String, rect: Rect2, color: Color = UI.SURFACE) -> Panel:
	var result := Panel.new()
	result.name = node_name
	result.position = rect.position
	result.size = rect.size
	result.add_theme_stylebox_override("panel", UI.panel(color, UI.BORDER, 18))
	parent.add_child(result)
	return result

static func build(main) -> void:
	# Keep encounter initialization in the same order as the original screen.
	main._clear_screen()
	main.active_screen = "raid"
	main.raid_running = false
	main._reset_raid_encounter()
	main.combat_labels.clear()
	var zone: Dictionary = main._raid_zone()
	var raid_stats: Dictionary = BALANCE.stats(zone)
	main.party_power = main._calculate_party_power()
	main._setup_hero_skills()
	var boss_clears := int(main.raid_clears.get(main.raid_encounter_zone, 0))
	var root: Control = main.content_root

	var back := UI.button("콘텐츠", Vector2(112, 42))
	back.name = "RaidBackButton"
	back.position = Vector2(32, 24)
	back.pressed.connect(main._build_boss_select_screen)
	root.add_child(back)
	_label(root, "콘텐츠  /  레이드", Rect2(162, 24, 470, 42), 15, UI.MUTED)
	var speed := UI.button("속도 ×%d" % int(main.battle_speed), Vector2(116, 42))
	speed.name = "RaidSpeedButton"
	speed.position = Vector2(1132, 24)
	speed.pressed.connect(main._cycle_battle_speed.bind(speed))
	root.add_child(speed)
	var report_button := UI.button("레이드 분석", Vector2(155, 42))
	report_button.name = "RaidContributionOpen"
	report_button.position = Vector2(950, 24)
	report_button.pressed.connect(main._open_raid_report)
	root.add_child(report_button)
	main.combat_labels["raid_report"] = report_button
	_label(root, str(zone["boss"]), Rect2(32, 88, 700, 43), 32)
	_label(root, "%s · %s" % [zone["name"], zone["boss_title"]], Rect2(34, 132, 930, 23), 14, UI.MUTED)
	var party_summary := _label(root, "원정대 %d명  ·  전투력 %s" % [main.deployed_heroes.size(), str(main.party_power)], Rect2(870, 98, 378, 36), 16, UI.PRIMARY)
	party_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_panel(root, "RaidBossPanel", Rect2(32, 170, 724, 352))
	_panel(root, "RaidStatusPanel", Rect2(778, 170, 470, 352))
	var boss_mark := UI.icon("sword", Vector2(22, 22), UI.GOLD)
	boss_mark.position = Vector2(58, 191)
	root.add_child(boss_mark)
	_label(root, "도전 정보", Rect2(90, 184, 260, 36), 21)
	var record := _label(root, "고유 스킬 · %s\n권장 전투력 · %d\n레이드 클리어 · %d회" % [zone["boss_skill"], raid_stats["recommended_power"], boss_clears], Rect2(58, 234, 332, 78), 15, UI.MUTED, 3)
	main.combat_labels["raid_record"] = record
	_label(root, "공략 메모", Rect2(58, 323, 300, 24), 13, UI.GOLD)
	var pattern: Dictionary = main._boss_pattern_profile(main.raid_encounter_zone)
	_label(root, str(pattern.get("counter", "예고 시 방어·제어 스킬 대응")), Rect2(58, 350, 322, 47), 14, UI.INK, 2)
	_label(root, "체력 60%·30%에 단계 전환\n180초 광폭화 · 240초 제한", Rect2(58, 399, 330, 38), 12, UI.MUTED, 2)

	# The portrait has a dedicated stage, separate from all battle text. Its feet
	# retain the existing FX coordinate so combat particles still land correctly.
	var stage := _panel(root, "RaidBossStage", Rect2(406, 191, 324, 238), UI.SOFT)
	stage.add_theme_stylebox_override("panel", UI.panel(UI.SOFT, Color.TRANSPARENT, 18, 0))
	var crest := UI.icon("shield", Vector2(174, 174), Color(UI.PRIMARY, 0.045))
	crest.position = Vector2(479, 211)
	root.add_child(crest)
	var shadow := Panel.new()
	shadow.name = "RaidBossGround"
	shadow.position = BOSS_FEET - Vector2(71, 5)
	shadow.size = Vector2(142, 19)
	shadow.add_theme_stylebox_override("panel", UI.panel(Color(UI.PRIMARY, 0.11), Color.TRANSPARENT, 10, 0))
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shadow)
	main.raid_boss_sprite = MonsterSpriteFactory.create_monster(str(zone["boss"]), Vector2(0.105, 0.105))
	main.raid_boss_sprite.position = BOSS_FEET
	root.add_child(main.raid_boss_sprite)
	main._update_boss_portrait(str(zone["boss"]))
	var boss_caption := _label(root, "지역을 수호하는 강적", Rect2(414, 390, 308, 22), 12, UI.MUTED)
	boss_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var start := UI.button("레이드 시작", Vector2(672, 48), UI.PRIMARY)
	start.name = "RaidStartButton"
	start.position = Vector2(58, 453)
	start.pressed.connect(main._start_raid)
	start.disabled = main.deployed_heroes.is_empty()
	root.add_child(start)
	main.combat_labels["raid_start"] = start

	_label(root, "전투 현황", Rect2(804, 186, 416, 36), 21)
	var enemy := _label(root, "보스 HP · %d · 공격력 %d\n원정대 HP · 준비 완료\n원정대 전투력 · %d" % [raid_stats["max_hp"], raid_stats["attack"], main.party_power], Rect2(804, 232, 418, 91), 15, UI.INK, 4)
	main.combat_labels["raid_enemy"] = enemy
	_label(root, "토벌 진행", Rect2(804, 329, 416, 22), 12, UI.MUTED)
	var progress := ProgressBar.new()
	progress.name = "RaidProgress"
	progress.position = Vector2(804, 357)
	progress.size = Vector2(418, 9)
	progress.max_value = 100.0
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", UI.panel(Color("#e2e6da"), Color.TRANSPARENT, 4, 0))
	progress.add_theme_stylebox_override("fill", UI.panel(UI.PRIMARY, Color.TRANSPARENT, 4, 0))
	root.add_child(progress)
	main.combat_labels["raid_progress"] = progress
	var mechanic_label := _label(root, "", Rect2(804, 372, 418, 18), 11, UI.GOLD, 1)
	mechanic_label.visible = false
	main.combat_labels["raid_mechanic_label"] = mechanic_label
	var mechanic_progress := ProgressBar.new()
	mechanic_progress.name = "RaidMechanicProgress"
	mechanic_progress.position = Vector2(804, 392)
	mechanic_progress.size = Vector2(418, 7)
	mechanic_progress.max_value = 100.0
	mechanic_progress.show_percentage = false
	mechanic_progress.visible = false
	mechanic_progress.add_theme_stylebox_override("background", UI.panel(Color("#e2e6da"), Color.TRANSPARENT, 3, 0))
	mechanic_progress.add_theme_stylebox_override("fill", UI.panel(UI.GOLD, Color.TRANSPARENT, 3, 0))
	root.add_child(mechanic_progress)
	main.combat_labels["raid_mechanic_progress"] = mechanic_progress
	var status := _label(root, "준비가 끝났어요. 원정대와 도전해 보세요.", Rect2(804, 404, 418, 34), 13, UI.GREEN, 2)
	main.combat_labels["raid_status"] = status
	var reward_line := ColorRect.new()
	reward_line.position = Vector2(804, 448)
	reward_line.size = Vector2(418, 1)
	reward_line.color = UI.BORDER
	reward_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(reward_line)
	var rewards := _label(root, "클리어 · 골드 %d · 경험치 %d\n장비 추첨 2회 (미획득 가능) · 기믹 성공 시 레이드 정수 보너스" % [500 * int(zone["difficulty"]), 250 * int(zone["difficulty"])], Rect2(804, 458, 418, 44), 13, UI.GOLD, 2)
	main.combat_labels["raid_rewards"] = rewards

	_label(root, "출전 원정대", Rect2(34, 532, 300, 23), 14, UI.MUTED)
	var grid := GridContainer.new()
	grid.name = "RaidPartyGrid"
	grid.columns = 10
	grid.position = Vector2(32, 561)
	grid.size = Vector2(1216, 70)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 0)
	root.add_child(grid)
	for index in range(10):
		var card := Panel.new()
		card.name = "RaidPartyCard%d" % index
		card.custom_minimum_size = Vector2(114, 70)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", UI.panel(UI.SURFACE, UI.BORDER, 10))
		grid.add_child(card)
		if index >= main.deployed_heroes.size():
			var empty := UI.icon("plus", Vector2(20, 20), Color(UI.MUTED, 0.45))
			empty.position = Vector2(47, 12)
			card.add_child(empty)
			var empty_text := _label(card, "대기", Rect2(5, 37, 104, 21), 12, UI.MUTED)
			empty_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			continue
		var hero: Dictionary = main.deployed_heroes[index]
		var hero_id := str(hero["id"])
		card.tooltip_text = str(hero["name"])
		var portrait := TextureRect.new()
		portrait.position = Vector2(6, 11)
		portrait.size = Vector2(25, 32)
		portrait.texture = main._combat_portrait_texture(hero_id)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(portrait)
		if portrait.texture == null:
			var fallback := UI.icon("hero", Vector2(24, 24), UI.PRIMARY)
			fallback.position = Vector2(7, 15)
			card.add_child(fallback)
		var hero_name := _label(card, "%s · %s" % [main._hero_short_name(hero_id), str(main.hero_battle_state.get(hero_id, {}).get("role_group", ""))], Rect2(36, 6, 72, 44), 12, UI.INK, 2)
		main.combat_labels["raid_hero_%s" % hero_id] = hero_name
		var health := ProgressBar.new()
		health.position = Vector2(8, 56)
		health.size = Vector2(98, 7)
		health.show_percentage = false
		health.value = 100
		health.add_theme_stylebox_override("background", UI.panel(Color("#e2e6da"), Color.TRANSPARENT, 3, 0))
		health.add_theme_stylebox_override("fill", UI.panel(UI.GREEN, Color.TRANSPARENT, 3, 0))
		card.add_child(health)
		main.combat_labels["raid_hero_hp_%s" % hero_id] = health
	main._add_bottom_nav("world")
	var onboarding := root.get_node_or_null("OnboardingHint")
	if is_instance_valid(onboarding):
		onboarding.visible = false
