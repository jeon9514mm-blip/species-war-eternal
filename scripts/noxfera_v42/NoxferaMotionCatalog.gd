extends RefCounted
## Art resources only. Explicit identity paths also support static resource scanners.
const HERO_IDS: Array[String] = ["morgas", "ragna", "bron", "nyx", "fenris", "isolde", "garm", "veyra", "ulric", "lucien", "corvin", "rokan", "bora", "selene"]
const FRAME_PATHS: Dictionary = {
	"morgas": "res://assets/heroes/noxfera-motion-v42/morgas/frames.tres",
	"ragna": "res://assets/heroes/noxfera-motion-v42/ragna/frames.tres",
	"bron": "res://assets/heroes/noxfera-motion-v42/bron/frames.tres",
	"nyx": "res://assets/heroes/noxfera-motion-v42/nyx/frames.tres",
	"fenris": "res://assets/heroes/noxfera-motion-v42/fenris/frames.tres",
	"isolde": "res://assets/heroes/noxfera-motion-v42/isolde/frames.tres",
	"garm": "res://assets/heroes/noxfera-motion-v42/garm/frames.tres",
	"veyra": "res://assets/heroes/noxfera-motion-v42/veyra/frames.tres",
	"ulric": "res://assets/heroes/noxfera-motion-v42/ulric/frames.tres",
	"lucien": "res://assets/heroes/noxfera-motion-v42/lucien/frames.tres",
	"corvin": "res://assets/heroes/noxfera-motion-v42/corvin/frames.tres",
	"rokan": "res://assets/heroes/noxfera-motion-v42/rokan/frames.tres",
	"bora": "res://assets/heroes/noxfera-motion-v42/bora/frames.tres",
	"selene": "res://assets/heroes/noxfera-motion-v42/selene/frames.tres",
}
static func has_hero(hero_id: String) -> bool:
	return FRAME_PATHS.has(hero_id)
static func frames_for(hero_id: String) -> SpriteFrames:
	if not has_hero(hero_id):return null
	return load(str(FRAME_PATHS[hero_id])) as SpriteFrames
static func release_cache() -> void:
	pass # No static texture retention.
