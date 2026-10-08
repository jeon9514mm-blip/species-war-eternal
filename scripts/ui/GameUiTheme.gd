extends RefCounted
class_name GameUiTheme

## Shared visual language for menus, onboarding and the field HUD.
## Canonical palette used by both portrait pages and compatibility screens.
const BG := Color("#0d1013")
const SURFACE := Color("#151a1e")
const SOFT := Color("#1e262d")
const RAISED := Color("#242d32")
const SELECTED := Color("#29332f")
const INK := Color("#e9e5dc")
const MUTED := Color("#9aa8b0")
const PRIMARY := Color("#c4a484")
const GOLD := Color("#c4a484")
const LAVENDER := Color("#b39bce")
const BORDER := Color("#384047")
const BLUE := Color("#76bfc1")
const RED := Color("#ef8490")
const GREEN := Color("#a8b89e")
const FONT_PROVIDER = preload("res://scripts/ui/UIFontProvider.gd")
const ICON_SCRIPT := preload("res://scripts/ui/GameUiIcon.gd")

static func _is_accent(color: Color) -> bool:
	for accent: Color in [PRIMARY, GOLD, BLUE, RED, GREEN, LAVENDER, Color("#328263"), Color("#3474ac"), Color("#b94c57"), Color("#9d6a18")]:
		if Color(color, 1.0).is_equal_approx(accent):
			return true
	return false

static func surface_color(color: Color) -> Color:
	if color.a < 0.02 or _is_accent(color):return color
	for token in [BG,SURFACE,SOFT,RAISED,SELECTED]:
		if Color(color,1.).is_equal_approx(token):return color
	# Older screens used unrelated blue/green/cream surfaces. Translate them once.
	return Color(SURFACE,maxf(color.a,.94))

static func text_color(color: Color) -> Color:
	if color.a < .02:return color
	if _is_accent(color):return color
	if color.get_luminance()<.35:return INK
	return color

