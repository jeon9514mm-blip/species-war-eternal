extends RefCounted
class_name MonsterPixelAtlasLayout

static func has_monster(monster_name: String) -> bool:
	return PROFILES.has(monster_name)

static func sheet_path(monster_name: String) -> String:
	if not has_monster(monster_name):
		return ""
	return str(SHEETS[PROFILES[monster_name]["sheet"]])

static func pose_index(monster_name: String, pose: int) -> int:
	var data: Dictionary = PROFILES[monster_name]
	return clampi(pose, 0, 3) * int(data["columns"]) + int(data["column"])

static func canvas_size(monster_name: String) -> Vector2:
	var data: Dictionary = PROFILES[monster_name]
	var result := Vector2.ZERO
	for pose in range(4):
		var bounds: Rect2i = REGIONS[data["sheet"]][pose_index(monster_name, pose)]
		result.x = maxf(result.x, bounds.size.x)
		result.y = maxf(result.y, bounds.size.y)
	return result + Vector2(8.0, 8.0)

static func frame_texture(texture: Texture2D, monster_name: String, pose: int) -> AtlasTexture:
	var data: Dictionary = PROFILES[monster_name]
	var index := pose_index(monster_name, pose)
	var bounds: Rect2 = Rect2(REGIONS[data["sheet"]][index])
	var pivot: Vector2 = PIVOTS[data["sheet"]][index]
	var canvas := canvas_size(monster_name)
	var frame := AtlasTexture.new()
	frame.atlas = texture
	frame.region = bounds
	frame.margin = Rect2(Vector2(canvas.x * 0.5, canvas.y - 4.0) - (pivot - bounds.position), canvas - bounds.size)
	frame.filter_clip = true
	return frame

## v32 measured artwork bounds. PNG pixels remain unchanged.
## All alpha >= 128 pixels belong to exactly one pose.
const PROFILES := {
	"초원 고블린": {"sheet": "meadow", "column": 0, "columns": 6, "target_height": 38, "reference_scale": 0.09, "idle_visual_height": 176},
	"들개 무리": {"sheet": "meadow", "column": 1, "columns": 6, "target_height": 36, "reference_scale": 0.09, "idle_visual_height": 193},
	"가시 멧돼지": {"sheet": "meadow", "column": 2, "columns": 6, "target_height": 42, "reference_scale": 0.09, "idle_visual_height": 192},
	"철갑 두더지": {"sheet": "meadow", "column": 3, "columns": 6, "target_height": 38, "reference_scale": 0.09, "idle_visual_height": 164},
	"독버섯 정령": {"sheet": "meadow", "column": 4, "columns": 6, "target_height": 38, "reference_scale": 0.09, "idle_visual_height": 180},
	"달빛 늑대": {"sheet": "meadow", "column": 5, "columns": 6, "target_height": 44, "reference_scale": 0.09, "idle_visual_height": 197},
	"바람 까마귀": {"sheet": "depths", "column": 0, "columns": 7, "target_height": 44, "reference_scale": 0.09, "idle_visual_height": 95},
	"광산 오크": {"sheet": "depths", "column": 1, "columns": 7, "target_height": 44, "reference_scale": 0.09, "idle_visual_height": 155},
	"용암 박쥐": {"sheet": "depths", "column": 2, "columns": 7, "target_height": 44, "reference_scale": 0.09, "idle_visual_height": 106},
	"수정 거미": {"sheet": "depths", "column": 3, "columns": 7, "target_height": 44, "reference_scale": 0.09, "idle_visual_height": 109},
	"숲의 망령": {"sheet": "depths", "column": 4, "columns": 7, "target_height": 44, "reference_scale": 0.09, "idle_visual_height": 162},
	"밤까마귀": {"sheet": "depths", "column": 5, "columns": 7, "target_height": 44, "reference_scale": 0.09, "idle_visual_height": 110},
	"서리 사슴": {"sheet": "depths", "column": 6, "columns": 7, "target_height": 44, "reference_scale": 0.09, "idle_visual_height": 168},
	"초원왕 그룬": {"sheet": "boss", "column": 0, "columns": 3, "target_height": 100, "reference_scale": 0.07, "idle_visual_height": 308},
	"광맥의 거인 모르굴": {"sheet": "boss", "column": 1, "columns": 3, "target_height": 100, "reference_scale": 0.07, "idle_visual_height": 314},
	"월식의 여왕 셀레네": {"sheet": "boss", "column": 2, "columns": 3, "target_height": 100, "reference_scale": 0.07, "idle_visual_height": 303},
}
const SHEETS := {
	"meadow": "res://assets/monsters/pixel-v32/meadow-six-atlas.png",
	"depths": "res://assets/monsters/pixel-v32/depths-seven-safe-atlas.png",
	"boss": "res://assets/monsters/pixel-v32/boss-three-atlas.png",
}
const REGIONS := {
	"meadow": [
		Rect2i(39, 90, 208, 182),
		Rect2i(266, 77, 222, 199),
		Rect2i(519, 74, 250, 198),
		Rect2i(789, 107, 235, 170),
		Rect2i(1047, 86, 181, 186),
		Rect2i(1269, 74, 240, 203),
		Rect2i(44, 327, 203, 176),
		Rect2i(273, 306, 228, 200),
		Rect2i(525, 306, 245, 200),
		Rect2i(788, 329, 235, 178),
		Rect2i(1056, 320, 188, 184),
		Rect2i(1276, 307, 238, 200),
		Rect2i(42, 548, 205, 182),
		Rect2i(274, 536, 228, 194),
		Rect2i(527, 528, 246, 205),
		Rect2i(798, 555, 231, 180),
		Rect2i(1061, 544, 178, 191),
		Rect2i(1272, 537, 245, 205),
		Rect2i(34, 753, 219, 210),
		Rect2i(266, 778, 228, 184),
		Rect2i(519, 773, 252, 195),
		Rect2i(789, 791, 246, 177),
		Rect2i(1053, 781, 200, 182),
		Rect2i(1273, 772, 240, 197),
	],
	"depths": [
		Rect2i(56, 145, 124, 101),
		Rect2i(259, 84, 146, 161),
		Rect2i(462, 114, 172, 112),
		Rect2i(687, 129, 159, 115),
		Rect2i(913, 85, 140, 168),
		Rect2i(1123, 131, 142, 116),
		Rect2i(1354, 75, 114, 174),
		Rect2i(49, 370, 135, 103),
		Rect2i(259, 314, 145, 162),
		Rect2i(464, 348, 163, 114),
		Rect2i(687, 356, 163, 115),
		Rect2i(910, 317, 139, 163),
		Rect2i(1125, 360, 143, 117),
		Rect2i(1351, 315, 118, 164),
		Rect2i(58, 553, 138, 155),
		Rect2i(262, 542, 148, 166),
		Rect2i(468, 579, 166, 111),
		Rect2i(684, 591, 165, 117),
		Rect2i(911, 538, 141, 175),
		Rect2i(1132, 553, 139, 155),
		Rect2i(1347, 540, 123, 174),
		Rect2i(55, 795, 142, 139),
		Rect2i(260, 766, 152, 171),
		Rect2i(470, 801, 161, 126),
		Rect2i(681, 792, 172, 147),
		Rect2i(898, 783, 175, 166),
		Rect2i(1118, 795, 153, 141),
		Rect2i(1325, 818, 160, 121),
	],
	"boss": [
		Rect2i(49, 22, 364, 314),
		Rect2i(470, 16, 341, 320),
		Rect2i(919, 27, 259, 309),
		Rect2i(43, 341, 357, 288),
		Rect2i(475, 340, 349, 289),
		Rect2i(925, 341, 257, 291),
		Rect2i(64, 643, 334, 285),
		Rect2i(481, 627, 345, 304),
		Rect2i(914, 630, 274, 305),
		Rect2i(61, 927, 361, 306),
		Rect2i(496, 932, 315, 307),
		Rect2i(876, 970, 346, 269),
	],
}

