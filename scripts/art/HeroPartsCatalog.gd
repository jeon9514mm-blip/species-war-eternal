extends RefCounted
## Production identities plus a strict, reviewed separated-art gate. This catalog
## creates no new gameplay heroes and never accepts a whole-body image as parts.
const ROSTER = preload("res://scripts/HeroRosterCatalog.gd")
const MOTIONS = preload("res://scripts/portrait/HeroRigMotionCatalog.gd")
const ROOT := "res://assets/art-direction/aurelia-4head/"
const HERO_IDS: Array[String] = ["leonhardt", "mira", "elisia", "kairen", "orwin", "seria", "astel", "darius", "lunea", "caelum", "adrien", "tessa", "naia", "sael", "odelia"]
const ACTIONS: Array[String] = ["idle", "walk", "run", "attack_1", "attack_2", "skill", "ultimate", "hit", "knockback", "dodge", "guard", "buff", "debuff", "victory", "death", "spawn"]
const BONE_NAMES: Array[String] = ["Root", "Pelvis", "Torso", "Chest", "Head", "Hair", "Cape", "LeftUpperArm", "LeftForearm", "LeftHand", "RightUpperArm", "RightForearm", "RightHand", "LeftThigh", "LeftShin", "LeftFoot", "RightThigh", "RightShin", "RightFoot", "Weapon", "Offhand"]
# Artist contract: body height = 1, feet at y=0, +x screen right, +y down.
# Anatomical Left appears on screen RIGHT in the frontal/three-quarter rest pose.
# Coordinates are GLOBAL REST joint positions, not local parent offsets.
const JOINTS := {
	"Root": ["", 0.0, 0.0], "Pelvis": ["Root", 0.0, -.45],
	"Torso": ["Pelvis", 0.0, -.55], "Chest": ["Torso", 0.0, -.67],
	"Head": ["Chest", 0.0, -.755], "Hair": ["Head", 0.0, -.90],
	"Cape": ["Chest", 0.0, -.69],
	"LeftUpperArm": ["Chest", .115, -.68], "LeftForearm": ["LeftUpperArm", .16, -.505], "LeftHand": ["LeftForearm", .18, -.365],
	"RightUpperArm": ["Chest", -.115, -.68], "RightForearm": ["RightUpperArm", -.16, -.505], "RightHand": ["RightForearm", -.18, -.365],
	"LeftThigh": ["Pelvis", .065, -.435], "LeftShin": ["LeftThigh", .075, -.23], "LeftFoot": ["LeftShin", .075, -.055],
	"RightThigh": ["Pelvis", -.065, -.435], "RightShin": ["RightThigh", -.075, -.23], "RightFoot": ["RightShin", -.075, -.055],
}
const PART_ORDER: Array[String] = ["head", "hair_back", "hair_front", "chest", "pelvis", "left_upper_arm", "left_forearm", "left_hand", "right_upper_arm", "right_forearm", "right_hand", "left_thigh", "left_shin", "left_foot", "right_thigh", "right_shin", "right_foot", "cape_back", "cape_front", "weapon", "offhand", "left_shoulder", "right_shoulder", "belt", "garment_back"]
const REQUIRED: Array[String] = ["head", "hair_back", "chest", "left_upper_arm", "left_forearm", "left_hand", "right_upper_arm", "right_forearm", "right_hand", "left_thigh", "left_shin", "left_foot", "right_thigh", "right_shin", "right_foot", "weapon"]
# A complete face/front-hair piece and a continuous chest/waist painting are
# preferred over forced fragmentation. Only motion-critical pieces are required.
# Old 25-cell drafts remain structurally loadable, never automatically reviewed.
const PART_ALIASES := {"core": "chest", "body_core": "chest", "rear_hair": "hair_back", "cape": "cape_back", "shield": "offhand", "left_boot": "left_foot", "right_boot": "right_foot"}
# Optional cloth can be a shoulder cape or a waist tabard in the painted art.
# Its mounting choice remains explicit; limbs, weapons and armor stay strict.
const ALLOWED_PARENTS := {"chest": ["Chest", "Torso"], "cape_front": ["Cape", "Chest", "Pelvis"], "garment_back": ["Pelvis", "Cape"]}
# bone, region-relative anchor x/y, displayed width/height, local offset x/y,
# draw order. PROPOSALS ONLY: generated art must be assembled and adjusted.
const PART_DEFAULTS := {
	"head": ["Head", .50, .95, .25, .265, 0.0, 0.0, 45],
	"hair_back": ["Hair", .50, .20, .32, .43, 0.0, 0.0, -30],
	"hair_front": ["Hair", .50, .28, .29, .205, 0.0, 0.0, 50],
	"chest": ["Chest", .50, .18, .25, .255, 0.0, 0.0, 10],
	"pelvis": ["Pelvis", .50, .30, .215, .14, 0.0, 0.0, 12],
	"left_upper_arm": ["LeftUpperArm", .50, .12, .105, .205, 0.0, 0.0, 21],
	"left_forearm": ["LeftForearm", .50, .12, .095, .170, 0.0, 0.0, 23],
	"left_hand": ["LeftHand", .50, .20, .075, .080, 0.0, 0.0, 25],
	"right_upper_arm": ["RightUpperArm", .50, .12, .105, .205, 0.0, 0.0, -5],
	"right_forearm": ["RightForearm", .50, .12, .095, .170, 0.0, 0.0, -3],
	"right_hand": ["RightHand", .50, .20, .075, .080, 0.0, 0.0, -1],
	"left_thigh": ["LeftThigh", .50, .10, .115, .235, 0.0, 0.0, 5],
	"left_shin": ["LeftShin", .50, .10, .095, .205, 0.0, 0.0, 6],
	"left_foot": ["LeftFoot", .42, .32, .115, .082, 0.0, 0.0, 7],
	"right_thigh": ["RightThigh", .50, .10, .115, .235, 0.0, 0.0, 1],
	"right_shin": ["RightShin", .50, .10, .095, .205, 0.0, 0.0, 2],
	"right_foot": ["RightFoot", .58, .32, .115, .082, 0.0, 0.0, 3],
	"cape_back": ["Cape", .50, .10, .36, .49, 0.0, 0.0, -40],
	"cape_front": ["Cape", .50, .10, .26, .34, 0.0, 0.0, 16],
	"weapon": ["Weapon", .50, .78, .14, .48, 0.0, 0.0, 30],
	"offhand": ["Offhand", .50, .45, .25, .34, 0.0, 0.0, 33],
	"left_shoulder": ["LeftUpperArm", .50, .48, .15, .115, 0.0, 0.0, 28],
	"right_shoulder": ["RightUpperArm", .50, .48, .15, .115, 0.0, 0.0, 27],
	"belt": ["Pelvis", .50, .50, .23, .080, 0.0, -.025, 29],
	"garment_back": ["Pelvis", .50, .08, .26, .27, 0.0, 0.0, -20],
}
const IDENTITIES := {
	"leonhardt": "금발 · 은갑옷 · 파란 망토 · 검과 문장 방패",
	"mira": "적갈색 포니테일 · 붉은 망토 · 금빛 활",
	"elisia": "밝은 장발 · 녹색 눈 · 백녹 성복 · 잎 보석 지팡이",
	"kairen": "연보라 장발 · 별 장식 · 남금 의복 · 푸른 구슬 지팡이",
	"orwin": "금발 · 은청 갑옷 · 긴 창과 방패",
	"seria": "금발 · 초록 리본 · 녹색 경갑 · 쌍단검",
	"astel": "밝은 장발 · 꽃 장식 · 백청금 성복 · 보석 지팡이",
	"darius": "검은 머리와 밝은 앞머리 · 흑갑옷 · 붉은 망토 · 대검",
	"lunea": "연보라 장발 · 초승달 · 보라 의복 · 원형 마법구",
	"caelum": "금발 · 청금 갑옷 · 흰 털깃 · 파란 망토 · 금빛 대검",
	"adrien": "은발 · 푸른 눈 · 백남 의복 · 가느다란 결투검",
	"tessa": "갈색 포니테일 · 고글 · 기계 장식 · 대형 룬포",
	"naia": "긴 백발 · 별 장식 · 백남 의복 · 푸른 마법 활",
	"sael": "밝은 금발 · 녹색 눈 · 잎 장식 · 초록 쌍검",
	"odelia": "밝은 머리 · 보라 눈 · 남색 두건 · 책과 부적",
}

