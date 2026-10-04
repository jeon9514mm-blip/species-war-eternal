extends RefCounted
class_name RewardDialogs

const UI := preload("res://scripts/GameUiTheme.gd")
const LAYOUT := preload("res://scripts/LandingScreens.gd")
const HERO_UI := preload("res://scripts/HeroScreens.gd")
const ROSTER := preload("res://scripts/HeroRosterCatalog.gd")

# These dialogs only present settled results. Rewards are credited by the
# existing game systems before entering here; confirmation never credits twice.
static func offline(main) -> void:
	if not is_instance_valid(main.content_root):
		return
	var needs_claim: bool=main.has_method('_claim_offline_rewards')
	var values := {
		"time": main._format_idle_time(main.offline_reward_seconds),
		"efficiency": main.offline_efficiency,
		"gold": main.offline_pending_gold+main.offline_pending_chest_gold if needs_claim else main.offline_reward_gold,
		"xp": main.offline_pending_xp+main.offline_pending_chest_xp if needs_claim else main.offline_reward_xp,
		"pet_xp": main.offline_pet_xp,
		"rations": main.offline_rations,
		"gear": main.offline_gear_rolls,
		"stages": main.offline_stage_clears
	}
	var modal := _modal(main, "OfflineRewardPopup", "OfflineRewardOverlay", Vector2(620, 532))
	var panel: Panel = modal["panel"]
	_emblem(panel, "bag", Rect2(280, 26, 60, 60), UI.PRIMARY)
	_heading(main, panel, "다녀오셨군요!", Rect2(28, 100, 564, 41), 29, UI.INK)
	_heading(main, panel, main.offline_reward_basis if not main.offline_reward_basis.is_empty() else "자리를 비운 동안 모은 원정대의 선물이에요.", Rect2(28, 151, 564, 29), 16, UI.MUTED)
	_heading(main, panel, "%s  ·  사냥 효율 %d%%" % [values["time"], values["efficiency"]], Rect2(28, 187, 564, 27), 15, UI.PRIMARY)
	_reward_cell(main, panel, Rect2(28, 232, 273, 91), "gold", "골드", int(values["gold"]), UI.GOLD)
	_reward_cell(main, panel, Rect2(319, 232, 273, 91), "growth", "경험치", int(values["xp"]), UI.PRIMARY)
	var extras := LAYOUT._panel(main, panel, Rect2(28, 338, 564, 76), UI.SOFT, Color.TRANSPARENT, 14)
	_heading(main, extras, "수호신 경험치 +%d  ·  군량 +%d\n장비 탐색 %d회  ·  스테이지 +%d" % [values["pet_xp"], values["rations"], values["gear"], values["stages"]], Rect2(12, 8, 540, 60), 16, UI.MUTED)
	var delivery_wait: int=preload("res://scripts/EquipmentMailService.gd").pending_count(main)
	var delivery_note: String="장비 탐색 %d회 배송 대기 · 가방·우편 공간을 확보하세요."%delivery_wait if delivery_wait>0 else "영웅 성장·장비는 반영됐어요. 골드와 계정 경험치를 받으세요."
	_heading(main, panel, delivery_note, Rect2(28, 425, 564, 26), 15, UI.MUTED)
	_confirm(main, modal, "오프라인 사냥 받기" if needs_claim else "보상 확인", Rect2(28, 470, 564, 48), Callable(main,'_claim_offline_rewards') if needs_claim else Callable())
	# Preserve the original one-time presentation handoff. The accumulated
	# reward wallet and _offline_checked are deliberately untouched.
	if not needs_claim:
		main.offline_reward_gold = 0
		main.offline_reward_xp = 0
		main.offline_reward_seconds = 0
		main.offline_pet_xp = 0
		main.offline_rations = 0
		main.offline_gear_rolls = 0
		main.offline_stage_clears = 0
		main.offline_efficiency = 0
	_reveal(main, panel)

