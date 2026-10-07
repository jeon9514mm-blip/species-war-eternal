extends RefCounted
## Advice is based on the failed encounter's actual party and outcome.
static func advice(main: Node) -> Dictionary:
	var zone: Dictionary = main._zone_data().get(main.raid_encounter_zone, main._current_zone())
	var recommended: int = preload("res://scripts/raid/RaidBalance.gd").stats(zone).recommended_power
	var roles: Array[String] = []
	for hero in main.deployed_heroes: roles.append(str(hero.get("role_group", "")))
	var text := "현재 전투력 %d / 권장 %d." % [main.party_power, recommended]
	var route := "growth"
	var caption := "성장 점검하기"
	if str(main.raid_outcome) == "timeout":
		text += " 공격 영웅의 무기와 공격 연구를 올린 뒤 다시 도전하세요."
	elif not "탱커" in roles or not "서포터" in roles:
		var missing: String="탱커" if not "탱커" in roles else "서포터"
		var unlock: int=10000
		for hero in main._hero_roster_for_faction():
			if str(hero.get("role_group",""))==missing:unlock=mini(unlock,int(hero.unlock_stage))
		if main.idle_stage<unlock:
			text += " %s는 스테이지 %d에서 열려요. 먼저 사냥으로 해금하고 편성하세요."%[missing,unlock]
			route="hunt";caption="사냥으로 역할 해금"
		else:
			text += " 편성에 %s를 넣어 %s을 보완하세요."%[missing,"전열" if missing=="탱커" else "회복"]
			route = "party"; caption = "편성 보완하기"
	elif main.party_power < recommended:
		text += " 권장 전투력까지 장비·연구를 강화하고, 전열 방어와 회복을 점검하세요."
	else:
		text += " 전열 방어와 회복을 점검하세요."
	if main.raid_pattern_count > main.raid_interrupt_count and main.raid_evaded_hits == 0:
		text += "\n패턴 회피 기록이 없어요. 예고된 위험 구역 밖으로 이동하거나 회피하세요."
	return {"text":text, "route":route, "caption":caption}
