extends Label
## Small impact -> legible hold -> short release. Shared hunt/raid numeral style.
const STYLE = preload('res://scripts/combat/CombatNumberStyle.gd')
const INK = preload('res://shaders/CombatNumberInk.gdshader')
var pooled := false
var _life_tween: Tween
var kind := 'damage'
var reserved_rect := Rect2()
var anchor_key := ''
var issued_at := 0
var burst_started_at := 0
var amount := 0
var burst_hits := 1
func show_value(message: String, _tint: Color, origin: Vector2, large: bool, lane: int) -> void:
	kind = 'critical' if large else kind
	if is_instance_valid(_life_tween): _life_tween.kill()
	modulate = Color.WHITE; rotation = 0; show()
	name = 'PortraitDamageNumber'; text = message
	add_to_group('floating_combat_text')
	mouse_filter = Control.MOUSE_FILTER_IGNORE; z_index = 85
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	size = STYLE.extent(message, kind); position = origin - size * .5
	add_theme_font_override('font', STYLE.FONT)
	add_theme_font_size_override('font_size', STYLE.font_size(kind))
	add_theme_color_override('font_color', Color.WHITE)
	add_theme_color_override('font_shadow_color', Color('#08101be0'))
	add_theme_constant_override('shadow_offset_x', 1)
	add_theme_constant_override('shadow_offset_y', 3)
	add_theme_color_override('font_outline_color', Color('#080e12e8'))
	add_theme_constant_override('outline_size', 3)
	var ink := ShaderMaterial.new(); ink.shader = INK
	var colors: Array = STYLE.PALETTES.get(kind, STYLE.PALETTES.damage)
	ink.set_shader_parameter('ink_top', colors[0]); ink.set_shader_parameter('ink_bottom', colors[1])
	ink.set_shader_parameter('label_height', size.y); ink.set_shader_parameter('holographic_strength',.02); material = ink
	pivot_offset = size * .5; scale = Vector2.ONE * (1.12 if large else 1.0)
	issued_at = Time.get_ticks_msec(); queue_redraw()
	var base := position
	var drift := Vector2(float(lane % 2 * 2 - 1) * 3, -16 if kind == 'heal' else -10)
	var motion := create_tween(); _life_tween = motion
	motion.tween_property(self, 'scale', Vector2.ONE, .09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_interval(.34 if large else .30)
	motion.set_parallel(true)
	motion.tween_property(self, 'position', base + drift, .30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion.tween_property(self, 'modulate:a', 0.0, .22).set_delay(.08)
	motion.chain().tween_callback(retire)
func _draw() -> void:
	if kind != 'critical' or not visible: return
	var width := STYLE.FONT.get_string_size('CRITICAL', HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string_outline(STYLE.FONT, Vector2((size.x-width)*.5, 12), 'CRITICAL', HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color('#080e12e8'))
	draw_string(STYLE.FONT, Vector2((size.x-width)*.5, 12), 'CRITICAL', HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color('#e0bd89'))
func retire() -> void:
	if is_instance_valid(_life_tween): _life_tween.kill()
	_life_tween = null; reserved_rect = Rect2(); anchor_key = ''; amount = 0; burst_hits = 1
	remove_from_group('floating_combat_text')
	if pooled: hide(); text = ''
	else: queue_free()
