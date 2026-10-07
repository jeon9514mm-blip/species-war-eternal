extends RefCounted
## Display-only fixed-step interpolation. Never writes simulation positions.
const TELEPORT_DISTANCE:=1.0
var previous: Dictionary={}
var current: Dictionary={}
var displayed: Dictionary={}
var states: Dictionary={}
var duration:=.05
var enabled:=false
var paused:=false
var resuming:=false

func capture(before: Dictionary,after: Dictionary,next_states: Dictionary,seconds: float) -> void:
	duration=maxf(.001,seconds);enabled=true
	var bridge:=paused or resuming
	previous.clear();current=after.duplicate()
	for id in after:
		var point: Vector2=after[id]
		var old: Vector2=before.get(id,point)
		if bridge:old=displayed.get(id,old)
		if not states.has(id) or states[id]!=next_states.get(id,false) or old.distance_to(point)>TELEPORT_DISTANCE:old=point
		previous[id]=old
	states=next_states.duplicate()
	paused=false;resuming=false

func sample(points: Dictionary,next_states: Dictionary,fraction: float,active: bool) -> Dictionary:
	var result: Dictionary={}
	for id in points:
		var point: Vector2=points[id]
		var changed: bool=not current.has(id) or current[id]!=point or states.get(id,false)!=next_states.get(id,false)
		if not enabled or changed:
			previous[id]=point;current[id]=point;states[id]=next_states.get(id,false)
			result[id]=point
		elif not active:
			result[id]=displayed.get(id,point)
		elif paused:
			# Bridge from the held foot; a resumed frame must not jump to its
			# simulation endpoint or replay the pre-pause path backwards.
			previous[id]=displayed.get(id,point);result[id]=previous[id];resuming=true
		else:result[id]=(previous.get(id,point) as Vector2).lerp(point,clampf(fraction,0,1))
	for id in current.keys():
		if not points.has(id):current.erase(id);previous.erase(id);states.erase(id)
	displayed=result.duplicate();paused=not active
	return result

func reset() -> void:
	previous.clear();current.clear();displayed.clear();states.clear();enabled=false;paused=false;resuming=false