static func profile(hero_id: String) -> Dictionary:
	if hero_id not in HERO_IDS: return {}
	var result := MOTIONS.profile(hero_id).duplicate(true)
	var hero: Dictionary = ROSTER.HEROES[hero_id]
	result.merge({"hero_id": hero_id, "name": hero.name, "role": hero.role_group,
		"faction": "aurelia", "identity": IDENTITIES[hero_id],
		"weapon_family": str(result.family),
		"weapon_hand": "right" if int(result.side) < 0 else "left",
		"offhand_required": str(result.family) in ["shield", "dual"] or hero_id == "orwin",
		"stride_distance": 1.32 if str(result.family) in ["dual", "rapier"] else 1.50,
		"motion_provenance": "Existing 16 procedural curves available for individually reviewed separated artwork; not 240 newly hand-drawn animations."})
	if hero_id == "leonhardt":
		result.motion_provenance = "Multipart key-pose prototype sampled at the existing controller's frame progress; new assembly and motion still require visual review. No hand-drawn action sequences."
	return result

static func definition_path(hero_id: String) -> String:
	return ROOT + hero_id + "/parts.json"

static func load_definition(hero_id: String, allow_unreviewed := false) -> Dictionary:
	if hero_id not in HERO_IDS or not FileAccess.file_exists(definition_path(hero_id)): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(definition_path(hero_id)))
	if not parsed is Dictionary or str(parsed.get("hero_id", "")) != hero_id: return {}
	var result: Dictionary = validate_definition(parsed, allow_unreviewed)
	return normalize_definition(parsed) if bool(result.valid) else {}

