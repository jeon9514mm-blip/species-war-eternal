extends Node
## Ultra pack's 40-label pool, adapted to the actual camera-projected HUD.
## Every reuse resets opacity and stops old tweens; no gameplay RNG is touched.
const LABEL=preload('res://scripts/portrait/PortraitDamageNumber.gd')
const CAPACITY=40
var pool: Array[Label]=[]
func spawn_damage(message: String,tint: Color,origin: Vector2,critical: bool,lane: int) -> Label:
	for i in range(pool.size()-1,-1,-1):
		if not is_instance_valid(pool[i]):pool.remove_at(i)
	var label: Label
	for candidate in pool:
		if not candidate.visible:label=candidate;break
	if label==null:
		if pool.size()>=CAPACITY:return null
		label=LABEL.new();label.pooled=true;add_child(label);pool.append(label)
	label.show_value(message,tint,origin,critical,lane)
	return label
