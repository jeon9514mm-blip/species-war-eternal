extends Node
## Empty compatibility adapter. All map props and their assets were removed.
var game: Node
var actor_layer: Node2D
var props: Array[Sprite2D]=[]
var zone_id: String='gray_meadow'
func install(main: Node,parent: Node2D) -> void:game=main;actor_layer=parent;zone_id=main.current_zone_id
func refresh(_delta: float=0) -> void:pass
static func texture_for(_kind: String,_zone: String) -> Texture2D:return null
static func visual_height(_kind: String,_radii: Vector2) -> float:return 0.0
