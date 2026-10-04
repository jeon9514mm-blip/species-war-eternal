extends RefCounted
## Visual profiles only. Never owns biome difficulty, enemies, RNG or unlocks.
const IDS := ["meadow","canyon","ruins"]
const ZONE_THEMES := {"gray_meadow":"meadow","forgotten_mine":"canyon","moonrest_forest":"ruins"}
const ROOT := "res://assets/art-direction/hunting-quality-03/"

static func theme_for_zone(zone: String) -> String:
	return str(ZONE_THEMES.get(zone,"meadow"))

static func profile(theme: String) -> Dictionary:
	var data := {
		"meadow":{"title":"빛바람 초원","ground":"res://assets/art-direction/meadow-quality-02/meadow-ground.png","props":"res://assets/art-direction/meadow-quality-02/environment-props.png",
			"regions":[Rect2(9,8,568,591),Rect2(593,3,403,593),Rect2(1001,56,531,518),Rect2(8,637,537,352),Rect2(557,603,481,399),Rect2(1043,594,472,421)],
			"ambient":"c5dacb","fog":"c7dfd0","sun":"fff3df","sun_energy":.84,"exposure":.85,"sky_top":"87badd","sky_bottom":"c4dccc","grass":["56773d","718c42","8a9b4c"]},
		"canyon":{"title":"붉은 협곡 광산","ground":ROOT+"canyon/ground.png","props":ROOT+"canyon/props.png","layers":ROOT+"canyon/layers.png",
			"regions":[],"layer_regions":[],"ambient":"dfb391","fog":"c5a397","sun":"ffd4a0","sun_energy":.90,"exposure":.85,"sky_top":"ad7479","sky_bottom":"edc3a0","grass":["886c4b","a38552","c2a15e"]},
		"ruins":{"title":"달쉼 숲 · 엘프 유적","ground":ROOT+"ruins/ground.png","props":ROOT+"ruins/props.png","layers":ROOT+"ruins/layers.png",
			"regions":[],"layer_regions":[],"ambient":"86b9b3","fog":"709c9a","sun":"c6e9e3","sun_energy":.65,"exposure":.85,"sky_top":"172d44","sky_bottom":"789b92","grass":["355746","4e7056","6b8061"]}
	}
	var result: Dictionary = data.get(theme,data.meadow).duplicate(true)
	if theme in ["canyon","ruins"]:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(ROOT+theme+"/layout.json"))
		if parsed is Dictionary:
			for key: String in ["regions","layer_regions"]:
				for box: Array in parsed[key]: result[key].append(Rect2(box[0],box[1],box[2],box[3]))
	return result
