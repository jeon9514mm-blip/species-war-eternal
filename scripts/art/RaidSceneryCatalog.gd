extends RefCounted
## Original environment paintings. No copied commercial game assets.
const THEMES := {
	"gray_meadow": {"title":"거목의 성역", "plate":"woodland", "accent":Color("#cfdf93"), "mote":Color("#cdec9b")},
	"forgotten_mine": {"title":"수정 용광로", "plate":"forge", "accent":Color("#ffc17d"), "mote":Color("#ff9c43")},
	"moonrest_forest": {"title":"월식의 정원", "plate":"eclipse", "accent":Color("#d7b5ff"), "mote":Color("#bfc3ff")},
}
static func profile(zone: String) -> Dictionary:
	return THEMES.get(zone,THEMES.gray_meadow)
static func texture_path(zone: String) -> String:
	return "res://assets/art-direction/raid-quality-01/%s.png" % profile(zone).plate
