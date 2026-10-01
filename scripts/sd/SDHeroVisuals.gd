extends RefCounted
## Image routing only; no gameplay data.
const HEROES: Dictionary = {
	"leonhardt": {"portrait": "res://assets/heroes/sd-v36/portraits/leonhardt.png", "sheet": "res://assets/heroes/sd-v36/sheets/leonhardt-motion.png", "native_height": 201.0},
	"mira": {"portrait": "res://assets/heroes/sd-v36/portraits/mira.png", "sheet": "res://assets/heroes/sd-v36/sheets/mira-motion.png", "native_height": 207.0},
	"elisia": {"portrait": "res://assets/heroes/sd-v36/portraits/elisia.png", "sheet": "res://assets/heroes/sd-v36/sheets/elisia-motion.png", "native_height": 195.0},
	"kairen": {"portrait": "res://assets/heroes/sd-v36/portraits/kairen.png", "sheet": "res://assets/heroes/sd-v36/sheets/kairen-motion.png", "native_height": 238.0},
	"orwin": {"portrait": "res://assets/heroes/sd-v36/portraits/orwin.png", "sheet": "res://assets/heroes/sd-v36/sheets/orwin-motion.png", "native_height": 150.0},
	"seria": {"portrait": "res://assets/heroes/sd-v36/portraits/seria.png", "sheet": "res://assets/heroes/sd-v36/sheets/seria-motion.png", "native_height": 205.0},
	"astel": {"portrait": "res://assets/heroes/sd-v36/portraits/astel.png", "sheet": "res://assets/heroes/sd-v36/sheets/astel-motion.png", "native_height": 227.0},
	"darius": {"portrait": "res://assets/heroes/sd-v36/portraits/darius.png", "sheet": "res://assets/heroes/sd-v36/sheets/darius-motion.png", "native_height": 204.0},
	"lunea": {"portrait": "res://assets/heroes/sd-v36/portraits/lunea.png", "sheet": "res://assets/heroes/sd-v36/sheets/lunea-motion.png", "native_height": 222.0},
	"caelum": {"portrait": "res://assets/heroes/sd-v36/portraits/caelum.png", "sheet": "res://assets/heroes/sd-v36/sheets/caelum-motion.png", "native_height": 186.0},
	"adrien": {"portrait": "res://assets/heroes/sd-v36/portraits/adrien.png", "sheet": "res://assets/heroes/sd-v36/sheets/adrien-motion.png", "native_height": 214.0},
	"tessa": {"portrait": "res://assets/heroes/sd-v36/portraits/tessa.png", "sheet": "res://assets/heroes/sd-v36/sheets/tessa-motion.png", "native_height": 220.0},
	"naia": {"portrait": "res://assets/heroes/sd-v36/portraits/naia.png", "sheet": "res://assets/heroes/sd-v36/sheets/naia-motion.png", "native_height": 238.0},
	"sael": {"portrait": "res://assets/heroes/sd-v36/portraits/sael.png", "sheet": "res://assets/heroes/sd-v36/sheets/sael-motion.png", "native_height": 222.0},
	"odelia": {"portrait": "res://assets/heroes/sd-v36/portraits/odelia.png", "sheet": "res://assets/heroes/sd-v36/sheets/odelia-motion.png", "native_height": 217.0},
	"valeria": {"portrait": "res://assets/heroes/sd-v36/portraits/valeria.png", "sheet": "res://assets/heroes/sd-v36/sheets/valeria-motion.png", "native_height": 186.0},
	"morgas": {"portrait": "res://assets/heroes/sd-v36/portraits/morgas.png", "sheet": "res://assets/heroes/sd-v36/sheets/morgas-motion.png", "native_height": 214.0},
	"ragna": {"portrait": "res://assets/heroes/sd-v36/portraits/ragna.png", "sheet": "res://assets/heroes/sd-v36/sheets/ragna-motion.png", "native_height": 176.0},
	"bron": {"portrait": "res://assets/heroes/sd-v36/portraits/bron.png", "sheet": "res://assets/heroes/sd-v36/sheets/bron-motion.png", "native_height": 205.0},
	"nyx": {"portrait": "res://assets/heroes/sd-v36/portraits/nyx.png", "sheet": "res://assets/heroes/sd-v36/sheets/nyx-motion.png", "native_height": 187.0},
	"fenris": {"portrait": "res://assets/heroes/sd-v36/portraits/fenris.png", "sheet": "res://assets/heroes/sd-v36/sheets/fenris-motion.png", "native_height": 178.0},
	"isolde": {"portrait": "res://assets/heroes/sd-v36/portraits/isolde.png", "sheet": "res://assets/heroes/sd-v36/sheets/isolde-motion.png", "native_height": 208.0},
	"garm": {"portrait": "res://assets/heroes/sd-v36/portraits/garm.png", "sheet": "res://assets/heroes/sd-v36/sheets/garm-motion.png", "native_height": 178.0},
	"veyra": {"portrait": "res://assets/heroes/sd-v36/portraits/veyra.png", "sheet": "res://assets/heroes/sd-v36/sheets/veyra-motion.png", "native_height": 145.0},
	"ulric": {"portrait": "res://assets/heroes/sd-v36/portraits/ulric.png", "sheet": "res://assets/heroes/sd-v36/sheets/ulric-motion.png", "native_height": 182.0},
	"lucien": {"portrait": "res://assets/heroes/sd-v36/portraits/lucien.png", "sheet": "res://assets/heroes/sd-v36/sheets/lucien-motion.png", "native_height": 169.0},
	"corvin": {"portrait": "res://assets/heroes/sd-v36/portraits/corvin.png", "sheet": "res://assets/heroes/sd-v36/sheets/corvin-motion.png", "native_height": 195.0},
	"rokan": {"portrait": "res://assets/heroes/sd-v36/portraits/rokan.png", "sheet": "res://assets/heroes/sd-v36/sheets/rokan-motion.png", "native_height": 198.0},
	"bora": {"portrait": "res://assets/heroes/sd-v36/portraits/bora.png", "sheet": "res://assets/heroes/sd-v36/sheets/bora-motion.png", "native_height": 238.0},
	"selene": {"portrait": "res://assets/heroes/sd-v36/portraits/selene.png", "sheet": "res://assets/heroes/sd-v36/sheets/selene-motion.png", "native_height": 210.0},
}
static var portraits: Dictionary = {}
static var sheets: Dictionary = {}
static func has_hero(hero_id: String) -> bool:
	return HEROES.has(hero_id)
static func portrait(hero_id: String) -> Texture2D:
	if not has_hero(hero_id): return null
	if not portraits.has(hero_id): portraits[hero_id] = load(str(HEROES[hero_id]["portrait"])) as Texture2D
	return portraits[hero_id] as Texture2D
static func sheet(hero_id: String) -> Texture2D:
	if not has_hero(hero_id): return null
	if not sheets.has(hero_id): sheets[hero_id] = load(str(HEROES[hero_id]["sheet"])) as Texture2D
	return sheets[hero_id] as Texture2D
static func native_height(hero_id: String) -> float:
	return float(HEROES.get(hero_id, {}).get("native_height", 238.0))
