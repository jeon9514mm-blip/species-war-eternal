extends Label
## Small impact -> legible hold -> short release. Shared hunt/raid numeral style.
const STYLE = preload('res://scripts/combat/CombatNumberStyle.gd')
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
	mouse_filter = Control.MOUSE_FILTER_IGNORE; z_index = 105
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	size = STYLE.extent(message, kind); position = origin - size * .5
	add_theme_font_override('font', STYLE.FONT)
	add_theme_font_size_override('font_size', STYLE.font_size(kind))
	var palette: Array=STYLE.PALETTES.get(kind,STYLE.PALETTES.damage)
	add_theme_color_override('font_color', palette[0])
	add_theme_color_override('font_shadow_color', Color('#08101be0'))
	add_theme_constant_override('shadow_offset_x', 1)
	add_theme_constant_override('shadow_offset_y', 3)
	add_theme_color_override('font_outline_color', Color('#000000cc'))
	add_theme_constant_override('outline_size', 2)
	material=null
	pivot_offset = size * .5; scale = Vector2.ONE * 1.2
	issued_at = Time.get_ticks_msec(); queue_redraw()
	var base := position
	var drift := Vector2(float(lane % 2 * 2 - 1) * 3, -16 if kind == 'heal' else -10)
	var motion := create_tween(); _life_tween = motion
	motion.tween_property(self, 'scale', Vector2.ONE*1.2, .06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_interval(.26)
	motion.chain().tween_property(self, 'position', base + drift, .28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion.parallel().tween_property(self, 'modulate:a', 0.0, .20).set_delay(.08)
	motion.chain().tween_callback(retire)
func _draw() -> void:
	if visible and kind in ['damage','critical']:
		var baseline:=Vector2((size.x-STYLE.FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x)*.5,size.y-STYLE.FONT.get_descent(14))
		draw_string(STYLE.FONT,baseline+Vector2(.15,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(1,.25,.3,.01))
		draw_string(STYLE.FONT,baseline-Vector2(.15,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(.25,.6,1,.01))
	if kind != 'critical' or not visible: return
	var phase:=clampf(float(Time.get_ticks_msec()-issued_at)/600.,0,1)
	for i in 8:
		var ray:=Vector2.from_angle(float(i)*TAU/8)
		draw_circle(size*.5+ray*(9+phase*16),1.2*(1-phase),Color(Color('#c4a484'),(1-phase)*.65))
	var width := STYLE.FONT.get_string_size('CRIT', HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string_outline(STYLE.FONT, Vector2((size.x-width)*.5, 8), 'CRIT', HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 2, Color('#080e12e8'))
	draw_string(STYLE.FONT, Vector2((size.x-width)*.5, 8), 'CRIT', HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color('#c4a484'))
func _process(_delta: float) -> void:
	if visible and kind=='critical':queue_redraw()
func retire() -> void:
	if is_instance_valid(_life_tween): _life_tween.kill()
	_life_tween = null; reserved_rect = Rect2(); anchor_key = ''; amount = 0; burst_hits = 1
	remove_from_group('floating_combat_text')
	if pooled: hide(); text = ''
	else: queue_free()
