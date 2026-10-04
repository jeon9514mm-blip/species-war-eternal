extends RefCounted
## Progress records deliberate actions, never passive loot or XP. No extra rewards.
static func sanitize(raw: Variant) -> Dictionary:
	var clean: Dictionary = {}
	if not raw is Dictionary: return clean
	for key: String in ["growth", "raid_started"]:
		if typeof(raw.get(key)) == TYPE_BOOL and raw[key]: clean[key] = true
	return clean

static func restore(main: Node, raw: Dictionary) -> Dictionary:
	var actions: Dictionary=sanitize(raw.get("tutorial_actions",{}))
	if raw.has("tutorial_actions"):return actions
	# Earlier saves did not record guide commands. Honor their actual invested
	# research/enhancement, including fully upgraded accounts with no legal +1.
	for tree: Dictionary in main.hero_skill_tree.values():
		for rank in tree.values():
			if int(rank)>0:actions["growth"]=true
	for equipment: Dictionary in main.hero_equipment.values():
		for level in equipment.values():
			if int(level)>1:actions["growth"]=true
	return actions

static func record(main: Node, action: String) -> void:
	if action not in ["growth", "raid_started"] or main.tutorial_completed: return
	if bool(main.get_meta("practice_active", false)) or preload("res://scripts/SaveSafety.gd").pending(main) or main._save_blocked_for_newer_version: return
	main.tutorial_actions[action] = true
	# The successful command saves both its own mutation and this flag together.

static func status(main: Node) -> Dictionary:
	var text := "초반 원정 가이드 완료 · 자유롭게 원정대를 성장시키세요."
	var short := "원정 가이드 완료"
	var caption := "사냥 이어하기"
	var route := "hunt"
	match int(main.tutorial_step):
		0:
			text = "1/6 · 진영을 선택하세요. 영웅과 시작 수호신이 달라집니다."
			short = "진영 선택"; caption = "진영 선택하기"; route = "faction"
		1:
			text = "2/6 · 첫 영웅 1명을 편성하세요. 스테이지 3에서 3인 편성이 열립니다."
			short = "첫 영웅 편성"; caption = "영웅 선택하기"; route = "party"
		2, 3:
			text = "3/6 · 첫 무리를 처치하세요." if main.tutorial_step == 2 else "4/6 · 보상은 자동으로 들어와요. 스테이지 2까지 사냥하세요."
			short = "첫 무리 처치" if main.tutorial_step == 2 else "자동 보상 · 스테이지 2 도달"
			caption = "사냥 안내"
		4:
			text = "5/6 · 장비 강화 또는 연구 1회를 직접 해보세요. 레벨업과 장비 획득만으로는 완료되지 않아요."
			short = "직접 강화 · 연구 1회"
			if not main.deployed_heroes.is_empty():
				var id: String = str(main.deployed_heroes[0].id)
				if main._skill_tree_available_points(id) > 0:
					caption = "연구 포인트 쓰기"; route = "research"
				else:
					var cost: int = main._inventory_upgrade_cost(main._gear_item("", id, "weapon"))
					if main.wallet_gold >= cost: caption = "무기 강화하기"; route = "enhance"
					else: text += "\n무기 강화 %dG · %dG 더 모으면 강화할 수 있어요." % [cost, cost-main.wallet_gold]
		5:
			short = "3인 편성 후 첫 레이드"
			if main.idle_stage < 3:
				text = "6/6 · 먼저 스테이지 3에 도달해 3인 편성을 여세요."; caption = "사냥 이어하기"
			elif main.deployed_heroes.size() < 3:
				text = "6/6 · 탱커·딜러·서포터 3명을 편성하고 첫 레이드에 도전하세요."
				if main.selected_faction=="noxfera":text="6/6 · 탱커·딜러·제어 영웅으로 3인 편성을 준비하세요. 회복 영웅은 스테이지 5에서 열려요."
				caption = "3명 편성하기"; route = "party"
			else:
				var recommended: int = preload("res://scripts/RaidBalance.gd").stats(main._zone_data().gray_meadow).recommended_power
				text = "6/6 · 첫 레이드에 도전하세요. 현재 전투력 %d / 권장 %d.\n입장 비용은 없고 승리할 때 보상을 받아요. 위험 구역 밖으로 이동하거나 회피하세요. 실패하면 편성과 성장을 점검하세요." % [main._calculate_party_power(), recommended]
				caption = "첫 레이드 준비"; route = "raid"
	return {"text":text, "short":short, "caption":caption, "route":route}

static func follow(main: Node) -> void:
	if main._save_blocked_for_newer_version or preload("res://scripts/SaveSafety.gd").pending(main) or bool(main.get_meta("practice_active", false)) or main.raid_running: return
	main._refresh_tutorial_state()
	var state := status(main)
	var overlay: Node = main.content_root.get_node_or_null("MenuOverlay")
	if is_instance_valid(overlay): overlay.hide(); overlay.queue_free()
	match str(state.route):
		"faction": main._build_faction_screen()
		"party": main._build_hero_select_screen()
		"research":
			main.set_meta("hero_showcase_tab","growth")
			main._build_hero_detail_screen(str(main.deployed_heroes[0].id))
		"enhance": main._build_equipment_detail("", str(main.deployed_heroes[0].id), "weapon", "enhance")
		"raid": main.selected_raid_id = "gray_meadow"; main._build_raid_screen()
		_:
			if main.active_screen == "combat" and not is_instance_valid(overlay) and main.combat_running: preload("res://scripts/UiChrome.gd").guide(main)
			else: main._open_home()
