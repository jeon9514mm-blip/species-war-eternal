extends RefCounted
## Uses the existing page widgets; no new artwork, theme or bottom navigation.
const C = preload("res://scripts/LongTermGoalCatalog.gd")
const MODEL = preload("res://scripts/LongTermGoalState.gd")
const SERVICE = preload("res://scripts/LongTermGoalsService.gd")

static func build(main: Node, page: Node, ui: Script) -> void:
	SERVICE.refresh(main)
	var summary: VBoxContainer = ui.card(page, "장기 목표 · " + main._faction_name())
	summary.name = "LongTermGoalSummary"
	ui.text(summary, "가이드·업적·도감은 진영별 기록 / 일일·주간 미션은 계정 공통", 16)
	ui.text(summary, "일일: 한국시간 00:00 / 주간: 월요일 00:00 / 미수령 보상은 기간 종료 시 초기화", 15)
	if str(main.selected_faction) not in C.FACTIONS:
		ui.text(summary, "진영을 먼저 선택하면 장기 목표가 시작됩니다.", 18)
		return
	var bank: Dictionary = main.long_term_goals["factions"][str(main.selected_faction)]
	ui.text(summary, "가이드 %d/100 · 도감 %d/15 · 수령 가능 %d개" % [bank["guide_claimed"], bank["discovered"].size(), SERVICE.ready_count(main)], 18)
	ui.text(summary, "칭호: %s · 도감 업적 효과: 최대 HP +%.1f%%" % [SERVICE.title_text(main), MODEL.collection_tier(main.long_term_goals, str(main.selected_faction)) * 0.5], 16)
	ui.progress(summary, int(bank["guide_claimed"]), 100)
	if main.goals_save_pending:
		var notice: Label = ui.text(summary, "저장 대기: 보상은 메모리에 반영되어 있습니다. 앱을 종료하기 전에 다시 저장하세요.", 18)
		notice.name = "GoalPendingSaveNotice"
		var retry: Button = ui.action(summary, "보상 다시 저장", func():
			SERVICE.retry_save(main)
			main._open_goal_screen(), true)
		retry.name = "GoalRetrySave"
	var scope: String = str(main.get_meta("goal_scope", "guide"))
	if scope not in ["guide", "daily", "weekly", "achievement", "legacy"]: scope = "guide"
	var tabs: GridContainer = ui.grid(page, 3)
	for entry: Array in [["guide", "가이드"], ["daily", "일일 미션"], ["weekly", "주간 미션"], ["achievement", "업적·칭호"], ["legacy", "기존 목표"]]:
		var key: String = str(entry[0])
		var tab: Button = ui.action(tabs, str(entry[1]), func():
			main.set_meta("goal_scope", key)
			main._open_goal_screen(), key == scope)
		tab.name = "GoalTab_" + key
		tab.disabled = scope == key
	if scope == "legacy":
		_legacy(main, page, ui)
		return
	var expected: Dictionary = SERVICE.context(main, scope)
	if scope in ["daily", "weekly", "achievement"]:
		var all_button: Button = ui.action(page, "완료한 보상 모두 받기", func():
			main._claim_all_goals(scope, expected)
			main._open_goal_screen(), true)
		all_button.name = "GoalClaimAll_" + scope
		all_button.disabled = main.goals_save_pending or SERVICE.ready_count(main, scope) == 0
	if scope == "guide":
		ui.text(page, "현재 목표를 수령하면 다음 단계가 열립니다. 이미 달성한 성장 기록은 다시 진행할 필요가 없습니다.", 16)
		ui.text(page, "사냥·원정 완료 횟수는 이 업데이트 이후부터 집계합니다. 오프라인 추정 사냥은 미션 횟수에 포함하지 않습니다.", 15)
	var entries: Array[Dictionary] = SERVICE.rows(main, scope)
	for goal: Dictionary in entries:
		if scope == "guide" and (bool(goal["claimed"]) or int(goal["number"]) > int(bank["guide_claimed"]) + 3): continue
		_goal_card(main, page, ui, scope, goal, expected)
	if scope == "guide" and int(bank["guide_claimed"]) >= C.GUIDE_COUNT:
		ui.text(page, "가이드 100단계 완료! 일일·주간 목표와 업적을 이어서 확인하세요.", 20)
	if scope == "achievement":
		_titles(main, page, ui)

