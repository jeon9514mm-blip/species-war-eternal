extends RefCounted
## Original timbre/haptic identity only. Never a combat element or RNG source.
const HEROES := {
	"leonhardt": {"ordinal": 0, "signature": 3501576342, "base_hz": 121.63, "theme": "light"},
	"mira": {"ordinal": 1, "signature": 1010346747, "base_hz": 197.86, "theme": "ice"},
	"elisia": {"ordinal": 2, "signature": 761283435, "base_hz": 334.59, "theme": "light"},
	"kairen": {"ordinal": 3, "signature": 1403562602, "base_hz": 214.8, "theme": "light"},
	"orwin": {"ordinal": 4, "signature": 1411044659, "base_hz": 281.35, "theme": "light"},
	"seria": {"ordinal": 5, "signature": 2083036972, "base_hz": 231.74, "theme": "ice"},
	"astel": {"ordinal": 6, "signature": 2469312143, "base_hz": 294.66, "theme": "light"},
	"darius": {"ordinal": 7, "signature": 642851462, "base_hz": 203.91, "theme": "fire"},
	"lunea": {"ordinal": 8, "signature": 3487209410, "base_hz": 208.75, "theme": "ice"},
	"caelum": {"ordinal": 9, "signature": 1348043853, "base_hz": 289.82, "theme": "fire"},
	"valeria": {"ordinal": 10, "signature": 2713899094, "base_hz": 332.17, "theme": "fire"},
	"morgas": {"ordinal": 11, "signature": 41700798, "base_hz": 298.29, "theme": "dark"},
	"ragna": {"ordinal": 12, "signature": 2447141078, "base_hz": 201.49, "theme": "dark"},
	"bron": {"ordinal": 13, "signature": 2865124420, "base_hz": 154.3, "theme": "fire"},
	"nyx": {"ordinal": 14, "signature": 2732285844, "base_hz": 266.83, "theme": "dark"},
	"fenris": {"ordinal": 15, "signature": 1132561256, "base_hz": 260.78, "theme": "ice"},
	"isolde": {"ordinal": 16, "signature": 2159542038, "base_hz": 127.68, "theme": "light"},
	"garm": {"ordinal": 17, "signature": 2003221945, "base_hz": 343.06, "theme": "fire"},
	"veyra": {"ordinal": 18, "signature": 2504869242, "base_hz": 268.04, "theme": "dark"},
	"ulric": {"ordinal": 19, "signature": 2425986424, "base_hz": 251.1, "theme": "dark"},
	"adrien": {"ordinal": 20, "signature": 1375475596, "base_hz": 278.93, "theme": "ice"},
	"tessa": {"ordinal": 21, "signature": 4278026292, "base_hz": 252.31, "theme": "fire"},
	"naia": {"ordinal": 22, "signature": 2425447961, "base_hz": 288.61, "theme": "light"},
	"sael": {"ordinal": 23, "signature": 3634139534, "base_hz": 288.61, "theme": "light"},
	"odelia": {"ordinal": 24, "signature": 3928018177, "base_hz": 312.81, "theme": "dark"},
	"lucien": {"ordinal": 25, "signature": 784666253, "base_hz": 237.79, "theme": "fire"},
	"corvin": {"ordinal": 26, "signature": 2570856915, "base_hz": 351.53, "theme": "dark"},
	"rokan": {"ordinal": 27, "signature": 1515680631, "base_hz": 258.36, "theme": "ice"},
	"bora": {"ordinal": 28, "signature": 1219476969, "base_hz": 351.53, "theme": "ice"},
	"selene": {"ordinal": 29, "signature": 2298549352, "base_hz": 179.71, "theme": "light"},
}
const SLOTS := {'passive':0, 'a1':1, 'a2':2, 'ultimate':3}
const PREFIX := 'hero_skill:'

static func profile(hero_id: String, slot: String) -> Dictionary:
	if not HEROES.has(hero_id) or not SLOTS.has(slot): return {}
	var hero: Dictionary = HEROES[hero_id]
	var index: int = int(SLOTS[slot])
	var ordinal: int = int(hero.ordinal)
	var strength := .22 + float(ordinal) * .004 + float(index) * .09
	var first := [0, 12 + ordinal % 19 + index * 3, strength]
	var pattern: Array = [first]
	if index > 0: pattern.append([55 + ordinal % 7 * 6, 10 + ordinal % 13 + index * 3, strength * .68])
	if index == 3: pattern.append([145 + ordinal % 5 * 9, 24 + ordinal % 17, minf(.75, strength + .1)])
	return {'event':PREFIX + hero_id + ':' + slot, 'path':'res://audio/ultra-skills/' + hero_id + '__' + slot + '.wav',
		'priority':5 if slot == 'ultimate' else 2 if slot == 'passive' else 4,
		'cooldown':.7 if slot == 'ultimate' else .8 if slot == 'passive' else .24,
		'hero_id':hero_id, 'slot':slot, 'theme':'ice' if hero_id == 'tessa' and slot == 'a2' else hero.theme, 'haptic':pattern}

static func event_spec(event: String) -> Array:
	if not event.begins_with(PREFIX): return []
	var parts := event.trim_prefix(PREFIX).split(':')
	if parts.size() != 2: return []
	var feedback := profile(parts[0], parts[1])
	if feedback.is_empty(): return []
	return [feedback.path, 'effects', feedback.priority, feedback.cooldown]
