extends Control
## Decorative header illustration only. Does not introduce any navigable geometry.
const MEADOW_SKY := preload('res://assets/terrain-v70/evergreen-header.png')
const MINE_SKY := preload('res://assets/terrain-v70/crimson-header.png')
const FOREST_SKY := preload('res://assets/terrain-v70/arcane-header.png')
var zone_id := 'gray_meadow'
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var header: Texture2D=MEADOW_SKY if zone_id=='gray_meadow' else MINE_SKY if zone_id=='forgotten_mine' else FOREST_SKY
	draw_texture_rect(header,Rect2(0,0,size.x,size.y),false)
