extends Control
class_name WorldWarMinimap
## A small strategic overview; tapping moves the map camera without selecting orders.
var map_view: WorldWarMapView
func _ready() -> void:
	custom_minimum_size=Vector2(112,64)
	mouse_filter=Control.MOUSE_FILTER_STOP
	tooltip_text='대륙 전체 지도 · 눌러 시점 이동'
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color('#13252d'))
	if map_view==null or map_view.world_state==null:return
	var world:=map_view.world_state
	var scale:=Vector2(size.x/WorldWarState.WIDTH,size.y/WorldWarState.HEIGHT)
	for key in world.cells:
		var tile: Dictionary=world.cells[key]
		var pos:=Vector2(int(tile.get('x',0)),int(tile.get('y',0)))
		# Coordinates are encoded in keys in older saved worlds as well.
		var pair:=str(key).split(':');pos=Vector2(int(pair[0]),int(pair[1]))
		var owner:=str(tile.get('owner','neutral'))
		var color:=Color('#627c55')
		if owner=='aurelia':color=Color('#68b8ee')
		elif owner=='noxfera':color=Color('#ed8091')
		elif str(tile.get('type','')) in ['fort','citadel','capital']:color=Color('#cfb16b')
		draw_rect(Rect2(pos*scale,scale+Vector2(.2,.2)),color)
	draw_line(Vector2(size.x*.5,0),Vector2(size.x*.5,size.y),Color('#172a3188'),1)
	draw_line(Vector2(0,size.y*.5),Vector2(size.x,size.y*.5),Color('#172a3188'),1)
	var corners:=PackedVector2Array()
	map_view._map_metrics()
	for point in [Vector2.ZERO,Vector2(map_view.size.x,0),map_view.size,Vector2(0,map_view.size.y)]:
		corners.append(map_view._unproject(point-map_view._origin)*scale)
	corners.append(corners[0]);draw_polyline(corners,Color('#fff2c9'),1,true)
	draw_circle(map_view.army_map_position()*scale,2.6,Color('#fff7d6'))
	draw_rect(Rect2(Vector2.ZERO,size),Color('#b5a377'),false,1)
func _gui_input(event: InputEvent) -> void:
	var point:=Vector2(-1,-1)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:point=event.position
	if event is InputEventScreenTouch and event.pressed:point=event.position
	if point.x<0 or not Rect2(Vector2.ZERO,size).has_point(point) or map_view==null:return
	if map_view.zoom<2:map_view.set_zoom(3.5)
	map_view.focus_cell(Vector2i(int(point.x/size.x*WorldWarState.WIDTH),int(point.y/size.y*WorldWarState.HEIGHT)))
	queue_redraw();accept_event()
