extends RefCounted
## Presentation-only skin shared by the portrait UI. Gameplay state is never mutated here.
const DARK := Color('#102b34')
const DARK_2 := Color('#21404a')
const SURFACE := Color('#294d55')
const SURFACE_2 := Color('#36616a')
const EDGE := Color('#102c35')
const EDGE_SOFT := Color('#82b2ac')
const INK := Color('#fff9ed')
const GOLD := Color('#f6d887')
const BLUE := Color('#72c9c0')
const BLUE_SOFT := Color('#b7eee0')
const AURELIA := Color('#4c9cff')
const NOXFERA := Color('#d55f91')
const MUTED := Color('#d5e4e0')
const MUTED_DARK := Color('#b0c9c5')
const SUCCESS := Color('#65c77f')
const FONT_PROVIDER = preload("res://scripts/UIFontProvider.gd")

static func font() -> Font:
	return FONT_PROVIDER.get_font()
static var _bold_font: FontVariation

static func bold_font() -> Font:
	if _bold_font == null:
		_bold_font=FontVariation.new()
		_bold_font.base_font=font()
		_bold_font.variation_embolden=0.43
	return _bold_font

static func faction_color(faction: String) -> Color:
	return AURELIA if faction == 'aurelia' else (NOXFERA if faction == 'noxfera' else BLUE)

static func box(fill: Color, edge: Color = EDGE, radius: int = 10, border: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.corner_detail = 8
	s.anti_aliasing = true
	return s

static func elevated(fill: Color, edge: Color = EDGE_SOFT, radius: int = 16) -> StyleBoxFlat:
	var style := box(fill,edge,radius,1)
	style.border_width_top=3
	style.shadow_color=Color('#051a22a0')
	style.shadow_size=7
	style.shadow_offset=Vector2(0,3)
	return style

static func label(text: String, points: int = 22, color: Color = INK) -> Label:
	var n := Label.new()
	n.text = text
	n.add_theme_font_override('font', bold_font() if points>=22 else font())
	n.add_theme_font_size_override('font_size', points)
	n.add_theme_color_override('font_color', color)
	n.add_theme_color_override('font_outline_color', Color('#11172a'))
	n.add_theme_constant_override('outline_size', 1)
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n

static func panel(parent: Node, rect: Rect2, fill: Color = Color('#22304fe8'), edge: Color = EDGE_SOFT, border: int = 2, radius: int = 12) -> Panel:
	var n := Panel.new()
	n.position = rect.position
	n.size = rect.size
	n.add_theme_stylebox_override('panel', box(fill, edge, radius, border))
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	return n

static func button(text: String, action: Callable, color: Color = Color('#2d5f9c')) -> Button:
	var n := Button.new()
	n.text = text
	n.add_theme_font_override('font', bold_font())
	n.add_theme_font_size_override('font_size', 20)
	for state in ['font_color','font_hover_color','font_pressed_color','font_focus_color']:
		n.add_theme_color_override(state, INK)
	n.add_theme_color_override('font_disabled_color', Color('#9aa7c2'))
	n.add_theme_color_override('font_outline_color', EDGE)
	n.add_theme_constant_override('outline_size', 1)
	n.add_theme_stylebox_override('normal', box(color, Color('#729a99'), 12, 1))
	n.add_theme_stylebox_override('hover', box(color.lightened(.10), GOLD, 12, 1))
	n.add_theme_stylebox_override('pressed', box(color.darkened(.14), GOLD, 12, 2))
	n.add_theme_stylebox_override('disabled', box(Color('#2b4247'), Color('#526b70'), 12, 1))
	n.add_theme_stylebox_override('focus', box(Color.TRANSPARENT, GOLD, 10, 3))
	n.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	n.clip_text=true
	n.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	n.tooltip_text=text
	if action.is_valid():
		n.pressed.connect(action)
	return n

static func chip(parent: Node, rect: Rect2, text_value: String, accent: Color = BLUE, fill: Color = Color('#17243ed9')) -> Panel:
	var p:=panel(parent,rect,fill,accent.darkened(.24),1,12)
	var l:=label(text_value,18,INK)
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	place(p,l,Rect2(6,0,rect.size.x-12,rect.size.y))
	return p

static func badge(parent: Node, rect: Rect2, text_value: String, accent: Color) -> Panel:
	var p:=panel(parent,rect,Color(accent,.18),Color(accent,.72),1,9)
	var l:=label(text_value,14,accent.lightened(.23))
	l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	place(p,l,Rect2(4,0,rect.size.x-8,rect.size.y))
	return p

static func gauge(parent: Node, rect: Rect2, color: Color) -> ProgressBar:
	var n := ProgressBar.new()
	n.position = rect.position
	n.show_percentage = false
	n.add_theme_font_size_override('font_size', 1)
	n.max_value = 100
	n.add_theme_stylebox_override('background', box(Color('#0f192b'), Color('#0f192b'), 5, 1))
	n.add_theme_stylebox_override('fill', box(color, color.darkened(.25), 5, 1))
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	# Apply dimensions after the inherited theme and compact styles set minimum size.
	n.size = rect.size
	return n

static func make_scroll_responsive(scroll: ScrollContainer) -> void:
	# Let ScrollContainer own drag velocity and momentum. Buttons inside lists
	# pass pointer events to it; a second delayed adjustment caused double drags.
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_RESERVE
	scroll.follow_focus=false
	scroll.scroll_deadzone=8
	var bar:=scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x=12
	bar.add_theme_stylebox_override('scroll',box(Color('#17333bbb'),Color.TRANSPARENT,8,0))
	bar.add_theme_stylebox_override('grabber',box(BLUE_SOFT,Color.TRANSPARENT,8,0))
	bar.add_theme_stylebox_override('grabber_highlight',box(GOLD,Color.TRANSPARENT,8,0))
	bar.add_theme_stylebox_override('grabber_pressed',box(GOLD,Color.TRANSPARENT,8,0))

static func place(parent: Node, control: Control, rect: Rect2) -> Control:
	control.position = rect.position
	control.size = rect.size
	parent.add_child(control)
	control.size = rect.size
	return control
