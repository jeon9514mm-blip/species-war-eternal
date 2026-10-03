extends RefCounted
## Presentation tracks only: radians and offsets in body-height units.
## Each row is an authored silhouette/weapon profile, not a gameplay class change.
const ACTIONS: Array[String] = ['idle','walk','run','attack_1','attack_2','skill','ultimate','hit','knockback','dodge','guard','buff','debuff','victory','death','spawn']
const WEAPON_TIPS := {
	'elisia':Vector3(.40,-.82,.23), 'kairen':Vector3(.31,-.98,.15),
	'astel':Vector3(.39,-.88,.17), 'nyx':Vector3(.36,-.70,.13),
	'isolde':Vector3(.40,-.87,.15), 'corvin':Vector3(.51,-.96,.16),
}
const LOOPS: Array[String] = ['idle','walk','run','debuff']
# Per-hero finishing accents: torso twist, wrist articulation, planted stance.
const SIGNATURES := {
	'leonhardt':[.026,.045,.90], 'mira':[.018,.050,1.08], 'elisia':[.012,.035,.80],
	'kairen':[.025,.042,.92], 'orwin':[.032,.025,1.00], 'seria':[.048,.060,1.14],
	'astel':[.010,.048,.76], 'darius':[.052,.035,1.12], 'lunea':[.014,.058,.82],
	'caelum':[.038,.043,1.02], 'valeria':[.042,.072,1.10], 'morgas':[.020,.046,.86],
	'ragna':[.055,.038,1.18], 'bron':[.060,.026,1.25], 'nyx':[.016,.055,.84],
	'fenris':[.046,.051,1.16], 'isolde':[.009,.040,.78], 'garm':[.044,.022,1.20],
	'veyra':[.036,.067,1.06], 'ulric':[.050,.033,1.13], 'adrien':[.024,.062,.98],
	'tessa':[.054,.018,1.22], 'naia':[.015,.057,.94], 'sael':[.040,.064,1.09],
	'odelia':[.011,.061,.79], 'lucien':[.030,.030,1.04], 'corvin':[.023,.049,.88],
	'rokan':[.037,.056,1.07], 'bora':[.047,.032,1.15], 'selene':[.013,.069,.81],
}
# family, cadence, amplitude, shoulder width, head pivot, weapon side, cloth sway
const PROFILES := {
	'leonhardt':['shield',.90,.90,.19,-.63,-1,.45],
	'mira':['bow',1.12,.92,.22,-.62,1,.80],
	'elisia':['heal',.88,.82,.19,-.63,1,1.10],
	'kairen':['staff',.98,1.00,.19,-.64,1,1.00],
	'orwin':['spear',.89,.95,.23,-.62,-1,.55],
	'seria':['dual',1.24,1.05,.23,-.60,1,.85],
	'astel':['heal',.84,.90,.18,-.65,1,1.20],
	'darius':['blade',.91,1.14,.24,-.62,1,.80],
	'lunea':['orb',.86,.88,.21,-.64,-1,1.25],
	'caelum':['blade',1.02,1.05,.24,-.61,-1,.75],
	'valeria':['dual',1.17,1.00,.20,-.64,1,1.20],
	'morgas':['orb',.93,.85,.21,-.63,1,1.15],
	'ragna':['claw',1.21,1.15,.26,-.59,1,.80],
	'bron':['fist',.80,1.18,.29,-.60,1,.35],
	'nyx':['staff',.86,.95,.20,-.65,1,1.10],
	'fenris':['claw',1.30,1.10,.26,-.58,-1,.80],
	'isolde':['heal',.82,.87,.20,-.64,1,1.25],
	'garm':['shield',.78,1.05,.28,-.59,-1,.50],
	'veyra':['dual',1.26,1.08,.22,-.63,1,1.20],
	'ulric':['claw',1.10,1.13,.27,-.60,1,.85],
	'adrien':['rapier',1.18,.92,.20,-.64,-1,.85],
	'tessa':['cannon',.86,1.15,.24,-.60,1,.50],
	'naia':['bow',1.01,.86,.20,-.65,1,1.00],
	'sael':['dual',1.28,1.02,.23,-.61,-1,1.05],
	'odelia':['orb',.90,.82,.19,-.64,-1,1.15],
	'lucien':['spear',1.03,1.09,.24,-.62,1,1.10],
	'corvin':['staff',.89,.98,.22,-.64,1,1.15],
	'rokan':['throw',1.15,1.03,.25,-.60,1,.70],
	'bora':['fist',1.23,1.08,.25,-.62,1,.60],
	'selene':['thread',.94,.88,.20,-.65,1,1.30],
}

