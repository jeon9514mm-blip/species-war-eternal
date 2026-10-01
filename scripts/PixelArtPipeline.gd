extends RefCounted
class_name PixelArtPipeline

## Shared presentation-only palette finish. Source pixels, alpha, atlas UVs,
## dimensions, pivots and animation data are untouched.
const ACTOR_SHADER = preload("res://assets/shaders/pixel-actor-v32.gdshader")
static var _actor_material: ShaderMaterial

static func actor_material() -> ShaderMaterial:
	if _actor_material == null:
		_actor_material = ShaderMaterial.new()
		_actor_material.shader = ACTOR_SHADER
	return _actor_material
