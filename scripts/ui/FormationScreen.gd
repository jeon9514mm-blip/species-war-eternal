extends RefCounted
const RULES = preload("res://scripts/combat/BattleFormation.gd")
const P = preload("res://scripts/portrait/PortraitPages.gd")
const S = preload("res://scripts/portrait/PortraitSkin.gd")
static func open(main: Node) -> void:
	if not is_instance_valid(main.content_root): return
	var old: Node = main.content_root.get_node_or_null("FormationOverlay")
	if old != null: old.free()
	var overlay := Control.new(); overlay.name = "FormationOverlay"; overlay.z_index = 250
	main.content_root.add_child(overlay); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new(); shade.color = Color(0,0,0,.8)
	overlay.add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new(); overlay.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 24; scroll.offset_right = -24; scroll.offset_top = 40; scroll.offset_bottom = -40
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := P.stack(scroll)
	P.text(body, "전투 진형", 28, S.GOLD)
	P.text(body, "자동사냥은 진형을 중심으로 적 부대를 맞이합니다. 진형 효과는 출전 영웅에게 적용되며, 변경해도 현재 체력 비율은 유지됩니다.", 18)
	for id: String in RULES.PROFILES:
		var data: Dictionary = RULES.profile(id)
		var card := P.card(body, data.name + (" · 사용 중" if id == main.formation_id else ""))
		P.text(card, data.description, 20, S.GOLD)
		P.text(card, _diagram(main, id), 18)
		var button := P.action(card, "선택", func():
			if RULES.select(main, id): open(main)
			else: main._show_toast("진형을 적용할 수 없거나 저장 대기 중입니다."))
		button.name = "Formation_" + id; button.disabled = id == main.formation_id
	P.action(body, "닫기", overlay.queue_free).name = "FormationClose"
static func _diagram(main: Node, id: String) -> String:
	var layout: Dictionary = RULES.offsets(main.deployed_heroes, id)
	var rows: Array[String] = []
	for hero in main.deployed_heroes:
		var point: Vector2 = layout.get(str(hero.id), Vector2.ZERO)
		rows.append("%s · %s" % [main._hero_short_name(str(hero.id)), "전열" if point.x >= .3 else "후열"])
	return " / ".join(rows) if not rows.is_empty() else "영웅을 편성하면 전열·후열이 표시됩니다."
