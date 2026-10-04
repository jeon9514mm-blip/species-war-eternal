extends RefCounted
## Source-time key poses for articulated painting parts. Leonhardt is the first
## tuning target; other heroes keep their existing curves until individually
## reviewed. No source animation, combat timing, hit event or world-position write.
const REVISION := "leonhardt_parts_keyposes_v4_bounded_equipment_wrists"
const AURELIA = preload("res://scripts/art/AureliaPartsMotion.gd")

static func apply(profile: Dictionary, action: String, time: float, duration: float, base: Dictionary, weapon_rest: float, offhand_rest: float) -> Dictionary:
	var q := base.duplicate()
	if str(profile.get("hero_id", "")) != "leonhardt":
		return AURELIA.apply(profile, action, time, duration, q, weapon_rest, offhand_rest)
	var u := clampf(time / maxf(.001, duration), 0.0, 1.0)
	var wind := smoothstep(0.0, .24, u) * (1.0 - smoothstep(.24, .42, u))
	# These release bounds match the original source-time presentation windows.
	var strike := smoothstep(.28, .44, u) * (1.0 - smoothstep(.60, 1.0, u))
	var follow := smoothstep(.42, .62, u) * (1.0 - smoothstep(.76, 1.0, u))
	var hold := sin(u * PI)
	var side := float(profile.side)
	var lead := "Left" if side > 0 else "Right"
	var off := "Right" if side > 0 else "Left"
	match action:
		"idle":
			# A stable face/core. Breathing is a tiny chest motion, never a bob of
			# the whole character, and the sword remains in its authored grip.
			q.Head = float(q.get("Head", 0.0)) * .45
			q.Torso = float(q.get("Torso", 0.0)) * .60
			q.Chest = 0.0
			q.chest_lift = float(q.get("chest_lift", 0.0)) * .50
		"walk", "run":
			q.Head = float(q.get("Head", 0.0)) * .5
			q.Torso = float(q.get("Torso", 0.0)) * .6
			q.root_y = 0.0
			# Keep shield/carrying hands quiet while the legs do the walking.
			q[lead + "UpperArm"] = float(q.get(lead + "UpperArm", 0.0)) * .55
			q[off + "UpperArm"] = float(q.get(off + "UpperArm", 0.0)) * .35
			q[off + "Forearm"] = -side * .07
			# Counter-rotate the supporting boot, instead of tilting the entire
			# sole with thigh+knee and pushing its toe through the ground.
			for limb in ["Left", "Right"]:
				var leg := float(q.get("Pelvis", 0.0)) + float(q.get(limb + "Thigh", 0.0)) + float(q.get(limb + "Shin", 0.0))
				q[limb + "Foot"] = -leg * .82
		"attack_1", "attack_2":
			# The arm creates the sword arc. Keep elbow flexion on the same side
			# throughout windup, release and recovery; the wrist adds only 6–7 deg.
			# Independent weapon-angle envelopes previously folded the recovery
			# wrist by about 164 deg even though its grip stayed numerically attached.
			var reverse := action == "attack_2"
			q.Pelvis = -side * (.035 * strike - .015 * wind)
			q.Torso = -side * (.12 * strike - .055 * wind)
			q.Chest = -side * (.055 * strike - .025 * wind)
			q.Head = side * .045 * strike
			_arm(q, lead,
				-side * (.30 if reverse else .65) * wind + side * (2.0 if reverse else 1.70) * strike,
				-side * ((1.32 if reverse else 1.0) * wind + (.38 if reverse else .24) * strike),
				-side * .10 * wind + side * .12 * strike)
			_arm(q, off, side * .10 * strike, -side * .10 * strike, 0.0)
			q.LeftThigh = -.08 * strike
			q.RightThigh = .10 * strike
			q.LeftShin = .09 * strike
			q.RightShin = -.11 * strike
			q._weapon_angle = _gripped_angle(q, lead, weapon_rest)
			q._offhand_angle = _gripped_angle(q, off, offhand_rest)
			q.Cape = side * (.045 * wind - .10 * follow)
		"skill", "guard":
			# The fortress knight's skill is a shield brace, distinct from a sword
			# attack. Raise the shield forearm, lower the stance and shelter the core.
			var brace := hold if action == "guard" else maxf(wind * .55, strike)
			_arm(q, off, side * .67 * brace, side * 1.03 * brace, -side * .12 * brace)
			_arm(q, lead, -side * .18 * brace, -side * .20 * brace, 0.0)
			q.Torso = -side * .11 * brace
			q.Chest = side * .04 * brace
			q.Head = side * .06 * brace
			q.LeftThigh = -.16 * brace
			q.RightThigh = .20 * brace
			q.LeftShin = .23 * brace
			q.RightShin = -.28 * brace
			q._offhand_angle = offhand_rest + side * .08 * brace
			q._weapon_angle = weapon_rest - side * .32 * brace
		"ultimate":
			# A larger rallying barrier stance: shield high, sword lifted, both feet
			# planted. The existing source timeline still owns activation/recovery.
			var rally := maxf(wind, strike)
			_arm(q, off, side * .95 * rally, side * .90 * rally, 0.0)
			_arm(q, lead, -side * .98 * rally, -side * .85 * rally, 0.0)
			q._weapon_angle = weapon_rest - side * 2.28 * rally
			q._offhand_angle = offhand_rest + side * .08 * rally
			q.Torso = side * .045 * wind - side * .06 * strike
			q.Head = side * .035 * rally
			q.LeftThigh = -.12 * rally
			q.RightThigh = .12 * rally
			q.Cape = -side * .14 * follow
		"hit", "knockback":
			var recoil := smoothstep(0.0, .16, u) * (1.0 - smoothstep(.22, 1.0, u))
			var strength := 1.30 if action == "knockback" else 1.0
			q.Torso = side * .19 * recoil * strength
			q.Head = -side * .11 * recoil
			_arm(q, lead, -side * .34 * recoil, side * .24 * recoil, 0.0)
			_arm(q, off, side * .28 * recoil, side * .38 * recoil, 0.0)
			q.LeftThigh = -.12 * recoil
			q.RightThigh = .17 * recoil
			q.LeftShin = .18 * recoil
			q.RightShin = -.20 * recoil
			q.root_x = -.055 * recoil if action == "knockback" else 0.0
		"dodge":
			q.Pelvis = side * .07 * hold
			q.Torso = -side * .17 * hold
			q.Head = side * .08 * hold
			q.LeftThigh = -.38 * hold
			q.RightThigh = .25 * hold
			q.LeftShin = .58 * hold
			q.RightShin = -.36 * hold
			_arm(q, off, side * .42 * hold, side * .62 * hold, 0.0)
			q._offhand_angle = offhand_rest + side * .10 * hold
			q.root_x = -.045 * hold
		"buff":
			_arm(q, lead, -side * .55 * hold, -side * .66 * hold, 0.0)
			_arm(q, off, side * .24 * hold, side * .48 * hold, 0.0)
			q._weapon_angle = weapon_rest - side * 1.75 * hold
			q._offhand_angle = offhand_rest
			q.Head = side * .04 * hold
		"debuff":
			q.Torso = -.065
			q.Head = .075 + sin(time * 3.2) * .01
			q[lead + "UpperArm"] = side * .12
			q[off + "UpperArm"] = side * .08
			q.LeftShin = .09
			q.RightShin = -.09
		"victory":
			var celebrate := smoothstep(0.0, .32, u) * (1.0 - smoothstep(.78, 1.0, u))
			_arm(q, lead, -side * 1.04 * celebrate, -side * .73 * celebrate, 0.0)
			_arm(q, off, side * .12 * celebrate, side * .16 * celebrate, 0.0)
			q._weapon_angle = weapon_rest - side * 2.38 * celebrate
			q.Head = side * .045 * celebrate
			q.Chest = side * .025 * celebrate
		"death":
			q.clear()
			var sink := smoothstep(0.0, .40, u)
			var fall := smoothstep(.24, .92, u)
			q.Root = .87 * fall
			q.Pelvis = .08 * fall
			q.Torso = .19 * fall
			q.Head = .16 * fall
			q.LeftThigh = -.43 * sink
			q.RightThigh = .31 * sink
			q.LeftShin = .79 * sink
			q.RightShin = -.62 * sink
			q.LeftFoot = -.16 * sink
			q.RightFoot = .20 * sink
			_arm(q, lead, -side * .42 * fall, side * .28 * fall, 0.0)
			_arm(q, off, side * .32 * fall, side * .48 * fall, 0.0)
			q._weapon_angle = lerpf(weapon_rest, -PI * .5, fall)
			q._offhand_angle = offhand_rest + .80 * fall
			q.Cape = -.10 * fall
		"spawn":
			var settle := 1.0 - smoothstep(0.0, .85, u)
			q.Torso = -.08 * settle
			q.Head = .06 * settle
			q.LeftThigh = -.22 * settle
			q.RightThigh = .22 * settle
			q.LeftShin = .34 * settle
			q.RightShin = -.34 * settle
			q.root_y = 0.0
			_arm(q, off, side * .32 * settle, side * .40 * settle, 0.0)
	# Every equipped pose must be physically attainable by its painted wrist.
	# Retain a small authored wrist accent, but never rotate the weapon/shield
	# independently through the hand to maintain a screen-space aim angle.
	_bound_grip(q, lead, "_weapon_angle", weapon_rest)
	_bound_grip(q, off, "_offhand_angle", offhand_rest)
	return q

static func _bound_grip(q: Dictionary, side: String, angle_key: String, rest: float) -> void:
	var coupled := _gripped_angle(q, side, rest)
	var requested := float(q.get(angle_key, coupled))
	var correction := wrapf(requested - coupled, -PI, PI)
	q[side + "Hand"] = clampf(float(q.get(side + "Hand", 0.0)) + correction, -.22, .22)
	q[angle_key] = _gripped_angle(q, side, rest)

static func _arm(q: Dictionary, side: String, shoulder: float, elbow: float, wrist: float) -> void:
	q[side + "UpperArm"] = shoulder
	q[side + "Forearm"] = elbow
	q[side + "Hand"] = wrist

static func _gripped_angle(q: Dictionary, side: String, rest: float) -> float:
	var angle := rest
	for joint in ["Root", "Pelvis", "Torso", "Chest", side + "UpperArm", side + "Forearm", side + "Hand"]:
		angle += float(q.get(joint, 0.0))
	return angle
