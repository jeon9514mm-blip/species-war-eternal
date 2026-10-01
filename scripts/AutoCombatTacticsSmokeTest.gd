extends SceneTree

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _state(hp: int, max_hp: int, role := "딜러") -> Dictionary:
	return {"hp": hp, "max_hp": max_hp, "role_group": role}

func _init() -> void:
	var tactics = AutoCombatTactics.new()
	var party = {
		"tank": _state(1000, 1000, "탱커"),
		"heal": _state(420, 900, "서포터"),
		"dps": _state(750, 900, "딜러")
	}
	var normal_wave = [
		{"hp": 100, "max_hp": 100, "attack": 10, "elite": false, "archetype": "brute"}
	]
	var elite_wave = [
		{"hp": 500, "max_hp": 500, "attack": 40, "elite": true, "archetype": "support"},
		{"hp": 300, "max_hp": 300, "attack": 35, "elite": false, "archetype": "assassin"},
		{"hp": 300, "max_hp": 300, "attack": 20, "elite": false, "archetype": "brute"}
	]
	var party_ctx = tactics.party_context(party)
	var normal_ctx = tactics.enemy_context(normal_wave)
	var elite_ctx = tactics.enemy_context(elite_wave)
	var no_boss = tactics.boss_context(false, false, 0.0, 0, 1)
	var telegraph = tactics.boss_context(true, true, 0.8, 8000, 10000)

	var heal_profile = {"kind":"heal","threshold":0.72}
	if not tactics.should_use_skill(heal_profile, party["heal"], party_ctx, normal_ctx, no_boss):
		_fail("V18: 저체력 힐 우선순위 실패")
		return
	var guard_profile = {"kind":"guard"}
	if tactics.should_use_skill(guard_profile, party["tank"], party_ctx, normal_ctx, no_boss):
		_fail("V18: 잡몹 1마리에 방어기 낭비")
		return
	if not tactics.should_use_skill(guard_profile, party["tank"], party_ctx, normal_ctx, telegraph):
		_fail("V18: 보스 예고 공격 방어 대응 실패")
		return
	if not tactics.should_use_ultimate("컨트롤러", party["dps"], party_ctx, elite_ctx, no_boss):
		_fail("V18: 정예전 컨트롤 궁극기 우선순위 실패")
		return
	var almost_dead = [{"hp":10,"max_hp":100,"attack":5,"elite":false,"archetype":"brute"}]
	if tactics.should_use_ultimate("딜러", party["dps"], party_ctx, tactics.enemy_context(almost_dead), no_boss):
		_fail("V18: 빈사 잡몹에 딜러 궁극기 낭비")
		return
	print("auto_combat_tactics_smoke_test_ok heal=smart guard=smart elite=priority ultimate=held")
	quit(0)
