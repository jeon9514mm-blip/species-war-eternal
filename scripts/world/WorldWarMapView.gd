extends Control
class_name WorldWarMapView

signal tile_selected(cell: Vector2i)
signal zoom_changed(value: float)
signal camera_changed
var world_state: WorldWarState
var march_state: WorldMarchState
var supply_network: WorldSupplyNetwork
var selected_cell:=Vector2i(-1,-1)
var zoom:=3.5
var camera_center:=Vector2(10,10)
var show_supply:=true
var map_filter: String='all'
var preview_path: Array[Vector2i]=[]
var _cell_size:=48.0
var _origin:=Vector2.ZERO
var _pointer: int=-1
var _drag_distance:=0.0
var _pointer_start:=Vector2.ZERO
var _touches: Dictionary={}
var _pinch_distance:=0.0
var _multi_touch:=false
const DRAG_THRESHOLD:=8.0
const MAX_ZOOM:=8.0

func _ready() -> void:
	clip_contents=true;mouse_filter=Control.MOUSE_FILTER_STOP
	resized.connect(func(): queue_redraw();camera_changed.emit())
func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT or (what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		_reset_gesture()
func _reset_gesture() -> void:
	_pointer=-1;_touches.clear();_multi_touch=false;_pinch_distance=0.0;_drag_distance=0.0
func set_world_state(value: WorldWarState) -> void:
	world_state=value
	if world_state!=null:selected_cell=world_state.army_position;camera_center=Vector2(selected_cell)+Vector2(.5,.5)
	queue_redraw()
func set_march_state(value: WorldMarchState) -> void:march_state=value;queue_redraw()
func set_supply_network(value: WorldSupplyNetwork) -> void:supply_network=value;queue_redraw()
func set_selected(cell: Vector2i) -> void:selected_cell=cell;queue_redraw()
func set_preview(route: Array) -> void:preview_path.assign(route);queue_redraw()
func _project(value: Vector2) -> Vector2:return Vector2((value.x-value.y)*.5,(value.x+value.y)*.25)*_cell_size
func _unproject(value: Vector2) -> Vector2:return Vector2(value.x+value.y*2,-value.x+value.y*2)/_cell_size
func _map_metrics() -> void:
	var fit:=minf(size.x/(float(WorldWarState.WIDTH+WorldWarState.HEIGHT)*.5),size.y/(float(WorldWarState.WIDTH+WorldWarState.HEIGHT)*.25))
	_cell_size=maxf(1,fit)*zoom
	if zoom<=1.001:camera_center=Vector2(WorldWarState.WIDTH,WorldWarState.HEIGHT)*.5
	else:camera_center=camera_center.clamp(Vector2.ZERO,Vector2(WorldWarState.WIDTH,WorldWarState.HEIGHT))
	_origin=size*.5-_project(camera_center)
func _cell_center(pos: Vector2i) -> Vector2:return _origin+_project(Vector2(pos)+Vector2(.5,.5))
func cell_at_point(point: Vector2) -> Vector2i:
	_map_metrics()
	if world_state==null or not Rect2(Vector2.ZERO,size).has_point(point):return Vector2i(-1,-1)
	var cell:=Vector2i(_unproject(point-_origin).floor())
	return cell if world_state.in_bounds(cell) else Vector2i(-1,-1)
func set_zoom(value: float, anchor:=Vector2(-1,-1)) -> void:
	if not is_finite(value):return
	_map_metrics()
	if anchor.x<0:anchor=size*.5
	var world_anchor:=_unproject(anchor-_origin)
	zoom=clampf(value,1.0,MAX_ZOOM);_map_metrics()
	camera_center=world_anchor-_unproject(anchor-size*.5)
	_map_metrics();zoom_changed.emit(zoom);camera_changed.emit();queue_redraw()
func focus_cell(cell: Vector2i) -> void:
	if world_state==null or not world_state.in_bounds(cell):return
	camera_center=Vector2(cell)+Vector2(.5,.5);_map_metrics();camera_changed.emit();queue_redraw()
func army_map_position() -> Vector2:
	if march_state!=null and march_state.active and march_state.path.size()>=2:
		var cursor: float=march_state.progress_ratio()*(march_state.path.size()-1)
		var index:=mini(int(floor(cursor)),march_state.path.size()-2)
		return Vector2(march_state.path[index]).lerp(Vector2(march_state.path[index+1]),cursor-index)+Vector2(.5,.5)
	return Vector2(world_state.army_position)+Vector2(.5,.5) if world_state!=null else Vector2.ZERO
func focus_army() -> void:
	if zoom<2:set_zoom(3.5)
	camera_center=army_map_position();_map_metrics();camera_changed.emit();queue_redraw()
func pan_by(offset: Vector2) -> void:
	_map_metrics();camera_center-=_unproject(offset);_map_metrics();camera_changed.emit();queue_redraw()
func _diamond(center: Vector2, width: float) -> PackedVector2Array:
	return PackedVector2Array([center+Vector2(0,-width*.25),center+Vector2(width*.5,0),center+Vector2(0,width*.25),center+Vector2(-width*.5,0)])
func _outline(points: PackedVector2Array, color: Color, thickness: float) -> void:
	var closed:=points.duplicate();closed.append(points[0]);draw_polyline(closed,color,thickness,true)
func _filter_match(type: String) -> bool:
	return map_filter=='all' or (map_filter=='resources' and type in ['mine','forest_resource','ruins']) or (map_filter=='forts' and type in ['fort','citadel','capital'])
func _draw() -> void:
	if world_state==null:return
	_map_metrics()
	draw_rect(Rect2(Vector2.ZERO,size),Color('#182c35'))
	var connected_a: Dictionary={};var connected_n: Dictionary={}
	if show_supply and supply_network!=null:
		connected_a=supply_network.connected_keys(world_state,'aurelia');connected_n=supply_network.connected_keys(world_state,'noxfera')
	var frame:=Rect2(Vector2(-_cell_size,-_cell_size),size+Vector2.ONE*_cell_size*2)
	# Back-to-front diagonal order keeps tall castles in front of their own tile.
	for diagonal in range(WorldWarState.WIDTH+WorldWarState.HEIGHT-1):
		for x in range(maxi(0,diagonal-WorldWarState.HEIGHT+1),mini(WorldWarState.WIDTH-1,diagonal)+1):
			var pos:=Vector2i(x,diagonal-x)
			var center:=_cell_center(pos)
			if not frame.has_point(center):continue
			var tile:=world_state.tile_at(pos);var type:=str(tile.get('type','plain'));var owner:=str(tile.get('owner','neutral'))
			var variant:=float((pos.x*17+pos.y*13)%5)*.018
			var base:=Color('#697951').lightened(variant)
			if type in ['forest','forest_resource']:base=Color('#4d6e50').lightened(variant)
			if type in ['hills','mine']:base=Color('#7e8066').lightened(variant)
			if type in ['fort','citadel','capital','ruins']:base=Color('#9a9570').lightened(variant)
			var color:=Color('#72b9f4') if owner=='aurelia' else Color('#eb7c90')
			if owner!='neutral':base=base.lerp(color,.32)
			if not _filter_match(type):base=base.darkened(.27)
			var diamond:=_diamond(center,_cell_size)
			draw_colored_polygon(diamond,base)
			if _cell_size>=25:_outline(diamond,Color('#32483240'),.8)
			# Dotted grass patches break the repeated flat-grid appearance.
			if type=='plain' and _cell_size>35:
				for i in 3:
					var pt:=center+Vector2((i-1)*_cell_size*.14,((pos.x+pos.y+i)%3-1)*_cell_size*.045)
					draw_line(pt,pt+Vector2(2,-3),Color('#b5bc7770'),1,true)
			if owner!='neutral':
				var offsets: Array[Vector2i]=[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
				for edge in 4:
					if world_state.tile_owner(pos+offsets[edge])!=owner:draw_line(diamond[edge],diamond[(edge+1)%4],Color(color,.8),2,true)
				var connected: Dictionary=connected_a if owner=='aurelia' else connected_n
				if show_supply and supply_network!=null and not connected.has(world_state._key(pos)):
					draw_line(diamond[0],diamond[2],Color('#ffe1b7'),1.5,true)
			if _cell_size>=18:_draw_landmark(type,center,color if owner!='neutral' else Color('#cfaa62'))
			if _filter_match(type) and map_filter!='all':_outline(_diamond(center,_cell_size*.92),Color('#ffe39a'),2)
			if world_state.sanctuary_owner(pos)!='neutral' and _cell_size>28:
				_outline(_diamond(center,_cell_size*.87),Color('#e9d79990'),1)
	var route: Array[Vector2i]=march_state.path if march_state!=null and march_state.active else preview_path
	if route.size()>=2:
		var points:=PackedVector2Array()
		for cell in route:points.append(_cell_center(cell))
		var active: bool=march_state!=null and march_state.active
		draw_polyline(points,Color('#16323baa'),6,true)
		draw_polyline(points,Color('#ffdb79') if active else Color('#a9e5ed'),3,true)
		for i in range(1,points.size()):
			var direction: Vector2=(points[i]-points[i-1]).normalized()
			var middle: Vector2=(points[i]+points[i-1])*.5
			draw_line(middle-direction.rotated(.6)*7,middle,Color('#ffecb2'),2,true)
			draw_line(middle-direction.rotated(-.6)*7,middle,Color('#ffecb2'),2,true)
	if world_state.in_bounds(selected_cell):_outline(_diamond(_cell_center(selected_cell),_cell_size*.94),Color('#fff0ad'),3)
	var army_point:=_origin+_project(army_map_position())
	draw_circle(army_point,13,Color('#172c35'));draw_arc(army_point,14,0,TAU,24,Color('#ffe5a1'),2,true)
	draw_line(army_point+Vector2(-2,5),army_point+Vector2(-2,-17),Color('#fff5cd'),2,true)
	draw_colored_polygon(PackedVector2Array([army_point+Vector2(-2,-17),army_point+Vector2(14,-12),army_point+Vector2(-2,-7)]),Color('#ffd67a'))

func _draw_landmark(type: String, center: Vector2, banner: Color) -> void:
	var u:=_cell_size*.30
	var shadow:=Color('#1b302b70')
	match type:
		'forest','forest_resource':
			for i in 3:
				var p:=center+Vector2((i-1)*u*.6,abs(i-1)*u*.12)
				draw_circle(p+Vector2(0,u*.15),u*.35,shadow)
				draw_line(p,p-Vector2(0,u*.7),Color('#7b654a'),maxf(1,u*.12))
				draw_colored_polygon(PackedVector2Array([p-Vector2(0,u*1.3),p+Vector2(u*.47,-u*.2),p+Vector2(-u*.47,-u*.2)]),Color('#a1c586') if type=='forest_resource' else Color('#31513b'))
				draw_colored_polygon(PackedVector2Array([p-Vector2(0,u),p+Vector2(u*.38,-u*.4),p+Vector2(-u*.38,-u*.4)]),Color('#c6d6a0') if type=='forest_resource' else Color('#607f51'))
		'hills','mine':
			draw_colored_polygon(PackedVector2Array([center+Vector2(-u,.2*u),center+Vector2(-u*.2,-u),center+Vector2(u,.2*u)]),Color('#737a6a'))
			draw_colored_polygon(PackedVector2Array([center+Vector2(-u*.2,-u),center+Vector2(u,.2*u),center+Vector2(.2*u,.1*u)]),Color('#a5a28a'))
			if type=='mine':draw_colored_polygon(PackedVector2Array([center+Vector2(0,-u*.6),center+Vector2(u*.45,-u*.05),center+Vector2(0,u*.3),center+Vector2(-u*.3,0)]),Color('#a3dfe8'))
		'fort','citadel','capital':
			var big:=1.25 if type in ['citadel','capital'] else 1.0
			u*=big
			draw_colored_polygon(_diamond(center+Vector2(0,u*.2),u*2.7),shadow)
			var base:=center-Vector2(0,u*.25)
			draw_rect(Rect2(base-Vector2(u*.85,u*.5),Vector2(u*1.7,u*.8)),Color('#ddd6ac'))
			draw_rect(Rect2(base+Vector2(u*.3,-u*.5),Vector2(u*.55,u*.8)),Color('#a39d7d'))
			for i in 3:
				var p:=base+Vector2((i-1)*u*.8,-u*.65)
				draw_rect(Rect2(p-Vector2(u*.2,u*.35),Vector2(u*.4,u*.8)),Color('#ede1b9'))
				draw_colored_polygon(PackedVector2Array([p+Vector2(-u*.34,-u*.35),p-Vector2(0,u*.7),p+Vector2(u*.34,-u*.35)]),Color('#456873') if type=='capital' else Color('#8b554b'))
			draw_rect(Rect2(base+Vector2(-u*.13,-u*.15),Vector2(u*.26,u*.44)),Color('#4a4d40'))
			draw_line(base-Vector2(0,u),base-Vector2(0,u*1.65),Color('#f4e5b7'),1.5,true)
			draw_colored_polygon(PackedVector2Array([base-Vector2(0,u*1.65),base+Vector2(u*.6,-u*1.45),base-Vector2(0,u*1.25)]),banner)
		'ruins':
			draw_colored_polygon(_diamond(center,u*2.2),Color('#b2aa8d'))
			for i in 3:draw_rect(Rect2(center+Vector2((i-1)*u*.7,-u*(.65 if i==1 else .9)),Vector2(u*.25,u*.9)),Color('#e0d7b7'))

func _gui_input(event: InputEvent) -> void:
	if world_state==null:return
	if event is InputEventMagnifyGesture:
		set_zoom(zoom*event.factor,event.position);accept_event();return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		set_zoom(zoom*(1.25 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .8),event.position);accept_event();return
	if event is InputEventScreenTouch:
		if event.canceled:
			_reset_gesture();accept_event();return
		if event.pressed:
			_touches[event.index]=event.position
			if _touches.size()>=2:
				_multi_touch=true;_pointer=-1
				var values:=_touches.values();_pinch_distance=values[0].distance_to(values[1])
			else:_pointer_event(true,event.position,event.index)
		else:
			_touches.erase(event.index)
			if _multi_touch:
				if _touches.is_empty():_multi_touch=false;_pointer=-1
				elif _touches.size()>=2:
					var values:=_touches.values();_pinch_distance=values[0].distance_to(values[1])
			else:_pointer_event(false,event.position,event.index)
		accept_event();return
	if event is InputEventScreenDrag:
		if not _touches.has(event.index):return
		_touches[event.index]=event.position
		if _multi_touch and _touches.size()>=2:
			var values:=_touches.values();var distance: float=values[0].distance_to(values[1])
			if _pinch_distance>1:set_zoom(zoom*distance/_pinch_distance,(values[0]+values[1])*.5)
			_pinch_distance=distance
		elif not _multi_touch and _pointer==event.index:_drag(event.relative)
		accept_event();return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:_pointer_event(event.pressed,event.position,-2)
	elif event is InputEventMouseMotion and _pointer==-2:_drag(event.relative)
func _pointer_event(pressed: bool, point: Vector2, pointer_id: int) -> void:
	if pressed:
		if _pointer!=-1:return
		_pointer=pointer_id;_pointer_start=point;_drag_distance=0
	elif _pointer==pointer_id:
		_pointer=-1
		if _drag_distance<DRAG_THRESHOLD and point.distance_to(_pointer_start)<DRAG_THRESHOLD:
			var cell:=cell_at_point(point)
			if world_state.in_bounds(cell):selected_cell=cell;queue_redraw();tile_selected.emit(cell)
	accept_event()
func _drag(offset: Vector2) -> void:
	_drag_distance+=offset.length()
	if _drag_distance>=DRAG_THRESHOLD:pan_by(offset)
	accept_event()
