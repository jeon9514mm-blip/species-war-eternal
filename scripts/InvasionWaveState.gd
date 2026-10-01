extends RefCounted
## Game-time admission and one-shot receipts, independent of rendering/real time.
const ENTRY_INTERVAL := 4.0
const MAX_ALIVE := 25
const MAX_CORPS := 2
const REINFORCE_AT := 5
var clock := 0.0
var last_entry := -ENTRY_INTERVAL
var serial := 0
var groups: Dictionary = {}
func reset() -> void:
	clock = 0.0; last_entry = -ENTRY_INTERVAL; serial = 0; groups.clear()
func advance(delta: float) -> void:
	if is_finite(delta) and delta > 0.0: clock += delta
func next_size() -> int:
	return 15 + (serial % 6)
func can_enter(alive: int) -> bool:
	return alive <= REINFORCE_AT and alive + next_size() <= MAX_ALIVE and groups.size() < MAX_CORPS and clock - last_entry + 0.000001 >= ENTRY_INTERVAL
func register(profile: Dictionary) -> int:
	serial += 1; last_entry = clock
	groups[serial] = profile.duplicate(true)
	return serial
func take_finished(enemies: Array) -> Array:
	var finished: Array = []
	for id in groups.keys():
		var members: Array = []; var alive := false
		for enemy in enemies:
			if int(enemy.get("corps_id", -1)) == int(id):
				members.append(enemy)
				alive = alive or int(enemy.get("hp", 0)) > 0
		if not members.is_empty() and not alive:
			finished.append({"id":id,"profile":groups[id],"members":members})
			groups.erase(id) # consume before any reward/save callback can re-enter.
	return finished
