extends RefCounted
## Sprite resources only. No new hero IDs, stats, skill names or gameplay constants.
const HERO_IDS: Array[String] = ["mira", "elisia", "kairen", "orwin", "seria", "astel", "darius", "lunea", "caelum", "adrien", "tessa", "naia", "sael", "odelia"]
static func has_hero(hero_id: String) -> bool:
	return hero_id in HERO_IDS
static func frames_for(hero_id: String) -> SpriteFrames:
	if not has_hero(hero_id):return null
	return load("res://assets/heroes/aurelia-motion-v41/%s/frames.tres" % hero_id) as SpriteFrames
static func release_cache() -> void:
	pass # ResourceLoader/actor references own atlas lifetime; no static cache retention.
