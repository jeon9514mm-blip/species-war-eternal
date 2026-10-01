extends RefCounted
## Existing portrait components; no art/theme changes. All draft edits are local.
const P = preload("res://scripts/portrait/PortraitPages.gd")
const S = preload("res://scripts/portrait/PortraitSkin.gd")
const SERVICE = preload("res://scripts/ResearchAllocationService.gd")

static func build(main: Node, hero_id: String) -> void:
	var error: String = SERVICE.entry_error(main, hero_id)
	if not error.is_empty(): main._show_toast(error); return
	var page := P.begin(main, "research_allocation", "연구 포인트 재배분", "초안 수정 → 효과 미리보기 → 확정 · 비용 0", "growth")
	main.set_meta("growth_hero_id", hero_id)
	var view_id: int = main.content_root.get_instance_id()
	var original: Dictionary = SERVICE.current(main, hero_id)
	var draft: Dictionary = original.duplicate(true)
	var state: Dictionary = {"token": SERVICE.fingerprint(main, hero_id), "confirmed_preview": false}
	P.text(page, str(SERVICE.HEROES.HEROES[hero_id]["name"]) + " · 실제 레벨에서 얻은 연구만 사용", 22, S.GOLD)
	P.text(page, "기존 연구를 줄여 다른 분야로 옮길 수 있어요. 되돌린 포인트는 미사용 포인트로 남으며, 레벨·경험치·장비·재화는 바뀌지 않습니다.", 17, S.MUTED)
	var summary := P.text(page, "", 20, S.BLUE_SOFT); summary.name = "ResearchDraftBudget"
	var controls: Dictionary = {}
	for branch: String in SERVICE.BRANCHES:
		var key: String = branch
		var box := P.card(page, {"offense": "공격", "survival": "생존", "utility": "기능"}[key], S.EDGE_SOFT)
		P.text(box, "현재 · " + main._skill_tree_branch_text(key, int(original[key])), 17, S.MUTED)
		var spin := SpinBox.new(); spin.name = "ResearchDraft_" + key
		spin.min_value = 0; spin.max_value = 10; spin.step = 1; spin.value = int(draft[key]); spin.custom_minimum_size.y = 56
		box.add_child(spin); controls[key] = spin
	var reset := P.action(page, "초안에서 전부 되돌리기", func():
		for key: String in SERVICE.BRANCHES: controls[key].value = 0)
	reset.name = "ResearchResetDraft"
	var preview_box := P.card(page, "변경 효과 미리보기", S.GOLD)
	var effects := P.text(preview_box, "", 17)
	var confirm := P.action(preview_box, "확인 · 재배분 적용", func():
		if not is_instance_valid(main.content_root) or view_id != main.content_root.get_instance_id() or not bool(state["confirmed_preview"]): return
		state["confirmed_preview"] = false
		var result: Dictionary = SERVICE.apply(main, hero_id, draft, str(state["token"]))
		main._show_toast(str(result["reason"]))
		if bool(result.get("applied", false)): main._build_growth_screen(), true)
	confirm.name = "ResearchConfirm"; confirm.disabled = true
	preview_box.get_parent().visible = false
	var refresh := func():
		state["confirmed_preview"] = false; confirm.disabled = true; preview_box.get_parent().visible = false
		var proposal: Dictionary = SERVICE.preview(main, hero_id, draft)
		if bool(proposal.get("ok", false)):
			summary.text = "획득 %d P · 초안 투자 %d P · 남는 %d P" % [proposal["budget"], proposal["spent"], proposal["available"]]
		else: summary.text = str(proposal["reason"])
	for branch: String in SERVICE.BRANCHES:
		var key: String = branch
		controls[key].value_changed.connect(func(value: float): draft[key] = int(value); refresh.call())
	var actions := P.grid(page, 2)
	P.action(actions, "취소 · 원래 배분 유지", Callable(main, "_build_growth_screen")).name = "ResearchCancel"
	P.action(actions, "변경 효과 미리보기", func():
		if not is_instance_valid(main.content_root) or view_id != main.content_root.get_instance_id(): return
		if str(state["token"]) != SERVICE.fingerprint(main, hero_id):
			main._show_toast("성장 정보가 바뀌었어요. 재배분 화면을 다시 열어 주세요."); return
		var proposal: Dictionary = SERVICE.preview(main, hero_id, draft)
		if not bool(proposal.get("ok", false)): main._show_toast(str(proposal["reason"])); return
		var lines: PackedStringArray = []
		for key: String in SERVICE.BRANCHES:
			lines.append(main._skill_tree_branch_text(key, int(original[key])) + "\n→ " + main._skill_tree_branch_text(key, int(draft[key])))
		lines.append("미사용 %d P 유지 · 비용 0" % proposal["available"])
		effects.text = "\n\n".join(lines)
		state["confirmed_preview"] = true; confirm.disabled = not bool(proposal["changed"])
		preview_box.get_parent().visible = true, true).name = "ResearchPreview"
	refresh.call()
