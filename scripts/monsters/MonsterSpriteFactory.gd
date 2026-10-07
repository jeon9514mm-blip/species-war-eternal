extends Node
class_name MonsterSpriteFactory

const PIXEL_PIPELINE := preload("res://scripts/art/PixelArtPipeline.gd")
const CASUAL := preload('res://scripts/portrait/CasualMonsterAtlas.gd')
const PIXEL_PROFILES := MonsterPixelAtlasLayout.PROFILES
static var _pixel_material: ShaderMaterial

static func pixel_material() -> ShaderMaterial:
	if _pixel_material == null:
		_pixel_material = PIXEL_PIPELINE.actor_material().duplicate() as ShaderMaterial
		# Crisp source silhouettes; node alpha is multiplied afterwards so
		# death fades and other runtime modulation remain continuous.
		_pixel_material.set_shader_parameter("alpha_cutoff", 0.5)
	return _pixel_material

const BATTLEFIELD_SCALE := 0.09
const BRIGHT_ATLAS := "res://assets/monsters/bright-v28/field-monsters-atlas.png"
const BRIGHT_COLUMNS := {"초원 고블린": 0, "들개 무리": 1, "가시 멧돼지": 2, "철갑 두더지": 3, "독버섯 정령": 4, "달빛 늑대": 5}
const BRIGHT_HEIGHTS := [38.0, 36.0, 42.0, 38.0, 38.0, 44.0]

const MONSTER_SPRITES := {
	"초원 고블린": "res://assets/monsters/gray-meadow-goblin.png",
	"들개 무리": "res://assets/monsters/gray-meadow-wolves.png",
	"가시 멧돼지": "res://assets/monsters/gray-meadow-boar.png",
	"바람 까마귀": "res://assets/monsters/gray-meadow-crow.png",
	"광산 오크": "res://assets/monsters/forgotten-mine-orc.png",
	"철갑 두더지": "res://assets/monsters/forgotten-mine-mole.png",
	"용암 박쥐": "res://assets/monsters/forgotten-mine-bat.png",
	"수정 거미": "res://assets/monsters/forgotten-mine-spider.png",
	"달빛 늑대": "res://assets/monsters/moonrest-wolf.png",
	"숲의 망령": "res://assets/monsters/moonrest-wraith.png",
	"독버섯 정령": "res://assets/monsters/moonrest-mushroom.png",
	"밤까마귀": "res://assets/monsters/moonrest-raven.png",
	"서리 사슴": "res://assets/monsters/moonrest-deer.png",
	"초원왕 그룬": "res://assets/monsters/gray-meadow-boss.png",
	"광맥의 거인 모르굴": "res://assets/monsters/forgotten-mine-boss.png",
	"월식의 여왕 셀레네": "res://assets/monsters/moonrest-boss.png"
}

static func create_monster(monster_name: String, scale := Vector2(0.12, 0.12)) -> MonsterSpriteController:
	var monster := MonsterSpriteController.new()
	monster.name = "%sSprite" % monster_name
	apply_monster(monster, monster_name, scale)
	return monster

static func apply_monster(monster: MonsterSpriteController, monster_name: String, scale := Vector2(0.12, 0.12)) -> bool:
	monster.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	monster.presentation_scale = scale
	var texture_path: String = MONSTER_SPRITES.get(monster_name, "")
	var pixel_path := MonsterPixelAtlasLayout.sheet_path(monster_name)
	if not pixel_path.is_empty() and ResourceLoader.exists(pixel_path):
		var profile: Dictionary = PIXEL_PROFILES[monster_name]
		monster.set_pixel_sheet(load(pixel_path) as Texture2D, monster_name)
		monster.material = pixel_material()
		monster.set_presentation_scale(scale * (float(profile["target_height"]) / float(profile["reference_scale"]) / maxf(monster.native_visual_height, 1.0)))
	elif BRIGHT_COLUMNS.has(monster_name) and ResourceLoader.exists(BRIGHT_ATLAS):
		var column: int = BRIGHT_COLUMNS[monster_name]
		monster.set_bright_sheet(load(BRIGHT_ATLAS) as Texture2D, column)
		monster.set_presentation_scale(scale * (BRIGHT_HEIGHTS[column] / BATTLEFIELD_SCALE / maxf(monster.native_visual_height, 1.0)))
	elif not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		monster.sheet_layout = "legacy"
		monster.frame_columns = 1
		monster.frame_rows = 1
		monster.set_sprite_sheet(load(texture_path) as Texture2D)
		var boss: bool = texture_path.ends_with("-boss.png")
		var target_height := 100.0 if boss else 44.0
		var reference_scale := 0.07 if boss else BATTLEFIELD_SCALE
		monster.set_presentation_scale(scale * (target_height / reference_scale / maxf(monster.native_visual_height, 1.0)))
	else:
		return false
	return true

static func apply_casual(monster: MonsterSpriteController, monster_name: String, scale := Vector2(0.12, 0.12)) -> bool:
	if not CASUAL.has_monster(monster_name):return apply_monster(monster,monster_name,scale)
	monster.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	monster.presentation_scale=scale
	monster.material=null
	monster.set_casual_sheet(CASUAL.texture(monster_name),monster_name)
	var profile: Dictionary=PIXEL_PROFILES[monster_name]
	monster.set_presentation_scale(scale*(float(profile['target_height'])/float(profile['reference_scale'])/maxf(monster.native_visual_height,1.0)))
	return true

static func get_casual_portrait_texture(monster_name: String) -> Texture2D:
	return CASUAL.frame(monster_name,0) if CASUAL.has_monster(monster_name) else get_portrait_texture(monster_name)

static func get_portrait_texture(monster_name: String) -> Texture2D:
	var pixel_path := MonsterPixelAtlasLayout.sheet_path(monster_name)
	if not pixel_path.is_empty() and ResourceLoader.exists(pixel_path):
		return MonsterPixelAtlasLayout.frame_texture(load(pixel_path) as Texture2D, monster_name, 0)
	var path: String = MONSTER_SPRITES.get(monster_name, "")
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null

static func attach_to(parent: Node2D, monster_name: String, position := Vector2.ZERO, scale := Vector2(0.12, 0.12)) -> MonsterSpriteController:
	var monster := create_monster(monster_name, scale)
	monster.position = position
	parent.add_child(monster)
	monster.play_idle("down")
	return monster
