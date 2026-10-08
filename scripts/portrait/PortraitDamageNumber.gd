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
var feedback_context: Dictionary = {}
var _visual_amount := 0.0
var _count_from := 0.0
var _number_color := Color('#d8d5cc')
const COUNT_SECONDS := .09
const LIFETIME := .80
var _particle_rays:=_make_particle_rays()
var _particle_lines:=PackedVector2Array()
static func _make_particle_rays() -> PackedVector2Array:
	var rays:=PackedVector2Array();rays.resize(20)
	for index in 20:rays[index]=Vector2.from_angle(float(index)*TAU/20)
	return rays
func show_value(message: String, _tint: Color, origin: Vector2, large: bool, lane: int) -> void:
	kind = 'critical' if large else kind
	if is_instance_valid(_life_tween): _life_tween.kill()
	modulate = Color.WHITE; rotation = 0; show()
	name = 'PortraitDamageNumber'; text = message
	add_to_group('floating_combat_text')
	mouse_filter = Control.MOUSE_FILTER_IGNORE; z_index = 105
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	size = STYLE.extent(message, kind, feedback_context); position = origin - size * .5
	add_theme_font_override('font', STYLE.FONT)
	add_theme_font_size_override('font_size', STYLE.font_size(kind))
	var palette: Array=STYLE.PALETTES.get(kind,STYLE.PALETTES.damage)
	_number_color=palette[0]
	# A cyan critical requires confirmed ultimate context from the settled
	# event; no new crit chance or upgraded hit is inferred by the label.
	if kind=='critical' and bool(feedback_context.get('ultimate_critical',false)):
		_number_color=STYLE.PALETTES.ultimate_critical[0]
	_count_from=_visual_amount if _visual_amount>0.0 and float(amount)>_visual_amount else floorf(float(maxi(0,amount))*.82)
	_visual_amount=_count_from
	# Semantic text and `amount` always contain the authoritative exact total.
	# The canvas alone morphs/counts for 90ms, before a 710ms readable hold.
	add_theme_color_override('font_color', Color.TRANSPARENT)
	add_theme_color_override('font_shadow_color', Color.TRANSPARENT)
	add_theme_constant_override('shadow_offset_x', 1)
	add_theme_constant_override('shadow_offset_y', 3)
	add_theme_color_override('font_outline_color', Color.TRANSPARENT)
	add_theme_constant_override('outline_size', 3)
	material=null
	pivot_offset = size * .5; scale = Vector2.ONE * 1.35
	issued_at = Time.get_ticks_msec(); queue_redraw()
	var base := position
	var drift := Vector2(float(lane % 2 * 2 - 1) * 3, -18)
	var motion := create_tween().set_ignore_time_scale(true); _life_tween = motion
	motion.tween_property(self, 'scale', Vector2.ONE*1.5, .08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_interval(.42)
	motion.chain().tween_property(self, 'position', base + drift, .30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion.parallel().tween_property(self, 'modulate:a', 0.0, .22).set_delay(.08)
	motion.chain().tween_callback(retire)
func _draw() -> void:
	if not visible:return
	var face:=STYLE.font_size(kind)
	var caption:=STYLE.caption(roundi(_visual_amount),kind) if amount>=0 else text
	var baseline:=Vector2((size.x-STYLE.FONT.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,face).x)*.5,size.y-STYLE.FONT.get_descent(face))
	# Small fixed-cost light/shadow edges replace extra number/light nodes.
	draw_string(STYLE.FONT,baseline+Vector2(1,3),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,face,Color('#08101be0'))
	draw_string_outline(STYLE.FONT,baseline,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,face,4,Color(_number_color,.10))
	draw_string_outline(STYLE.FONT,baseline,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,face,3,Color('#000000cc'))
	draw_string(STYLE.FONT,baseline,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,face,_number_color)
	if kind in ['damage','critical']:
		draw_string(STYLE.FONT,baseline+Vector2(.35,0),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,face,Color(1,.25,.3,.05))
		draw_string(STYLE.FONT,baseline-Vector2(.35,0),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,face,Color(.25,.6,1,.05))
	if kind=='critical':
		var phase:=clampf(float(Time.get_ticks_msec()-issued_at)/(LIFETIME*1000.),0,1)
		_particle_lines.resize(40)
		for i in 20:
			var ray: Vector2=_particle_rays[i]
			var point:=size*.5+ray*(9+phase*20)
			_particle_lines[i*2]=point-ray*1.2*(1-phase)
			_particle_lines[i*2+1]=point+ray*1.2*(1-phase)
		draw_multiline(_particle_lines,Color(_number_color,(1-phase)*.65),1.4*(1-phase),true)
	if kind!='critical' and int(feedback_context.get('overkill',0))<=0:return
	var banner: String='ULT CRIT' if bool(feedback_context.get('ultimate_critical',false)) else 'CRITICAL'
	# An overkill annotation is optional observed settled metadata only.
	if int(feedback_context.get('overkill',0))>0:banner='OVERKILL'
	var width := STYLE.FONT.get_string_size(banner,HORIZONTAL_ALIGNMENT_LEFT,-1,9).x
	draw_string_outline(STYLE.FONT,Vector2((size.x-width)*.5,8),banner,HORIZONTAL_ALIGNMENT_LEFT,-1,9,2,Color('#080e12e8'))
	draw_string(STYLE.FONT,Vector2((size.x-width)*.5,8),banner,HORIZONTAL_ALIGNMENT_LEFT,-1,9,_number_color)
func _process(_delta: float) -> void:
	if not visible:return
	var ratio:=clampf(float(Time.get_ticks_msec()-issued_at)/(COUNT_SECONDS*1000.),0.0,1.0)
	var previous:=_visual_amount
	if amount>=0:_visual_amount=lerpf(_count_from,float(amount),1.0-pow(1.0-ratio,3.0))
	if previous!=_visual_amount or ratio<1.0 or kind=='critical':queue_redraw()
func retire() -> void:
	if is_instance_valid(_life_tween): _life_tween.kill()
	_life_tween = null; reserved_rect = Rect2(); anchor_key = ''; amount = 0; burst_hits = 1;feedback_context.clear();_visual_amount=0.0
	remove_from_group('floating_combat_text')
	if pooled: hide(); text = ''
	else: queue_free()
