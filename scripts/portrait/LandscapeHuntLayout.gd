extends RefCounted
## Shared battlefield/footer geometry; presentation changes never rebuild a hunt.
const NAV_HEIGHT := 52.0
static func footer(screen: Vector2) -> Rect2:
	return Rect2(12,screen.y-NAV_HEIGHT-76,screen.x-24,64)
static func field(screen: Vector2) -> Rect2:
	return Rect2(12,136,screen.x-24,footer(screen).position.y-160)