static func summon(main, result: Dictionary) -> void:
	if not is_instance_valid(main.content_root):
		return
	var modal := _modal(main, "SummonRevealPanel", "SummonRevealOverlay", Vector2(580, 582))
	var panel: Panel = modal["panel"]
	_emblem(panel, "summon", Rect2(267, 22, 46, 46), UI.GOLD)
	_heading(main, panel, "새로운 인연의 조각", Rect2(28, 81, 524, 39), 27, UI.INK)
	var hero_id := str(result.get("hero_id", ""))
	var hero: Dictionary = ROSTER.hero(hero_id)
	if hero.is_empty():
		hero = {"id": hero_id, "name": result.get("name", "영웅"), "race": "영웅", "class": "", "color": UI.GOLD}
	panel.add_child(HERO_UI._portrait(main, hero, Rect2(194, 137, 192, 193), true))
	_heading(main, panel, str(result.get("name", hero.get("name", "영웅"))), Rect2(28, 344, 524, 35), 26, UI.INK)
	_heading(main, panel, "%s · %s" % [hero.get("race", ""), hero.get("class", "")], Rect2(28, 386, 524, 26), 16, UI.MUTED)
	var shards := int(result.get("shards", 0))
	LAYOUT._badge(main, panel, "영웅 조각 +%d" % shards, Rect2(166, 427, 248, 40), UI.SOFT, UI.PRIMARY)
	var pity_text := "10회 소환 보장을 받았어요!" if shards >= 30 else "다음 보장까지 %d회" % maxi(0, 10 - int(main.summon_pity))
	_heading(main, panel, pity_text, Rect2(28, 479, 524, 26), 15, UI.MUTED)
	_confirm(main, modal, "확인", Rect2(28, 522, 524, 46), Callable(main, "_build_summon_screen"))
	_reveal(main, panel)

static func guardian(main, result: Dictionary) -> void:
	if not is_instance_valid(main.content_root):return
	var catalog:=preload("res://scripts/GuardianCatalog.gd")
	var profile: Dictionary=catalog.profile(str(result.get("id","")))
	if profile.is_empty():return
	var modal:=_modal(main,"GuardianRevealPanel","GuardianRevealOverlay",Vector2(580,550))
	var panel: Panel=modal["panel"]
	var accent: Color=catalog.tier_color(str(profile["tier"]))
	_heading(main,panel,"수호신의 계약",Rect2(28,34,524,43),29,accent)
	var sigil:=preload("res://scripts/portrait/PortraitGuardianSigil.gd").new()
	sigil.accent=accent;sigil.tier=str(profile["tier"])
	sigil.position=Vector2(180,90);sigil.size=Vector2(220,140)
	panel.add_child(sigil)
	_heading(main,panel,str(profile["symbol"]),Rect2(180,105,220,118),82,accent)
	_heading(main,panel,str(profile["name"]),Rect2(28,238,524,38),28,UI.INK)
	_heading(main,panel,"[%s] %s"%[profile["tier"],"새로운 수호신" if bool(result.get("new",false)) else "공명 재료 획득"],Rect2(28,283,524,34),20,accent)
	_heading(main,panel,"공명 %d단계 · 보유 %d장"%[catalog.resonance(int(result.get("copies",1))),int(result.get("copies",1))],Rect2(28,324,524,28),17,UI.MUTED)
	var detail:=_heading(main,panel,catalog.bonus_text(profile,int(result.get("copies",1))),Rect2(38,364,504,92),17,UI.INK,true)
	detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_heading(main,panel,"무료 소환" if bool(result.get("free",false)) else "젬 %d 소모"%catalog.SUMMON_COST,Rect2(28,462,524,26),15,UI.MUTED)
	_confirm(main,modal,"도감 확인",Rect2(28,493,524,45),Callable(main,"_build_summon_screen"))
	_reveal(main,panel)

static func battle(main, title_text: String, headline: String, detail: String, accent: Color) -> void:
	if not is_instance_valid(main.content_root):
		return
	if str(main.active_screen) == "combat":
		_field_result(main, title_text, headline, detail, accent)
		return
	var modal := _modal(main, "BattleResultPopup", "BattleResultOverlay", Vector2(660, 516))
	var panel: Panel = modal["panel"]
	var title: String = {"STAGE CLEAR": "스테이지 돌파", "RAID CLEAR": "레이드 승리"}.get(title_text, title_text)
	var ink := UI.text_color(accent)
	_emblem(panel, "check", Rect2(302, 27, 56, 56), ink)
	_heading(main, panel, title, Rect2(30, 97, 600, 42), 31, UI.INK)
	_heading(main, panel, headline, Rect2(30, 149, 600, 49), 21, ink, true)
	var reward_box := LAYOUT._panel(main, panel, Rect2(30, 216, 600, 151), UI.SOFT, Color.TRANSPARENT, 16)
	var scroll := ScrollContainer.new()
	scroll.name = "BattleResultDetails"
	scroll.position = Vector2(18, 12)
	scroll.size = Vector2(564, 127)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reward_box.add_child(scroll)
	var details: Label = main._label(detail, 17, UI.MUTED)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	details.custom_minimum_size = Vector2(543, 127)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(details)
	var survivors: int = main._alive_hero_ids().size()
	_heading(main, panel, "생존 영웅 %d/%d  ·  원정대 전투력 %s" % [survivors, main.deployed_heroes.size(), LAYOUT._number(main._calculate_party_power())], Rect2(30, 389, 600, 29), 16, UI.MUTED)
	_confirm(main, modal, "계속 진행", Rect2(30, 442, 600, 51))
	_reveal(main, panel)

