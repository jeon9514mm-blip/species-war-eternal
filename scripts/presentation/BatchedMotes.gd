extends RefCounted
## Soft circular particles in one native triangle command, with cached topology.
const SEGMENTS:=12
const VERTICES:=25
var points:=PackedVector2Array()
var colors:=PackedColorArray()
var indices:=PackedInt32Array()
var _unit:=PackedVector2Array()
var _capacity:=0
var _amount:=0
func _init() -> void:
	for i in SEGMENTS:_unit.append(Vector2.from_angle(float(i)*TAU/SEGMENTS))
func begin(capacity: int) -> void:
	_amount=0
	if capacity<=_capacity:return
	_capacity=capacity;points.resize(capacity*VERTICES);colors.resize(capacity*VERTICES)
	indices.resize(capacity*SEGMENTS*9)
	for mote in capacity:
		var base:=mote*VERTICES
		for edge in SEGMENTS:
			var next: int=(edge+1)%SEGMENTS;var at:=mote*SEGMENTS*9+edge*9
			var triangles: Array[int]=[base,base+1+edge,base+1+next,base+1+edge,base+13+edge,base+13+next,base+1+edge,base+13+next,base+1+next]
			for j in 9:indices[at+j]=triangles[j]
func add(point: Vector2,radius: float,color: Color) -> void:
	if _amount>=_capacity or radius<=0:return
	var base:=_amount*VERTICES;points[base]=point;colors[base]=color
	for edge in SEGMENTS:
		points[base+1+edge]=point+_unit[edge]*radius*.8;colors[base+1+edge]=color
		points[base+13+edge]=point+_unit[edge]*radius;colors[base+13+edge]=Color(color,0)
	_amount+=1
func draw(canvas: CanvasItem) -> void:
	if _amount<=0:return
	# Submit complete active arrays. Keep unused capacity out of the native
	# command so overload and shrinking bursts have the same buffer contract.
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),indices.slice(0,_amount*SEGMENTS*9),points.slice(0,_amount*VERTICES),colors.slice(0,_amount*VERTICES))
