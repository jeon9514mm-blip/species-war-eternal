extends SceneTree
## Read-only migration export. No Main scene and no player SaveStore are loaded.
const SOURCES := {
	"roster": "res://scripts/heroes/HeroRosterCatalog.gd",
	"identity": "res://scripts/heroes/HeroIdentityCatalog.gd",
	"guardian": "res://scripts/heroes/GuardianCatalog.gd",
	"raid": "res://scripts/raid/RaidBossDesign.gd",
	"raid_balance": "res://scripts/raid/RaidBalance.gd",
	"formation": "res://scripts/combat/BattleFormation.gd",
	"equipment": "res://scripts/equipment/EquipmentRules.gd",
	"navigation": "res://scripts/ui/NavigationCatalog.gd",
	"vfx": "res://scripts/presentation/HeroSkillVfxCatalog.gd",
}
func _initialize() -> void:
	var output := {"schema": 1, "source_engine": Engine.get_version_info().string, "catalogs": {}}
	for key in SOURCES:
		var script: Script = load(SOURCES[key])
		if script == null:
			push_error("Cannot read original catalog: " + SOURCES[key]); quit(1); return
		var constants := script.get_script_constant_map()
		var data := {}
		for name in constants:
			if typeof(constants[name]) != TYPE_OBJECT:
				data[str(name)] = safe_value(constants[name])
		output.catalogs[key] = {"source": SOURCES[key], "sha256": FileAccess.get_sha256(SOURCES[key]), "data": data}
	output["zones"] = safe_value(preload("res://scripts/maps/ZoneCatalog.gd").all())
	var profiles := []
	for hero_id in preload("res://scripts/heroes/HeroRosterCatalog.gd").HEROES:
		for slot in ["passive", "a1", "a2", "ultimate"]:
			profiles.append(safe_value(preload("res://scripts/presentation/HeroSkillVfxCatalog.gd").profile(hero_id, slot)))
	output["skill_vfx"] = profiles
	var path := "res://Unity/Assets/Game/Resources/Eternal/legacy-catalogs.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: push_error("Migration export cannot be written"); quit(1); return
	file.store_string(JSON.stringify(output, "  ")); file.close()
	print("UNITY_LEGACY_CATALOG_EXPORT_OK: 30 heroes, 120 VFX profiles, 3 zones, canonical raid/formation/equipment/guardian/navigation tables")
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
