extends RefCounted

## v83: HeroProgressionService. Main remains the single owner of mutable game state.
## The injected host supplies state, virtual UI hooks and runtime refreshes.
## No cached host reference, duplicate wallet, RNG or save schema is introduced.

static func hero_xp_to_next(main: Node, level: int) -> int:
	return preload("res://scripts/progression/GrowthEconomyRules.gd").xp_cost(level,main.MAX_HERO_LEVEL)


static func valid_growth_hero(main: Node, hero_id: String) -> bool:
	var hero: Dictionary = preload("res://scripts/heroes/HeroRosterCatalog.gd").HEROES.get(hero_id, {})
	return not hero.is_empty() and str(hero.get("faction", "")) == str(main.selected_faction)


static func refresh_growth_runtime(main: Node) -> void:
	main.party_power = main._calculate_party_power()
	# The combat owner supplies this hook; keep growth usable in isolation.
	if main.has_method("_refresh_hero_growth_stats"):
		main.call("_refresh_hero_growth_stats")


static func setup_hero_progress(main: Node, roster: Array) -> void:
	for hero in roster:
		var hero_id = str(hero["id"])
		if not main.hero_progress.has(hero_id):
			main.hero_progress[hero_id] = {"level": 1, "xp": 0}
		if not main.hero_equipment.has(hero_id):
			main.hero_equipment[hero_id] = {"weapon": 1, "armor": 1, "accessory": 1}
		if not main.hero_equipment_rarity.has(hero_id):
			main.hero_equipment_rarity[hero_id] = {"weapon": "일반", "armor": "일반", "accessory": "일반"}
		if not main.hero_equipment_names.has(hero_id):
			main.hero_equipment_names[hero_id] = {"weapon": "초보자의 검", "armor": "초보자의 가죽갑옷", "accessory": "빛바랜 부적"}
		main._get_hero_equipment_sets(hero_id)
		main._get_skill_tree(hero_id)


static func get_skill_tree(main: Node, hero_id: String) -> Dictionary:
	if not main._valid_growth_hero(hero_id):
		return {"offense": 0, "survival": 0, "utility": 0}
	if not main.hero_skill_tree.has(hero_id) or typeof(main.hero_skill_tree[hero_id]) != TYPE_DICTIONARY:
		main.hero_skill_tree[hero_id] = {"offense": 0, "survival": 0, "utility": 0}
	var tree: Dictionary = main.hero_skill_tree[hero_id]
	var budget = main._skill_tree_total_points(hero_id)
	for branch in ["offense", "survival", "utility"]:
		tree[branch] = clampi(int(tree.get(branch, 0)), 0, mini(10, budget))
		budget -= int(tree[branch])
	main.hero_skill_tree[hero_id] = tree
	return tree


static func skill_tree_spent(main: Node, hero_id: String) -> int:
	var tree = main._get_skill_tree(hero_id)
	return int(tree.get("offense", 0)) + int(tree.get("survival", 0)) + int(tree.get("utility", 0))


static func skill_tree_total_points(main: Node, hero_id: String) -> int:
	var level = int(main._get_hero_progress(hero_id).get("level", 1))
	return clampi(int((level - 1) / 3.0), 0, 30)


static func skill_tree_available_points(main: Node, hero_id: String) -> int:
	return maxi(0, main._skill_tree_total_points(hero_id) - main._skill_tree_spent(hero_id))


static func upgrade_skill_tree(main: Node, hero_id: String, branch: String) -> void:
	if bool(main.get_meta("practice_active", false)) or preload("res://scripts/persistence/SaveSafety.gd").pending(main):
		main._show_toast("연습 또는 저장 대기를 마친 뒤 연구를 변경하세요."); return
	if not main._valid_growth_hero(hero_id) or branch not in ["offense", "survival", "utility"]:
		return
	if main._skill_tree_available_points(hero_id) <= 0:
		main._show_toast("사용 가능한 스킬 포인트가 없습니다. 영웅 레벨을 올려보세요.")
		return
	var tree = main._get_skill_tree(hero_id)
	if int(tree.get(branch, 0)) >= 10:
		main._show_toast("해당 스킬트리는 최대 10단계입니다.")
		return
	tree[branch] = int(tree.get(branch, 0)) + 1
	main.hero_skill_tree[hero_id] = tree
	main._record_first_session_action("growth")
	main._refresh_growth_runtime()
	main._save_idle_state()
	if main.active_screen not in ["combat", "raid"]:
		main._build_growth_screen()
	else:
		main._update_hero_progress_label()


