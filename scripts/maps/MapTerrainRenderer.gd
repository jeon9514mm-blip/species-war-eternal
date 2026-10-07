extends Control
class_name MapTerrainRenderer

## A single world-space projection keeps the terrain and roaming actors aligned.
const WORLD_SIZE := Vector2(32.0, 20.0)
const MOOD_BRIGHTNESS := 0.90
const MOOD_SATURATION := 0.88
const AMBIENT_REDRAW_INTERVAL := 0.08
const FIELD_ART := preload("res://scripts/maps/FieldArtCatalog.gd")
const MEADOW_PATH := ""
var zone_id := "gray_meadow"
var zone_color := Color("#75b98a")
var elapsed := 0.0
var redraw_accumulator := 0.0
var camera_position := WORLD_SIZE * 0.5
var pixels_per_unit := 61.333333
var local_anchor := Vector2(612, 239.2)
var field_texture: Texture2D
var grid_size := Vector2i(7, 5)
var cell_size := Vector2(94, 44)
var map_origin := Vector2(53, 85)

func configure(next_zone_id: String, next_zone_color: Color) -> void:
	zone_id = next_zone_id
	zone_color = next_zone_color
	field_texture = FIELD_ART.texture_for(zone_id)
	queue_redraw()

func configure_world_view(ppu: float, anchor: Vector2) -> void:
	pixels_per_unit = maxf(1.0, ppu)
	local_anchor = anchor
	queue_redraw()

func set_camera_position(world_position: Vector2) -> void:
	camera_position = world_position
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if field_texture == null:
		field_texture = FIELD_ART.texture_for(zone_id)
	var mood := Shader.new()
	mood.code = "shader_type canvas_item; render_mode unshaded; uniform float mood_brightness = 0.90; uniform float mood_saturation = 0.88; void fragment() { float luminance = dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722)); COLOR.rgb = mix(vec3(luminance), COLOR.rgb, mood_saturation) * mood_brightness; }"
	var mood_material := ShaderMaterial.new()
	mood_material.shader = mood
	material = mood_material

func _process(delta: float) -> void:
	elapsed += delta
	redraw_accumulator += delta
	if redraw_accumulator >= AMBIENT_REDRAW_INTERVAL:
		redraw_accumulator = 0.0
		queue_redraw()

func _map_point(world_position: Vector2) -> Vector2:
	return local_anchor + (world_position - camera_position) * pixels_per_unit

func local_to_world(point: Vector2) -> Vector2:
	return camera_position + (point - local_anchor) / pixels_per_unit

func visible_world_rect() -> Rect2:
	return Rect2(local_to_world(Vector2.ZERO), size / pixels_per_unit)

func art_world_rect() -> Rect2:
	return FIELD_ART.world_art_rect(zone_id, WORLD_SIZE)

func source_rect_for_world(world_rect: Rect2) -> Rect2:
	if not is_instance_valid(field_texture):
		return Rect2()
	var uv := FIELD_ART.source_uv(zone_id)
	var texture_size := field_texture.get_size()
	var ratio := texture_size * uv.size / WORLD_SIZE
	return Rect2(texture_size * uv.position + world_rect.position * ratio, world_rect.size * ratio)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("#29313a"))
