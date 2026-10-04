extends RefCounted

const UI := preload("res://scripts/GameUiTheme.gd")
const EQUIPMENT_ART := preload("res://scripts/EquipmentArtCatalog.gd")

static func _text(parent: Control, value: String, rect: Rect2, font_size: int = 16, color: Color = UI.INK) -> Label:
	var label := UI.label(value, font_size, color)
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

static func _panel(parent: Control, rect: Rect2, color: Color = UI.SURFACE) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", UI.panel(color))
	parent.add_child(panel)
	return panel

static func _action(parent: Control, label: String, rect: Rect2, action: Callable, primary: bool = false) -> Button:
	var button := UI.button(label, rect.size, UI.PRIMARY if primary else UI.SOFT)
	button.position = rect.position
	button.pressed.connect(action)
	parent.add_child(button)
	return button

static func growth(main) -> void:
	main._clear_screen()
	main.active_screen = "growth"
	main._add_screen_header("원정대로", Callable(main, "_build_lobby_screen"), "영웅 성장", "쌓아 온 경험으로 영웅의 강점을 완성하세요.", "훈련소", UI.PRIMARY, "골드 %d" % main.wallet_gold)
	var pet: Dictionary = main._get_pet_progress()
	var profile: Dictionary = main._pet_profile()
	var companion := _panel(main.content_root, Rect2(55, 188, 312, 442))
	var companion_icon := UI.icon("leaf", Vector2(72, 72), UI.PRIMARY)
	companion_icon.position = Vector2(120, 35)
	companion.add_child(companion_icon)
	_text(companion, "함께 자라는 동료", Rect2(24, 132, 264, 24), 14, UI.GOLD)
	_text(companion, str(profile.get("name", "동료")), Rect2(24, 167, 264, 38), 25)
	_text(companion, "Lv.%d  ·  %s" % [int(pet.get("level", 1)), main._pet_evolution_name(int(pet.get("evolution", 0)))], Rect2(24, 216, 264, 30), 17, UI.PRIMARY)
	var xp := ProgressBar.new()
	xp.position = Vector2(24, 258)
	xp.size = Vector2(264, 8)
	xp.max_value = main._pet_xp_to_next(int(pet.get("level", 1)))
	xp.value = int(pet.get("xp", 0))
	xp.show_percentage = false
	companion.add_child(xp)
	_text(companion, "경험치 %d / %d" % [int(pet.get("xp", 0)), int(xp.max_value)], Rect2(24, 277, 264, 24), 13, UI.MUTED)
	_text(companion, str(profile.get("description", "전투를 함께하며 성장해요.")), Rect2(24, 316, 264, 54), 15, UI.MUTED)
	_text(companion, "Lv.5 각성  ·  Lv.10 초월", Rect2(24, 390, 264, 26), 14, UI.GOLD)
	_text(main.content_root, "영웅 훈련", Rect2(392, 186, 360, 32), 23)
	_text(main.content_root, "3레벨마다 훈련 포인트 +1 · 각 분야 최대 10단계", Rect2(392, 223, 820, 25), 14, UI.MUTED)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(392, 263)
	scroll.size = Vector2(833, 367)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.content_root.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 811
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	for hero: Dictionary in main._hero_roster_for_faction():
		var id := str(hero["id"])
		var progress: Dictionary = main._get_hero_progress(id)
		var tree: Dictionary = main._get_skill_tree(id)
		var points: int = main._skill_tree_available_points(id)
		var card := Panel.new()
		card.custom_minimum_size = Vector2(811, 206)
		card.add_theme_stylebox_override("panel", UI.panel(UI.SURFACE))
		list.add_child(card)
		_text(card, "%s  ·  Lv.%d" % [hero["name"], int(progress.get("level", 1))], Rect2(20, 14, 500, 30), 18)
		_text(card, "사용 가능 %d P" % points, Rect2(618, 18, 173, 24), 14, UI.PRIMARY)
		var branch_index := 0
		for branch: String in ["offense", "survival", "utility"]:
			var rank := int(tree.get(branch, 0))
			var upgrade := _action(card, main._skill_tree_branch_text(branch, rank), Rect2(20 + branch_index * 258, 62, 247, 63), Callable(main, "_upgrade_skill_tree").bind(id, branch))
			upgrade.add_theme_font_size_override("font_size", 14)
			upgrade.disabled = points <= 0 or rank >= 10
			branch_index += 1
		_action(card, "연구 재배분 · 미리보기", Rect2(20, 143, 770, 50), Callable(main, "_open_research_allocation").bind(id))
	main._add_bottom_nav("growth")

