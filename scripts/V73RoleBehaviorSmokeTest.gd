extends SceneTree

const PARTY = preload("res://scripts/PartyMovementDirector.gd")
const DECISIONS = preload("res://scripts/CombatDecisionEngine.gd")
const TACTICS = preload("res://scripts/AutoCombatTactics.gd")
const ROSTER = preload("res://scripts/HeroRosterCatalog.gd")
const IDENTITY = preload("res://scripts/HeroIdentityCatalog.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("V73 role behavior: " + label)

func _state(role: String, style: String, attack_range: int, slot := 0, row := "middle", hp := 1000, attack := 100) -> Dictionary:
	return {
		"hp":hp, "max_hp":1000, "attack":attack, "range":attack_range,
		"role_group":role, "ai_style":style, "slot":slot, "row":row, "alive":true
	}

func _enemy(hp := 1000, archetype := "brute", attack := 60, elite := false) -> Dictionary:
	return {"hp":hp,"max_hp":1000,"row":0,"archetype":archetype,"attack":attack,"elite":elite,"alive":true}

func _run() -> void:
	_test_all_roster_profiles()
	_test_target_identity()
	_test_skill_timing()
	_test_role_positions()
	_test_target_spread_caps()
	print("V73RoleBehaviorSmokeTest: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_all_roster_profiles() -> void:
	var identity := IDENTITY.new()
	var heroes: Array = []
	var states: Dictionary = {}
	var slot := 0
	for id_value in ROSTER.HEROES:
		var hero_id := str(id_value)
		var roster: Dictionary = ROSTER.HEROES[hero_id]
		var profile: Dictionary = identity.profile(hero_id)
		var role := str(roster.get("role_group", "딜러"))
		var style := str(profile.get("ai_style", "balanced"))
		var reach := 1 if str(roster.get("reach", "ranged")) == "melee" else 3
		heroes.append({"id":hero_id})
		states[hero_id] = _state(role, style, reach, slot, "front" if slot < 3 else ("middle" if slot < 7 else "rear"))
		slot += 1
	var party := PARTY.new()
	party.configure(heroes, states, Vector2(16, 10))
	check(party.movement_profiles.size() == ROSTER.HEROES.size(), "all 30 roster heroes receive a movement profile")
	for id_value in ROSTER.HEROES:
		var hero_id := str(id_value)
		var state: Dictionary = states[hero_id]
		var movement: Dictionary = party.movement_profiles[hero_id]
		var role := str(state["role_group"])
		var style := str(state["ai_style"])
		if role == "탱커":
			check(bool(movement.get("frontline_screen", false)), hero_id + " tank receives frontline screen behavior")
		if role == "서포터":
			check(bool(movement.get("rear_support", false)), hero_id + " support receives rear-line behavior")
		if role == "컨트롤러":
			check(bool(movement.get("lateral_control", false)), hero_id + " controller receives lateral control behavior")
		if str(ROSTER.HEROES[hero_id].get("reach", "ranged")) == "melee" and style in ["aggressive", "finisher"]:
			check(bool(movement.get("flanker", false)), hero_id + " pressure melee receives flanking behavior")

func _test_target_identity() -> void:
	var decisions := DECISIONS.new()
	var distances: Array = [1.0, 1.0, 1.0]
	var enemies: Array = [_enemy(1000, "brute"), _enemy(1000, "support"), _enemy(1000, "ranged")]
	var aggressive := _state("딜러", "aggressive", 3)
	check(decisions.select_enemy_target(aggressive, enemies, distances) == 1, "aggressive dealer pressures exposed support targets")
	var finisher := _state("딜러", "finisher", 3)
	enemies = [_enemy(220, "brute"), _enemy(1000, "support"), _enemy(1000, "ranged")]
	check(decisions.select_enemy_target(finisher, enemies, distances) == 0, "finisher stays on the wounded execute target")
	var sustain := _state("딜러", "sustain", 2, 0, "middle", 300, 100)
	enemies = [_enemy(10, "brute", 30), _enemy(650, "brute", 30)]
	check(decisions.select_enemy_target(sustain, enemies, [1.0, 1.0]) == 1, "injured sustain dealer avoids a nearly empty target that cannot return useful life")

func _test_skill_timing() -> void:
	var tactics := TACTICS.new()
	var party := {"alive":4,"injured":0,"avg_hp":1.0,"lowest_hp":1.0}
	var boss := {"is_raid":false,"telegraph":false,"telegraph_remaining":0.0,"boss_hp_ratio":1.0}
	var healthy := {"alive":2,"elites":0,"supports":0,"assassins":0,"total_attack":120,"lowest_hp":0.95}
	var wounded := healthy.duplicate(true)
	wounded["lowest_hp"] = 0.30
	var finisher := _state("딜러", "finisher", 3)
	var damage := {"kind":"damage"}
	check(tactics.skill_priority(damage, finisher, party, healthy, boss) < TACTICS.CAST_THRESHOLD, "finisher holds ordinary burst while all normal targets are healthy")
	check(tactics.skill_priority(damage, finisher, party, wounded, boss) >= TACTICS.CAST_THRESHOLD, "finisher releases burst inside an execute window")
	var high_hp_damage := {"kind":"damage","high_hp_threshold":0.7,"high_hp_bonus":1.25}
	check(tactics.skill_priority(high_hp_damage, finisher, party, healthy, boss) >= TACTICS.CAST_THRESHOLD, "high-HP sniper kit overrides generic finisher hesitation")
	var aggressive := _state("딜러", "aggressive", 3)
	var balanced := _state("딜러", "balanced", 3)
	var pack := {"alive":4,"elites":0,"supports":1,"assassins":0,"total_attack":240,"lowest_hp":0.9}
	check(tactics.skill_priority(damage, aggressive, party, pack, boss) > tactics.skill_priority(damage, balanced, party, pack, boss), "aggressive dealer spends damage cooldowns faster into a dense pack")
	check(tactics.ultimate_priority("딜러", finisher, party, healthy, boss) < TACTICS.CAST_THRESHOLD, "finisher stores ultimate on healthy normal cleanup")
	check(tactics.ultimate_priority("딜러", finisher, party, wounded, boss) >= TACTICS.CAST_THRESHOLD, "finisher commits ultimate when a kill window opens")
	var high_hp_ultimate := {"high_hp_threshold":0.70,"high_hp_bonus":1.20}
	check(tactics.ultimate_priority("딜러", finisher, party, healthy, boss, high_hp_ultimate) >= TACTICS.CAST_THRESHOLD, "authored high-HP finisher ultimate keeps its sniper timing")

func _test_role_positions() -> void:
	var center := Vector2(10, 10)
	var enemy_position := Vector2(12, 10)
	var enemies: Array = [_enemy()]
	var enemy_positions: Array[Vector2] = [enemy_position]
	var homes: Array[Vector2] = [enemy_position]

	var tank_party := PARTY.new()
	var tank_heroes: Array = [{"id":"leonhardt"},{"id":"elisia"}]
	var tank_states := {
		"leonhardt":_state("탱커","protector",1,0,"front"),
		"elisia":_state("서포터","support",3,9,"rear")
	}
	tank_party.configure(tank_heroes, tank_states, center)
	tank_party.positions["leonhardt"] = Vector2(10.5, 10)
	tank_party.positions["elisia"] = Vector2(9.5, 10)
	var tank_goal: Vector2 = tank_party._combat_goal("leonhardt", tank_party.positions["leonhardt"], 0, tank_states["leonhardt"], {}, tank_states, tank_party.positions.duplicate(), enemies, enemy_positions, [], homes)
	check(tank_goal.x < enemy_position.x and tank_goal.x > 10.8, "tank occupies the party-facing screen point in front of the threat")
	check(tank_goal.distance_to(enemy_position) <= PARTY.FRONTLINE_SCREEN_DISTANCE + 0.05, "tank screen point remains inside melee reach")

	var flank_party := PARTY.new()
	var flank_heroes: Array = [{"id":"ragna"},{"id":"garm"}]
	var flank_states := {
		"ragna":_state("딜러","aggressive",1,1,"front"),
		"garm":_state("탱커","protector",1,0,"front")
	}
	flank_party.configure(flank_heroes, flank_states, center)
	flank_party.positions["ragna"] = Vector2(10.5, 10)
	flank_party.positions["garm"] = Vector2(10.0, 10)
	var flank_goal: Vector2 = flank_party._combat_goal("ragna", flank_party.positions["ragna"], 0, flank_states["ragna"], {}, flank_states, flank_party.positions.duplicate(), enemies, enemy_positions, [], homes)
	check(absf(flank_goal.y - enemy_position.y) > 0.45, "aggressive melee approaches from a visible side lane")
	check(flank_goal.distance_to(enemy_position) <= PARTY.FLANK_STANDOFF + 0.05, "flanking point remains inside melee attack spacing")

	var support_party := PARTY.new()
	var support_heroes: Array = [{"id":"elisia"},{"id":"leonhardt"}]
	var support_states := {
		"elisia":_state("서포터","support",3,9,"rear"),
		"leonhardt":_state("탱커","protector",1,0,"front")
	}
	support_party.configure(support_heroes, support_states, center)
	support_party.positions["elisia"] = Vector2(9.4, 10)
	support_party.positions["leonhardt"] = Vector2(10.5, 10)
	var support_goal: Vector2 = support_party._combat_goal("elisia", support_party.positions["elisia"], 0, support_states["elisia"], {}, support_states, support_party.positions.duplicate(), enemies, enemy_positions, [], homes)
	check(support_goal.x <= support_party.positions["leonhardt"].x + 0.05, "support firing point stays behind the frontline ally")
	check(support_goal.distance_to(enemy_position) <= DECISIONS.new().spatial_range(3), "support remains inside real casting range")

	var control_party := PARTY.new()
	var control_heroes: Array = [{"id":"kairen"},{"id":"leonhardt"}]
	var control_states := {
		"kairen":_state("컨트롤러","controller",3,4,"middle"),
		"leonhardt":_state("탱커","protector",1,0,"front")
	}
	control_party.configure(control_heroes, control_states, center)
	control_party.positions["kairen"] = Vector2(10.4, 10)
	control_party.positions["leonhardt"] = Vector2(10.8, 10)
	var control_goal: Vector2 = control_party._combat_goal("kairen", control_party.positions["kairen"], 0, control_states["kairen"], {}, control_states, control_party.positions.duplicate(), enemies, enemy_positions, [], homes)
	check(absf(control_goal.y - 10.0) > 0.25, "controller claims a lateral casting lane instead of stacking directly behind the tank")

func _test_target_spread_caps() -> void:
	var party := PARTY.new()
	var normal := _enemy(1000, "brute")
	var support := _enemy(1000, "support")
	check(party._target_soft_cap(_state("컨트롤러","controller",3), normal) == 1, "controllers spread limited control across fresh normal targets")
	check(party._target_soft_cap(_state("탱커","protector",1), normal) == 2, "tanks may share a dangerous contact without dogpiling the whole party")
	check(party._target_soft_cap(_state("딜러","aggressive",1), support) == 1, "aggressive melee splits across exposed back-line targets")
	var elite := _enemy(1000, "brute", 60, true)
	check(party._target_soft_cap(_state("컨트롤러","controller",3), elite) == 2, "elite targets permit one extra controller when focus is tactically justified")
