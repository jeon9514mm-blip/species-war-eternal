extends "res://tests/support/V83GameplayBattleHost.gd"
var raid_observed: Dictionary={"boss_damage":0,"guard_damage":0,"add_damage":0,"healing":0}
func _apply_raid_damage(amount: int, source_id: String = "") -> int:
	var body: int=raid_boss_hp;var armor: int=raid_guard_hp;var cores: int=raid_add_hp
	var actual: int=super._apply_raid_damage(amount,source_id)
	raid_observed.boss_damage+=maxi(0,body-raid_boss_hp)
	raid_observed.guard_damage+=maxi(0,armor-raid_guard_hp)
	raid_observed.add_damage+=maxi(0,cores-raid_add_hp)
	return actual
func _heal_hero(id: String, amount: int) -> int:
	var state: Dictionary=hero_battle_state.get(id,{})
	var before: int=int(state.get("hp",0))
	var actual: int=super._heal_hero(id,amount)
	if raid_running:raid_observed.healing+=maxi(0,int(state.get("hp",0))-before)
	return actual
