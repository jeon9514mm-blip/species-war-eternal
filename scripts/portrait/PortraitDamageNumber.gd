extends Label
## Combat numbers use a short impact beat, distinct colors and fixed-width lanes.
const SKIN := preload('res://scripts/portrait/PortraitSkin.gd')

func show_value(message: String, tint: Color, origin: Vector2, large: bool, lane: int) -> void:
	name='PortraitDamageNumber'
	text=message
	add_to_group('floating_combat_text')
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	z_index=85
	horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	size=Vector2(156,42)
	position=origin+Vector2(-78.0+float(lane%3-1)*9.0,-13.0-float(lane%3)*6.0)
	add_theme_font_override('font',SKIN.bold_font())
	add_theme_font_size_override('font_size',23 if large else 17)
	add_theme_color_override('font_color',tint)
	add_theme_color_override('font_shadow_color',Color('#06161dcc'))
	add_theme_constant_override('shadow_offset_x',2)
	add_theme_constant_override('shadow_offset_y',3)
	add_theme_color_override('font_outline_color',Color('#132024'))
	add_theme_constant_override('outline_size',3)
	pivot_offset=size*.5
	scale=Vector2(.56,.56)
	var base: Vector2=position
	var motion:=create_tween().set_parallel(true)
	motion.tween_property(self,'scale',Vector2(1.17,1.17),.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	motion.tween_property(self,'position',base+Vector2(0,-42),.68).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.chain().tween_property(self,'scale',Vector2.ONE,.16)
	motion.parallel().tween_property(self,'modulate:a',0.0,.25).set_delay(.16)
	motion.chain().tween_callback(queue_free)