static func inventory(main) -> void:
	main._clear_screen()
	main.active_screen = "inventory"
	main._add_screen_header("원정대로", Callable(main, "_build_lobby_screen"), "장비 보관함", "좋은 장비를 골라 영웅에게 장착하고, 다음 모험을 준비하세요.", "%d / %d칸" % [main.loot_inventory.size(), main.INVENTORY_CAP], UI.PRIMARY, "골드 %d" % main.wallet_gold)
	_action(main.content_root, "추천 장착", Rect2(55, 188, 154, 44), Callable(main, "_recommend_equip_all"), true)
	_action(main.content_root, "장착 장비 일괄 강화", Rect2(221, 188, 216, 44), Callable(main, "_bulk_enhance_equipped"))
	_action(main.content_root, "거래소", Rect2(449, 188, 112, 44), Callable(main, "_build_equipment_market"))
	_action(main.content_root, "장비 우편함", Rect2(573, 188, 142, 44), Callable(main, "_build_equipment_stash"))
	_text(main.content_root, "자동 분해", Rect2(791, 189, 104, 42), 14, UI.MUTED)
	var salvage := OptionButton.new()
	salvage.position = Vector2(901, 188)
	salvage.size = Vector2(324, 44)
	var values := ["일반", "희귀", "전설"]
	var titles := ["사용 안 함", "희귀 미만 장비", "전설 미만 장비"]
	for i in values.size():
		salvage.add_item(titles[i])
		salvage.set_item_metadata(i, values[i])
		if values[i] == main.auto_salvage_min_rarity:
			salvage.select(i)
	salvage.item_selected.connect(func(index): main._set_auto_salvage(str(salvage.get_item_metadata(index))))
	main.content_root.add_child(salvage)
	if main.loot_inventory.is_empty():
		var empty := _panel(main.content_root, Rect2(55, 252, 1170, 378))
		var bag := UI.icon("bag", Vector2(76, 76), UI.PRIMARY)
		bag.position = Vector2(547, 42)
		empty.add_child(bag)
		var title := _text(empty, "새로운 장비가 기다리고 있어요", Rect2(260, 145, 650, 40), 24)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var note := _text(empty, "사냥에서 얻은 장비는 이곳에 모입니다.", Rect2(260, 197, 650, 32), 16, UI.MUTED)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_action(empty, "사냥터 둘러보기", Rect2(457, 261, 256, 50), Callable(main, "_open_world_menu"), true)
	else:
		var scroll := ScrollContainer.new()
		scroll.position = Vector2(55, 252)
		scroll.size = Vector2(1170, 378)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		main.content_root.add_child(scroll)
		var list := VBoxContainer.new()
		list.custom_minimum_size.x = 1148
		list.add_theme_constant_override("separation", 12)
		scroll.add_child(list)
		var roster: Array = main._hero_roster_for_faction()
		for index in main.loot_inventory.size():
			if not main._inventory_action_valid(index):
				continue
			var item: Dictionary = main._normalize_inventory_item(main.loot_inventory[index])
			main.loot_inventory[index] = item
			var item_id := str(item["id"])
			var crystal := str(item.get("item_type","equipment"))=="option_crystal"
			var card := Panel.new()
			card.custom_minimum_size = Vector2(1148, 170)
			card.add_theme_stylebox_override("panel", UI.panel(UI.SURFACE))
			list.add_child(card)
			var rarity: Color = UI.text_color(main._rarity_color(str(item["rarity"])))
			var icon_bg := _panel(card, Rect2(18, 21, 72, 72), UI.SOFT)
			var icon := TextureRect.new()
			icon.name = "EquipmentArt"
			icon.texture = EQUIPMENT_ART.texture_for(item)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.position = Vector2.ZERO
			icon.size = Vector2(72, 72)
			icon.set_meta("equipment_art_cell", EQUIPMENT_ART.cell_for(item))
			icon_bg.add_child(icon)
			_text(card, "%s  +%d" % [item["name"], item["level"]], Rect2(110, 17, 408, 32), 18)
			_text(card, "%s · %s · %s 세트" % [item["rarity"], main._equipment_slot_name(str(item["slot"])), str(item.get("set", "초보자"))], Rect2(110, 51, 408, 24), 14, rarity)
			_text(card, "전투력 %d" % item.get("power", 0), Rect2(110, 80, 408, 20), 13, UI.MUTED)
			var heroes := OptionButton.new()
			heroes.position = Vector2(541, 35)
			heroes.size = Vector2(232, 44)
			var eligible: Array=[]
			for hero: Dictionary in roster:
				if main._gear_role_matches(item,str(hero.get("id",""))):eligible.append(hero)
			for hero: Dictionary in eligible:
				heroes.add_item(str(hero["name"]))
				heroes.set_item_metadata(heroes.item_count - 1, str(hero["id"]))
			card.add_child(heroes)
			var equip := _action(card, "장착", Rect2(789, 35, 99, 44), func(): main._equip_inventory_item(index, str(heroes.get_item_metadata(heroes.selected)), item_id), true)
			equip.disabled = eligible.is_empty() or crystal
			_action(card, "강화", Rect2(900, 35, 99, 44), Callable(main, "_enhance_inventory_item").bind(index, item_id)).disabled=crystal
			var dismantle := _action(card, "분해", Rect2(1011, 35, 119, 44), func():preload("res://scripts/portrait/PortraitPages.gd").confirm_decompose(main,index,item_id))
			dismantle.disabled=crystal or bool(item.get("locked",false)) or not (item.get("proposal",{}) as Dictionary).is_empty()
			_action(card,"결정 상세 · 이식" if crystal else "옵션 공방",Rect2(789, 100, 210, 44),Callable(main,"_build_option_crystal" if crystal else "_build_equipment_workshop").bind(item_id))
			_text(card,preload("res://scripts/EquipmentRules.gd").origin_text(item),Rect2(110,112,650,28),14,UI.MUTED)
	main._add_bottom_nav("inventory")
