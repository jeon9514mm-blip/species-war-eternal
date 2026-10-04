extends RefCounted
## Planar two-link IK for a supporting wrist. Uses authored anatomical lengths;
## only visual joint angles change, never the actor or combat controller.
const CATALOG = preload("res://scripts/art/HeroPartsCatalog.gd")

static func apply(pose: Dictionary, definition: Dictionary, action: String, time: float, duration: float) -> void:
	var id := str(definition.hero_id)
	if id not in ["mira", "naia", "tessa"] or action in ["death", "victory", "buff", "spawn"]: return
	var rest := CATALOG.joint_positions(id, definition)
	var lead := "Left" if str(definition.weapon_hand) == "left" else "Right"
	var off := "Right" if lead == "Left" else "Left"
	var lead_frame := frame(lead + "Hand", pose, rest)
	var offset: Vector2 = rest[off + "Hand"].position - rest[lead + "Hand"].position
	if id in ["mira", "naia"] and action in ["attack_1", "attack_2", "skill", "ultimate"]:
		var u := clampf(time / maxf(duration, .001), 0, 1)
		var draw := smoothstep(0, .24, u) * (1 - smoothstep(.28, .44, u))
		offset.x -= .035 * draw
	var target: Vector2 = lead_frame.point + offset.rotated(float(lead_frame.angle))
	_solve(pose, rest, off, target)
	# Recompute equipment aim from the solved arm, retaining a bounded wrist.
	var art_angle := 0.0
	for part: Dictionary in definition.parts:
		if str(part.id) == "offhand": art_angle = float(part.get("rotation", 0))
	pose._offhand_angle = float(frame(off + "Hand", pose, rest).angle) + art_angle
	for part: Dictionary in definition.parts:
		if str(part.id) == "weapon":
			pose._weapon_angle = float(frame(lead+"Hand",pose,rest).angle)+float(part.get("rotation",0))

static func _solve(pose: Dictionary, rest: Dictionary, side: String, target: Vector2) -> void:
	var chest := frame("Chest", pose, rest)
	var shoulder: Vector2 = rest[side + "UpperArm"].position - rest.Chest.position
	var upper: Vector2 = rest[side + "Forearm"].position - rest[side + "UpperArm"].position
	var lower: Vector2 = rest[side + "Hand"].position - rest[side + "Forearm"].position
	var desired: Vector2 = (target - (chest.point as Vector2)).rotated(-float(chest.angle)) - shoulder
	var a := upper.length()
	var b := lower.length()
	var d := clampf(desired.length(), absf(a - b) + .0001, a + b - .0001)
	var bend := 1.0 if upper.cross(lower) >= 0 else -1.0
	var shoulder_angle := desired.angle() - bend * acos(clampf((a*a + d*d - b*b) / (2*a*d), -1, 1))
	var elbow_angle := bend * acos(clampf((d*d - a*a - b*b) / (2*a*b), -1, 1))
	pose[side + "UpperArm"] = wrapf(shoulder_angle - upper.angle(), -PI, PI)
	pose[side + "Forearm"] = wrapf(elbow_angle - (lower.angle() - upper.angle()), -PI, PI)
	pose[side + "Hand"] = clampf(float(pose.get(side + "Hand", 0)), -.22, .22)

static func frame(key: String, pose: Dictionary, rest: Dictionary) -> Dictionary:
	var parent: String = rest[key].parent
	var relative: Vector2 = rest[key].position
	var origin := Vector2(float(pose.get("root_x", 0)), float(pose.get("root_y", 0)))
	var parent_angle := 0.0
	if not parent.is_empty():
		var base := frame(parent, pose, rest)
		origin = base.point
		parent_angle = float(base.angle)
		relative -= rest[parent].position
	if key == "Chest": relative.y -= float(pose.get("chest_lift", 0))
	return {"point": origin + relative.rotated(parent_angle), "angle": parent_angle + float(pose.get(key, 0))}

static func error(rig: Node3D) -> float:
	var id := str(rig.definition.hero_id)
	if id not in ["mira", "naia", "tessa"]: return 0.0
	var rest := CATALOG.joint_positions(id, rig.definition)
	var lead := "Left" if str(rig.definition.weapon_hand) == "left" else "Right"
	var off := "Right" if lead == "Left" else "Left"
	var offset: Vector2 = rest[off + "Hand"].position - rest[lead + "Hand"].position
	var snapshot: Dictionary = rig.debug_snapshot()
	var action := str(snapshot.source_action)
	if id in ["mira", "naia"] and action in ["attack_1", "attack_2", "skill", "ultimate"]:
		var u := clampf(float(snapshot.action_time) / maxf(float(snapshot.action_duration), .001), 0, 1)
		offset.x -= .035 * smoothstep(0, .24, u) * (1 - smoothstep(.28, .44, u))
	var hand: Node3D = rig.joints[lead + "Hand"]
	var target := hand.global_transform * Vector3(offset.x, -offset.y, 0)
	return target.distance_to(rig.joints[off + "Hand"].global_position) / rig.global_basis.y.length()
