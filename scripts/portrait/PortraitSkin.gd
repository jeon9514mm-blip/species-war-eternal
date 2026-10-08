extends RefCounted
## Presentation-only skin shared by the portrait UI. Gameplay state is never mutated here.
const UI = preload('res://scripts/ui/GameUiTheme.gd')
const DARK = UI.BG
const DARK_2 = UI.SURFACE
const SURFACE = UI.SURFACE
const SURFACE_2 = UI.SOFT
const EDGE = UI.BG
const EDGE_SOFT = UI.BORDER
const INK = UI.INK
const GOLD = UI.GOLD
const BLUE = UI.BLUE
const BLUE_SOFT = UI.BLUE
const AURELIA := Color('#79aeea')
const NOXFERA := Color('#d88caa')
const MUTED = UI.MUTED
const MUTED_DARK = UI.MUTED
const SUCCESS = UI.GREEN
const FONT_PROVIDER = preload("res://scripts/ui/UIFontProvider.gd")

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
	var s:=UI.panel(fill,edge,mini(radius,12),mini(border,2))
	# Health, grades and faction badges retain their semantic colors.
	if fill.get_luminance()>.35 and fill.a>.4:s.bg_color=fill
	return s

static func elevated(fill: Color, edge: Color = EDGE_SOFT, radius: int = 12) -> StyleBoxFlat:
	var style:=box(fill,edge,radius,1)
	style.shadow_color=Color(0,0,0,.24)
	style.shadow_size=12
	style.shadow_offset=Vector2(0,4)
	return style

static func label(text: String, points: int = 22, color: Color = INK) -> Label:
	var n := Label.new()
	n.text = text
	n.add_theme_font_override('font', bold_font() if points>=22 else font())
	n.add_theme_font_size_override('font_size', points)
	n.add_theme_color_override('font_color', UI.text_color(color))
	n.add_theme_color_override('font_outline_color', Color('#11172a'))
	n.add_theme_constant_override('outline_size', 0)
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

static func button(text: String, action: Callable, color: Color = SURFACE_2) -> Button:
	var primary:=Color(color,1.).is_equal_approx(GOLD)
	var n:=UI.button(text,Vector2.ZERO,UI.PRIMARY if primary else (Color.TRANSPARENT if color.a<.02 else SURFACE_2))
	n.add_theme_font_override('font',bold_font())
	n.add_theme_font_size_override('font_size',18)
	n.clip_text=true;n.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;n.tooltip_text=text
	if action.is_valid():n.pressed.connect(action)
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
	# TouchScrollController owns drag gestures across all list descendants;
	# native wheel and scrollbar input remain available.
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_RESERVE
	scroll.follow_focus=false
	scroll.scroll_deadzone=8
	var bar:=scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x=12
	bar.add_theme_stylebox_override('scroll',box(DARK,Color.TRANSPARENT,8,0))
	bar.add_theme_stylebox_override('grabber',box(EDGE_SOFT,Color.TRANSPARENT,8,0))
	bar.add_theme_stylebox_override('grabber_highlight',box(GOLD,Color.TRANSPARENT,8,0))
	bar.add_theme_stylebox_override('grabber_pressed',box(GOLD,Color.TRANSPARENT,8,0))

static func place(parent: Node, control: Control, rect: Rect2) -> Control:
	control.position = rect.position
	control.size = rect.size
	parent.add_child(control)
	control.size = rect.size
	return control
