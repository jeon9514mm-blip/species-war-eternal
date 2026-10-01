extends RefCounted

## v83: LegacyQuestService. Main remains the single owner of mutable game state.
## The injected host supplies state, virtual UI hooks and runtime refreshes.
## No cached host reference, duplicate wallet, RNG or save schema is introduced.

static func quest_status(main: Node, quest_id: String) -> Dictionary:
	match quest_id:
		"stage5":
			return {"title": "스테이지 5 도달", "current": mini(main.idle_stage, 5), "target": 5, "complete": main.idle_stage >= 5}
		"raid1":
			var total = 0
			for value in main.raid_clears.values():
				total += int(value)
			return {"title": "레이드 1회 클리어", "current": mini(total, 1), "target": 1, "complete": total >= 1}
		"tower5":
			return {"title": "무한탑 5층 돌파", "current": mini(main.tower_best_floor, 5), "target": 5, "complete": main.tower_best_floor >= 5}
	return {"title": "원정 성장", "current": 0, "target": 1, "complete": false}


static func auto_track_quest(main: Node) -> void:
	if not main.tracked_quest_id.is_empty() and not bool(main.quest_claimed.get(main.tracked_quest_id, false)):
		return
	for id in ["stage5", "raid1", "tower5"]:
		if not bool(main.quest_claimed.get(id, false)):
			main.tracked_quest_id = id
			return
	main.tracked_quest_id = ""


static func legacy_tracked_quest_text(main: Node) -> String:
	main._auto_track_quest()
	if main.tracked_quest_id.is_empty():
		return "모든 핵심 퀘스트 완료"
	var q = main._quest_status(main.tracked_quest_id)
	return "%s %d/%d%s" % [str(q["title"]), int(q["current"]), int(q["target"]), " · 보상 가능" if bool(q["complete"]) else ""]


static func refresh_tutorial_state(main: Node) -> void:
	if main.tutorial_completed:
		return
	var old_step = main.tutorial_step
	if main.selected_faction.is_empty():
		main.tutorial_step = 0
	elif main.deployed_heroes.is_empty():
		main.tutorial_step = 1
	elif main.idle_stage == 1 and main.idle_stage_kills == 0 and main.combat_kills == 0:
		main.tutorial_step = 2
	elif main.idle_stage < 2 and main.unclaimed_gold + main.unclaimed_xp <= 0:
		main.tutorial_step = 3
	elif main.loot_inventory.is_empty() and int(main._get_hero_progress(str(main.deployed_heroes[0]["id"])).get("level", 1)) <= 1:
		main.tutorial_step = 4
	else:
		var raid_total = 0
		for value in main.raid_clears.values():
			raid_total += int(value)
		if raid_total <= 0 and main.tower_best_floor <= 0:
			main.tutorial_step = 5
		else:
			main.tutorial_step = 6
			main.tutorial_completed = true
	if old_step != main.tutorial_step:
		main._save_idle_state()


static func tutorial_text(main: Node) -> String:
	main._refresh_tutorial_state()
	match main.tutorial_step:
		0: return "1/6 · 진영을 선택하세요. 두 진영은 영웅과 시작 수호신이 달라집니다."
		1: return "2/6 · 첫 영웅 1명을 편성하세요. 사냥 진행에 따라 3→5→7→10인으로 확장됩니다."
		2: return "3/6 · 자동사냥을 시작해 첫 몬스터 무리를 처치하세요."
		3: return "4/6 · 누적 보상을 수령하고 다음 스테이지를 향해 진행하세요."
		4: return "5/6 · 장비 또는 스킬트리를 강화해 전투력을 올리세요."
		5: return "6/6 · 월드맵에서 보스 레이드나 무한탑에 도전하세요."
	return "초반 원정 가이드 완료 · 이제 자유롭게 원정대를 성장시키세요."


static func claim_quest(main: Node, quest_id: String) -> bool:
	if bool(main.quest_claimed.get(quest_id, false)):
		return false
	var complete = false
	var gold_reward = 0
	var gem_reward = 0
	match quest_id:
		"stage5":
			complete = main.idle_stage >= 5
			gold_reward = 500
			gem_reward = 20
		"raid1":
			var total_raids = 0
			for value in main.raid_clears.values():
				total_raids += int(value)
			complete = total_raids >= 1
			gold_reward = 800
			gem_reward = 30
		"tower5":
			complete = main.tower_best_floor >= 5
			gold_reward = 1000
			gem_reward = 40
	if not complete:
		main._show_toast("아직 퀘스트 조건을 달성하지 못했습니다.")
		return false
	main.quest_claimed[quest_id] = true
	if main.tracked_quest_id == quest_id:
		main.tracked_quest_id = ""
	main._auto_track_quest()
	main.wallet_gold += gold_reward
	main.wallet_gems += gem_reward
	main._show_toast("퀘스트 완료 · 골드 +%d · 젬 +%d" % [gold_reward, gem_reward])
	main._save_idle_state()
	return true


static func quest_ready_count(main: Node) -> int:
	var count = 0
	if main.idle_stage >= 5 and not bool(main.quest_claimed.get("stage5", false)):
		count += 1
	var total_raids = 0
	for value in main.raid_clears.values():
		total_raids += int(value)
	if total_raids >= 1 and not bool(main.quest_claimed.get("raid1", false)):
		count += 1
	if main.tower_best_floor >= 5 and not bool(main.quest_claimed.get("tower5", false)):
		count += 1
	return count