@warning_ignore("unused_parameter")
static func skill_tree_branch_text(main: Node, branch: String, rank: int) -> String:
	match branch:
		"offense": return "공격 %d · 공격력 +%d%%" % [rank, rank * 4]
		"survival": return "생존 %d · HP +%d%% / 방어 +%d" % [rank, rank * 5, rank]
		"utility": return "기능 %d · 쿨다운 -%d%% / 궁극기 충전 +%d%%" % [rank, rank * 3, rank * 5]
	return ""


static func get_hero_progress(main: Node, hero_id: String) -> Dictionary:
	if not main._valid_growth_hero(hero_id):
		return {"level": 1, "xp": 0}
	if not main.hero_progress.has(hero_id) or not main.hero_progress[hero_id] is Dictionary:
		main.hero_progress[hero_id] = {"level": 1, "xp": 0}
	var progress: Dictionary = main.hero_progress[hero_id]
	progress["level"] = clampi(int(progress.get("level", 1)), 1, main.MAX_HERO_LEVEL)
	progress["xp"] = clampi(int(progress.get("xp", 0)), 0, 100000000) if int(progress["level"]) < main.MAX_HERO_LEVEL else 0
	return progress


static func grant_hero_xp(main: Node, amount: int) -> void:
	if amount <= 0 or main.deployed_heroes.is_empty():
		return
	var recipients: Array[String] = []
	var drafts: Dictionary = {}
	var old_levels: Dictionary = {}
	for hero in main.deployed_heroes:
		var hero_id: String = str(hero.get("id", ""))
		if not main._valid_growth_hero(hero_id) or drafts.has(hero_id):
			continue
		var progress: Dictionary = main._get_hero_progress(hero_id).duplicate(true)
		if int(progress["level"]) >= main.MAX_HERO_LEVEL:
			continue
		recipients.append(hero_id)
		drafts[hero_id] = progress
		old_levels[hero_id] = int(progress["level"])
	if recipients.is_empty():
		main.hero_level_event = "원정대 영웅이 최대 레벨입니다."
		return
	# Keep the existing per-award ceiling and remainder ordering. Only XP from
	# this award that could not fit below max level is redistributed.
	var total: int = mini(amount, 100000000)
	var remaining: int = total
	while remaining > 0 and not recipients.is_empty():
		recipients.sort_custom(func(a: String, b: String) -> bool:
			var pa: Dictionary = drafts[a]
			var pb: Dictionary = drafts[b]
			return int(pa["level"]) < int(pb["level"]) or (int(pa["level"]) == int(pb["level"]) and int(pa["xp"]) < int(pb["xp"]))
		)
		var round_pool: int = remaining
		var count: int = recipients.size()
		var per_hero: int = floori(float(round_pool) / float(count))
		var remainder: int = round_pool % count
		var next_recipients: Array[String] = []
		for index in count:
			var hero_id: String = recipients[index]
			var progress: Dictionary = drafts[hero_id]
			var allocated: int = per_hero + (1 if index < remainder else 0)
			var level: int = int(progress["level"])
			var xp: int = int(progress["xp"]) + allocated
			while level < main.MAX_HERO_LEVEL:
				var required: int = int(main._hero_xp_to_next(level))
				if required <= 0:
					push_error("레벨업 필요 경험치가 올바르지 않아 배분을 중단했습니다.")
					return
				if xp < required:
					break
				xp -= required
				level += 1
			var unused: int = 0
			if level >= main.MAX_HERO_LEVEL:
				# Never turn an old/malformed residual XP value into a new reward.
				unused = mini(allocated, maxi(0, xp))
				xp = 0
			else:
				next_recipients.append(hero_id)
			progress["level"] = level
			progress["xp"] = xp
			remaining -= allocated - unused
		# A residual pool must have retired at least one capped recipient.
		if remaining == round_pool and next_recipients.size() == count:
			push_error("경험치 배분이 진행되지 않아 적용을 중단했습니다.")
			return
		recipients = next_recipients
	var level_events: Array[String] = []
	for key in drafts:
		var hero_id: String = str(key)
		var progress: Dictionary = drafts[hero_id]
		main.hero_progress[hero_id] = progress
		if int(progress["level"]) > int(old_levels[hero_id]):
			level_events.append("%s Lv.%d" % [main._hero_short_name(hero_id), int(progress["level"])])
	var applied: int = total - remaining
	main.hero_level_event = "영웅 경험치 총 +%d 분배" % applied if level_events.is_empty() else "레벨업!  " + " · ".join(level_events)
	if remaining > 0:
		main.hero_level_event += " · 전원 최대 레벨, 미적용 XP %d" % remaining
	main._refresh_growth_runtime()


