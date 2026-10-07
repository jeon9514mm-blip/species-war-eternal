extends RefCounted
class_name HeroIdentityCatalog

const BALANCE_VERSION := 3

const PROFILES := {
	# 아우렐리아: 안정적인 전열, 정교한 원거리/지원, 긴 호흡의 전술전
	"leonhardt": {"ai_style":"protector","identity":"철벽 수호","trait":"위험 공격에 방어기 우선","hp_mult":1.10,"attack_mult":0.90,"defense_bonus":5,"attack_interval_mult":1.04,"ult_gain_mult":0.96,"skill_cooldown_mult":0.96,"skill_value_mult":1.00,"duration_mult":1.06,"sustain_mult":1.00},
	"mira": {"ai_style":"finisher","identity":"정밀 사수","trait":"위험한 후열·정예 마무리","hp_mult":0.94,"attack_mult":1.08,"defense_bonus":0,"attack_interval_mult":0.98,"ult_gain_mult":1.00,"skill_cooldown_mult":1.00,"skill_value_mult":1.06,"duration_mult":1.00,"sustain_mult":1.00},
	"elisia": {"ai_style":"support","identity":"숲의 치유사","trait":"아군 위기 시 회복 우선","hp_mult":1.00,"attack_mult":0.87,"defense_bonus":1,"attack_interval_mult":1.04,"ult_gain_mult":1.10,"skill_cooldown_mult":0.98,"skill_value_mult":1.10,"duration_mult":1.00,"sustain_mult":1.00},
	"kairen": {"ai_style":"controller","identity":"별빛 제어","trait":"정예·보스 패턴 차단","hp_mult":0.97,"attack_mult":0.99,"defense_bonus":0,"attack_interval_mult":1.02,"ult_gain_mult":1.05,"skill_cooldown_mult":1.00,"skill_value_mult":1.00,"duration_mult":1.12,"sustain_mult":1.00},
	"orwin": {"ai_style":"protector","identity":"방진 지휘관","trait":"전원 보호로 다수전 피해 경감","hp_mult":1.12,"attack_mult":0.86,"defense_bonus":6,"attack_interval_mult":1.06,"ult_gain_mult":0.95,"skill_cooldown_mult":0.98,"skill_value_mult":1.00,"duration_mult":1.10,"sustain_mult":1.00},
	"seria": {"ai_style":"aggressive","identity":"질풍 연사","trait":"빠른 기본공격·연속 압박","hp_mult":0.93,"attack_mult":1.03,"defense_bonus":0,"attack_interval_mult":0.86,"ult_gain_mult":1.03,"skill_cooldown_mult":0.98,"skill_value_mult":1.00,"duration_mult":1.00,"sustain_mult":1.00},
	"astel": {"ai_style":"support","identity":"광역 보호","trait":"다수 부상 시 광역 회복","hp_mult":1.02,"attack_mult":0.84,"defense_bonus":2,"attack_interval_mult":1.06,"ult_gain_mult":1.12,"skill_cooldown_mult":1.00,"skill_value_mult":1.12,"duration_mult":1.00,"sustain_mult":1.00},
	"darius": {"ai_style":"finisher","identity":"처형 집행","trait":"빈사 적에 단일 폭딜 집중","hp_mult":0.95,"attack_mult":1.11,"defense_bonus":1,"attack_interval_mult":1.02,"ult_gain_mult":0.98,"skill_cooldown_mult":1.04,"skill_value_mult":1.10,"duration_mult":1.00,"sustain_mult":1.00},
	"lunea": {"ai_style":"controller","identity":"안개 봉인","trait":"적 공격 약화 유지시간 특화","hp_mult":0.98,"attack_mult":0.97,"defense_bonus":1,"attack_interval_mult":1.02,"ult_gain_mult":1.05,"skill_cooldown_mult":0.98,"skill_value_mult":1.00,"duration_mult":1.14,"sustain_mult":1.00},
	"caelum": {"ai_style":"balanced","identity":"태양검 돌파","trait":"전열에서도 안정적인 공격","hp_mult":1.02,"attack_mult":1.06,"defense_bonus":2,"attack_interval_mult":0.98,"ult_gain_mult":1.00,"skill_cooldown_mult":1.00,"skill_value_mult":1.04,"duration_mult":1.00,"sustain_mult":1.00},

	# 녹스페라: 흡혈·약화·광폭, 빠른 템포와 위험 보상
	"valeria": {"ai_style":"sustain","identity":"혈검 흡혈","trait":"체력이 낮을수록 흡혈 우선","hp_mult":0.99,"attack_mult":1.05,"defense_bonus":1,"attack_interval_mult":0.98,"ult_gain_mult":1.02,"skill_cooldown_mult":1.00,"skill_value_mult":1.02,"duration_mult":1.00,"sustain_mult":1.16},
	"morgas": {"ai_style":"controller","identity":"핏빛 저주","trait":"취약 효과를 길게 유지","hp_mult":0.98,"attack_mult":0.92,"defense_bonus":1,"attack_interval_mult":1.05,"ult_gain_mult":1.07,"skill_cooldown_mult":0.98,"skill_value_mult":1.00,"duration_mult":1.15,"sustain_mult":1.00},
	"ragna": {"ai_style":"aggressive","identity":"달빛 돌진","trait":"빠르게 선공해 전열 압박","hp_mult":1.02,"attack_mult":1.04,"defense_bonus":1,"attack_interval_mult":0.91,"ult_gain_mult":1.04,"skill_cooldown_mult":0.98,"skill_value_mult":1.02,"duration_mult":1.00,"sustain_mult":1.00},
	"bron": {"ai_style":"protector","identity":"파쇄 탱커","trait":"정예전에서 기절 우선","hp_mult":1.08,"attack_mult":0.92,"defense_bonus":4,"attack_interval_mult":1.04,"ult_gain_mult":0.99,"skill_cooldown_mult":1.00,"skill_value_mult":1.00,"duration_mult":1.10,"sustain_mult":1.00},
	"nyx": {"ai_style":"controller","identity":"밤의 낙인","trait":"보스·정예 취약 유지","hp_mult":0.96,"attack_mult":0.98,"defense_bonus":0,"attack_interval_mult":1.01,"ult_gain_mult":1.06,"skill_cooldown_mult":0.98,"skill_value_mult":1.00,"duration_mult":1.14,"sustain_mult":1.00},
	"fenris": {"ai_style":"aggressive","identity":"회색 발톱","trait":"최고 수준의 기본공격 속도","hp_mult":0.92,"attack_mult":1.05,"defense_bonus":0,"attack_interval_mult":0.84,"ult_gain_mult":1.04,"skill_cooldown_mult":0.97,"skill_value_mult":1.00,"duration_mult":1.00,"sustain_mult":1.00},
	"isolde": {"ai_style":"support","identity":"피의 성녀","trait":"부상 아군 둘에게 회복 분배","hp_mult":1.00,"attack_mult":0.88,"defense_bonus":1,"attack_interval_mult":1.04,"ult_gain_mult":1.10,"skill_cooldown_mult":0.99,"skill_value_mult":1.08,"duration_mult":1.00,"sustain_mult":1.08},
	"garm": {"ai_style":"protector","identity":"철갑 송곳니","trait":"자기회복과 도발로 전열 고정","hp_mult":1.13,"attack_mult":0.85,"defense_bonus":6,"attack_interval_mult":1.07,"ult_gain_mult":0.96,"skill_cooldown_mult":1.00,"skill_value_mult":1.00,"duration_mult":1.08,"sustain_mult":1.00},
	"veyra": {"ai_style":"sustain","identity":"그림자 흡혈검","trait":"빈사 적 처형·자기회복","hp_mult":0.91,"attack_mult":1.11,"defense_bonus":0,"attack_interval_mult":0.96,"ult_gain_mult":1.01,"skill_cooldown_mult":1.02,"skill_value_mult":1.08,"duration_mult":1.00,"sustain_mult":1.12},
	"ulric": {"ai_style":"controller","identity":"월식 강습","trait":"돌진 후 짧은 기절 연계","hp_mult":1.00,"attack_mult":1.04,"defense_bonus":1,"attack_interval_mult":0.95,"ult_gain_mult":1.03,"skill_cooldown_mult":1.00,"skill_value_mult":1.04,"duration_mult":1.10,"sustain_mult":1.00},
	"adrien": {"ai_style": "balanced", "identity": "은빛 결투가", "trait": "검 끝으로 공격을 흘리고 반격하는 정교한 결투가.", "hp_mult": 1.0, "attack_mult": 1.0, "defense_bonus": 1, "attack_interval_mult": 1.0, "ult_gain_mult": 1.0, "skill_cooldown_mult": 1.0, "skill_value_mult": 1.0, "duration_mult": 1.0, "sustain_mult": 1.0},
	"tessa": {"ai_style": "balanced", "identity": "룬포 기술자", "trait": "작은 룬포의 과열을 조절하며 밀집한 적을 공략한다.", "hp_mult": 1.0, "attack_mult": 1.0, "defense_bonus": 1, "attack_interval_mult": 1.0, "ult_gain_mult": 1.0, "skill_cooldown_mult": 1.0, "skill_value_mult": 1.0, "duration_mult": 1.0, "sustain_mult": 1.0},
	"naia": {"ai_style": "finisher", "identity": "별자리 관측자", "trait": "온전한 적과 정예에게 별점을 새기는 먼 거리 관측자.", "hp_mult": 1.0, "attack_mult": 1.0, "defense_bonus": 1, "attack_interval_mult": 1.0, "ult_gain_mult": 1.0, "skill_cooldown_mult": 1.0, "skill_value_mult": 1.0, "duration_mult": 1.0, "sustain_mult": 1.0},
	"sael": {"ai_style": "aggressive", "identity": "잎새 쌍검사", "trait": "숲길을 가로지른 이동을 검무의 추진력으로 바꾼다.", "hp_mult": 1.0, "attack_mult": 1.0, "defense_bonus": 1, "attack_interval_mult": 1.0, "ult_gain_mult": 1.0, "skill_cooldown_mult": 1.0, "skill_value_mult": 1.0, "duration_mult": 1.0, "sustain_mult": 1.0},
	"odelia": {"ai_style": "controller", "identity": "문장 봉인관", "trait": "약화와 취약을 번갈아 새겨 아군의 공략 창을 만든다.", "hp_mult": 1.0, "attack_mult": 0.96, "defense_bonus": 1, "attack_interval_mult": 1.0, "ult_gain_mult": 1.05, "skill_cooldown_mult": 1.0, "skill_value_mult": 1.0, "duration_mult": 1.1, "sustain_mult": 1.0},
	"lucien": {"ai_style": "sustain", "identity": "혈약 창술사", "trait": "자신의 현재 체력을 대가로 묵직한 창격을 강화한다.", "hp_mult": 1.0, "attack_mult": 1.0, "defense_bonus": 1, "attack_interval_mult": 1.0, "ult_gain_mult": 1.0, "skill_cooldown_mult": 1.0, "skill_value_mult": 1.0, "duration_mult": 1.0, "sustain_mult": 1.0},
	"corvin": {"ai_style": "balanced", "identity": "황혼 지휘봉", "trait": "동료가 남긴 약화를 공명시켜 단단한 적을 공략한다.", "hp_mult": 1.0, "attack_mult": 1.0, "defense_bonus": 1, "attack_interval_mult": 1.0, "ult_gain_mult": 1.0, "skill_cooldown_mult": 1.0, "skill_value_mult": 1.0, "duration_mult": 1.0, "sustain_mult": 1.0},
	"rokan": {"ai_style": "aggressive", "identity": "무리 투창수", "trait": "같은 표적을 추적해 투창의 빈틈을 줄이는 사냥꾼.", "hp_mult": 1.0, "attack_mult": 1.0, "defense_bonus": 1, "attack_interval_mult": 1.0, "ult_gain_mult": 1.0, "skill_cooldown_mult": 1.0, "skill_value_mult": 1.0, "duration_mult": 1.0, "sustain_mult": 1.0},
	"bora": {"ai_style": "sustain", "identity": "설원 권투가", "trait": "상처가 깊어질수록 방어와 연타를 함께 준비한다.", "hp_mult": 1.0, "attack_mult": 1.0, "defense_bonus": 1, "attack_interval_mult": 1.0, "ult_gain_mult": 1.0, "skill_cooldown_mult": 1.0, "skill_value_mult": 1.0, "duration_mult": 1.0, "sustain_mult": 1.0},
	"selene": {"ai_style": "support", "identity": "홍실 재봉사", "trait": "회복과 다른 홍실 보호막으로 동료의 다음 피격을 막는다.", "hp_mult": 1.0, "attack_mult": 0.87, "defense_bonus": 1, "attack_interval_mult": 1.0, "ult_gain_mult": 1.08, "skill_cooldown_mult": 1.0, "skill_value_mult": 1.08, "duration_mult": 1.0, "sustain_mult": 1.0}
}