const PIVOTS := {
	"meadow": [
		Vector2(143.0, 269),
		Vector2(377.0, 273),
		Vector2(644.0, 269),
		Vector2(906.5, 274),
		Vector2(1137.5, 269),
		Vector2(1389.0, 274),
		Vector2(145.5, 500),
		Vector2(387.0, 503),
		Vector2(647.5, 503),
		Vector2(905.5, 504),
		Vector2(1150.0, 501),
		Vector2(1395.0, 504),
		Vector2(144.5, 727),
		Vector2(388.0, 727),
		Vector2(650.0, 730),
		Vector2(913.5, 732),
		Vector2(1150.0, 732),
		Vector2(1394.5, 739),
		Vector2(143.5, 960),
		Vector2(380.0, 959),
		Vector2(645.0, 965),
		Vector2(912.0, 965),
		Vector2(1153.0, 960),
		Vector2(1393.0, 966),
	],
	"depths": [
		Vector2(118.0, 243),
		Vector2(332.0, 242),
		Vector2(548.0, 223),
		Vector2(766.5, 241),
		Vector2(983.0, 250),
		Vector2(1194.0, 244),
		Vector2(1411.0, 246),
		Vector2(116.5, 470),
		Vector2(331.5, 473),
		Vector2(545.5, 459),
		Vector2(768.5, 468),
		Vector2(979.5, 477),
		Vector2(1196.5, 474),
		Vector2(1410.0, 476),
		Vector2(127.0, 705),
		Vector2(336.0, 705),
		Vector2(551.0, 687),
		Vector2(766.5, 705),
		Vector2(981.5, 710),
		Vector2(1201.5, 705),
		Vector2(1408.5, 711),
		Vector2(126.0, 931),
		Vector2(336.0, 934),
		Vector2(550.5, 924),
		Vector2(767.0, 936),
		Vector2(985.5, 946),
		Vector2(1194.5, 933),
		Vector2(1405.0, 936),
	],
	"boss": [
		Vector2(231.0, 333),
		Vector2(640.5, 333),
		Vector2(1048.5, 333),
		Vector2(221.5, 626),
		Vector2(649.5, 626),
		Vector2(1053.5, 629),
		Vector2(231.0, 927),
		Vector2(653.5, 928),
		Vector2(1051.0, 932),
		Vector2(241.5, 1232),
		Vector2(653.5, 1236),
		Vector2(1049.0, 1236),
	],
}
