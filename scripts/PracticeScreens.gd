extends RefCounted
const P = preload("res://scripts/portrait/PortraitPages.gd")
const S = preload("res://scripts/portrait/PortraitSkin.gd")
const PRESETS = preload("res://scripts/CombatPresetService.gd")
const PRACTICE = preload("res://scripts/PracticeBattleService.gd")

static func build(main: Node) -> void:
	var page := P.begin(main, "practice", "전투 연습실", "실전과 같은 적 · 보상과 진행 기록은 변경하지 않습니다", "content")
	P.text(page, "원정 횟수를 모두 사용해도 연습할 수 있어요. 레벨만 맞추거나 현재 성장 상태로 비교하세요. 임시 레벨은 실제 레벨·경험치·연구에 저장되지 않습니다.", 18, S.MUTED)
	var level_box := P.card(page, "연습 레벨 설정", S.BLUE)
	var mode_select := OptionButton.new(); mode_select.name = "PracticeLevelMode"; mode_select.custom_minimum_size.y = 54
	mode_select.add_item("현재 성장 상태로 연습"); mode_select.add_item("레벨만 맞춰서 연습")
	level_box.add_child(mode_select)
	var level := SpinBox.new(); level.name = "PracticeMatchLevel"; level.min_value = 1
	level.max_value = preload("res://scripts/PracticeLevelRules.gd").ceiling(main); level.step = 1; level.value = level.max_value
	level.custom_minimum_size.y = 54; level.editable = false; level_box.add_child(level)
	mode_select.item_selected.connect(func(index: int): level.editable = index == 1)
	P.text(level_box, "레벨 범위 1~%d · 현재 진영의 합류 영웅 중 최고 레벨까지만 가능. 장비·연구·돌파·수호신은 그대로이므로 모든 조건이 같아지는 모드는 아닙니다." % int(level.max_value), 16, S.MUTED)
	var nav := P.grid(page, 2)
	P.action(nav, "통합 프리셋", Callable(main, "_open_combat_presets")).name = "PracticePresets"
	P.action(nav, "원정대 편성", Callable(main, "_build_hero_select_screen"))
	P.action(nav, "도전 목록", Callable(main, "_build_meta_hub_screen"))
	var previous: Dictionary = main.get_meta("last_challenge_report", {})
	if bool(previous.get("practice", false)) and str(previous.get("entry", {}).get("faction", "")) == str(main.selected_faction):
		P.action(nav, "최근 연습 분석", Callable(main, "_open_challenge_report").bind(int(previous["serial"])), true).name = "PracticeReportOpen"
	P.text(page, "현재 편성 %d명 · %.0f배속 · 자동 스킬 %s · 자동 궁극기 %s" % [main.deployed_heroes.size(), main.battle_speed, "켬" if main.skill_auto else "끔", "켬" if main.ultimate_auto else "끔"], 17, S.BLUE_SOFT)
	var expected: Dictionary = PRACTICE.context(main)
	var daily := P.card(page, "일일 던전 연습", S.BLUE)
	var tier := OptionButton.new(); tier.name = "PracticeDailyTier"; tier.custom_minimum_size.y = 52
	for i in 3: tier.add_item("%d단계" % (i + 1))
	daily.add_child(tier)
	for pair: Array in [["gold_rush", "골드 러시 · 60초"], ["survival", "생존전 · 60초"], ["boss_hunt", "보스 토벌 · 60초"]]:
		var variant: String = pair[0]
		var button := P.action(daily, pair[1] + " 연습", func(): main._start_practice("daily", tier.selected + 1, variant, expected, "matched" if mode_select.selected == 1 else "actual", int(level.value)))
		button.name = "PracticeStart_" + variant; button.disabled = main.deployed_heroes.is_empty()
	var tower := P.card(page, "무한탑 연습", S.GOLD)
	var floor := SpinBox.new(); floor.name = "PracticeTowerFloor"
	floor.min_value = 1; floor.max_value = mini(9999, maxi(1, int(main.tower_floor))); floor.step = 1
	floor.value = floor.max_value; floor.custom_minimum_size.y = 52; tower.add_child(floor)
	P.text(tower, "이미 도달한 층과 현재 도전 층을 반복해 비교합니다. 층 상승·보상은 없습니다.", 16, S.MUTED)
	var tower_hint: Label = P.text(tower, str(preload("res://scripts/TowerBattleRules.gd").plan(int(floor.value)).get("description", "")), 16, S.MUTED)
	tower_hint.name = "PracticeTowerPattern"
	floor.value_changed.connect(func(value: float): tower_hint.text = str(preload("res://scripts/TowerBattleRules.gd").plan(int(value)).get("description", "")))
	var tower_button := P.action(tower, "선택 층 연습", func(): main._start_practice("tower", int(floor.value), "", expected, "matched" if mode_select.selected == 1 else "actual", int(level.value)))
	tower_button.name = "PracticeStart_tower"; tower_button.disabled = main.deployed_heroes.is_empty()
	var weekly := P.card(page, "주간 심연 연습", S.BLUE)
	P.text(weekly, "이번 주 변칙 그대로 · 90게임초 · 연습 피해는 최고점/주간 기록에 합산하지 않습니다.", 17, S.MUTED)
	P.text(weekly, str(preload("res://scripts/WeeklyAbyssBattleRules.gd").plan(str(main._week_key())).get("description", "")), 16, S.MUTED).name = "PracticeWeeklyPattern"
	var weekly_button := P.action(weekly, "90초 심연 연습", func(): main._start_practice("weekly", 1, "", expected, "matched" if mode_select.selected == 1 else "actual", int(level.value)))
	weekly_button.name = "PracticeStart_weekly"; weekly_button.disabled = main.deployed_heroes.is_empty()
	P.text(page, "같은 레벨 모드·맞춤 레벨의 연습 분석끼리만 비교합니다. 같은 적/난이도라도 편성·장비·배속·스킬 설정 차이가 결과에 포함되며 완전 동일 난수 실험은 아닙니다.", 16, S.MUTED)

