extends "res://tests/support/V83UpgradeTestBase.gd"
## The old values are independent fixtures, not values obtained from RaidBalance.
const BALANCE := preload("res://scripts/raid/RaidBalance.gd")
const ZONES := preload("res://scripts/maps/ZoneCatalog.gd")
const DESIGN := preload("res://scripts/raid/RaidBossDesign.gd")
const REPORT := preload("res://scripts/raid/RaidContributionService.gd")
const ARCHIVE := preload("res://scripts/raid/RaidReportArchive.gd")
const BASELINE := {
	"gray_meadow": {"hp": 3600, "attack": 60, "recommendation": 540},
	"forgotten_mine": {"hp": 7200, "attack": 120, "recommendation": 1080},
	"moonrest_forest": {"hp": 12400, "attack": 206, "recommendation": 1860},
}
var natural_results: Array[Dictionary] = []
var natural_snapshot: Dictionary = {}
var natural_parties: Dictionary = {}

class AttackProbe:
	extends "res://tests/support/V836RaidObserveHost.gd"
	var incoming_trace: Array[Dictionary] = []
	func _incoming_damage_to_hero(id: String, amount: int, index: int = -1) -> int:
		var actual: int = super._incoming_damage_to_hero(id, amount, index)
		incoming_trace.append({"hero": id, "raw": amount, "actual": actual})
		return actual

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = AttackProbe.new()
	game.save_state_path = "user://raid-strength-save.json"
	root.add_child(game)
	await settle()
	game.set_process(false)
	game.set_physics_process(false)
	game._offline_checked = true
	game.selected_faction = "aurelia"
	game.current_zone_id = "gray_meadow"
	game.idle_stage = 100
	game.party_slot_legacy_cap = 10
	game.combat_effects_enabled = false
	game.sound_effects_enabled = false
	game.set_meta("raid_report_path", "user://raid-strength-reports.json")
	var catalog: Dictionary = ZONES.all()
	var catalog_before: Dictionary = catalog.duplicate(true)
	for zone: String in BASELINE:
		var original: Dictionary = BASELINE[zone]
		var stats: Dictionary = BALANCE.stats(catalog[zone])
		check(stats.max_hp == original.hp * 10, zone + " HP exactly tenfold")
		check(stats.attack == original.attack * 10, zone + " attack rounded before tenfold scaling")
		check(stats.recommended_power == original.recommendation * 10, zone + " recommendation matches strength")
		_set_roster(game, 1, 60)
		for attempt in 3:
			await _start(game, zone)
			check(game.raid_boss_max_hp == stats.max_hp and game.raid_boss_hp == stats.max_hp and game.raid_boss_attack == stats.attack, zone + " repeat entry does not compound " + str(attempt))
			var serial: int = game.raid_encounter_serial
			game._start_raid()
			check(game.raid_encounter_serial == serial and game.raid_boss_attack == stats.attack, zone + " duplicate start is inert")
			game._finish_raid("cancelled")
			_check_report(game, zone, stats)
		await _start(game, zone)
		_test_attacks(game, zone, original)
		_test_mechanics(game, zone, original)
		game._finish_raid("cancelled")
	check(catalog == catalog_before and ZONES.all() == catalog_before, "encounters preserve hunting stats, unlocks and reward data")
	await _test_reload(game)
	for field: String in PRACTICE.SNAPSHOT_FIELDS:
		var value: Variant = game.get(field)
		natural_snapshot[field] = value.duplicate(true) if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY] else value
	for level in [1, 60]:
		for zone: String in BASELINE:
			for strengthened in [false, true]:
				await _natural_battle(game, zone, level, strengthened)
	var file := FileAccess.open("user://raid-strength-results.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "battles": natural_results}, "\t"))
	await dispose(game)
	done("raid_strength")

func _set_roster(game, count: int, level: int) -> void:
	var ids: Array[String] = []
	for hero: Dictionary in ROSTER.roster("aurelia"):
		if ids.size() < count: ids.append(str(hero.id))
	game._restore_deployed_heroes(ids)
	game.hero_progress.clear()
	for id in ids: game.hero_progress[id] = {"level": level, "xp": 0}

func _start(game, zone: String) -> void:
	if game.raid_running: game._finish_raid("cancelled")
	game.selected_raid_id = zone
	game._build_raid_screen()
	await settle()
	game._start_raid()
	check(game.raid_running, zone + " starts")
	if is_instance_valid(game.combat_timer): game.combat_timer.stop()

func _durable_target(game) -> String:
	# Isolate damage and mitigation without letting death make later checks vacuous.
	var id: String = str(game.deployed_heroes[0].id)
	var state: Dictionary = game.hero_battle_state[id]
	state.hp = 1000000
	state.max_hp = 1000000
	state.defense = 40
	state.shield = 0
	state.guard = 0.0
	state.taunt = 1.0
	state.ultimate = 0.0
	state.ult_gain_mult = 0.0
	game._guard_seconds = 0.0
	game._weaken_seconds = 0.0
	game._stun_seconds = 0.0
	game.raid_dodge_remaining = 0.0
	game.incoming_trace.clear()
	return id

func _check_hit(game, expected: int, label: String) -> void:
	check(game.incoming_trace.size() == 1, label + " damages exactly one living target")
	if game.incoming_trace.size() != 1: return
	var hit: Dictionary = game.incoming_trace[0]
	check(hit.raw == expected, label + " raw attack uses tuned base once")
	check(hit.actual == maxi(1, expected - 14), label + " actual HP damage retains defense")
	check(int(game.hero_battle_state[hit.hero].hp) > 0, label + " survivor keeps avoidance checks meaningful")

func _test_attacks(game, zone: String, original: Dictionary) -> void:
	var tuned_attack: int = game.raid_boss_attack
	for phase in [1, 2, 3]:
		game.raid_phase = phase
		for enraged in [false, true]:
			game.raid_enraged = enraged
			game.raid_mechanic_rage_stacks = 0
			var phase_factor: float = (1.0 + 0.12 * (phase - 1)) * (1.6 if enraged else 1.0)
			for sequence in [0, 1]:
				var profile: Dictionary = DESIGN.pattern(zone, phase, sequence)
				var old_raw: int = int(original.attack * float(profile.multiplier) * phase_factor)
				var expected: int = int(tuned_attack * float(profile.multiplier) * phase_factor)
				check(absi(expected - old_raw * 10) <= 9, zone + " phase threat scales tenfold before final integer damage rounding")
				var id: String = _durable_target(game)
				game.raid_pattern_shape = {"shape": "circle", "center": game.raid_positions[id], "radius": 1.0}
				game._apply_boss_pattern(profile)
				_check_hit(game, expected, "%s phase%d variant%d rage%s" % [zone, phase, sequence, enraged])
				if str(profile.kind) == "earthquake":
					_durable_target(game)
					game._apply_raid_second_wave()
					_check_hit(game, expected, zone + " earthquake followup")
				_durable_target(game)
				game.raid_dodge_remaining = 0.5
				game._apply_boss_pattern(profile)
				check(game.incoming_trace.is_empty(), zone + " strengthened pattern remains dodgeable")
	game.raid_phase = 1
	game.raid_enraged = false
	game.raid_second_wave_remaining = 0.0
	game.raid_second_wave_shape.clear()
	game.raid_pattern_shape.clear()
	var id: String = _durable_target(game)
	game.pet_runtime = {"kind": "none"}
	game.hero_skill_runtime[id].attack_remaining = 9999.0
	game.hero_skill_runtime[id].remaining = 9999.0
	game.hero_skill_runtime[id].secondary_remaining = 9999.0
	game.raid_positions[id] = game.raid_boss_position - Vector2(100, 0)
	game.raid_boss_turns = 0
	game.raid_boss_attack_remaining = 0.001
	game._advance_raid_encounter(0.01)
	_check_hit(game, tuned_attack, zone + " live basic attack")

func _test_mechanics(game, zone: String, original: Dictionary) -> void:
	game.raid_enraged = false
	game.raid_mechanic_rage_stacks = 0
	for phase in [2, 3]:
		game.raid_phase = phase
		game._raid_activate_phase_mechanic(phase)
		var mechanic: Dictionary = DESIGN.mechanic(zone, phase)
		var expected_pool: int = int(int(original.hp) * 10 * float(mechanic.ratio))
		match str(mechanic.kind):
			"guard":
				check(game.raid_guard_max_hp == expected_pool and game.raid_guard_hp == expected_pool, zone + " armor scales with boss HP")
			"adds":
				check(game.raid_add_max_hp == expected_pool and game.raid_add_hp == expected_pool, zone + " crystal durability scales with boss HP")
				_durable_target(game)
				game.raid_add_attack_remaining = 0.001
				game._raid_advance_mechanics(0.01)
				var expected_attack: int = int(int(original.attack) * 10 * (0.28 + 0.10 * int(mechanic.count)) * (1.0 + 0.12 * (phase - 1)))
				_check_hit(game, expected_attack, zone + " crystal pulse")
			"dps_check":
				check(game.raid_dps_check_target == expected_pool, zone + " ritual scales with boss HP")
				check(is_equal_approx(game.raid_dps_check_remaining, float(mechanic.duration)), zone + " ritual response duration unchanged")

func _check_report(game, zone: String, stats: Dictionary) -> void:
	var report: Dictionary = game.get_meta("last_raid_contribution", {})
	check(not report.is_empty() and report.entry.zone == zone, zone + " report has encounter identity")
	if report.is_empty(): return
	check(report.entry.max_hp == stats.max_hp and report.entry.attack == stats.attack and report.entry.balance_revision == BALANCE.REVISION, zone + " report records actual strength")
	var reports: Array = ARCHIVE.load_reports("user://raid-strength-reports.json")
	check(not reports.is_empty() and reports[0].entry == report.entry, zone + " archive retains difficulty after JSON reload")
	var legacy: Dictionary = report.duplicate(true)
	for key: String in ["max_hp", "attack", "balance_revision"]: legacy.entry.erase(key)
	check(not ARCHIVE.clean(legacy).is_empty(), "old reports without strength metadata remain readable")
	var malformed: Dictionary = report.duplicate(true)
	malformed.entry.attack = -1
	check(ARCHIVE.clean(malformed).is_empty(), "invalid recorded strength is rejected")

func _test_reload(game) -> void:
	game._build_lobby_screen()
	game._save_idle_state()
	var saved: Dictionary = game.save_store.read_save(game.save_state_path).get("data", {})
	check(not saved.is_empty() and not saved.has("raid_boss_max_hp") and not saved.has("raid_boss_attack"), "difficulty stays derived outside persistent growth data")
	game._load_idle_state()
	for zone: String in BASELINE:
		await _start(game, zone)
		check(game.raid_boss_max_hp == int(BASELINE[zone].hp) * 10 and game.raid_boss_attack == int(BASELINE[zone].attack) * 10, zone + " load and reselection apply exactly one multiplier")
		game._finish_raid("cancelled")

func _natural_battle(game, zone: String, level: int, strengthened: bool) -> void:
	# Restore pet XP, auto-equipped rewards and all other progression too, so the
	# previous comparison's victory cannot make the next party stronger.
	for field: String in natural_snapshot:
		var value: Variant = natural_snapshot[field]
		game.set(field, value.duplicate(true) if typeof(value) in [TYPE_DICTIONARY, TYPE_ARRAY] else value)
	_set_roster(game, 10, level)
	game.skill_auto = true
	game.ultimate_auto = true
	game.loot_rng.seed = 1701
	await _start(game, zone)
	var fixture_key: String = "%s-%d" % [zone, level]
	var party: Dictionary = {"heroes": game.hero_battle_state.duplicate(true), "pet": game.pet_runtime.duplicate(true), "power": game.party_power}
	if strengthened:
		check(party == natural_parties[fixture_key], "old/new fixtures have identical hero, equipment and pet state " + fixture_key)
	else:
		natural_parties[fixture_key] = party
	if not strengthened:
		# Reproduce the previous release's stats only in this comparison fixture.
		game.raid_boss_max_hp = BASELINE[zone].hp
		game.raid_boss_hp = BASELINE[zone].hp
		game.raid_boss_attack = BASELINE[zone].attack
		REPORT.begin(game)
	game.raid_observed = {"boss_damage": 0, "guard_damage": 0, "add_damage": 0, "healing": 0}
	game.incoming_trace.clear()
	var steps: int = 0
	while game.raid_running and steps < 4801:
		game._advance_raid_encounter(0.05)
		steps += 1
		if steps % 160 == 0: await process_frame
	check(not game.raid_running and game.raid_outcome in ["victory", "defeat", "timeout"], "natural raid terminates " + zone)
	var report: Dictionary = game.get_meta("last_raid_contribution", {})
	check(report.total_damage == game.raid_damage_dealt, "natural battle report conserves applied damage")
	for metric: String in ["boss_damage", "guard_damage", "add_damage"]:
		check(int(report.totals[metric]) == int(game.raid_observed[metric]), "natural observed HP agrees " + metric)
	var taken: int = 0
	for hit: Dictionary in game.incoming_trace: taken += int(hit.actual)
	var row: Dictionary = {"zone": zone, "heroes": 10, "level": level, "strength": 10 if strengthened else 1, "hp": game.raid_boss_max_hp, "attack": game.raid_boss_attack, "outcome": game.raid_outcome, "elapsed": game.raid_elapsed, "damage_taken": taken, "damage_dealt": game.raid_damage_dealt, "patterns": game.raid_pattern_count, "survivors": game._alive_hero_ids().size()}
	natural_results.append(row)
	print("raid_strength_battle " + JSON.stringify(row))
	var settled: Dictionary = economic(game)
	game._finish_raid("victory")
	game._on_raid_tick(game.raid_encounter_serial)
	check(economic(game) == settled, "finished raid ignores duplicate settlement and stale ticks")
