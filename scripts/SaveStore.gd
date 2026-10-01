extends RefCounted
class_name SaveStore

# Flat JSON remains readable by old diagnostic tools. Integrity detects accidental
# corruption; it is not a signature or a substitute for server authority.
# v33 persists direct daily clears. v34 separates real abyss damage scores
# from archived power-based scores without refilling spent weekly attempts.
const VERSION := 37 # v83-6.2: formation selection and preset formation IDs.
const INTEGRITY_REQUIRED_VERSION := 27
const MAX_FILE_BYTES := 8 * 1024 * 1024
const INTEGRITY_KEY := "_save_integrity"

func read_save(path: String) -> Dictionary:
	for suffix in ["", ".bak", ".tmp"]:
		var result := _read_candidate(path + suffix)
		if bool(result.get("unsupported", false)):
			return result
		if bool(result.get("ok", false)):
			result["source"] = "primary" if suffix.is_empty() else ("backup" if suffix == ".bak" else "temporary")
			return result
	return {"ok": false, "status": "corrupt" if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak") or FileAccess.file_exists(path + ".tmp") else "missing"}

func write_save(path: String, data: Dictionary) -> Dictionary:
	# A downgrade must not overwrite progress written by a newer application,
	# including a newer backup or temporary file that is the only recoverable state.
	for suffix in ["", ".bak", ".tmp"]:
		if bool(_read_candidate(path + suffix).get("unsupported", false)):
			return {"ok": false, "status": "unsupported_version", "unsupported": true}
	var payload := data.duplicate(true)
	payload.erase(INTEGRITY_KEY)
	payload["save_version"] = VERSION
	# JSON numbers change from int to float on parsing. Hash the canonical parsed
	# representation so a valid round trip never reports false corruption.
	var canonical = JSON.parse_string(JSON.stringify(payload))
	if typeof(canonical) != TYPE_DICTIONARY:
		return {"ok": false, "status": "serialize_failed"}
	payload[INTEGRITY_KEY] = {"format": 1, "sha256": JSON.stringify(canonical).sha256_text()}
	var serialized := JSON.stringify(payload)
	if serialized.to_utf8_buffer().size() > MAX_FILE_BYTES:
		return {"ok": false, "status": "too_large"}
	var temporary_path := path + ".tmp"
	var error := _write_text(temporary_path, serialized)
	if error != OK:
		return {"ok": false, "status": "write_failed", "error": error}
	if not bool(_read_candidate(temporary_path).get("ok", false)):
		return {"ok": false, "status": "verification_failed"}
	var current := _read_candidate(path)
	if bool(current.get("ok", false)):
		# Never rotate a damaged primary over the last known valid backup.
		error = _write_text(path + ".bak.tmp", str(current["raw"]))
		if error != OK:
			return {"ok": false, "status": "backup_failed", "error": error}
		if not bool(_read_candidate(path + ".bak.tmp").get("ok", false)):
			return {"ok": false, "status": "backup_verification_failed"}
		error = _replace(path + ".bak.tmp", path + ".bak")
		if error != OK:
			return {"ok": false, "status": "backup_replace_failed", "error": error}
	elif FileAccess.file_exists(path):
		# Retain one damaged original for diagnosis instead of silently deleting it.
		if not FileAccess.file_exists(path + ".corrupt"):
			if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path + ".corrupt")):
				return {"ok": false, "status": "corrupt_archive_failed", "error": ERR_FILE_CANT_WRITE}
			error = DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".corrupt"))
			if error != OK:
				return {"ok": false, "status": "corrupt_archive_failed", "error": error}
	error = _replace(temporary_path, path)
	if error != OK:
		return {"ok": false, "status": "replace_failed", "error": error}
	return {"ok": true, "status": "saved"}

func _read_candidate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "status": "missing"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "status": "read_failed"}
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		return {"ok": false, "status": "too_large"}
	var raw := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(raw) != OK:
		return {"ok": false, "status": "invalid_json"}
	var parsed = parser.data
	if typeof(parsed) != TYPE_DICTIONARY or parsed.is_empty():
		return {"ok": false, "status": "invalid_json"}
	var version_value = parsed.get("save_version", 1)
	if typeof(version_value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(version_value)) or float(version_value) < 1 or fmod(float(version_value), 1.0) != 0.0:
		return {"ok": false, "status": "invalid_version"}
	if float(version_value) > VERSION:
		return {"ok": false, "status": "unsupported_version", "unsupported": true}
	var version := int(version_value)
	if parsed.has(INTEGRITY_KEY):
		var integrity = parsed[INTEGRITY_KEY]
		if typeof(integrity) != TYPE_DICTIONARY:
			return {"ok": false, "status": "invalid_integrity"}
		if typeof(integrity.get("format")) not in [TYPE_INT, TYPE_FLOAT] or integrity.get("format") != 1 or typeof(integrity.get("sha256")) != TYPE_STRING:
			return {"ok": false, "status": "invalid_integrity"}
		parsed.erase(INTEGRITY_KEY)
		if JSON.stringify(parsed).sha256_text() != integrity["sha256"]:
			return {"ok": false, "status": "checksum_mismatch"}
	elif version >= INTEGRITY_REQUIRED_VERSION:
		return {"ok": false, "status": "missing_integrity"}
	return {"ok": true, "status": "loaded", "data": parsed, "raw": raw, "migrated": version < VERSION}

func _write_text(path: String, value: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(value)
	file.flush()
	var error := file.get_error()
	file.close()
	return error

func _replace(source: String, destination: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(destination))
