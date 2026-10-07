extends Node
class_name HeroSpriteFactory

const BATTLEFIELD_SCALE := 0.065
const BRIGHT_HERO_HEIGHT := 40.0
const BRIGHT_SPRITES := {
	"leonhardt": "res://assets/sprites/bright-v28/leonhardt-sheet.png",
	"mira": "res://assets/sprites/bright-v28/mira-sheet.png",
	"orwin": "res://assets/sprites/bright-v28/orwin-sheet.png",
	"darius": "res://assets/sprites/bright-v28/darius-sheet.png",
	"caelum": "res://assets/sprites/bright-v28/caelum-sheet.png"
}

const HERO_SPRITES := {
	"leonhardt": "res://assets/sprites/leonhardt-sheet.png",
	"mira": "res://assets/sprites/mira-sheet.png",
	"elisia": "res://assets/sprites/elisia-sheet.png"
}

static func create_hero(hero_id: String, scale := Vector2(1.0, 1.0)) -> HeroSpriteController:
	# Two approved action sheets, isolated from the 30-hero SD fallback and gameplay.
	if hero_id in ["leonhardt", "valeria"] and OS.get_environment("V37_DISABLE_ACTIONS") != "1":
		var actor = preload("res://scripts/actions_v37/TwoHeroActionSprite.gd").new()
		actor.name = "%sSprite" % hero_id
		actor.configure_actions(hero_id)
		actor.scale = scale * (BRIGHT_HERO_HEIGHT / BATTLEFIELD_SCALE / maxf(actor.native_visual_height, 1.0))
		return actor
	# Noxfera art-only pass: existing IDs, unchanged gameplay. Disable only for equivalence tests.
	var noxfera_art = preload("res://scripts/noxfera_v42/NoxferaMotionCatalog.gd")
	if noxfera_art.has_hero(hero_id) and OS.get_environment("NOXFERA_V42_BASELINE") != "1":
		var actor = preload("res://scripts/noxfera_v42/NoxferaActionSprite.gd").new()
		actor.name = "%sSprite" % hero_id
		actor.configure_actions(hero_id)
		actor.scale = scale * (BRIGHT_HERO_HEIGHT / BATTLEFIELD_SCALE / maxf(actor.native_visual_height,1.0))
		return actor
	# Aurelia art-only pass: existing IDs, unchanged gameplay. Disable only for equivalence tests.
	var aurelia_art = preload("res://scripts/aurelia_v41/AureliaMotionCatalog.gd")
	if aurelia_art.has_hero(hero_id) and OS.get_environment("AURELIA_V41_BASELINE") != "1":
		var actor = preload("res://scripts/aurelia_v41/AureliaActionSprite.gd").new()
		actor.name = "%sSprite" % hero_id
		actor.configure_actions(hero_id)
		actor.scale = scale * (BRIGHT_HERO_HEIGHT / BATTLEFIELD_SCALE / maxf(actor.native_visual_height,1.0))
		return actor
	# v36 SD presentation-only route. Legacy branches remain as fallbacks.
	var sd_catalog = preload("res://scripts/sd/SDHeroVisuals.gd")
	if sd_catalog.has_hero(hero_id):
		var sd_hero = preload("res://scripts/sd/SDHeroSpriteController.gd").new()
		sd_hero.name = "%sSprite" % hero_id
		sd_hero.configure_sd(hero_id)
		sd_hero.scale = scale * (BRIGHT_HERO_HEIGHT / BATTLEFIELD_SCALE / maxf(sd_hero.native_visual_height, 1.0))
		return sd_hero
	var hero := HeroSpriteController.new()
	hero.name = "%sSprite" % hero_id
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hero.material = preload("res://scripts/art/PixelArtPipeline.gd").actor_material()
	hero.scale = scale
	var texture_path: String = HERO_SPRITES.get(hero_id, "")
	var bright_path: String = BRIGHT_SPRITES.get(hero_id, "")
	var artwork_ready := false
	if not bright_path.is_empty() and ResourceLoader.exists(bright_path):
		hero.set_bright_sheet(load(bright_path) as Texture2D, hero_id)
		artwork_ready = hero._frames_ready
	if not artwork_ready and HeroAnimationAtlas.has_hero(hero_id):
		artwork_ready = hero.set_animation_atlas(load(HeroAnimationAtlas.sheet_path(hero_id)) as Texture2D, hero_id)
	if not artwork_ready and not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		hero.sheet_layout = "legacy"
		hero.set_sprite_sheet(load(texture_path))
		artwork_ready = hero._frames_ready
	if artwork_ready:
		hero.scale = scale * (BRIGHT_HERO_HEIGHT / BATTLEFIELD_SCALE / maxf(hero.native_visual_height, 1.0))
	else:
		# An unknown or damaged asset must not make an actor invisible. This
		# emergency silhouette is not used by any of the 30 packaged heroes.
		var marker := Polygon2D.new()
		marker.polygon = PackedVector2Array([Vector2(-4, -24), Vector2(4, -24), Vector2(6, -18), Vector2(9, -14), Vector2(7, -6), Vector2(4, -8), Vector2(5, 0), Vector2(1, 0), Vector2(0, -5), Vector2(-1, 0), Vector2(-5, 0), Vector2(-4, -8), Vector2(-7, -6), Vector2(-9, -14), Vector2(-6, -18)])
		marker.color = Color(str(preload("res://scripts/heroes/HeroRosterCatalog.gd").HEROES.get(hero_id, {}).get("color", "#e36b78")))
		marker.scale = Vector2(1.0 / maxf(scale.x, 0.001), 1.0 / maxf(scale.y, 0.001))
		hero.add_child(marker)
	return hero

static func portrait_texture(hero_id: String) -> Texture2D:
	if ResourceLoader.exists("res://scripts/heroes/HeroVisualCatalog.gd"):
		var visual_catalog = load("res://scripts/heroes/HeroVisualCatalog.gd")
		if visual_catalog != null and visual_catalog.has_hero(hero_id):
			var portrait: Texture2D = visual_catalog.portrait_texture(hero_id)
			if portrait != null:
				return portrait
	var bright_path: String = BRIGHT_SPRITES.get(hero_id, "")
	if not bright_path.is_empty() and ResourceLoader.exists(bright_path):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(bright_path) as Texture2D
		atlas.region = Rect2(BrightSpriteAtlasLayout.REGIONS[hero_id][0])
		return atlas
	var legacy_path: String = HERO_SPRITES.get(hero_id, "")
	if not legacy_path.is_empty() and ResourceLoader.exists(legacy_path):
		var texture := load(legacy_path) as Texture2D
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2.ZERO, texture.get_size() / 4.0)
		return atlas
	return null

static func attach_to(parent: Node2D, hero_id: String, position := Vector2.ZERO, scale := Vector2(1.0, 1.0)) -> HeroSpriteController:
	var hero := create_hero(hero_id, scale)
	hero.position = position
	parent.add_child(hero)
	hero.play_idle("down")
	return hero