static func has_ready_parts(hero_id: String) -> bool:
	return not load_definition(hero_id).is_empty()

static func normalize_definition(raw: Dictionary) -> Dictionary:
	var result := raw.duplicate(true)
	var entries = result.get("parts", [])
	if entries is Array:
		for entry in entries:
			if not entry is Dictionary: continue
			var supplied_id := str(entry.get("id", ""))
			if PART_ALIASES.has(supplied_id):
				entry.source_part_id = supplied_id
				entry.id = PART_ALIASES[supplied_id]
	return result

static func validate_definition(definition: Dictionary, allow_unreviewed := false) -> Dictionary:
	definition = normalize_definition(definition)
	var issues: Array[String] = []
	var hero_id := str(definition.get("hero_id", ""))
	if hero_id not in HERO_IDS: issues.append("Unknown Aurelia hero ID")
	if int(definition.get("schema_version", 0)) != 1: issues.append("Unsupported parts schema")
	var reviewed := bool(definition.get("reviewed", false)) and bool(definition.get("component_integrity_verified", false))
	if not allow_unreviewed and not reviewed: issues.append("Assembled visual review is pending")
	if str(definition.get("weapon_hand", profile(hero_id).get("weapon_hand", "right"))) not in ["left", "right"]:
		issues.append("weapon_hand must use anatomical left or right")
	var path := str(definition.get("atlas", ""))
	if not path.begins_with(ROOT + hero_id + "/") or not path.ends_with(".png"):
		issues.append("Atlas must be a PNG in this hero's own art directory")
	var texture: Texture2D
	if ResourceLoader.exists(path): texture = load(path) as Texture2D
	if texture == null: issues.append("Separated parts atlas is missing or not imported")
	var atlas_size := texture.get_size() if texture != null else Vector2.ZERO
	var declared_size = definition.get("atlas_size", [])
	if not _pair(declared_size) or Vector2(float(declared_size[0]), float(declared_size[1])) != atlas_size:
		issues.append("atlas_size must match the actual imported image")
	var atlas_image: Image = texture.get_image() if texture != null else null
	if atlas_image != null and atlas_image.detect_alpha() == Image.ALPHA_NONE:
		issues.append("Parts atlas must have a transparent background")
	var entries = definition.get("parts", [])
	if not entries is Array: entries = []; issues.append("parts must be an array")
	if entries.size() < 16: issues.append("At least 16 genuinely separate anatomical components are required")
	if entries.size() > 32: issues.append("Parts budget exceeds 32 per hero")
	var seen: Dictionary = {}
	var regions: Array[Rect2] = []
	for entry in entries:
		if not entry is Dictionary: issues.append("Part entry must be a dictionary"); continue
		var id := str(entry.get("id", ""))
		if id not in PART_ORDER or seen.has(id): issues.append("Unknown or duplicate part: " + id)
		seen[id] = true
		if str(entry.get("bone", "")) not in BONE_NAMES: issues.append("Invalid parent bone for " + id)
		elif PART_DEFAULTS.has(id):
			var allowed: Array = ALLOWED_PARENTS.get(id, [str(PART_DEFAULTS[id][0])])
			if str(entry.bone) not in allowed: issues.append("Part is not attached to its anatomical joint: " + id)
		var region = entry.get("region", [])
		if not region is Array or region.size() != 4:
			issues.append("Missing pixel region for " + id); continue
		var rect := Rect2(float(region[0]), float(region[1]), float(region[2]), float(region[3]))
		if not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x < 2 or rect.size.y < 2 or not Rect2(Vector2.ZERO, atlas_size).encloses(rect):
			issues.append("Invalid atlas region for " + id); continue
		for other in regions:
			if rect.intersects(other): issues.append("Overlapping texture regions at " + id); break
		regions.append(rect)
		if atlas_image != null and atlas_image.get_region(Rect2i(rect)).get_used_rect().size == Vector2i.ZERO:
			issues.append("Empty alpha region for " + id)
		var anchor = entry.get("anchor", [])
		if not _pair(anchor) or float(anchor[0]) < 0 or float(anchor[0]) > 1 or float(anchor[1]) < 0 or float(anchor[1]) > 1:
			issues.append("Anchor must lie inside its part region: " + id)
		var size = entry.get("display_size", [])
		if not _pair(size) or float(size[0]) <= 0 or float(size[1]) <= 0 or float(size[0]) > 1.5 or float(size[1]) > 1.5:
			issues.append("Invalid body-height-unit display size: " + id)
		if not _pair(entry.get("offset", [0.0, 0.0])): issues.append("Invalid part offset: " + id)
		if not is_finite(float(entry.get("rotation", 0.0))): issues.append("Invalid part rotation: " + id)
		if absf(float(entry.get("z_order", 0))) > 100: issues.append("Part depth exceeds bounded range: " + id)
	for id in REQUIRED:
		if not seen.has(id): issues.append("Required separate component missing: " + id)
	if hero_id in HERO_IDS and bool(profile(hero_id).offhand_required) and not seen.has("offhand"):
		issues.append("This identity requires a separately drawn offhand weapon/shield")
	issues.append_array(_validate_joint_rest(definition.get("joint_rest", {})))
	return {"valid": issues.is_empty(), "issues": issues, "part_count": entries.size(), "reviewed": reviewed, "independent_texture_regions": regions.size()}

