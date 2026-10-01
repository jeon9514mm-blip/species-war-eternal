extends RefCounted
## Shared scrolling settings panel, reuses existing widgets and theme.
const P := preload("res://scripts/portrait/PortraitPages.gd")
const S := preload("res://scripts/portrait/PortraitSkin.gd")

static func open(game: Node) -> void:
	if not is_instance_valid(game.content_root): return
	for name in ["PortraitActionSheet", "MenuOverlay", "PresentationSettingsOverlay"]:
		var old: Node = game.content_root.get_node_or_null(name)
		if old != null:
			old.get_parent().remove_child(old)
			old.queue_free()
	var overlay := Control.new(); overlay.name = "PresentationSettingsOverlay"; overlay.z_index = 250
	game.content_root.add_child(overlay); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new(); shade.color = Color(0, 0, 0, 0.68)
	overlay.add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new(); panel.name = "PresentationSettingsPanel"
	panel.add_theme_stylebox_override("panel", S.elevated(S.DARK_2, S.EDGE_SOFT, 16))
	overlay.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe: Vector4 = game._safe_margins()
	panel.offset_left = maxf(20.0, safe.x); panel.offset_right = -maxf(20.0, safe.z)
	panel.offset_top = maxf(40.0, safe.y); panel.offset_bottom = -maxf(40.0, safe.w)
	var margin := MarginContainer.new(); panel.add_child(margin)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 20)
	var layout: VBoxContainer = P.stack(margin, 12)
	var heading := HBoxContainer.new(); layout.add_child(heading)
	var title: Label = P.text(heading, "화면 · 소리 · 진동 · 성능", 27, S.GOLD); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close: Button = P.action(heading, "닫기", func(): game._save_ui_preferences(); overlay.queue_free()); close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.custom_minimum_size = Vector2(90, 52); close.name = "PresentationClose"
	var scroll := ScrollContainer.new(); scroll.name = "PresentationSettingsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var body: VBoxContainer = P.stack(scroll, 14)
	P.text(body, "소리와 진동은 전투 능력치에 영향을 주지 않습니다.", 17, S.MUTED)
	_choice(game, body, "orientation", "화면 방향", [["portrait", "세로 모드"], ["landscape", "가로 모드"], ["auto", "기기 회전 따라가기"]])
	P.text(body, "전투 중에도 방향을 바꿀 수 있습니다. 체력·전투 진행·보상은 유지됩니다.", 16, S.MUTED)
	var music := CheckButton.new(); music.name = "PresentationMusicEnabled"; music.text = "배경음 사용"
	music.custom_minimum_size.y = 52; music.button_pressed = game.presentation_options["music_enabled"]
	body.add_child(music); music.toggled.connect(func(on: bool): game._set_presentation_option("music_enabled", on))
	var sound := CheckButton.new(); sound.name = "PresentationSoundEnabled"; sound.text = "효과음 · UI · 환경음 사용"
	sound.custom_minimum_size.y = 52; sound.button_pressed = game.sound_effects_enabled; body.add_child(sound)
	sound.toggled.connect(func(on: bool): game.sound_effects_enabled = on; game._save_ui_preferences())
	for spec in [["music_volume", "배경음"], ["effects_volume", "전투 효과음"], ["ui_volume", "UI · 보상"], ["ambient_volume", "환경음"]]:
		_volume(game, body, str(spec[0]), str(spec[1]))
	P.action(body, "효과음 미리 듣기", func(): game._presentation_event("reward")).name = "PresentationAudioPreview"
	_choice(game, body, "haptics", "진동 강도", [["off", "끔"], ["light", "약하게"], ["normal", "보통"]])
	P.text(body, "진동은 기본 꺼짐입니다. 지원 기기와 진동 권한이 필요하며, 자동 전투 중 연속 진동을 제한합니다.", 16, S.MUTED)
	_choice(game, body, "performance", "화면 성능", [["balanced", "기본 · 최대 60 FPS"], ["battery", "절전 · 최대 30 FPS"]])
	P.text(body, "절전은 화면 갱신과 장식 효과 수만 줄입니다. 이동·공격 판정과 게임 배속, 보스 위험 표시는 유지합니다.", 16, S.MUTED)
	var notice: Label = P.text(layout, "", 16, S.MUTED); notice.name = "PresentationSettingsSaveStatus"
	var retry: Button = P.action(layout, "설정 다시 저장", func(): game._save_ui_preferences()); retry.name = "PresentationRetrySave"
	retry.visible = game.presentation_settings_error != OK
	var diagnostics: Label = P.text(body, "FPS·발열 수치는 실제 기기에서 별도로 확인해야 합니다.", 16, S.MUTED)
	diagnostics.name = "PresentationPerformanceNotice"
	game._refresh_presentation_save_notice()

static func _volume(game: Node, parent: Node, key: String, caption: String) -> void:
	var title: Label = P.text(parent, "%s · %d%%" % [caption, roundi(float(game.presentation_options[key]) * 100)], 18)
	var slider := HSlider.new(); slider.name = "Presentation_" + key
	slider.min_value = 0; slider.max_value = 100; slider.step = 1; slider.value = float(game.presentation_options[key]) * 100
	slider.custom_minimum_size = Vector2(0, 52); parent.add_child(slider)
	slider.value_changed.connect(func(value: float):
		title.text = "%s · %d%%" % [caption, roundi(value)]
		game._set_presentation_option(key, value / 100.0, false))
	# Coalesce drag writes; keyboard/controller changes are saved on focus exit.
	slider.drag_ended.connect(func(_changed: bool): game._save_ui_preferences())
	slider.focus_exited.connect(func(): game._save_ui_preferences())

static func _choice(game: Node, parent: Node, key: String, caption: String, choices: Array) -> void:
	P.text(parent, caption, 19, S.GOLD)
	var choice := OptionButton.new(); choice.name = "Presentation_" + key; choice.custom_minimum_size.y = 52
	for entry in choices:
		choice.add_item(str(entry[1])); choice.set_item_metadata(choice.item_count - 1, str(entry[0]))
		if str(game.presentation_options[key]) == str(entry[0]): choice.select(choice.item_count - 1)
	parent.add_child(choice)
	choice.item_selected.connect(func(index: int): game._set_presentation_option(key, str(choice.get_item_metadata(index))))
