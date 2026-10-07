extends Control
## Isolated art review. No Main, source monster controller, economy or save.
const UI = preload("res://scripts/ui/GameUiTheme.gd")
const SKIN = preload("res://scripts/portrait/PortraitSkin.gd")
const PRESENTATION = preload("res://scripts/art/PilotMonsterPresentation.gd")
const ACTION_LABELS := {
	"idle": "대기", "walk": "이동", "attack": "공격", "hit": "피격", "death": "사망",
}
const SPECIES_LABELS := {
	"초원 고블린": ["초원 고블린", "작은 정찰병 · 가죽 장비", Color("749262")],
	"들개 무리": ["초원 들개", "날렵한 추격자 · 따뜻한 털빛", Color("b18e67")],
	"가시 멧돼지": ["가시 멧돼지", "묵직한 돌격수 · 거친 갈기", Color("947e66")],
	"바람 까마귀": ["바람 까마귀", "푸른 깃털 · 날개 실루엣", Color("728fa3")],
}

var presentation = PRESENTATION.new()
var selected_action := "idle"
var animation_playing := true
var animation_time := 0.0
var _cards: Dictionary = {}
var _action_buttons: Dictionary = {}
var _play_button: Button


class MonsterCard extends Control:
	var sprite: Sprite2D
	var frame_label: Label
	var foot := Vector2.ZERO
	var tint := Color("749262")

	func _draw() -> void:
		# A separate, stationary review plinth keeps the sprite's alpha clean.
		for index in range(7, 0, -1):
			var points := PackedVector2Array()
			var radius := Vector2(57.0, 12.0) * (0.58 + float(index) * 0.08)
			for segment in 48:
				var angle := TAU * float(segment) / 48.0
				points.append(foot + Vector2(cos(angle), sin(angle)) * radius)
			draw_colored_polygon(points, Color(tint.darkened(0.35), 0.025))


func _ready() -> void:
	theme = UI.make_theme()
	get_window().content_scale_size = Vector2i(1280, 720)
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_build()


func _text(parent: Node, value: String, points: int, color := Color("233d4a")) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("dce8db")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	margin.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var heading := _text(header, "밝은 초원 · 몬스터 시안", 30)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back := SKIN.button("초원 사냥 시범 보기", func(): get_tree().change_scene_to_file("res://scenes/art/ArtDirectionLab.tscn"))
	back.name = "OpenArtDirectionLab"
	back.custom_minimum_size = Vector2(226, 48)
	header.add_child(back)
	_text(stack, "4종 · 8개 자세 · 5가지 행동", 20, Color("486658"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(row)
	for monster_name: String in SPECIES_LABELS:
		_make_card(row, monster_name)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	stack.add_child(actions)
	for action: String in ACTION_LABELS:
		var button := SKIN.button(ACTION_LABELS[action], select_action.bind(action))
		button.name = "Action_" + action
		button.toggle_mode = true
		button.button_pressed = action == selected_action
		button.custom_minimum_size = Vector2(142, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
		_action_buttons[action] = button
	_play_button = SKIN.button("일시 정지", func(): set_animation_playing(not animation_playing))
	_play_button.name = "ToggleMonsterAnimation"
	_play_button.custom_minimum_size = Vector2(156, 52)
	actions.add_child(_play_button)
	_text(stack, "2D 프레임 애니메이션 시범 · 초원과 어울리는 색감과 실루엣을 확인해요.", 16, Color("486658"))
	_refresh_cards()


func _make_card(parent: Node, monster_name: String) -> void:
	var identity: Array = SPECIES_LABELS[monster_name]
	var panel := PanelContainer.new()
	panel.name = "MonsterCard_" + str(PRESENTATION.SPECIES[monster_name])
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4f5e9")
	style.border_color = Color(identity[2], 0.58)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)
	_text(stack, str(identity[0]), 24)
	_text(stack, str(identity[1]), 15, Color("637366"))
	var art := MonsterCard.new()
	art.custom_minimum_size = Vector2(220, 260)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.tint = identity[2]
	stack.add_child(art)
	art.sprite = Sprite2D.new()
	art.sprite.name = "PaintedMonster"
	art.sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.add_child(art.sprite)
	art.frame_label = _text(stack, "대기 · 자세 01/08", 16, Color("486658"))
	_cards[monster_name] = art
	art.resized.connect(_refresh_cards)


func _process(delta: float) -> void:
	if animation_playing:
		animation_time += maxf(delta, 0.0)
		_refresh_cards()


func select_action(action: String) -> void:
	if not ACTION_LABELS.has(action):
		return
	selected_action = action
	animation_time = 0.0
	for key: String in _action_buttons:
		_action_buttons[key].set_pressed_no_signal(key == action)
	_refresh_cards()


func set_animation_playing(enabled: bool) -> void:
	animation_playing = enabled
	if is_instance_valid(_play_button):
		_play_button.text = "일시 정지" if enabled else "재생"


func _gallery_pose() -> int:
	match selected_action:
		"walk": return 2 + int(floor(animation_time * 7.0)) % 2
		"attack": return 4 if fmod(animation_time, 0.8) < 0.336 else 5
		"hit": return 6
		"death": return 7
	return int(floor(animation_time * 1.6)) % 2


func _refresh_cards() -> void:
	var catalog: Dictionary = presentation.catalog()
	var pose := _gallery_pose()
	for monster_name: String in _cards:
		var card: MonsterCard = _cards[monster_name]
		if not is_instance_valid(card.sprite):
			continue
		var info: Dictionary = catalog[monster_name]
		card.foot = Vector2(card.size.x * 0.5, card.size.y * 0.82)
		card.sprite.texture = presentation.frame_texture(monster_name, pose)
		if bool(info.available):
			var native: float = float(info.native_height)
			var anchor: Vector2 = info.anchors[pose]
			var cell: Vector2 = card.sprite.texture.get_size()
			# Fit one fixed envelope for all poses. The club reaches farther to
			# the right than the body: fitting only region width would spill into
			# the next card, while centring each frame would slide planted feet.
			var left_extent := 0.0
			var right_extent := 0.0
			for index in PRESENTATION.POSE_COUNT:
				left_extent = maxf(left_extent, info.anchors[index].x)
				right_extent = maxf(right_extent, info.frame_regions[index].size.x - info.anchors[index].x)
			var target_height: float = minf(205.0, card.size.y * 0.66)
			var scale_factor: float = minf(target_height / native, (card.size.x - 8.0) / maxf(1.0, left_extent + right_extent))
			card.foot.x += (left_extent - right_extent) * scale_factor * 0.5
			card.sprite.scale = Vector2.ONE * scale_factor
			card.sprite.offset = cell * 0.5 - anchor
		card.sprite.position = card.foot
		card.queue_redraw()
		card.frame_label.text = "%s · 자세 %02d/08" % [ACTION_LABELS[selected_action], pose + 1]


func gallery_state() -> Dictionary:
	return {
		"action": selected_action, "playing": animation_playing,
		"time": animation_time, "pose": _gallery_pose(),
		"species_count": _cards.size(), "cache_frames": presentation.cached_frame_count(),
	}