static func hero_base_grade_index(main: Node, hero_id: String) -> int:
	var roster = main._hero_roster_for_faction()
	for index in roster.size():
		if str(roster[index].get("id", "")) == hero_id:
			if index >= 7:
				return 2
			if index >= 3:
				return 1
			return 0
	return 0


static func hero_ascension_rank(main: Node, hero_id: String) -> int:
	return clampi(int(main.hero_ascension.get(hero_id, 0)), 0, 3)


static func hero_grade(main: Node, hero_id: String) -> String:
	var grades = ["R", "SR", "SSR", "UR"]
	var index = clampi(main._hero_base_grade_index(hero_id) + main._hero_ascension_rank(hero_id), 0, grades.size() - 1)
	return str(grades[index])


static func hero_grade_multiplier(main: Node, hero_id: String) -> float:
	return {"R": 1.0, "SR": 1.08, "SSR": 1.18, "UR": 1.32}.get(main._hero_grade(hero_id), 1.0)


static func ascension_requirement(main: Node, hero_id: String) -> Dictionary:
	var asc = main._hero_ascension_rank(hero_id)
	return {"level": 10 + asc * 10, "gold": 1200 + asc * 1800}


static func try_ascend_hero(main: Node, hero_id: String) -> bool:
	if not preload("res://scripts/persistence/SaveSafety.gd").allow_mutation(main): return false
	if not main._valid_growth_hero(hero_id):
		return false
	var base = main._hero_base_grade_index(hero_id)
	var asc = main._hero_ascension_rank(hero_id)
	if base + asc >= 3:
		main._show_toast("이미 최고 등급 UR입니다.")
		return false
	var req = main._ascension_requirement(hero_id)
	var level = int(main._get_hero_progress(hero_id).get("level", 1))
	if level < int(req["level"]):
		main._show_toast("승급에는 Lv.%d가 필요합니다." % int(req["level"]))
		return false
	if main.wallet_gold < int(req["gold"]):
		main._show_toast("승급 골드가 부족합니다. 필요 %dG" % int(req["gold"]))
		return false
	main.wallet_gold -= int(req["gold"])
	main.hero_ascension[hero_id] = asc + 1
	main._show_toast("%s · %s 승급!" % [main._hero_short_name(hero_id), main._hero_grade(hero_id)])
	main._refresh_growth_runtime()
	main._save_idle_state()
	return true


static func hero_shard_count(main: Node, hero_id: String) -> int:
	return maxi(0, int(main.hero_shards.get(hero_id, 0)))


static func hero_breakthrough_rank(main: Node, hero_id: String) -> int:
	return clampi(int(main.hero_breakthrough.get(hero_id, 0)), 0, 5)


@warning_ignore("unused_parameter")
static func breakthrough_cost(main: Node, rank: int) -> int:
	return 20 + rank * 20


static func try_breakthrough(main: Node, hero_id: String) -> bool:
	if not preload("res://scripts/persistence/SaveSafety.gd").allow_mutation(main): return false
	if not main._valid_growth_hero(hero_id):
		return false
	var rank = main._hero_breakthrough_rank(hero_id)
	if rank >= 5:
		main._show_toast("이미 최대 돌파입니다.")
		return false
	var cost = main._breakthrough_cost(rank)
	if main._hero_shard_count(hero_id) < cost:
		main._show_toast("영웅 조각이 부족합니다. 필요 %d" % cost)
		return false
	main.hero_shards[hero_id] = main._hero_shard_count(hero_id) - cost
	main.hero_breakthrough[hero_id] = rank + 1
	main._show_toast("%s · %d돌파 달성!" % [main._hero_short_name(hero_id), rank + 1])
	main._refresh_growth_runtime()
	main._save_idle_state()
	return true
