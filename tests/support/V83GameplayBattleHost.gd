extends "res://scripts/portrait/PortraitMain.gd"
## Independent actual-HP trace for integration tests, not production metrics.
var audit_damage: int = 0
var audit_raw_damage: int = 0
var audit_lowest_hp: Dictionary = {}
var audit_sources: Dictionary = {}
var audit_taken: Dictionary = {}
var audit_healing: Dictionary = {}
var audit_enemy_contacts: int = 0
func auditing() -> bool:
	return challenge_session != null and challenge_session.is_running() and challenge_session.elapsed < challenge_session.limit_seconds and combat_running and not _application_suspended and hunt_ai.encounter_id == challenge_session.active_wave_token
func _damage_enemy(index: int, damage: int, source_index := 0) -> int:
	var watch: bool = auditing() and index >= 0 and index < enemy_wave.size()
	var target: Dictionary = enemy_wave[index] if watch else {}
	var before: int = int(target.get("hp",0))
	var key: String = str(challenge_session.serial) + ":" + str(target.get("id", "")) if watch else ""
	if watch and not audit_lowest_hp.has(key): audit_lowest_hp[key] = before
	var actual: int = super._damage_enemy(index,damage,source_index)
	if watch:
		audit_raw_damage += maxi(0,before-int(target.get("hp",0)))
		var delta: int = maxi(0, mini(before, int(audit_lowest_hp[key])) - int(target.get("hp", 0)))
		audit_lowest_hp[key] = mini(int(audit_lowest_hp[key]), int(target.get("hp", 0)))
		audit_damage+=delta
		audit_sources[source_index]=int(audit_sources.get(source_index,0))+delta
	return actual
func _incoming_damage_to_hero(id: String, amount: int, index: int = -1) -> int:
	if challenge_session==null and active_screen=='combat' and amount>0:audit_enemy_contacts+=1
	var watch: bool=auditing() and hero_battle_state.has(id)
	var state: Dictionary=hero_battle_state.get(id,{})
	var before: int=int(state.get("hp",0))
	var actual: int=super._incoming_damage_to_hero(id,amount,index)
	if watch: audit_taken[id]=int(audit_taken.get(id,0))+maxi(0,before-int(state.get("hp",0)))
	return actual
func _heal_hero(id: String, amount: int) -> int:
	var watch: bool=auditing() and hero_battle_state.has(id)
	var state: Dictionary=hero_battle_state.get(id,{})
	var before: int=int(state.get("hp",0))
	var actual: int=super._heal_hero(id,amount)
	if watch: audit_healing[id]=int(audit_healing.get(id,0))+maxi(0,int(state.get("hp",0))-before)
	return actual
