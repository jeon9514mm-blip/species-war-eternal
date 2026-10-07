extends RefCounted
## Uniform painting scale only. Feet, navigation, damage and telegraphs stay put.
const GAP := .035

static func fit(items: Array[Dictionary]) -> Dictionary:
	var scales: Dictionary={}
	for item in items:scales[item.id]=1.0
	for a in items.size():
		for b in range(a+1,items.size()):
			var left: Dictionary=items[a];var right: Dictionary=items[b]
			var distance: Vector2=right.point-left.point
			var lr: Rect2=left.bounds;var rr: Rect2=right.bounds
			var across: float=lr.end.x-rr.position.x if distance.x>=0 else rr.end.x-lr.position.x
			var down: float=lr.end.y-rr.position.y if distance.y>=0 else rr.end.y-lr.position.y
			var horizontal:=maxf(0,absf(distance.x)-GAP)/maxf(.001,across)
			var vertical:=maxf(0,absf(distance.y)-GAP)/maxf(.001,down)
			var allowed:=minf(1,maxf(horizontal,vertical))
			# Exact coincident feet require simulation separation. Do not disappear.
			if distance.length_squared()<.000001:allowed=.20
			scales[left.id]=minf(scales[left.id],allowed)
			scales[right.id]=minf(scales[right.id],allowed)
	# Use one crowd factor for both sides. Giving each monster its own large
	# factor while shrinking every hero to the worst pair makes heroes tiny.
	# Species/boss base heights still differ; the whole composition scales once.
	var crowd_scale:=1.0
	for item in items:crowd_scale=minf(crowd_scale,scales[item.id])
	for item in items:scales[item.id]=crowd_scale
	return scales
