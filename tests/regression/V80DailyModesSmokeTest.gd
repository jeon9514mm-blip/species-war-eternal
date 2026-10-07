extends SceneTree

const SESSION = preload("res://scripts/combat/ChallengeBattleSession.gd")
const RULES = preload("res://scripts/progression/DailyDungeonBattleRules.gd")
const PROGRESS = preload("res://scripts/progression/DailyDungeonProgress.gd")
var checks: int = 0
var failures: Array[String] = []

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _init() -> void:
	_check(RULES.plan("unknown").is_empty(), "unknown mode cannot become a gold run")
	_check(RULES.enemy_count("unknown") == 0, "unknown mode has no enemies")
	var expected_counts: Dictionary = {"gold_rush": 6, "survival": 4, "boss_hunt": 1}
	for variant in RULES.VARIANTS:
		var plan: Dictionary = RULES.plan(variant)
		_check(float(plan["limit_seconds"]) == 60.0, variant + " 60s limit")
		_check(RULES.enemy_count(variant) == expected_counts[variant], variant + " distinct population")
		for tier in RULES.DAILY_LIMIT:
			var reward: Dictionary = RULES.reward(tier)
			_check(reward == {"gold": 950 + tier * 250, "xp": 350 + tier * 100, "pet_xp": 60}, variant + " original reward schedule")
			for enemy in RULES.enemy_count(variant):
				var stats: Dictionary = RULES.enemy_stats(tier, 0, enemy, variant)
				_check(int(stats.get("hp", 0)) > 0 and int(stats.get("attack", 0)) > 0, "valid bounded stats")
	_check(RULES.reward(3).is_empty() and RULES.reward(-1).is_empty(), "quota is not silently clamped into a reward")
	_check(RULES.enemy_stats(3, 0, 0).is_empty(), "invalid difficulty rejected")
	_check(RULES.enemy_stats(0, 0, 1, "boss_hunt").is_empty(), "boss has exactly one target")
	_check(RULES.enemy_stats(0, 99, 0, "survival") == RULES.enemy_stats(0, 4, 0, "survival"), "survival pressure is capped")
	for variant in ["gold_rush", "boss_hunt"]:
		var session: ChallengeBattleSession = SESSION.new()
		var plan: Dictionary = RULES.plan(variant)
		_check(session.begin(10, plan, {}), "wave mode starts")
		for wave in int(plan["required_waves"]):
			_check(session.start_wave(wave + 1), "wave is unique")
			_check(session.complete_wave(wave + 1, 0, 1), "live party cleared enemy wave")
		_check(session.state == SESSION.State.WON, variant + " wins only after required kills")
		_check(not session.take_victory_receipt(10).is_empty(), "winning receipt")
		_check(session.take_victory_receipt(10).is_empty(), "receipt cannot repeat")
	var survival: ChallengeBattleSession = SESSION.new()
	survival.begin(20, RULES.plan("survival"), {})
	survival.start_wave(1)
	survival.complete_wave(1, 0, 1)
	_check(survival.is_running(), "survival does NOT win when first wave falls")
	_check(survival.start_wave(2), "survival allows replacement waves")
	survival.advance_clock(59.99, 1)
	_check(survival.is_running() and survival.progress_ratio() < 1.0, "must survive whole duration")
	survival.advance_clock(0.02, 1)
	_check(survival.state == SESSION.State.WON and survival.reason == "survived", "survival reaches correct deadline")
	_check(survival.elapsed == 60.0, "clock never overshoots")
	var dead: ChallengeBattleSession = SESSION.new()
	dead.begin(21, RULES.plan("survival"), {})
	dead.start_wave(1)
	dead.advance_clock(60.0, 0)
	_check(dead.state == SESSION.State.LOST, "last hero death beats survival timeout success")
	_check(dead.take_victory_receipt(21).is_empty(), "dead party cannot claim")
	var blank: ChallengeBattleSession = SESSION.new()
	blank.begin(22, RULES.plan("survival"), {})
	blank.advance_clock(60.0, 1)
	_check(blank.state == SESSION.State.LOST, "unspawned survival screen cannot win")
	var invalid: ChallengeBattleSession = SESSION.new()
	_check(not invalid.begin(30, {"limit_seconds": 60.0, "objective": "survive", "required_waves": 3}, {}), "invalid survival plan rejected")
	_check(not invalid.begin(30, {"limit_seconds": 60.0, "objective": "unknown", "required_waves": 3}, {}), "invalid objective rejected")
	var clears: Dictionary = {}
	_check(not PROGRESS.can_sweep(clears, "aurelia", "gold_rush", 0), "legacy absence is locked")
	_check(PROGRESS.record_direct_clear(clears, "aurelia", "gold_rush", 0), "direct clear unlocks")
	_check(PROGRESS.can_sweep(clears, "aurelia", "gold_rush", 0), "matching record usable")
	_check(not PROGRESS.can_sweep(clears, "noxfera", "gold_rush", 0), "other faction stays locked")
	_check(not PROGRESS.can_sweep(clears, "aurelia", "survival", 0), "other mode stays locked")
	_check(not PROGRESS.can_sweep(clears, "aurelia", "gold_rush", 1), "higher tier stays locked")
	for faction in PROGRESS.FACTIONS:
		for variant in RULES.VARIANTS:
			for tier in RULES.DAILY_LIMIT:
				_check(PROGRESS.record_direct_clear(clears, faction, variant, tier), "all valid clear keys supported")
	_check(clears.size() == 18, "bounded 2 factions x 3 modes x 3 tiers")
	_check(PROGRESS.sanitize(clears) == clears, "valid records round-trip")
	var malformed: Dictionary = {"aurelia:gold_rush:0": "true", "aurelia:survival:0": 1, "noxfera:boss_hunt:2": true, "unknown:gold_rush:0": true, "aurelia:gold_rush:9": true}
	_check(PROGRESS.sanitize(malformed) == {"noxfera:boss_hunt:2": true}, "allowlist and strict Boolean validation")
	_check(PROGRESS.sanitize(null).is_empty() and PROGRESS.sanitize([]).is_empty(), "malformed root rejected")
	var legacy: Dictionary = SaveValidation.sanitize({"save_version": 32, "daily_dungeon_runs": 3}, ["gray_meadow"])
	_check(legacy["daily_dungeon_clears"].is_empty(), "v32 instant clears do not retrospectively unlock sweeps")
	print("v80_daily_modes_unit checks=%d passed=%d failures=%s" % [checks, checks - failures.size(), JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
