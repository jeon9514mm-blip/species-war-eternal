extends RefCounted
## Device preference only. Resizing never recreates game state or battle sessions.
static func apply(main: Node, resize_window: bool = true) -> void:
	if not main.is_inside_tree(): return
	var choice: String = str(main.presentation_options.get("orientation", "portrait"))
	var window: Window = main.get_window()
	var landscape: bool = choice == "landscape" or (choice == "auto" and window.size.x > window.size.y)
	var base := Vector2i(1280,720) if landscape else Vector2i(720,1280)
	if window.content_scale_size != base: window.content_scale_size = base
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR if choice == "auto" else (DisplayServer.SCREEN_LANDSCAPE if landscape else DisplayServer.SCREEN_PORTRAIT))
	elif resize_window and choice != "auto" and DisplayServer.get_name() != "headless":
		window.size = Vector2i(1120,630) if landscape else Vector2i(450,800)