static func profile(hero_id: String) -> Dictionary:
	var p: Array=PROFILES.get(hero_id,['blade',1.0,1.0,.22,-.64,1,.7])
	return {'family':p[0],'cadence':float(p[1]),'power':float(p[2]),'shoulder':float(p[3]),'head':float(p[4]),'side':int(p[5]),'cloth':float(p[6]),'weapon_tip':WEAPON_TIPS.get(hero_id,Vector3.ZERO),'signature':SIGNATURES.get(hero_id,[.025,.035,1.0])}

static func add_spawn_track(frames: SpriteFrames) -> void:
	if frames.has_animation('spawn'):return
	# The skeletal track supplies the motion; atlas is held at its neutral pose.
	frames.add_animation('spawn');frames.set_animation_loop('spawn',false)
	frames.set_animation_speed('spawn',1.0/.72)
	frames.add_frame('spawn',frames.get_frame_texture('idle',0))

static func sample(p: Dictionary, action: String, t: float, duration: float) -> Dictionary:
	var q: Dictionary={}
	var u:=clampf(t/maxf(duration,.01),0.0,1.0)
	var breath:=sin(t*2.6*p.cadence)
	q['Torso']=breath*.018
	q['Head']=-breath*.013
	q['LeftUpperArm']=breath*.035
	q['RightUpperArm']=-breath*.035
	q['Hair']=sin(t*2.6*p.cadence-.7)*.025*p.cloth
	q['Cape']=sin(t*2.6*p.cadence-1.2)*.035*p.cloth
	var lead: String='Right' if p.side>0 else 'Left'
	var off: String='Left' if p.side>0 else 'Right'
	var sign: float=float(p.side)
	match action:
		'walk','run':
			var fast:=action=='run'
			var step:=sin(t*(14.0 if fast else 9.0)*p.cadence)
			var stride: float=(.28 if fast else .18)*p.power
			q['root_y']=-absf(step)*(.035 if fast else .015)
			q['Pelvis']=step*.035;q['Torso']=-step*.055
			q['Head']=step*.028
			q['LeftThigh']=-step*stride;q['RightThigh']=step*stride
			q['LeftShin']=maxf(step,0)*.23;q['RightShin']=-maxf(-step,0)*.23
			q['LeftFoot']=-maxf(step,0)*.12;q['RightFoot']=maxf(-step,0)*.12
			q['LeftUpperArm']=step*.14;q['RightUpperArm']=-step*.14
			q['LeftForearm']=-absf(step)*.10;q['RightForearm']=absf(step)*.10
			q['Cape']=-step*.075*p.cloth;q['Hair']=step*.04*p.cloth
			if fast:q['Chest']=-.055
		'attack_1','attack_2','skill','ultimate':
			# Anticipation -> fast release -> follow through -> recovery.
			var charge:=sin(clampf(u/.30,0,1)*PI*.5)*(1.0-smoothstep(.28,.48,u))
			var release:=smoothstep(.28,.44,u)*(1.0-smoothstep(.60,1.0,u))
			var alt: float=-1.0 if action=='attack_2' else 1.0
			var power: float=p.power*(1.3 if action=='ultimate' else 1.12 if action=='skill' else 1.0)
			var swing: float=(release-charge*.48)*power
			q['Torso']=-sign*swing*.10*alt;q['Chest']=-sign*swing*.06*alt
			q['Head']=sign*swing*.055
			q['LeftThigh']=-release*.09;q['RightThigh']=release*.08
			q['Cape']=sign*swing*.09*p.cloth;q['Hair']=sign*swing*.035
			q[lead+'UpperArm']=sign*swing*.40*alt
			q[lead+'Forearm']=sign*(charge*.18+release*.28)*alt
			q[lead+'Hand']=-sign*swing*.06
			q[off+'UpperArm']=-sign*swing*.17
			q[off+'Forearm']=sign*swing*.13
			match str(p.family):
				'bow':
					q[lead+'UpperArm']=sign*(-charge*.11+release*.20)
					q[lead+'Forearm']=-sign*charge*.10
					q[off+'UpperArm']=-sign*charge*.23
					q[off+'Forearm']=sign*(charge*.32-release*.19)
					q['Weapon']=sign*release*.035
				'cannon':
					q['root_x']=-sign*release*.035
					q[lead+'UpperArm']=sign*release*.19;q[lead+'Forearm']=sign*release*.14
					q[off+'UpperArm']=sign*release*.16;q[off+'Forearm']=-sign*release*.13
				'staff','heal','orb','thread':
					q[lead+'UpperArm']=-sign*(charge*.22+release*.32)
					q[lead+'Forearm']=sign*(charge*.18-release*.16)
					q[off+'UpperArm']=sign*release*.30;q[off+'Forearm']=-sign*release*.25
					q['Weapon']=-sign*swing*.045
					q['root_y']=-release*(.045 if action=='ultimate' else .012)
				'spear','rapier','throw':
					q[lead+'UpperArm']=sign*swing*.32
					q[lead+'Forearm']=-sign*swing*.26
					q['root_x']=sign*swing*.035
					if p.family=='throw':q[lead+'UpperArm']+=-sign*charge*.20
				'dual','claw','fist':
					q[off+'UpperArm']=-sign*swing*.32*alt
					q[off+'Forearm']=-sign*(charge*.15+release*.24)*alt
					q['Chest']=-sign*swing*.09*alt
					if p.family=='fist':q['root_y']=release*.022
				'shield':
					q[off+'UpperArm']=-sign*release*.14;q[off+'Forearm']=sign*release*.16
			if action=='ultimate':
				q['Chest']=float(q.get('Chest',0))-.04*release
				q['Cape']=float(q['Cape'])*1.6
		'hit','knockback':
			var recoil:=sin(clampf(u/.18,0,1)*PI*.5)*(1-smoothstep(.2,1.0,u))
			var strength:=1.6 if action=='knockback' else 1.0
			q['Torso']=recoil*.15*strength;q['Head']=-recoil*.11
			q['LeftUpperArm']=recoil*.23;q['RightUpperArm']=-recoil*.23
			q['LeftForearm']=-recoil*.16;q['RightForearm']=recoil*.16
			q['LeftThigh']=-recoil*.12;q['RightShin']=recoil*.15
			q['root_x']=-recoil*.065 if action=='knockback' else 0.0
		'dodge':
			var evade:=sin(u*PI)
			q['root_x']=-evade*.075;q['root_y']=evade*.045
			q['Pelvis']=-evade*.10;q['Torso']=evade*.13;q['Head']=-evade*.06
			q['LeftThigh']=-evade*.24;q['LeftShin']=evade*.27
			q['RightThigh']=evade*.13;q['RightShin']=-evade*.18
			q['Cape']=evade*.15*p.cloth
		'guard':
			var brace:=sin(u*PI)
			q['root_y']=brace*.02;q['Torso']=-brace*.065
			q[off+'UpperArm']=sign*brace*.24;q[off+'Forearm']=-sign*brace*.27
			q[lead+'UpperArm']=-sign*brace*.12;q[lead+'Forearm']=sign*brace*.16
			q['LeftThigh']=-brace*.10;q['RightThigh']=brace*.10
		'buff','spawn':
			var rise:=sin(u*PI)
			q['Chest']=-rise*.04;q['Head']=-rise*.06
			q['LeftUpperArm']=rise*.19;q['RightUpperArm']=-rise*.19
			q['LeftForearm']=-rise*.13;q['RightForearm']=rise*.13
			q['Cape']=rise*.07*p.cloth
			if action=='spawn':
				var settle:=1.0-smoothstep(0,.85,u)
				q['root_y']=settle*.12;q['LeftThigh']=-settle*.22;q['RightThigh']=settle*.22
				q['Head']=settle*.10;q['Torso']=settle*.12
		'debuff':
			q['Torso']=.055;q['Head']=.06+sin(t*6)*.02
			q['LeftForearm']=sin(t*7)*.055;q['RightForearm']=-sin(t*7)*.055
			q['root_y']=.018
		'victory':
			var celebrate:=sin(u*PI)
			q[lead+'UpperArm']=-sign*celebrate*.42;q[lead+'Forearm']=-sign*celebrate*.26
			q[off+'UpperArm']=sign*celebrate*.14;q['Head']=-celebrate*.06
			q['root_y']=-celebrate*.025
		'death':
			q.clear()
			var fall:=smoothstep(0,.85,u)
			q['Root']=fall*.65;q['root_y']=fall*.14
			q['Torso']=fall*.18;q['Head']=fall*.18
			q['LeftThigh']=-fall*.18;q['RightThigh']=fall*.25
			q['LeftShin']=fall*.22;q['RightShin']=-fall*.17
			q['LeftUpperArm']=fall*.16;q['RightUpperArm']=-fall*.22
			q['Cape']=-fall*.12
	if action in ['attack_1','attack_2','skill','ultimate','guard']:
		_polish_weapon(q,p,action,u,lead,off,sign)
	return q

