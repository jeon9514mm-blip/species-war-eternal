extends Control
## Minimal presentation context for the standalone map gallery, with no game.
var zone_id: String
var game: Node
var actors: Dictionary={}
var camera: Camera3D
func _projection_scale() -> Vector2:return Vector2.ONE
func project_world(point: Vector2,height: float=0) -> Vector2:
	return camera.unproject_position(Vector3(point.x,height,point.y))
