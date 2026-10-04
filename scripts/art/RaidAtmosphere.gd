extends Control
## Two independently animated peripheral mote bands over a single painted plate.
## No random calls, camera movement, or particles over the walkable floor.
var field: Control
var accent := Color.WHITE
var clock := 0.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	if not is_instance_valid(field) or not is_instance_valid(field.game):return
	var game: Node=field.game
	if not get_tree().paused and not bool(game._application_suspended) and bool(field.animate_environment):
		clock+=minf(delta,.1)
		queue_redraw()
func _draw() -> void:
	if size.x<1 or size.y<1:return
	for i in 28:
		var side: float=.03+fmod(float(i)*.061,.105) if i%2==0 else .86+fmod(float(i)*.043,.105)
		var cycle: float=fmod(float(i)*.173+clock*(.018+float(i%3)*.004),1.0)
		var point:=Vector2(size.x*side+sin(clock*.55+float(i))*8,size.y*(.15+cycle*.70))
		var alpha:=.18+.28*(.5+.5*sin(clock*1.2+float(i)))
		draw_circle(point,2.5,Color(accent,alpha*.10))
		draw_circle(point,1.1,Color(accent,alpha))
