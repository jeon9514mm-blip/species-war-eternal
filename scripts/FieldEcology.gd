extends RefCounted
class_name FieldEcology

# A species keeps its combat role across encounters and regions.
const SPECIES := {
	"초원 고블린": {"role":"skirmisher", "sight":2.3},
	"들개 무리": {"role":"assassin", "sight":2.6},
	"가시 멧돼지": {"role":"brute", "sight":2.0},
	"바람 까마귀": {"role":"ranged", "sight":2.8},
	"광산 오크": {"role":"brute", "sight":2.3},
	"철갑 두더지": {"role":"brute", "sight":1.9},
	"용암 박쥐": {"role":"ranged", "sight":2.6},
	"수정 거미": {"role":"support", "sight":2.4},
	"달빛 늑대": {"role":"assassin", "sight":2.8},
	"숲의 망령": {"role":"ranged", "sight":2.6},
	"독버섯 정령": {"role":"support", "sight":2.3},
	"밤까마귀": {"role":"ranged", "sight":2.8},
	"서리 사슴": {"role":"brute", "sight":2.2}
}

static func species_profile(monster_name: String, fallback: String = "brute") -> Dictionary:
	return SPECIES.get(monster_name, {"role":fallback, "sight":2.4}).duplicate(true)

static func stage_pressure(stage: int, unlock_stage: int) -> float:
	return 1.0 + minf(0.35, float(maxi(0, clampi(stage, 1, 10000) - maxi(1, unlock_stage))) * 0.0125)

static func population_count(party_size: int, difficulty: int) -> int:
	# v70: denser hunting grounds. The population grows from 8 up to 20,
	# while RoamingHuntDirector still partitions it into local aggro packs.
	var heroes := clampi(party_size, 1, 10)
	var tier := int((heroes - 1) / 2.0)
	var population := 8 + tier * 2 + (clampi(difficulty, 1, 3) - 1) * 2
	return clampi(population, 8, 20)

static func pack_size(population: int) -> int:
	return 2 if population <= 4 else (3 if population <= 8 else (4 if population <= 14 else 5))

static func respawn_delay(difficulty: int) -> float:
	return 0.45 + float(clampi(difficulty, 1, 3)) * 0.05

static func prepare_enemy(enemy: Dictionary, stage: int, unlock_stage: int, difficulty: int) -> Dictionary:
	var result := enemy.duplicate(true)
	var pressure := stage_pressure(stage, unlock_stage)
	result["max_hp"] = maxi(1, int(float(result.get("max_hp", 1)) * pressure))
	result["hp"] = result["max_hp"]
	result["attack"] = maxi(1, int(float(result.get("attack", 1)) * sqrt(pressure)))
	result["base_attack"] = result["attack"]
	var species := species_profile(str(result.get("name", "")), str(result.get("archetype", "brute")))
	result["sight_radius"] = float(species["sight"])
	result["leash_radius"] = 2.6 + float(clampi(difficulty, 1, 3)) * 0.15
	result["healing_range"] = 1.6
	result["stun_seconds"] = 0.0
	result["weaken_seconds"] = 0.0
	result["vulnerable_seconds"] = 0.0
	return result