func profile(hero_id: String) -> Dictionary:
	return PROFILES.get(hero_id, {
		"ai_style":"balanced","identity":"균형 전투","trait":"상황에 맞춘 균형 행동",
		"hp_mult":1.0,"attack_mult":1.0,"defense_bonus":0,"attack_interval_mult":1.0,
		"ult_gain_mult":1.0,"skill_cooldown_mult":1.0,"skill_value_mult":1.0,
		"duration_mult":1.0,"sustain_mult":1.0
	}).duplicate(true)

func ai_style_name(style: String) -> String:
	var names := {
		"protector":"수호 우선",
		"support":"지원 우선",
		"controller":"제어 우선",
		"aggressive":"공격 우선",
		"finisher":"처형 우선",
		"sustain":"생존 공격",
		"balanced":"균형 전술"
	}
	return str(names.get(style, "균형 전술"))

func compact_text(hero_id: String) -> String:
	var p := profile(hero_id)
	return "%s · %s" % [ai_style_name(str(p.get("ai_style","balanced"))), str(p.get("identity","균형 전투"))]

func balance_budget(hero_id: String) -> float:
	var p := profile(hero_id)
	var speed_value := 1.0 / maxf(0.70, float(p.get("attack_interval_mult",1.0)))
	return (
		float(p.get("hp_mult",1.0)) * 0.24 +
		float(p.get("attack_mult",1.0)) * 0.30 +
		speed_value * 0.12 +
		float(p.get("ult_gain_mult",1.0)) * 0.08 +
		(2.0 - float(p.get("skill_cooldown_mult",1.0))) * 0.06 +
		float(p.get("skill_value_mult",1.0)) * 0.08 +
		float(p.get("duration_mult",1.0)) * 0.06 +
		float(p.get("sustain_mult",1.0)) * 0.04 +
		clampf(float(p.get("defense_bonus",0)) / 10.0, 0.0, 1.0) * 0.02
	)

func faction_average(hero_ids: Array) -> float:
	if hero_ids.is_empty():
		return 0.0
	var total := 0.0
	for hero_id in hero_ids:
		total += balance_budget(str(hero_id))
	return total / float(hero_ids.size())
