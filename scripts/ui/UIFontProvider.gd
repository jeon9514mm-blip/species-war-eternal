extends RefCounted
## SystemFont resource only. No font binary is shipped.
const DEVICE_FONT = preload("res://ui/DeviceFont.tres")
static func get_font() -> Font:
	return DEVICE_FONT