static func _pair(value) -> bool:
	return value is Array and value.size() == 2 and is_finite(float(value[0])) and is_finite(float(value[1]))

static func _validate_joint_rest(overrides) -> Array[String]:
	var issues: Array[String] = []
	if not overrides is Dictionary:
		issues.append("joint_rest must map existing joints to global rest [x,y] pairs")
		return issues
	var points: Dictionary = {}
	for key in JOINTS: points[key] = Vector2(float(JOINTS[key][1]), float(JOINTS[key][2]))
	for key in overrides:
		if not JOINTS.has(key):
			issues.append("Unknown or derived joint cannot be overridden: " + str(key)); continue
		var value = overrides[key]
		if not _pair(value):
			issues.append("Joint rest must be a finite [x,y] pair: " + str(key)); continue
		var point := Vector2(float(value[0]), float(value[1]))
		if absf(point.x) > .65 or point.y < -1.50 or point.y > .10:
			issues.append("Joint rest exceeds body-height bounds: " + str(key)); continue
		if str(key) == "Root" and not point.is_zero_approx():
			issues.append("The world-foot Root rest must stay at [0,0]"); continue
		points[key] = point
	# Parent names are not accepted from metadata, so the fixed acyclic anatomy
	# is retained. Validate lengths/order before deriving each local transform.
	if not (points.Head.y < points.Chest.y and points.Chest.y < points.Torso.y and points.Torso.y < points.Pelvis.y):
		issues.append("Head, chest, torso and pelvis must retain anatomical rest order")
	for side in ["Left", "Right"]:
		var thigh: Vector2 = points[side + "Thigh"]
		var shin: Vector2 = points[side + "Shin"]
		var foot: Vector2 = points[side + "Foot"]
		if shin.y - thigh.y < .04 or foot.y - shin.y < .04:
			issues.append("Thigh, knee and ankle must retain descending rest order: " + side)
		for pair in [["UpperArm", "Forearm"], ["Forearm", "Hand"], ["Thigh", "Shin"], ["Shin", "Foot"]]:
			var length: float = points[side + pair[0]].distance_to(points[side + pair[1]])
			if length < .025 or length > .48: issues.append("Unreasonable limb rest length: " + side + pair[0])
	return issues

static func joint_positions(hero_id: String, definition: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	for key in JOINTS:
		result[key] = {"parent": str(JOINTS[key][0]), "position": Vector2(float(JOINTS[key][1]), float(JOINTS[key][2]))}
	var overrides = definition.get("joint_rest", {})
	if _validate_joint_rest(overrides).is_empty():
		for key in overrides:
			result[key].position = Vector2(float(overrides[key][0]), float(overrides[key][1]))
	var hand := str(definition.get("weapon_hand", profile(hero_id).get("weapon_hand", "right")))
	var weapon_parent := "LeftHand" if hand == "left" else "RightHand"
	var offhand_parent := "RightHand" if hand == "left" else "LeftHand"
	result.Weapon = {"parent": weapon_parent, "position": result[weapon_parent].position}
	result.Offhand = {"parent": offhand_parent, "position": result[offhand_parent].position}
	return result
