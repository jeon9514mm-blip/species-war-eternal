extends SceneTree
## Production SaveStore oracle; only explicitly named fixture files are used.
const Store = preload("res://scripts/persistence/SaveStore.gd")
const FOLDER = "res://checks/unity-migration-2026-10-08/save-oracle-fixtures"
const OUTPUT = "res://Unity/Assets/Game/Editor/Fixtures/save-integrity-fixtures.json"
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	var store = Store.new()
	var cases: Array = []
	var values: Array = [0, 1, -1, 1.5, .000001, .000000000001, 123456789.12345, 1e20, -0.0, 999999999999999, 3.141592653589793]
	for index in values.size():
		var data = {"save_version":37,"number":values[index],"hero_levels":{"레온하르트":20},"nested":[true,false,null,"quote \" slash / backslash \\ newline\n tab\t"],"한글":"영웅 원정대","🌹":"bloodrose","\uE000":"private"}
		var path = FOLDER + "/numeric-%d.json" % index
		var written: Dictionary = store.write_save(path,data)
		assert(written.get("ok",false))
		var raw = FileAccess.get_file_as_string(path)
		var payload: Dictionary = JSON.parse_string(raw)
		payload.erase("_save_integrity")
		cases.append({"name":"numeric-%d" % index,"raw":raw,"canonical":JSON.stringify(payload),"expected":store._read_candidate(path)})
	var raw_cases = {
		"old_without_hash":"{\"save_version\":26,\"gold\":120}",
		"unversioned":"{\"gold\":12}",
		"unsupported":"{\"save_version\":38,\"gold\":2}",
		"missing_integrity":"{\"save_version\":37,\"gold\":5}",
		"empty":"{}", "array":"[]", "broken":"{bad",
		"version_string":"{\"save_version\":\"37\"}",
		"version_bool":"{\"save_version\":true}",
		"version_fraction":"{\"save_version\":1.5}",
		"version_zero":"{\"save_version\":0}",
		"version_null":"{\"save_version\":null}",
		"integrity_array":"{\"save_version\":37,\"_save_integrity\":[]}",
		"integrity_format_string":"{\"save_version\":37,\"_save_integrity\":{\"format\":\"1\",\"sha256\":\"abc\"}}",
		"integrity_wrong_hash":"{\"save_version\":37,\"_save_integrity\":{\"format\":1,\"sha256\":\"abc\"}}"
	}
	for name in raw_cases:
		var path = FOLDER + "/" + name + ".json"
		var file = FileAccess.open(path,FileAccess.WRITE)
		file.store_string(raw_cases[name]);file.close()
		cases.append({"name":name,"raw":raw_cases[name],"expected":store._read_candidate(path)})
	var report = {"source":"scripts/persistence/SaveStore.gd","save_version":Store.VERSION,"integrity_required_version":Store.INTEGRITY_REQUIRED_VERSION,"cases":cases,"note":"Synthetic fixture paths only. No user:// save path or real player data was accessed."}
	var output = FileAccess.open(OUTPUT,FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"));output.close()
	print("ETERNAL_SAVE_ORACLE_OK ", cases.size(), " cases")
	quit()
