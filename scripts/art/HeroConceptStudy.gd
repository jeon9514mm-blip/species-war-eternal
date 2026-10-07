extends Control
## Art review only: this scene never creates Main, a save store, or a combat rig.
const UI = preload("res://scripts/ui/GameUiTheme.gd")
const SKIN = preload("res://scripts/portrait/PortraitSkin.gd")
const OLD_ART = preload("res://assets/heroes/sd-v36/sheets/leonhardt-pose.png")
const CONCEPT = preload("res://assets/art-direction/pilot-01/leonhardt-concept.png")

func _ready() -> void:
	theme = UI.make_theme()
	get_window().content_scale_size = Vector2i(1280, 720)
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_build()
	resized.connect(_build)

func _text(parent: Node, value: String, points: int, color := Color("233d4a")) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _image(parent: Node, texture: Texture2D, minimum: Vector2) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	picture.custom_minimum_size = minimum
	picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	return picture

func _panel(parent: Node, minimum_width: float, expand := false) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = minimum_width
	if expand: panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4f4e7")
	style.set_corner_radius_all(16)
	style.set_content_margin_all(20)
	style.border_color = Color("b9c9b0")
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	return column

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var background := ColorRect.new()
	background.color = Color("dbe8d8")
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
	var title := _text(header, "레온하르트 · 원화 시안 01", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var play := SKIN.button("초원 사냥 시범 보기", func(): get_tree().change_scene_to_file("res://scenes/art/ArtDirectionLab.tscn"))
	play.name = "OpenArtDirectionLab"
	play.custom_minimum_size = Vector2(240, 48)
	header.add_child(play)
	_text(stack, "4등신 안팎 SD · 성벽기사 · 밝은 회화풍 판타지", 18, Color("45665d"))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	stack.add_child(row)
	var identity := _panel(row, 270)
	_text(identity, "기존 원화 · 정체성 기준", 19)
	_image(identity, OLD_ART, Vector2(210, 200))
	_text(identity, "금발과 푸른 눈\n은색 갑옷과 금색 장식\n푸른 망토 · 검과 방패", 18)
	_text(identity, "역할과 전투 능력은 유지", 16, Color("537262"))
	var large := _panel(row, 360, true)
	_text(large, "새 원화 · 비율과 색감 검토", 20)
	_image(large, CONCEPT, Vector2(300, 380)).name = "NewHeroConcept"
	var small := _panel(row, 230)
	_text(small, "작게 표시했을 때", 19)
	var sample := _image(small, CONCEPT, Vector2(128, 148))
	sample.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_text(small, "얼굴 · 무기 · 방패의\n실루엣을 확인해요.", 17)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	small.add_child(spacer)
	_text(small, "다음 제작\n부위 분리 → 핵심 동작 → 16종 동작", 17, Color("537262"))
	_text(stack, "원화 검토 단계 · 새 애니메이션과 전투 적용은 부위 분리 후 진행합니다.", 17, Color("45665d"))