static func _modal(main, panel_name: String, overlay_name: String, size: Vector2) -> Dictionary:
	for name: String in [panel_name, overlay_name]:
		var old: Node = main.content_root.get_node_or_null(name)
		if is_instance_valid(old):
			main.content_root.remove_child(old)
			old.queue_free()
	var overlay := ColorRect.new()
	overlay.name = overlay_name
	overlay.color = Color(0.10, 0.19, 0.15, 0.52)
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(main._layout_width(), main._layout_height())
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 110
	main.content_root.add_child(overlay)
	var rect := Rect2((Vector2(main._layout_width(), main._layout_height()) - size) * 0.5, size)
	var panel := LAYOUT._panel(main, main.content_root, rect, UI.SURFACE, UI.BORDER, 24)
	panel.name = panel_name
	panel.z_index = 111
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return {"panel": panel, "overlay": overlay}

static func _confirm(main, modal: Dictionary, caption: String, rect: Rect2, after_close: Callable = Callable()) -> void:
	var panel: Panel = modal["panel"]
	var overlay: ColorRect = modal["overlay"]
	var button: Button = LAYOUT._action(main, panel, caption, rect, func():
		if not is_instance_valid(panel) or panel.is_queued_for_deletion(): return
		for control: Control in [panel, overlay]:
			if is_instance_valid(control):
				# Keep the GUI target in the tree through emulated mouse/touch
				# release. Hiding closes immediately; deletion waits for frame end.
				control.hide()
				control.queue_free()
		if after_close.is_valid():
			after_close.call()
	, true)
	button.name = "DialogConfirm"
	# Keep keyboard navigation inside the one-action dialog while its shade is up.
	button.focus_next = button.get_path()
	button.focus_previous = button.get_path()
	button.focus_neighbor_left = button.get_path()
	button.focus_neighbor_right = button.get_path()
	button.focus_neighbor_top = button.get_path()
	button.focus_neighbor_bottom = button.get_path()
	button.grab_focus()

static func _heading(main, parent: Control, text: String, rect: Rect2, font_size: int, color: Color, wrap := false) -> Label:
	var label: Label = LAYOUT._text(main, parent, text, rect, font_size, color, wrap)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

static func _emblem(parent: Control, icon_name: String, rect: Rect2, color: Color) -> void:
	var icon: Control = UI.icon(icon_name, rect.size, color)
	icon.position = rect.position
	parent.add_child(icon)

static func _reward_cell(main, parent: Control, rect: Rect2, icon_name: String, caption: String, value: int, color: Color) -> void:
	var panel := LAYOUT._panel(main, parent, rect, UI.SOFT, Color.TRANSPARENT, 14)
	_emblem(panel, icon_name, Rect2(18, 27, 35, 35), color)
	LAYOUT._text(main, panel, caption, Rect2(68, 12, 184, 26), 15, UI.MUTED)
	LAYOUT._text(main, panel, "+" + LAYOUT._number(value), Rect2(68, 41, 184, 34), 25, color)

static func _reveal(main, panel: Panel) -> void:
	if not main.combat_effects_enabled:
		return
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.96, 0.96)
	panel.pivot_offset = panel.size * 0.5
	var tween: Tween = panel.create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.16)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

static func _field_result(main, title_text: String, headline: String, detail: String, accent: Color) -> void:
	for name: String in ["BattleResultPopup", "BattleResultOverlay"]:
		var old: Node = main.content_root.get_node_or_null(name)
		if is_instance_valid(old):
			main.content_root.remove_child(old)
			old.queue_free()
	var field: Rect2 = main.combat_field_rect
	var rect := Rect2(field.position + Vector2((field.size.x - 442.0) * 0.5, 12), Vector2(442, 99))
	var panel := LAYOUT._panel(main, main.content_root, rect, Color(UI.SURFACE, 0.97), UI.BORDER, 16)
	panel.name = "BattleResultPopup"
	panel.z_index = 90
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption: String = {"STAGE CLEAR": "스테이지 돌파", "RAID CLEAR": "레이드 승리"}.get(title_text, title_text)
	var icon: Control = UI.icon("check", Vector2(31, 31), UI.text_color(accent))
	icon.position = Vector2(17, 17)
	panel.add_child(icon)
	LAYOUT._text(main, panel, caption + " · " + headline, Rect2(61, 12, 363, 33), 17, UI.INK)
	var reward_line: String = detail.split("\n")[0]
	LAYOUT._text(main, panel, reward_line, Rect2(18, 53, 406, 30), 16, UI.MUTED)
	var tween: Tween = panel.create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.24)
	tween.tween_callback(panel.queue_free)
