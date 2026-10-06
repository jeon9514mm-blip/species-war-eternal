extends RefCounted
## Canonical zone names and gameplay data; stable IDs remain save keys.
const MINE_NAME := "사냥터 2"
const FOREST_NAME := "사냥터 3"
const MEADOW_NAME := "사냥터 1"
static func all() -> Dictionary:
	return {
		"gray_meadow": {
			"name": MEADOW_NAME,
			"description": "청록 룬이 빛나는 돌바닥에서 여러 방향의 몬스터를 사냥합니다.",
				"monsters": ["초원 고블린", "들개 무리", "가시 멧돼지", "바람 까마귀"],
				"boss": "초원왕 그룬",
				"boss_title": "초원의 포식자",
				"boss_skill": "대지 포효",
			"wave_pattern": ["brute", "skirmisher", "ranged", "skirmisher", "support"],
			"battle_trait": "정면 압박 · 균형형",
			"equipment_set": "개척자",
			"difficulty": 1,
			"unlock_stage": 1,
			"power": 180,
			"gold": 35,
			"xp": 22,
			"color": Color("#68badb"),
			"positions": [Vector2(2, 0), Vector2(4, 1), Vector2(0, 3), Vector2(6, 4)]
		},
		"forgotten_mine": {
			"name": MINE_NAME,
			"description": "호박색 룬과 흙빛 돌바닥에서 몬스터 무리와 전투합니다.",
				"monsters": ["광산 오크", "철갑 두더지", "용암 박쥐", "수정 거미"],
				"boss": "광맥의 거인 모르굴",
				"boss_title": "검은 광산의 수호자",
				"boss_skill": "광석 낙하",
			"wave_pattern": ["brute", "brute", "support", "ranged", "assassin"],
			"battle_trait": "중갑 전열 · 지원형",
			"equipment_set": "강철",
			"difficulty": 2,
			"unlock_stage": 4,
			"power": 360,
			"gold": 70,
			"xp": 48,
			"color": Color("#c28b5c"),
			"positions": [Vector2(1, 1), Vector2(5, 0), Vector2(2, 3), Vector2(6, 2)]
		},
		"moonrest_forest": {
			"name": FOREST_NAME,
			"description": "차가운 돌바닥과 보랏빛 룬 위에서 몬스터 무리를 사냥합니다.",
				"monsters": ["달빛 늑대", "숲의 망령", "독버섯 정령", "밤까마귀", "서리 사슴"],
				"boss": "월식의 여왕 셀레네",
				"boss_title": "달잠 숲의 지배자",
				"boss_skill": "월식의 저주",
			"wave_pattern": ["assassin", "ranged", "support", "assassin", "skirmisher"],
			"battle_trait": "후열 기습 · 고속 암살",
			"equipment_set": "월광",
			"difficulty": 3,
			"unlock_stage": 8,
			"power": 620,
			"gold": 120,
			"xp": 86,
			"color": Color("#9b82d6"),
			"positions": [Vector2(0, 0), Vector2(5, 1), Vector2(1, 4), Vector2(5, 4)]
		}
	}

static func display_name(id: String) -> String:
	return str(all().get(id, {}).get("name", id))