static func presets(main: Node) -> void:
	var page := P.begin(main, "combat_presets", "통합 전투 프리셋", "진영별 P1~P3 · 장비는 ID로 참조 · 재화 소비 없음", "heroes")
	P.action(page, "연습실로", Callable(main, "_open_practice_screen"))
	P.action(page, "편성으로", Callable(main, "_build_hero_select_screen"))
	for i in 3:
		var index: int = i
		var saved: Dictionary = PRESETS.get_preset(main, index)
		var box := P.card(page, "P%d" % (i + 1), S.BLUE)
		P.text(box, "통합 기록 없음 · 예전 명단 프리셋은 편성 화면에서 유지됩니다." if saved.is_empty() else "%d명 · 수호신 %s · 자동 스킬 %s / 궁극기 %s" % [saved["heroes"].size(), str(main.GUARDIANS.profile(saved["guardian"]).get("name", "미지정")), "켬" if saved["skill_auto"] else "끔", "켬" if saved["ultimate_auto"] else "끔"], 17)
		var row := P.grid(box, 2)
		P.action(row, "적용 전 확인", Callable(main, "_preview_party_preset").bind(index)).name = "PresetPreview%d" % i
		P.action(row, "현재 설정 저장", func():
			main._save_party_preset(index)
			main._open_combat_presets()).name = "PresetSave%d" % i
	P.text(page, "프리셋은 레벨·연구·강화 수치·아이템을 복사하거나 되돌리지 않습니다. 저장했던 장비가 강화됐다면 현재 강화 상태로 적용합니다. 다른 영웅의 장비를 자동으로 빼앗거나 없는 장비를 새로 만들지 않습니다.", 17, S.MUTED)

static func preview(main: Node, index: int) -> void:
	var page := P.begin(main, "preset_preview", "P%d 적용 확인" % (index + 1), "확인하기 전에는 장비·설정을 변경하지 않습니다", "heroes")
	P.action(page, "프리셋 목록", Callable(main, "_open_combat_presets"))
	var view_id: int = main.content_root.get_instance_id()
	var result: Dictionary = PRESETS.plan(main, index)
	var saved: Dictionary = PRESETS.get_preset(main, index)
	if saved.is_empty():
		P.text(page, "새 통합 기록이 없습니다. 기존 P1~P3 명단만 적용하거나 현재 설정을 새로 저장할 수 있습니다.", 18, S.MUTED)
		var token: String = PRESETS.fingerprint(main, index)
		P.action(page, "기존 명단만 적용", func():
			if not is_instance_valid(main.content_root) or view_id != main.content_root.get_instance_id() or token != PRESETS.fingerprint(main, index): return
			main._apply_party_preset(index)
			main._build_hero_select_screen()).name = "LegacyPresetApply"
		return
	var names: PackedStringArray = []
	for id: String in saved["heroes"]: names.append(str(PRESETS.MODEL.HEROES.HEROES[id].get("name", id)))
	P.text(page, "저장된 편성: " + " / ".join(names), 18)
	P.text(page, "수호신: %s → %s\n자동 스킬: %s → %s · 궁극기: %s → %s" % [str(main.GUARDIANS.profile(main.guardian_equipped).get("name", "미지정")), str(main.GUARDIANS.profile(saved["guardian"]).get("name", "미지정")), "켬" if main.skill_auto else "끔", "켬" if saved["skill_auto"] else "끔", "켬" if main.ultimate_auto else "끔", "켬" if saved["ultimate_auto"] else "끔"], 18)
	P.text(page, str(result.get("reason", "")), 19, S.GOLD)
	if not bool(result.get("ok", false)): return
	P.text(page, "장비 이동 %d개 · 적용 후 가방 %d칸 · 비용 0" % [result["moved"], result["inventory"].size()], 18)
	var token: String = str(result["token"])
	P.action(page, "확인 · 전체 적용", func():
		if not is_instance_valid(main.content_root) or view_id != main.content_root.get_instance_id(): return
		var applied: Dictionary = PRESETS.apply(main, index, token)
		main._show_toast(str(applied.get("reason", "")))
		main._open_combat_presets(), true).name = "ConfirmCombatPreset"
