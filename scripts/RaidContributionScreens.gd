extends RefCounted
const P = preload("res://scripts/portrait/PortraitPages.gd")
const S = preload("res://scripts/portrait/PortraitSkin.gd")
const A = preload("res://scripts/RaidReportArchive.gd")
static func reports(main) -> Array:
	var all: Array = A.load_reports(str(main.get_meta("raid_report_path",A.PATH)))
	var last: Dictionary = main.get_meta("last_raid_contribution",{})
	if not last.is_empty():
		all = all.filter(func(r):return r.get("stamp","") != last.get("stamp",""))
		all.push_front(last.duplicate(true))
	return all.slice(0,A.MAX_REPORTS).filter(func(r):return r.get("entry",{}).get("faction","")==main.selected_faction)
static func build(main, index: int = 0) -> void:
	if main.raid_running or main.challenge_session != null: return
	var page = P.begin(main,"raid_report","레이드 기여도 분석","기기 내 최근 12회 · 현재 진영만 표시","content")
	P.action(page,"레이드로 돌아가기",Callable(main,"_build_raid_screen")).name="RaidReportBack"
	var list: Array = reports(main)
	if list.is_empty():
		P.text(page,"기록된 레이드가 없어요. 직접 전투 후 이곳에서 확인하세요.",20)
		return
	index=clampi(index,0,list.size()-1)
	var report: Dictionary=list[index]
	var history=P.grid(page,2)
	for i in list.size():
		var old: Dictionary=list[i]
		P.action(history,"%d · %s · %.1f초"%[i+1,old["entry"].get("name","레이드"),old["elapsed"]],Callable(main,"_open_raid_report").bind(i),i==index).name="RaidHistory_%d"%i
	var box=P.card(page,str(report["entry"].get("name","레이드")),S.BLUE)
	var outcome: String={"victory":"승리","timeout":"시간 초과","defeat":"전멸","cancelled":"취소"}.get(str(report["reason"]),str(report["reason"]))
	P.text(box,"%s · %.1f게임초 · 생존 %d명"%[outcome,report["elapsed"],report["alive"]],20).name="RaidReportSummary"
	var totals: Dictionary=report["totals"]
	P.text(box,"본체 피해 %d · 갑주 피해 %d · 수정핵 피해 %d"%[totals["boss_damage"],totals["guard_damage"],totals["add_damage"]],18)
	P.text(box,"차단 성공 %d회 · 유효 치유 %d · 새로 부여한 보호막 %d"%[totals["interrupts"],totals["healing_given"],totals["shield_given"]],18)
	P.text(box,"피해는 실제로 소모한 HP입니다. 보스가 회복한 뒤 다시 가한 피해도 포함하며, 심연의 중복 제외 점수와 다릅니다. 보호막 부여는 기존 보호막보다 늘어난 양만, 치유는 실제 회복량만 집계합니다.",15,S.MUTED)
	if not bool(main.get_meta("raid_report_saved",true)) and report.get("stamp","")==main.get_meta("last_raid_contribution",{}).get("stamp",""):
		P.text(box,"분석 기록 저장 실패 · 이번 실행 중에는 열람 가능. 게임 보상 저장과는 별도입니다.",17,S.GOLD)
	# Comparison is deliberately limited: same boss/rule/faction/outcome and auto settings.
	for j in range(index+1,list.size()):
		var old: Dictionary=list[j]
		if old["entry"]==report["entry"] and old["rule"]==report["rule"] and old["reason"]==report["reason"] and outcome!="취소":
			var previous_dps: float=float(old["total_damage"])/maxf(.001,float(old["elapsed"]))
			var dps: float=float(report["total_damage"])/maxf(.001,float(report["elapsed"]))
			P.text(box,"같은 보스·규칙·종료·시작 자동설정 기록 대비: 초당 피해 %+.1f · 생존 %+d명"%[dps-previous_dps,int(report["alive"])-int(old["alive"])],16,S.BLUE_SOFT)
			P.text(box,"레벨·장비·편성, 도중 설정 변경·수동 입력 차이는 포함됩니다. 통제된 성능 실험이나 영웅 우열 판정이 아닙니다.",15,S.MUTED)
			break
	for row in report["actors"]:
		var actor=P.card(page,str(row["name"])+" · "+str(row["role"]),S.EDGE_SOFT)
		actor.name="RaidContribution_"+str(row["id"]).replace("$","")
		P.text(actor,"본체 %d / 갑주 %d / 수정핵 %d · 초당 %.1f"%[row["boss_damage"],row["guard_damage"],row["add_damage"],row["dps"]],18)
		P.text(actor,"제공한 치유 %d · 보호막 부여 %d · 차단 성공 %d회"%[row["healing_given"],row["shield_given"],row["interrupts"]],17,S.BLUE_SOFT)
		if not str(row["id"]).begins_with("$"):
			P.text(actor,"받은 피해 %d · 받은 회복 %d · 본인 보호막 흡수 %d"%[row.get("damage_taken",0),row.get("healing_received",0),row.get("shield_absorbed",0)],16,S.MUTED)
			if float(row.get("first_down_at",-1))>=0:P.text(actor,"첫 전투불능 %.1f초"%row["first_down_at"],16,S.GOLD)
	P.text(page,"차단 성공은 게이지를 완성해 실제 시전을 취소한 영웅에게 기록합니다. 이전 제어 기여 전부를 뜻하지 않으며, 피해 순위나 종합 MVP로 영웅의 가치를 판단하지 않습니다. 소탕·서버 랭킹·보상 산정에 쓰지 않는 로컬 관찰 기록입니다.",15,S.MUTED)
