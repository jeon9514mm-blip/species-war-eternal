extends RefCounted
## Shared presentation geometry. No encounter, camera or reward state is rebuilt here.
## All measurements use Godot viewport units, not Android dp or physical pixels.
const NAV_HEIGHT := 52.0 # Compatibility token; the hunt dock uses navigation_rect().
const SINGLE_ROW_MIN_WIDTH := 1180.0
const EDGE := 12.0
const PADDING := 8.0
const PARTY_SUMMARY_WIDTH := 68.0
const PARTY_SUMMARY_GAP := 8.0
const NAV_WIDTH := 440.0
const HERO_HEIGHT := 60.0
const HERO_CELL_MAX := 64.0
const FIELD_TOP := 136.0

static func single_row(screen: Vector2) -> bool:
	return screen.x >= SINGLE_ROW_MIN_WIDTH

static func footer(screen: Vector2) -> Rect2:
	var height: float = 76.0 if single_row(screen) else 136.0
	return Rect2(EDGE, screen.y - height - EDGE, screen.x - EDGE * 2.0, height)

static func party_rect(screen: Vector2) -> Rect2:
	var dock: Rect2 = footer(screen)
	var width: float = dock.size.x - (NAV_WIDTH + PADDING * 3.0 if single_row(screen) else PADDING * 2.0)
	return Rect2(dock.position + Vector2.ONE * PADDING, Vector2(width, HERO_HEIGHT))

static func slots_rect(screen: Vector2) -> Rect2:
	var party: Rect2 = party_rect(screen)
	var inset: float = PARTY_SUMMARY_WIDTH + PARTY_SUMMARY_GAP
	return Rect2(party.position + Vector2(inset, 0.0), Vector2(party.size.x - inset, HERO_HEIGHT))

static func navigation_rect(screen: Vector2) -> Rect2:
	var dock: Rect2 = footer(screen)
	if single_row(screen):
		return Rect2(dock.end.x - NAV_WIDTH - PADDING, dock.position.y + PADDING, NAV_WIDTH, HERO_HEIGHT)
	return Rect2(dock.position.x + PADDING, dock.position.y + 80.0, dock.size.x - PADDING * 2.0, 48.0)

static func field(screen: Vector2) -> Rect2:
	return Rect2(EDGE, FIELD_TOP, screen.x - EDGE * 2.0, maxf(0.0, footer(screen).position.y - PADDING - FIELD_TOP))
