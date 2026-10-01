extends RefCounted
## Existing portrait components only; no images, theme replacement or auto-spend.
const P = preload("res://scripts/portrait/PortraitPages.gd")
const S = preload("res://scripts/portrait/PortraitSkin.gd")

static func build(main: Node, report: Dictionary) -> void:
	var serial: int = int(report["serial"])
	var page := P.begin(main, "challenge_report", "도전 전투 분석", str(report.get("title", "")), "content")
	var controls := P.grid(page, 2)
	P.action(controls, "도전 목록", Callable(main, "_challenge_report_action").bind("back", serial)).name = "ChallengeReportBack"
	P.action(controls, "편성 점검", Callable(main, "_challenge_report_action").bind("formation", serial), true).name = "ChallengeReportFormation"
	var practice: bool = bool(report.get("practice", false))
	if practice:
		P.text(page, "연습 기록 · 보상·횟수·미션·최고점 미반영", 20, S.GOLD)
		var entry: Dictionary = report.get("entry", {})
		P.text(page, "레벨만 맞춤 Lv.%d · 장비·연구·돌파는 실제 상태" % int(entry.get("match_level", 1)) if str(entry.get("level_mode", "actual")) == "matched" else "현재 성장 상태로 연습", 17, S.BLUE_SOFT).name = "ReportPracticeLevel"
		P.action(controls, "연습실로", Callable(main, "_open_practice_screen")).name = "PracticeReturn"
	var summary := P.card(page, "이번 연습 기록" if practice else "이번 실전 기록", S.BLUE)
	summary.name = "ChallengeReportSummary"
	P.text(summary, "%.1f초 · 실효 피해 %d · 평균 초당 피해 %.1f" % [report["elapsed"], report["total_damage"], report["dps"]], 20)
	P.text(summary, "종료 시 생존 %d / %d명 · 완료한 적 무리 %d" % [report["alive"], report["actors"].size(), report["waves"]], 18)
	P.text(summary, "전투 관찰 기록입니다. 보상 지급·최고점 반영 여부는 도전 결과에서 확인하세요.", 16, S.MUTED)
	if str(report.get("mode", "")) == "weekly":
		P.text(summary, "이번 시도 심연 실효 점수 %d" % int(report.get("score", 0)), 17, S.BLUE_SOFT)
	var pattern: Dictionary = report.get("pattern", {})
	if not pattern.is_empty():
		var metrics: Dictionary = report.get("pattern_metrics", {})
		P.text(summary, "패턴 · " + str(pattern["label"]) + " · 규칙 v" + str(pattern["version"]), 18, S.GOLD).name = "ChallengePatternReport"
		P.text(summary, str(pattern["hint"]), 16, S.MUTED)
		P.text(summary, "회복 %d회 / %d HP · 강타 준비 %d회 / 차단 %d회 / 발동 %d회 / 불발 %d회" % [metrics.get("heals", 0), metrics.get("healed_hp", 0), metrics.get("casts_started", 0), metrics.get("interrupts", 0), metrics.get("casts_completed", 0), metrics.get("casts_missed", 0)], 16, S.MUTED)
	var previous: Dictionary = report.get("previous", {})
	if not previous.is_empty():
		P.text(summary, "같은 조건의 이전 시도 대비: 피해 %+d · 초당 피해 %+.1f · 생존 %+d명" % [int(report["total_damage"]) - int(previous["total_damage"]), float(report["dps"]) - float(previous["dps"]), int(report["alive"]) - int(previous["alive"])], 16, S.BLUE_SOFT).name = "ChallengeReportComparison"
		P.text(summary, "같은 패턴·규칙 버전·진영·지역·유형·난이도(심연은 같은 주)만 비교해요. 편성·스킬 설정·완주 시간 차이가 포함되며 승리 보장은 아니에요.", 15, S.MUTED)
	var advice := P.card(page, "다음 시도 점검", S.GOLD)
	P.text(advice, "관찰에 근거한 점검 제안입니다. 패배 원인을 확정하거나 영웅의 우열을 판정하지 않아요.", 16, S.MUTED)
	for tip in report["advice"]:
		P.text(advice, str(tip["text"]), 18)
		var action: String = str(tip.get("action", "none"))
		if action != "none":
			P.action(advice, "해당 영웅 성장 보기" if action == "growth" else "편성 확인", Callable(main, "_challenge_report_action").bind(action, serial, str(tip.get("hero_id", ""))))
	P.text(page, "영웅별 기록 · 실효 피해 순", 22, S.GOLD)
	P.text(page, "탱커·서포터는 피해만으로 평가하지 않아요. 받은 회복은 치유자가 아닌 수혜자 기준, 보호막은 본인에게 흡수된 피해입니다.", 16, S.MUTED)
	for row in report["actors"]:
		var box := P.card(page, str(row["name"]) + " · " + str(row["role"]), S.EDGE_SOFT)
		box.name = "ChallengeActor_" + str(row["id"])
		P.text(box, "피해 %d · %.1f%% · 초당 %.1f" % [row["damage"], float(row["share"]) * 100.0, row["dps"]], 19)
		P.progress(box, float(row["share"]), 1.0)
		P.text(box, "받은 피해 %d · 받은 회복 %d · 보호막 흡수 %d" % [row["damage_taken"], row["healing_received"], row["shield_absorbed"]], 16, S.MUTED)
		P.text(box, "종료 HP %d / 입장 HP 최대 %d · 처치 %d" % [row["hp"], row["max_hp"], row["kills"]], 16, S.MUTED)
		if float(row["first_down_at"]) >= 0.0:
			P.text(box, "첫 전투불능 %.1f초" % row["first_down_at"], 16, S.GOLD)
		P.action(box, "이 영웅 성장 확인", Callable(main, "_challenge_report_action").bind("growth", serial, str(row["id"]))).name = "ChallengeActorGrowth_" + str(row["id"])
	if int(report["support_damage"]) > 0:
		P.text(page, "수호신·지원 피해 %d (영웅 피해와 별도)" % report["support_damage"], 18, S.BLUE_SOFT).name = "ChallengeSupportDamage"
	if int(report["unknown_damage"]) > 0:
		P.text(page, "출처 미분류 피해 %d" % report["unknown_damage"], 16, S.MUTED)
	P.text(page, "실효 피해는 적 HP 감소 기준이며 과잉 피해·중복 관찰·되채운 HP의 재채점을 제외합니다. 시간은 전투 배속을 따른 게임 내 시간입니다. 기록은 이번 실행 중 최근 실전만 유지하고 앱 종료 시 사라집니다. 소탕·일반 필드·레이드는 이 분석 대상이 아닙니다.", 15, S.MUTED)