static func _polish_weapon(q: Dictionary,p: Dictionary,action: String,u: float,lead: String,off: String,sign: float) -> void:
	var gesture:=sin(u*PI)
	var strike:=smoothstep(.24,.42,u)*(1.0-smoothstep(.58,.96,u))
	var follow:=sin(clampf((u-.38)/.62,0,1)*PI)
	var accent: Array=p.signature
	q['Chest']=float(q.get('Chest',0))+sign*gesture*float(accent[0])
	q[lead+'Hand']=float(q.get(lead+'Hand',0))-sign*strike*float(accent[1])
	q['Pelvis']=float(q.get('Pelvis',0))-gesture*.025*float(accent[2])
	q['Cape']=float(q.get('Cape',0))+follow*.045*float(p.cloth)
	match str(p.family):
		'shield':
			q['Offhand']=sign*gesture*(.15 if action=='guard' else .07)
			q[off+'Forearm']=float(q.get(off+'Forearm',0))-sign*gesture*.07
		'bow':
			q[off+'Hand']=sign*strike*.07
			q['root_x']=float(q.get('root_x',0))-sign*strike*.018
		'cannon':
			q['root_x']=float(q.get('root_x',0))-sign*strike*.025*float(accent[2])
			q['LeftShin']=strike*.12;q['RightShin']=-strike*.10
			q['Weapon']=sign*strike*.025
		'heal':
			q[off+'Hand']=-sign*gesture*.08
			q['Head']=float(q.get('Head',0))-gesture*.025
		'orb','thread':
			q[off+'Forearm']=float(q.get(off+'Forearm',0))+sign*gesture*.09
			q[off+'Hand']=sign*sin(u*TAU)*.055
			q['Weapon']=sign*gesture*.035
		'staff':
			q['Weapon']=float(q.get('Weapon',0))-sign*gesture*.025
			q[off+'Hand']=sign*gesture*.055
		'spear','rapier','throw':
			q['root_x']=float(q.get('root_x',0))+sign*strike*.025
			q['Weapon']=sign*strike*.035
		'blade':
			q['Weapon']=sign*strike*(.075 if action=='attack_2' else -.045)
			q[off+'Hand']=-sign*follow*.04
		'dual','claw':
			q['Offhand']=-sign*sin(u*TAU)*.055
			q['Weapon']=sign*strike*.055
		'fist':
			q[off+'Hand']=sign*gesture*.065
			q['root_y']=float(q.get('root_y',0))+strike*.012*float(accent[2])
