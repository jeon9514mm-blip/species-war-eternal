extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _unit(name: String, role: String, row: String, hp: int, attack: int, defense: int) -> Dictionary:
	return {"id": name, "name": name, "role": role, "row": row, "max_hp": hp, "hp": hp, "attack": attack, "defense": defense}

func _init() -> void:
	var resolver = WorldBattleResolver.new()
	var attackers: Array = []
	var defenders: Array = []
	for index in 10:
		var role = "딜러"
		var row = "중열"
		if index < 2:
			role = "탱커"
			row = "전열"
		elif index in [7, 8]:
			role = "서포터"
			row = "후열"
		elif index == 9:
			role = "암살자"
			row = "후열"
		attackers.append(_unit("A%d" % index, role, row, 650, 105, 18))
		defenders.append(_unit("D%d" % index, role, row, 430, 55, 12))
	var report = resolver.resolve(attackers, defenders, 0, 1.0, 12345)
	if not bool(report.get("victory", false)):
		_fail("V14: 우세 공격대 전투 승리 판정 실패")
		return
	if int(report.get("attacker_alive", 0)) <= 0 or int(report.get("defender_alive", 10)) != 0:
		_fail("V14: 생존자 집계 실패")
		return
	if int(report.get("rounds", 0)) <= 0 or int(report.get("attacker_damage", 0)) <= 0:
		_fail("V14: 전투 라운드/피해 기록 실패")
		return
	var repeated = resolver.resolve(attackers, defenders, 0, 1.0, 12345)
	if int(repeated.get("attacker_damage", 0)) != int(report.get("attacker_damage", 0)):
		_fail("V14: 비동기 전투 결정론 실패")
		return
	var garrison = resolver.make_garrison(WorldWarState.FACTION_NOXFERA, Vector2i(8, 8), "fort", 1800)
	if garrison.size() != 10:
		_fail("V14: 10인 수비대 스냅샷 생성 실패")
		return
	print("world_battle_resolver_smoke_test_ok deterministic=ok roles=ok garrison=10")
	quit(0)
