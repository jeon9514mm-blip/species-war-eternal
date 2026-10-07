extends RefCounted
## v74: each regional raid keeps its original core mechanic, but every phase now
## owns deterministic variants, target behavior and readable counterplay.
const RAIDS := {
	'gray_meadow': {
		'type': '대지 격돌', 'accent': Color('#e8ba6b'), 'ground': Color('#355b44'),
		'description': '거리를 바꾸며 원형·원뿔·십자 균열을 피하는 근접 압박 레이드',
		'movement': 'bulwark',
		'mechanics': [
			{'kind':'none'},
			{'kind':'guard','name':'대지 갑주','ratio':0.10,'vulnerability':3.0,'hint':'보호막을 먼저 파괴하면 보스가 3초간 약점 노출됩니다.'},
			{'kind':'guard','name':'거목 철갑','ratio':0.14,'vulnerability':3.5,'hint':'강화 보호막을 빠르게 깨고 약점 시간에 각성기를 집중하세요.'},
		],
		'phases': [
			{'interval':6,'telegraph':1.20,'name':'대지 포효','kind':'aoe','radius':250.0,'multiplier':1.40,'basic_target':'front','phase_hint':'전열 압박 · 원형 충격과 돌진 파쇄가 교차합니다.','counter':'보스 주변 원형 범위 밖으로 이동 · 회피로 충격 무효',
				'variants':[{'telegraph':1.05,'name':'돌숨결 파쇄','kind':'cone','radius':290.0,'half_angle':0.58,'multiplier':1.52,'counter':'보스 정면 부채꼴을 벗어나 측면으로 이동'}]},
			{'interval':5,'telegraph':1.40,'name':'갈라지는 대지','kind':'earthquake','inner':100.0,'outer':232.0,'multiplier':0.88,'basic_target':'front','phase_hint':'연속 지진 · 첫 파동 뒤 2차 충격까지 위치를 유지하세요.','counter':'도넛형 충격파 2회 · 안쪽 또는 바깥쪽으로 이동',
				'variants':[{'telegraph':1.15,'name':'대지 십자균열','kind':'cross','width':82.0,'multiplier':1.12,'counter':'십자 균열의 세로·가로 축에서 벗어나 대각선 안전지대로 이동'}]},
			{'interval':4,'telegraph':1.25,'name':'거목의 격진','kind':'earthquake','inner':86.0,'outer':240.0,'multiplier':1.04,'basic_target':'front','phase_hint':'고속 압박 · 짧은 예고를 보고 즉시 측면 또는 안쪽으로 이동하세요.','counter':'빠른 연속 충격파 · 두 번째 파동도 이동이나 회피로 대응',
				'variants':[{'telegraph':0.95,'name':'거목 돌진','kind':'cone','radius':320.0,'half_angle':0.66,'multiplier':1.70,'counter':'짧은 전방 돌진 예고 · 측면으로 크게 이탈'}]},
		],
	},
	'forgotten_mine': {
		'type': '전열·후열 교대', 'accent': Color('#f0a15c'), 'ground': Color('#373a49'),
		'description': '전열과 후열을 번갈아 노리는 낙석·수정 통로 레이드',
		'movement': 'hunter',
		'mechanics': [
			{'kind':'none'},
			{'kind':'adds','name':'광맥 수정핵','count':2,'ratio':0.08,'pulse':3.2,'hint':'수정핵 2개가 보스를 보호합니다. 수정핵을 제거해야 보스를 다시 공격할 수 있습니다.'},
			{'kind':'adds','name':'폭주 수정핵','count':3,'ratio':0.11,'pulse':2.6,'hint':'수정핵 3개가 주기적으로 후열을 폭격합니다. 먼저 파괴해 공격 기회를 여세요.'},
		],
		'phases': [
			{'interval':5,'telegraph':1.10,'name':'광석 낙하','kind':'front_blast','width':142.0,'multiplier':1.72,'basic_target':'row_cycle','phase_hint':'전열·후열 교대 표적 · 같은 줄에 오래 머물지 마세요.','counter':'전열을 노리는 낙석 통로 · 붉은 세로선 밖으로 이동',
				'variants':[{'telegraph':1.20,'name':'쌍광맥 붕괴','kind':'double_lane','width':76.0,'gap':108.0,'multiplier':1.38,'counter':'두 낙석 통로 사이 또는 가장자리 안전 공간으로 이동'}]},
			{'interval':5,'telegraph':1.25,'name':'수정 관통','kind':'rear_blast','width':142.0,'multiplier':1.58,'basic_target':'row_cycle','phase_hint':'후열 압박 강화 · 수정 폭쇄가 교차해 측면 공간을 제한합니다.','counter':'후열을 노리는 수정 관통 · 통로를 벗어나 회피',
				'variants':[{'telegraph':1.15,'name':'수정 폭쇄','kind':'cross','width':74.0,'multiplier':1.34,'counter':'십자 수정선 바깥의 대각선 안전지대로 이동'}]},
			{'interval':4,'telegraph':1.00,'name':'붕괴 낙석','kind':'front_blast','width':156.0,'multiplier':2.00,'basic_target':'row_cycle','phase_hint':'빠른 교대 타격 · 전열과 후열을 연속으로 바꾸며 압박합니다.','counter':'빠른 낙석 · 좌우 이동 또는 회피로 대응',
				'variants':[{'telegraph':0.95,'name':'광맥 절단','kind':'double_lane','width':82.0,'gap':118.0,'multiplier':1.72,'counter':'좁아진 두 통로 사이를 읽고 즉시 안전 줄로 이동'}]},
		],
	},
	'moonrest_forest': {
		'type': '월식 흡혈', 'accent': Color('#c3a1ff'), 'ground': Color('#263955'),
		'description': '낮은 체력 영웅을 추적하는 표식과 흡혈 장판을 분산시키는 레이드',
		'movement': 'stalker',
		'mechanics': [
			{'kind':'none'},
			{'kind':'dps_check','name':'월식 의식','duration':9.0,'ratio':0.07,'heal_ratio':0.035,'hint':'9초 안에 보스 최대 HP의 7%를 깎아 월식 의식을 끊으세요.'},
			{'kind':'dps_check','name':'붉은 월식 의식','duration':8.0,'ratio':0.10,'heal_ratio':0.05,'enrage_on_fail':true,'hint':'8초 안에 10% 피해를 넣지 못하면 즉시 광폭화합니다.'},
		],
		'phases': [
			{'interval':4,'telegraph':0.95,'name':'월식의 저주','kind':'curse','radius':278.0,'multiplier':1.16,'basic_target':'lowest_hp','phase_hint':'부상자 추적 · 낮은 체력 영웅이 보스에게 오래 노출되지 않게 하세요.','counter':'넓은 흡혈 영역 밖으로 이동 · 피격되면 보스 회복',
				'variants':[{'telegraph':1.20,'name':'달그림자 표식','kind':'moon_mark','radius':54.0,'mark_count':2,'multiplier':1.42,'counter':'표식 대상끼리 겹치지 말고 원정대에서 분리'}]},
			{'interval':4,'telegraph':1.15,'name':'달그림자 표식','kind':'moon_mark','radius':56.0,'mark_count':2,'multiplier':1.54,'basic_target':'lowest_hp','phase_hint':'표식 추적 강화 · 부상자 둘을 중심으로 전장을 분리하세요.','counter':'체력이 낮은 두 영웅의 고정된 표식에서 이탈',
				'variants':[{'telegraph':1.00,'name':'월광 추적','kind':'cone','radius':300.0,'half_angle':0.50,'multiplier':1.46,'counter':'부상자를 향한 부채꼴 추적 · 표적은 측면으로, 다른 영웅은 반대편으로 이동'}]},
			{'interval':3,'telegraph':1.00,'name':'붉은 월식','kind':'curse','radius':292.0,'multiplier':1.40,'basic_target':'lowest_hp','phase_hint':'흡혈 극대화 · 광역 저주와 3중 표식이 빠르게 교차합니다.','counter':'넓은 흡혈 영역 · 회피와 제어 스킬로 생존',
				'variants':[{'telegraph':0.95,'name':'삼중 월흔','kind':'moon_mark','radius':58.0,'mark_count':3,'multiplier':1.60,'counter':'체력이 낮은 세 영웅의 표식을 서로 겹치지 않게 분산'}]},
		],
	},
}

static func raid(zone_id: String) -> Dictionary:
	return RAIDS.get(zone_id,RAIDS['gray_meadow'])

static func mechanic(zone_id: String, phase: int = 1) -> Dictionary:
	var raid_data: Dictionary=raid(zone_id)
	var mechanics: Array=raid_data.get('mechanics',[])
	if mechanics.is_empty(): return {'kind':'none'}
	return mechanics[clampi(phase,1,mechanics.size())-1].duplicate(true)

static func _clean_pattern(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	result.erase('variants')
	return result

static func pattern(zone_id: String, phase: int = 1, sequence: int = -1) -> Dictionary:
	var phases: Array=raid(zone_id)['phases']
	var source: Dictionary=phases[clampi(phase,1,phases.size())-1]
	var primary := _clean_pattern(source)
	if sequence < 0:
		return primary
	var options: Array[Dictionary]=[primary]
	for variant_value in source.get('variants',[]):
		if typeof(variant_value)!=TYPE_DICTIONARY:
			continue
		var merged := primary.duplicate(true)
		var variant: Dictionary=variant_value
		for key in variant.keys():
			merged[key]=variant[key]
		options.append(merged)
	return options[posmod(sequence,options.size())].duplicate(true)
