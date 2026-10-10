extends SceneTree
## Read original domain definitions only. Never instantiate Main or SaveStore.
const SOURCES := {
	"goals": "res://scripts/progression/LongTermGoalCatalog.gd",
	"daily": "res://scripts/progression/DailyDungeonBattleRules.gd",
	"tower": "res://scripts/progression/TowerBattleRules.gd",
	"weekly": "res://scripts/progression/WeeklyAbyssBattleRules.gd",
	"challenge_patterns": "res://scripts/combat/ChallengePatternRules.gd",
	"world": "res://scripts/world/WorldWarState.gd",
	"march": "res://scripts/world/WorldMarchState.gd",
	"campaign": "res://scripts/world/WorldCampaignRules.gd",
	"season": "res://scripts/world/WorldSeasonState.gd",
	"market": "res://scripts/equipment/EquipmentMarketService.gd",
	"workshop": "res://scripts/equipment/EquipmentWorkshop.gd",
	"idle": "res://scripts/hunting/IdleHuntEstimator.gd",
	"growth": "res://scripts/progression/GrowthEconomyRules.gd"
}
func _initialize() -> void:
	var output := {"schema": 1, "engine": Engine.get_version_info().string, "sources": {}, "definitions": {}}
	for key in SOURCES:
		var source: Script = load(SOURCES[key])
		if source == null: push_error("Missing feature source: " + SOURCES[key]); quit(1); return
		var definitions := {}
		for name in source.get_script_constant_map():
			var value = source.get_script_constant_map()[name]
			if typeof(value) != TYPE_OBJECT: definitions[str(name)] = safe_value(value)
		output.sources[key] = {"path": SOURCES[key], "sha256": FileAccess.get_sha256(SOURCES[key])}
		output.definitions[key] = definitions
	var goals: Script = load(SOURCES.goals)
	output["goals"] = {}
	for scope in ["guide", "daily", "weekly", "achievement"]:
		output.goals[scope] = safe_value(goals.entries(scope))
	var daily: Script = load(SOURCES.daily)
	output["daily_plans"] = {}
	for variant in daily.VARIANTS: output.daily_plans[variant] = safe_value(daily.plan(variant))
	output["daily_rewards"] = []
	for index in daily.DAILY_LIMIT: output.daily_rewards.append(safe_value(daily.reward(index)))
	var weekly: Script = load(SOURCES.weekly)
	output["weekly_rewards"] = []
	for index in weekly.WEEKLY_LIMIT: output.weekly_rewards.append(safe_value(weekly.reward(index)))
	output["initial_worlds"] = {}
	for faction in ["aurelia", "noxfera"]:
		var world = load(SOURCES.world).new()
		world.initialize_new(faction)
		output.initial_worlds[faction] = safe_value(world.export_state())
	var save_source := FileAccess.get_file_as_string("res://scripts/persistence/GameSaveCoordinator.gd").split("static func save_idle_state")[0]
	var pattern := RegEx.new(); pattern.compile('(?m)^\t\t"([a-z_]+)":')
	output["save_fields"] = []
	for found in pattern.search_all(save_source): output.save_fields.append(found.get_string(1))
	output["oracle"] = {"world_plans": {}, "stage_chests": {}}
	var oracle_world = load(SOURCES.world).new(); oracle_world.initialize_new("aurelia")
	for pair in [Vector2i(3,9),Vector2i(3,10),Vector2i(18,10),Vector2i(4,5)]:
		output.oracle.world_plans["%d:%d" % [pair.x,pair.y]] = safe_value(load(SOURCES.march).new().plan(oracle_world,pair))
	for stage in [1,25,26,9999]: output.oracle.stage_chests[str(stage)] = safe_value(load(SOURCES.growth).stage_chest(stage))
	var args := OS.get_cmdline_user_args()
	if args.size() != 1: push_error("Pass one output JSON path after --."); quit(1); return
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null: push_error("Cannot write feature definitions."); quit(1); return
	file.store_string(JSON.stringify(output, "  ")); file.close()
	print("UNITY_FEATURE_DEFINITIONS_EXPORTED: original goals, challenges, initial worlds, campaign and market constants; no player save accessed.")
	quit(0)
func safe_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var result := {}
			for key in value: result[str(key)] = safe_value(value[key])
			return result
		TYPE_ARRAY:
			var result := []
			for item in value: result.append(safe_value(item))
			return result
		TYPE_COLOR: return "#" + Color(value).to_html(true)
		TYPE_VECTOR2, TYPE_VECTOR2I: return [value.x, value.y]
		TYPE_STRING_NAME: return str(value)
		_: return value
