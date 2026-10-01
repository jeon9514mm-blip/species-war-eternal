extends RefCounted
class_name EquipmentArtCatalog

## v32: exact item art, independent of item stats and equipment eligibility.
## Fire staff is an art-only sample, not a newly added drop.
const ATLAS_PATH := "res://assets/ui/pixel-v32/equipment-icons-v32.png"
const COLUMNS := 4
const ROWS := 3
const ITEM_CELLS := {
	"낡은 사냥검": 0, "푸른 별의 활": 1, "새벽의 성검": 2,
	"튼튼한 가죽갑옷": 4, "월광 비늘갑옷": 5, "불멸의 수호갑": 6,
	"초보자의 가죽갑옷": 7, "빛바랜 부적": 8, "마력의 반지": 9,
	"왕국의 심장": 10, "초보자의 검": 11,
}
static var _textures: Dictionary = {}

static func cell_for(item: Dictionary) -> int:
	var item_name := str(item.get("name", ""))
	if ITEM_CELLS.has(item_name): return int(ITEM_CELLS[item_name])
	# Old saves and generic items still get art for their real slot and rarity.
	var rank: int = int({"일반": 0, "희귀": 1, "전설": 2}.get(str(item.get("rarity", "일반")), 0))
	match str(item.get("slot", "weapon")):
		"armor": return 4 + int(rank)
		"accessory": return 8 + int(rank)
	return int(rank)

static func texture_for(item: Dictionary) -> Texture2D:
	return cell_texture(cell_for(item))

static func cell_texture(index: int) -> Texture2D:
	if index < 0 or index >= COLUMNS * ROWS: return null
	if _textures.has(index): return _textures[index]
	if not ResourceLoader.exists(ATLAS_PATH): return null
	var atlas := load(ATLAS_PATH) as Texture2D
	var cell := Vector2(atlas.get_width() / float(COLUMNS), atlas.get_height() / float(ROWS))
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(Vector2(index % COLUMNS, index / COLUMNS) * cell, cell)
	texture.filter_clip = true
	_textures[index] = texture
	return texture
