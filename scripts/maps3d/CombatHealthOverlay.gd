extends Control
var links: Array[PackedVector2Array]=[]
func _draw() -> void:
	for link in links:
		draw_line(link[0],link[1],Color(.75,.85,.9,.48),1.0,true)