static func panel(color: Color, border: Color = BORDER, radius: int = 14, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = surface_color(color)
	style.border_color = BORDER if border.get_luminance() < 0.14 and not _is_accent(border) else border
	style.set_border_width_all(maxi(0, width))
	# Shared corner and border metrics across all pages.
	style.set_corner_radius_all(clampi(radius, 0, 12))
	style.corner_detail = 8
	style.anti_aliasing = true
	if radius >= 10 and style.bg_color.a > 0.8:
		style.shadow_color = Color(0.16, 0.23, 0.17, 0.13)
		style.shadow_size = 0
		style.shadow_offset = Vector2(0, 2)
	return style

static func _button_style(color: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := panel(SURFACE, border, 11, width)
	# Explicit button state colors must not be normalized a second time.
	style.bg_color = color
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

static func card_style(selected: bool = false, accent: Color = PRIMARY) -> StyleBoxFlat:
	return panel(SELECTED if selected else SOFT, Color(accent,.72) if selected else BORDER, 10, 1)

static func dock_style(selected: bool, pressed: bool = false) -> StyleBoxFlat:
	var style := panel(SELECTED if selected else Color.TRANSPARENT, Color.TRANSPARENT, 10, 0)
	if pressed:style.bg_color=RAISED
	return style

static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font = preload("res://scripts/ui/UIFontProvider.gd").get_font()
	result.default_font_size = 16
	result.set_color("font_color", "Label", INK)
	result.set_color("default_color", "RichTextLabel", INK)
	result.set_color("font_shadow_color", "Label", Color.TRANSPARENT)
	result.set_constant("outline_size", "Label", 0)
	result.set_constant("separation", "HBoxContainer", 10)
	result.set_constant("separation", "VBoxContainer", 10)
	result.set_constant("h_separation", "GridContainer", 12)
	result.set_constant("v_separation", "GridContainer", 12)
	result.set_stylebox("panel", "Panel", panel(SURFACE))
	result.set_stylebox("panel", "PanelContainer", panel(SURFACE))
	for type_name: String in ["Button", "OptionButton", "MenuButton"]:
		result.set_stylebox("normal", type_name, _button_style(SOFT, BORDER))
		result.set_stylebox("hover", type_name, _button_style(RAISED, PRIMARY))
		result.set_stylebox("pressed", type_name, _button_style(BG, PRIMARY))
		result.set_stylebox("disabled", type_name, _button_style(SURFACE, BORDER))
		var focus := panel(Color.TRANSPARENT, GOLD, 12, 2)
		focus.expand_margin_left = 2
		focus.expand_margin_right = 2
		focus.expand_margin_top = 2
		focus.expand_margin_bottom = 2
		result.set_stylebox("focus", type_name, focus)
		result.set_color("font_color", type_name, INK)
		result.set_color("font_hover_color", type_name, INK)
		result.set_color("font_pressed_color", type_name, PRIMARY)
		result.set_color("font_focus_color", type_name, INK)
		result.set_color("font_disabled_color", type_name, MUTED)
		result.set_font_size("font_size", type_name, 16)
	var entry := panel(SURFACE, BORDER, 10)
	entry.content_margin_left = 14
	entry.content_margin_right = 14
	entry.content_margin_top = 10
	entry.content_margin_bottom = 10
	result.set_stylebox("normal", "LineEdit", entry)
	var entry_focus := entry.duplicate() as StyleBoxFlat
	entry_focus.border_color = PRIMARY
	entry_focus.set_border_width_all(2)
	result.set_stylebox("focus", "LineEdit", entry_focus)
	result.set_stylebox("read_only", "LineEdit", panel(SOFT, BORDER, 10))
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	result.set_color("caret_color", "LineEdit", PRIMARY)
	result.set_color("selection_color", "LineEdit", BORDER)
	result.set_color("font_selected_color", "LineEdit", INK)
	result.set_stylebox("background", "ProgressBar", panel(BG, Color.TRANSPARENT, 4, 0))
	result.set_stylebox("fill", "ProgressBar", panel(GREEN, Color.TRANSPARENT, 4, 0))
	result.set_color("font_color", "ProgressBar", INK)
	for type_name: String in ["HScrollBar", "VScrollBar"]:
		var rail := panel(BG, Color.TRANSPARENT, 4, 0)
		rail.content_margin_left = 4
		rail.content_margin_right = 4
		rail.content_margin_top = 4
		rail.content_margin_bottom = 4
		result.set_stylebox("scroll", type_name, rail)
		result.set_stylebox("grabber", type_name, panel(BORDER, Color.TRANSPARENT, 4, 0))
		result.set_stylebox("grabber_highlight", type_name, panel(MUTED, Color.TRANSPARENT, 4, 0))
		result.set_stylebox("grabber_pressed", type_name, panel(GREEN, Color.TRANSPARENT, 4, 0))
		result.set_constant("increment", type_name, 0)
		result.set_constant("decrement", type_name, 0)
	var tooltip := panel(INK, Color("#496254"), 8)
	tooltip.bg_color = INK
	tooltip.content_margin_left = 12
	tooltip.content_margin_right = 12
	tooltip.content_margin_top = 8
	tooltip.content_margin_bottom = 8
	tooltip.bg_color = SOFT
	result.set_stylebox("panel", "TooltipPanel", tooltip)
	result.set_color("font_color", "TooltipLabel", INK)
	result.set_font_size("font_size", "TooltipLabel", 13)
	return result

static func label(text: String, size: int = 16, color: Color = INK) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", maxi(10, size))
	result.add_theme_color_override("font_color", text_color(color))
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func button(text: String, min_size: Vector2 = Vector2(0, 44), color: Color = SOFT) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = min_size
	var primary := Color(color, 1.0).is_equal_approx(PRIMARY)
	var fill := PRIMARY if primary else surface_color(color)
	if not primary and _is_accent(color):
		fill = SURFACE.lerp(color, 0.12)
	var foreground := BG if primary else INK
	result.add_theme_font_size_override("font_size", 16)
	result.add_theme_color_override("font_color", foreground)
	result.add_theme_color_override("font_hover_color", foreground)
	result.add_theme_color_override("font_pressed_color", foreground)
	result.add_theme_color_override("font_focus_color", foreground)
	result.add_theme_color_override("font_disabled_color", MUTED)
	result.add_theme_stylebox_override("normal", _button_style(fill, PRIMARY if primary else BORDER))
	result.add_theme_stylebox_override("hover", _button_style(fill.lightened(0.08) if primary else RAISED, PRIMARY))
	result.add_theme_stylebox_override("pressed", _button_style(fill.darkened(0.10) if primary else fill.lerp(BG, 0.5), PRIMARY))
	result.add_theme_stylebox_override("disabled", _button_style(SURFACE, BORDER))
	var focus := panel(Color.TRANSPARENT, GOLD, 12, 2)
	focus.expand_margin_left = 2
	focus.expand_margin_right = 2
	focus.expand_margin_top = 2
	focus.expand_margin_bottom = 2
	result.add_theme_stylebox_override("focus", focus)
	result.focus_mode = Control.FOCUS_ALL
	result.mouse_filter = Control.MOUSE_FILTER_STOP
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return result

static func icon(name: String, size: Vector2 = Vector2(24, 24), color: Color = INK) -> Control:
	var result := ICON_SCRIPT.new()
	result.icon_name = name
	result.ink = color
	result.custom_minimum_size = size
	result.size = size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func background(size: Vector2) -> Control:
	var result := AmbientBackground.new()
	result.size = size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

class AmbientBackground extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), BG)
