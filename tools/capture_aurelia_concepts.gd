extends SceneTree
## A labelled reference gallery, not a battle or animation-completion screenshot.
const CATALOG = preload("res://scripts/art/HeroPartsCatalog.gd")
const FONT = preload("res://scripts/ui/UIFontProvider.gd")
const OUTPUT := "res://checks/aurelia-four-head/"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use the display renderer for the concept reference gallery")
		quit(1)
		return
	root.size = Vector2i(1920, 1440)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var page := Control.new()
	page.size = Vector2(root.size)
	root.add_child(page)
	var background := ColorRect.new()
	background.size = page.size
	background.color = Color("e4e9df")
	page.add_child(background)
	_label(page, "아우렐리아 15명 · 길어진 비율의 원화 검토", Rect2(24, 12, 1850, 48), 34)
	_label(page, "정적 원화 초안 · 실제 부위 조립 및 동작 완성과 구분됩니다.", Rect2(25, 61, 1845, 30), 21)
	var records: Array[Dictionary] = []
	for index in CATALOG.HERO_IDS.size():
		var id: String = CATALOG.HERO_IDS[index]
		var panel := Panel.new()
		panel.position = Vector2(20 + (index % 5) * 380, 105 + int(index / 5.0) * 435)
		panel.size = Vector2(364, 422)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("f2f4ed")
		style.border_color = Color("bbcbb3")
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		panel.add_theme_stylebox_override("panel", style)
		page.add_child(panel)
		var path := CATALOG.ROOT + id + "/concept.png"
		var texture := load(path) as Texture2D
		assert(texture != null)
		var painting := TextureRect.new()
		painting.position = Vector2(10, 8)
		painting.size = Vector2(344, 363)
		painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		painting.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		painting.texture = texture
		panel.add_child(painting)
		_label(panel, str(CATALOG.profile(id).name), Rect2(12, 375, 340, 32), 23)
		records.append({"hero_id": id, "concept": path, "sha256": FileAccess.get_sha256(path), "static_reference_only": true})
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	assert(root.get_texture().get_image().save_png(OUTPUT + "concept-lineup.png") == OK)
	var file := FileAccess.open(OUTPUT + "concept-lineup.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"hero_count": records.size(), "records": records, "scope": "Static reference paintings rendered in a labelled Godot gallery; not assembled heroes or animation approval."}, "  ") + "\n")
	print("AURELIA_CONCEPT_LINEUP count=", records.size())
	page.free()
	for frame in 3: await process_frame
	quit()

func _label(parent: Node, value: String, rect: Rect2, points: int) -> void:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", FONT.get_font())
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", Color("294137"))
	parent.add_child(label)
