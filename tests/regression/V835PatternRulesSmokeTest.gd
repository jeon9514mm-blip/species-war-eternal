extends SceneTree
const RULES = preload("res://scripts/combat/ChallengePatternRules.gd")
const RUNTIME = preload("res://scripts/combat/ChallengePatternRuntime.gd")
const TOWER = preload("res://scripts/progression/TowerBattleRules.gd")
const ABYSS = preload("res://scripts/progression/WeeklyAbyssBattleRules.gd")
var checks: int = 0
var failures: Array[String] = []
class Fixture extends Node:
	var challenge_session: ChallengeBattleSession
	var challenge_serial: int = 835
	var active_screen: String = "combat"
	var combat_running: bool = true
	var _application_suspended: bool = false
	var enemy_wave: Array = []
	var enemy_wave_sprites: Array = []
	var hero_battle_state: Dictionary = {"hero":{"hp":10000}}
	var hunt_ai := AutoHuntController.new()
	var roaming_hunt := RoamingHuntDirector.new()
	var skill_event_text: String = ""
	var hits: int = 0
	func _heal_enemy(index: int, amount: int) -> int:
		var enemy: Dictionary = enemy_wave[index]
		var actual: int = mini(amount, int(enemy["max_hp"]) - int(enemy["hp"]))
		enemy["hp"] += actual; return actual
	func _hero_field_position(_id: String) -> Vector2: return Vector2(16.1,10)
	func _enemy_attack_range(_enemy: Dictionary) -> float: return 0.92
	func _select_hero_target_for_enemy(_index: int, _range: bool) -> String: return "hero"
	func _incoming_damage_to_hero(_id: String, _amount: int, _enemy: int) -> int: hits += 1; return 1
	func _presentation_event(_event: String) -> void: pass
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func _init() -> void: _run.call_deferred()
func make_session(pattern: String) -> ChallengeBattleSession:
	var session := ChallengeBattleSession.new()
	session.begin(835, {"mode":"weekly","objective":"score","required_waves":0,"limit_seconds":90.0,"pattern":{"id":pattern,"version":1}}, {})
	session.cleared_waves = 1; session.start_wave(10)
	return session
func _run() -> void:
	check(TOWER.plan(9)["pattern"].is_empty(), "first nine floors unchanged")
	for floor_number in range(10, 80):
		var plan: Dictionary = TOWER.plan(floor_number)
		check(plan["pattern"]["id"] == RULES.IDS[(floor_number-10)%3], "tower predictable pattern")
		check(TOWER.reward(floor_number) == {"gold":250+90*floor_number,"gems":2+int(floor_number/5.0)}, "tower reward unchanged")
	for week in range(2958, 2964):
		var plan: Dictionary = ABYSS.plan(str(week))
		check(plan["pattern"]["id"] == RULES.IDS[posmod(week,3)], "same week deterministic pattern")
	for pattern: String in RULES.IDS:
		var session: ChallengeBattleSession = make_session(pattern)
		var enemies: Array = [{"id":"boss","name":"철갑 두더지","hp":18000,"max_hp":18000,"attack":26,"elite":true,"challenge_boss":true}]
		RULES.prepare_enemies(session,enemies)
		var total_hp: int = 0; var total_attack: int = 0
		for enemy in enemies:
			total_hp += int(enemy["hp"]); total_attack += int(enemy["attack"])
			check(session.register_score_target(10, enemy["id"], enemy["hp"]), "register bounded distinct HP budget")
		check(total_hp == 18000 and total_attack == 26, "encounter base budgets conserved "+pattern)
		var boss_hp: int = int(enemies[0]["hp"])
		check(session.record_hp_loss(10,"boss",boss_hp,boss_hp-100)==100, "new minimum scores")
		check(session.record_hp_loss(10,"boss",boss_hp,boss_hp-100)==0, "duplicate does not score")
		check(session.record_hp_loss(10,"boss",boss_hp,boss_hp-50)==0, "rehealed HP cannot farm score")
		check(session.record_hp_loss(10,"boss",boss_hp-50,boss_hp-150)==50, "only new minimum after heal scores")
	var f := Fixture.new(); root.add_child(f)
	f.challenge_session = make_session("healing_guard"); f.hunt_ai.encounter_id = 10
	f.enemy_wave = [{"id":"boss","name":"철갑 두더지","hp":18000,"max_hp":18000,"attack":26,"elite":true,"challenge_boss":true}]
	RULES.prepare_enemies(f.challenge_session,f.enemy_wave); f.roaming_hunt.configure(Vector2(16,10),835); f.roaming_hunt.spawn_group(f.enemy_wave)
	for i in f.enemy_wave.size(): f.roaming_hunt.enemy_positions[i] = Vector2(16 + i*0.3,10)
	# Synthetic HP fixture only; natural AI playthrough is a separate script.
	for pulse in 7:
		f.enemy_wave[0]["hp"] = int(f.enemy_wave[0]["max_hp"])-2000
		RUNTIME.tick_enemy(f,1,4.0)
	check(f.challenge_session.pattern_metrics.get("heals",0)==3 and f.enemy_wave[1]["pattern_heals_left"]==0, "healer finite 3 pulses, no generic fallback")
	f.challenge_session = make_session("charged_strike")
	f.enemy_wave = [{"id":"charge","hp":10000,"max_hp":10000,"attack":26,"stun_seconds":0.0}]
	RULES.prepare_enemies(f.challenge_session,f.enemy_wave); f.roaming_hunt.spawn_group(f.enemy_wave); f.roaming_hunt.enemy_positions[0] = Vector2(16,10)
	f.enemy_wave[0]["pattern_cooldown"] = 0.0
	check(RUNTIME.tick_enemy(f,0,0.1) and f.hits==0, "cast starts without instant damage")
	f._application_suspended = true; var remaining: float = f.enemy_wave[0]["pattern_cast_remaining"]
	RUNTIME.tick_enemy(f,0,1.0)
	check(f.enemy_wave[0]["pattern_cast_remaining"]==remaining and f.hits==0, "background pauses cast")
	f._application_suspended = false; f.combat_running = false; RUNTIME.tick_enemy(f,0,1.0)
	check(f.enemy_wave[0]["pattern_cast_remaining"]==remaining, "pause freezes cast")
	f.combat_running = true; RUNTIME.interrupt(f,0); RUNTIME.interrupt(f,0)
	check(f.challenge_session.pattern_metrics.get("interrupts",0)==1 and f.hits==0, "interrupt consumes once")
	f.enemy_wave[0]["pattern_cooldown"] = 0.0; RUNTIME.tick_enemy(f,0,0.1); RUNTIME.tick_enemy(f,0,1.9)
	check(f.hits==0,"no early cast hit")
	RUNTIME.tick_enemy(f,0,0.1); check(f.hits==1,"deadline hit exactly once")
	f.challenge_session.cancel(); RUNTIME.tick_enemy(f,0,100.0)
	check(f.hits==1, "cancelled session cannot damage")
	f.free()
	var a: Dictionary = {"pattern":{"id":"healing_guard","version":1}}
	var b: Dictionary = {"pattern":{"id":"healing_guard","version":2}}
	check(preload("res://scripts/combat/ChallengeCombatLedger.gd").comparison_key(a)!=preload("res://scripts/combat/ChallengeCombatLedger.gd").comparison_key(b),"rule version separates comparisons")
	print("v835_pattern_rules checks=%d failures=%s" % [checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
