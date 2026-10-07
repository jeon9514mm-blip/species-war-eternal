extends RefCounted
class_name BrightSpriteAtlasLayout

## Bounds measured from alpha-connected artwork, not a nominal equal grid.
## Source PNG pixels are preserved. Three transparent pixels protect filtering.
const REGIONS := {
	"leonhardt": [
		Rect2i(47, 37, 197, 255),
		Rect2i(358, 36, 204, 258),
		Rect2i(663, 37, 205, 255),
		Rect2i(946, 51, 299, 241),
		Rect2i(59, 346, 184, 252),
		Rect2i(356, 344, 185, 254),
		Rect2i(667, 343, 200, 254),
		Rect2i(945, 359, 300, 238),
		Rect2i(64, 650, 197, 251),
		Rect2i(392, 654, 179, 251),
		Rect2i(707, 658, 190, 246),
		Rect2i(1006, 646, 231, 255),
		Rect2i(76, 950, 173, 259),
		Rect2i(395, 950, 185, 259),
		Rect2i(700, 953, 208, 256),
		Rect2i(930, 970, 307, 235),
	],
	"mira": [
		Rect2i(64, 41, 190, 265),
		Rect2i(372, 41, 194, 265),
		Rect2i(686, 41, 195, 263),
		Rect2i(990, 40, 248, 264),
		Rect2i(55, 349, 210, 263),
		Rect2i(366, 345, 214, 267),
		Rect2i(686, 348, 213, 265),
		Rect2i(977, 350, 264, 261),
		Rect2i(69, 656, 177, 256),
		Rect2i(385, 654, 178, 262),
		Rect2i(690, 654, 181, 261),
		Rect2i(1005, 634, 232, 279),
		Rect2i(57, 953, 201, 261),
		Rect2i(369, 949, 203, 264),
		Rect2i(685, 950, 199, 263),
		Rect2i(968, 952, 256, 261),
	],
	"orwin": [
		Rect2i(72, 27, 201, 283),
		Rect2i(358, 28, 194, 282),
		Rect2i(659, 27, 200, 283),
		Rect2i(940, 78, 303, 230),
		Rect2i(78, 333, 183, 279),
		Rect2i(362, 337, 190, 276),
		Rect2i(667, 349, 178, 266),
		Rect2i(938, 381, 313, 231),
		Rect2i(70, 629, 178, 282),
		Rect2i(363, 631, 192, 280),
		Rect2i(662, 634, 196, 277),
		Rect2i(932, 691, 314, 220),
		Rect2i(67, 937, 180, 269),
		Rect2i(374, 937, 184, 267),
		Rect2i(664, 935, 175, 270),
		Rect2i(882, 975, 309, 231),
	],
	"darius": [
		Rect2i(83, 41, 158, 251),
		Rect2i(382, 43, 176, 246),
		Rect2i(689, 42, 178, 248),
		Rect2i(963, 51, 279, 238),
		Rect2i(70, 340, 152, 253),
		Rect2i(373, 342, 224, 252),
		Rect2i(684, 342, 203, 252),
		Rect2i(939, 350, 310, 245),
		Rect2i(79, 647, 162, 244),
		Rect2i(377, 649, 195, 243),
		Rect2i(698, 647, 177, 248),
		Rect2i(979, 664, 259, 235),
		Rect2i(102, 943, 152, 248),
		Rect2i(347, 944, 217, 247),
		Rect2i(675, 944, 202, 247),
		Rect2i(919, 950, 302, 241),
	],
	"caelum": [
		Rect2i(73, 47, 181, 254),
		Rect2i(371, 48, 207, 256),
		Rect2i(683, 48, 198, 255),
		Rect2i(972, 53, 260, 247),
		Rect2i(80, 352, 148, 257),
		Rect2i(350, 353, 236, 254),
		Rect2i(678, 352, 213, 257),
		Rect2i(955, 357, 295, 248),
		Rect2i(87, 660, 183, 245),
		Rect2i(371, 659, 201, 246),
		Rect2i(687, 660, 201, 245),
		Rect2i(962, 651, 265, 255),
		Rect2i(58, 950, 177, 256),
		Rect2i(360, 951, 221, 256),
		Rect2i(673, 949, 230, 257),
		Rect2i(955, 961, 277, 245),
	],
	"monsters": [
		Rect2i(41, 117, 201, 166),
		Rect2i(267, 101, 216, 181),
		Rect2i(523, 84, 244, 195),
		Rect2i(789, 117, 220, 168),
		Rect2i(1045, 97, 174, 182),
		Rect2i(1272, 84, 236, 201),
		Rect2i(51, 339, 194, 169),
		Rect2i(282, 328, 217, 180),
		Rect2i(530, 315, 240, 189),
		Rect2i(793, 337, 231, 170),
		Rect2i(1056, 328, 181, 179),
		Rect2i(1284, 317, 230, 193),
		Rect2i(49, 557, 199, 175),
		Rect2i(283, 547, 220, 181),
		Rect2i(539, 537, 238, 193),
		Rect2i(799, 558, 229, 171),
		Rect2i(1058, 548, 178, 180),
		Rect2i(1276, 543, 242, 193),
		Rect2i(31, 764, 219, 192),
		Rect2i(271, 780, 224, 174),
		Rect2i(524, 771, 246, 187),
		Rect2i(790, 783, 242, 171),
		Rect2i(1052, 780, 206, 176),
		Rect2i(1278, 771, 234, 192),
	],
}

static func canvas_size(key: String, column: int = -1) -> Vector2:
	var result := Vector2.ZERO
	var regions: Array = REGIONS.get(key, [])
	for index in regions.size():
		if column >= 0 and index % 6 != column:
			continue
		var region: Rect2i = regions[index]
		result.x = maxf(result.x, region.size.x)
		result.y = maxf(result.y, region.size.y)
	return result + Vector2(4, 4)

static func frame_texture(texture: Texture2D, key: String, index: int, column: int = -1) -> AtlasTexture:
	var region: Rect2 = Rect2(REGIONS[key][index])
	var canvas := canvas_size(key, column)
	var frame := AtlasTexture.new()
	frame.atlas = texture
	frame.region = region
	frame.margin = Rect2(Vector2((canvas.x - region.size.x) * 0.5, canvas.y - 2.0 - region.size.y), canvas - region.size)
	return frame
