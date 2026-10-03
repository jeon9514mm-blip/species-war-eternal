extends RefCounted
## Landscape-only release. Resizing never recreates game state or battle sessions.
static func apply(main: Node, resize_window: bool = true) -> void:
	if not main.is_inside_tree(): return
	# Older local settings can still contain portrait/auto. Always normalize them.
	main.presentation_options["orientation"] = "landscape"
	var window: Window = main.get_window()
	var base := Vector2i(1280,720)
	if window.content_scale_size != base: window.content_scale_size = base
	# Desktop window resizing must not reactivate the unfinished portrait layouts.
	# Wide mobile screens still receive the extra horizontal combat space.
	var aspect := Window.CONTENT_SCALE_ASPECT_EXPAND if window.size.x > window.size.y else Window.CONTENT_SCALE_ASPECT_KEEP
	if window.content_scale_aspect != aspect: window.content_scale_aspect = aspect
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	elif resize_window and DisplayServer.get_name() != "headless":
		window.size = Vector2i(1120,630)
