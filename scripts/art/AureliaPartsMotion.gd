extends RefCounted
## Hero-specific cutout poses. Source frames still own combat activation timing.
const REVISION := "aurelia14_weapon_poses_v2_supporting_grip"
const STYLES := {
	"mira": ["bow", .95, .85, .30, .055],
	"elisia": ["heal", .76, 1.10, .18, .040],
	"kairen": ["staff", 1.02, 1.00, .28, .050],
	"orwin": ["spear", 1.04, .55, .22, .035],
	"seria": ["dual", 1.13, .90, .40, .065],
	"astel": ["heal", .68, 1.22, .14, .035],
	"darius": ["greatsword", 1.18, .80, .33, .040],
	"lunea": ["orb_staff", .82, 1.25, .20, .055],
	"caelum": ["greatsword", 1.03, .72, .27, .045],
	"adrien": ["rapier", .94, .82, .36, .060],
	"tessa": ["cannon", 1.12, .48, .16, .025],
	"naia": ["bow", .82, 1.02, .24, .050],
	"sael": ["dual", 1.02, 1.08, .35, .060],
	"odelia": ["book", .73, 1.15, .17, .060],
}

static func apply(p: Dictionary, action: String, time: float, duration: float, base: Dictionary, weapon_rest: float, offhand_rest: float) -> Dictionary:
	var id := str(p.get("hero_id", ""))
	if not STYLES.has(id): return base
	var style: Array = STYLES[id]
	var kind := str(style[0])
	var power := float(style[1])
	var cloth := float(style[2])
	var agility := float(style[3])
	var wrist := float(style[4])
	var q := base.duplicate()
	var side := float(p.side)
	var lead := "Left" if side > 0 else "Right"
	var off := "Right" if side > 0 else "Left"
	var u := clampf(time / maxf(duration, .001), 0, 1)
	var wind := smoothstep(0, .24, u) * (1 - smoothstep(.24, .44, u))
	var strike := smoothstep(.28, .44, u) * (1 - smoothstep(.60, 1, u))
	var hold := sin(u * PI)
	var alternate := -1.0 if action == "attack_2" else 1.0
	match action:
		"idle":
			q.Head = float(q.get("Head", 0)) * .45
			q.Torso = float(q.get("Torso", 0)) * .55
			q.chest_lift = float(q.get("chest_lift", 0)) * .6
		"walk", "run":
			q.Head = float(q.get("Head", 0)) * .5
			q.Torso = float(q.get("Torso", 0)) * .65
			q.root_y = 0.0
			for limb in ["Left", "Right"]:
				var leg := float(q.get("Pelvis", 0)) + float(q.get(limb + "Thigh", 0)) + float(q.get(limb + "Shin", 0))
				q[limb + "Foot"] = -leg * .82
				q[limb + "UpperArm"] = float(q.get(limb + "UpperArm", 0)) * (.18 if kind in ["bow", "cannon", "book"] else .45)
				q[limb + "Forearm"] = 0.0
		"attack_1", "attack_2", "skill", "ultimate":
			var special := action in ["skill", "ultimate"]
			var strength := power * (1.25 if action == "ultimate" else 1.10 if special else 1.0)
			if action == "attack_2" and kind != "dual": strength *= .88
			q.Pelvis = -.025 * strike
			q.Torso = -side * .075 * strike * strength
			q.Chest = -side * .035 * strike
			q.Head = side * .025 * strike
			q.LeftThigh = -.07 * strike
			q.RightThigh = .09 * strike
			q.LeftShin = .08 * strike
			q.RightShin = -.09 * strike
			q.Cape = -side * .08 * strike * cloth
			match kind:
				"bow":
					# Bow arm settles while the other elbow draws and releases.
					_arm(q, lead, -side * .16 * wind + side * .08 * strike, side * .10 * wind, -side * wrist * strike)
					_arm(q, off, side * .38 * wind - side * .18 * strike, -side * .48 * wind + side * .16 * strike, 0)
					q.Chest = -side * .09 * wind + side * .05 * strike
					if special: q.Head = -side * .055 * wind
				"spear", "rapier":
					var reach := .56 if kind == "spear" else .72
					_arm(q, lead, -side * .26 * wind + side * reach * strike * strength, side * .38 * wind - side * .40 * strike, side * wrist * strike)
					_arm(q, off, side * .12 * strike, -side * .14 * strike, 0)
					q.root_x = side * .035 * strike
					q.LeftThigh = -.15 * strike
					q.RightThigh = .18 * strike
				"dual":
					_arm(q, lead, side * (-.40 * wind + 1.15 * strike) * alternate * strength, -side * (.62 * wind + .22 * strike), side * wrist * strike)
					_arm(q, off, -side * (-.24 * wind + .85 * strike) * alternate * strength, side * (.42 * wind + .18 * strike), -side * wrist * strike)
					q.Chest = -side * .15 * strike * alternate
					q.LeftThigh = -.18 * strike
					q.RightThigh = .22 * strike
				"greatsword":
					_arm(q, lead, side * (-.56 * wind + 1.40 * strike) * strength, -side * (.72 * wind + .28 * strike), side * wrist * strike)
					_arm(q, off, side * .35 * wind - side * .30 * strike, -side * .45 * wind + side * .24 * strike, 0)
					q.Torso = -side * .13 * strike * strength
					q.LeftShin = .15 * strike
					q.RightShin = -.17 * strike
				"cannon":
					_arm(q, lead, -side * .12 * wind + side * .18 * strike, side * .10 * wind - side * .16 * strike, 0)
					_arm(q, off, -side * .10 * wind + side * .15 * strike, side * .09 * wind - side * .12 * strike, 0)
					q.root_x = -side * .035 * strike
					q.Torso = side * .07 * strike
				"book":
					_arm(q, lead, -side * .12 * wind - side * .16 * strike, side * .14 * strike, 0)
					_arm(q, off, side * (.18 * wind + .68 * strike) * strength, -side * .45 * strike, -side * wrist * strike)
					q.Head = side * .07 * wind - side * .035 * strike
				_: # Staff, healing and moon-orb staff gestures are distinct.
					var flourish := .38 if kind == "heal" else .65 if kind == "orb_staff" else .82
					_arm(q, lead, -side * (.18 * wind + flourish * strike) * strength, side * .24 * strike, side * wrist * strike)
					_arm(q, off, side * (.12 * wind + .52 * strike) * strength, -side * .35 * strike, -side * wrist * strike)
					q.Head = -side * .04 * wind
					q.Cape = -side * .12 * strike * cloth
		"hit", "knockback":
			var recoil := smoothstep(0, .16, u) * (1 - smoothstep(.22, 1, u))
			var force := 1.3 if action == "knockback" else 1.0
			q.Torso = side * .15 * recoil * force
			q.Head = -side * .10 * recoil
			_arm(q, lead, -side * .20 * recoil, side * .16 * recoil, 0)
			_arm(q, off, side * .24 * recoil, -side * .18 * recoil, 0)
			q.root_x = -.045 * recoil if action == "knockback" else 0.0
		"dodge":
			q.Torso = -side * (.12 + agility * .1) * hold
			q.Head = side * .07 * hold
			q.LeftThigh = -(.24 + agility * .35) * hold
			q.RightThigh = (.18 + agility * .2) * hold
			q.LeftShin = .44 * hold
			q.RightShin = -.30 * hold
			q.root_x = -.045 * hold
		"guard":
			_arm(q, lead, -side * .22 * hold, side * .25 * hold, 0)
			_arm(q, off, side * .45 * hold, -side * .36 * hold, 0)
			q.Torso = -side * .08 * hold
			q.LeftThigh = -.13 * hold
			q.RightThigh = .15 * hold
		"buff":
			_arm(q, lead, -side * .52 * hold * power, side * .28 * hold, side * wrist * hold)
			_arm(q, off, side * .44 * hold, -side * .25 * hold, 0)
			q.Head = -side * .045 * hold
			q.Cape = .055 * hold * cloth
		"debuff":
			q.Torso = -.05
			q.Head = .07 + sin(time * (2.5 + agility)) * .009
			q.LeftShin = .08
			q.RightShin = -.08
			if kind == "cannon": _arm(q, lead, 0, 0, 0)
		"victory":
			var celebrate := smoothstep(0, .32, u) * (1 - smoothstep(.78, 1, u))
			_arm(q, lead, -side * .90 * celebrate * power, -side * .40 * celebrate, 0)
			_arm(q, off, side * .20 * celebrate, -side * .14 * celebrate, 0)
			q.Head = side * .04 * celebrate
		"death":
			q.clear()
			var sink := smoothstep(0, .40, u)
			var fall := smoothstep(.24, .92, u)
			q.Root = (.76 + power * .09) * fall
			q.Torso = .16 * fall
			q.Head = .15 * fall
			q.LeftThigh = -.36 * sink
			q.RightThigh = .28 * sink
			q.LeftShin = .65 * sink
			q.RightShin = -.52 * sink
			_arm(q, lead, -side * .32 * fall, side * .22 * fall, 0)
			_arm(q, off, side * .26 * fall, -side * .28 * fall, 0)
			q.Cape = -.08 * fall * cloth
		"spawn":
			var settle := 1 - smoothstep(0, .85, u)
			q.Torso = -.07 * settle
			q.Head = .055 * settle
			q.LeftThigh = -.19 * settle
			q.RightThigh = .19 * settle
			q.LeftShin = .29 * settle
			q.RightShin = -.29 * settle
			q.root_y = 0.0
	# Shared safety rule: the equipment rotates through its real glove/wrist.
	q[lead + "Hand"] = clampf(float(q.get(lead + "Hand", 0)), -.22, .22)
	q[off + "Hand"] = clampf(float(q.get(off + "Hand", 0)), -.22, .22)
	q._weapon_angle = _grip(q, lead, weapon_rest)
	q._offhand_angle = _grip(q, off, offhand_rest)
	return q

static func _arm(q: Dictionary, side: String, shoulder: float, elbow: float, wrist: float) -> void:
	q[side + "UpperArm"] = shoulder
	q[side + "Forearm"] = elbow
	q[side + "Hand"] = wrist

static func _grip(q: Dictionary, side: String, rest: float) -> float:
	var angle := rest
	for key in ["Root", "Pelvis", "Torso", "Chest", side + "UpperArm", side + "Forearm", side + "Hand"]:
		angle += float(q.get(key, 0))
	return angle