static func _goal_card(main: Node, page: Node, ui: Script, scope: String, goal: Dictionary, expected: Dictionary) -> void:
	var id: String = str(goal["id"])
	var box: VBoxContainer = ui.card(page, ("%03d · " % int(goal["number"]) if scope == "guide" else "") + str(goal["title"]))
	box.get_parent().name = "GoalCard_" + id
	var label: Label = ui.text(box, "%d / %d · 골드 %d · 젬 %d" % [goal["current"], goal["target"], goal["gold"], goal["gems"]], 17)
	label.name = "GoalProgress_" + id
	ui.progress(box, goal["current"], goal["target"])
	if id.begins_with("collection_"):
		ui.text(box, "수령 시 현재 진영 최대 HP +0.5% · 도감 효과 합계 최대 +1.5%", 16)
	if C.TITLES.has(id): ui.text(box, "수령 시 칭호 해금: " + str(C.TITLES[id]) + " (능력치 없음)", 16)
	var actions: GridContainer = ui.grid(box, 2)
	var caption: String = "수령 완료" if bool(goal["claimed"]) else ("보상 받기" if bool(goal["ready"]) else ("이전 목표 완료 필요" if not bool(goal["unlocked"]) else "진행 중"))
	var claim_button: Button = ui.action(actions, caption, func():
		main._claim_goal(scope, id, expected)
		main._open_goal_screen(), bool(goal["ready"]))
	claim_button.name = "GoalClaim_" + id
	claim_button.disabled = not bool(goal["ready"]) or main.goals_save_pending
	var route: String = str(goal["route"])
	var move: Button = ui.action(actions, "해당 콘텐츠로 이동", Callable(main, "_goal_route").bind(route))
	move.name = "GoalGo_" + id

static func _titles(main: Node, page: Node, ui: Script) -> void:
	var faction: String = str(main.selected_faction)
	var bank: Dictionary = main.long_term_goals["factions"][faction]
	var box: VBoxContainer = ui.card(page, "칭호 선택 · 능력치와 무관")
	box.name = "GoalTitleSelection"
	var clear: Button = ui.action(box, "칭호 해제", func():
		SERVICE.equip_title(main, "", faction)
		main._open_goal_screen())
	clear.name = "GoalTitleClear"
	for id: String in C.TITLES:
		var ready: bool = bool(bank["achievements"].get(id, false))
		var button: Button = ui.action(box, str(C.TITLES[id]) + (" · 선택 중" if str(bank["title"]) == id else ("" if ready else " · 업적 수령 필요")), func():
			SERVICE.equip_title(main, id, faction)
			main._open_goal_screen(), str(bank["title"]) == id)
		button.name = "GoalTitle_" + id
		button.disabled = not ready or main.goals_save_pending

static func _legacy(main: Node, page: Node, ui: Script) -> void:
	ui.text(page, "기존 목표 3개의 보상과 수령 기록은 그대로 유지됩니다.", 17)
	for entry: Array in [["stage5", 500, 20], ["raid1", 800, 30], ["tower5", 1000, 40]]:
		var id: String = str(entry[0])
		var status: Dictionary = main._quest_status(id)
		var claimed: bool = bool(main.quest_claimed.get(id, false))
		var box: VBoxContainer = ui.card(page, str(status["title"]))
		box.get_parent().name = "ContentQuest_" + id
		ui.text(box, "%d / %d · 골드 %d · 젬 %d" % [status["current"], status["target"], entry[1], entry[2]], 17)
		var button: Button = ui.action(box, "수령 완료" if claimed else "보상 받기", func():
			main._claim_quest(id)
			main._open_goal_screen(), bool(status["complete"]) and not claimed)
		button.name = "ContentQuestClaim_" + id
		button.disabled = claimed or not bool(status["complete"]) or main.goals_save_pending
