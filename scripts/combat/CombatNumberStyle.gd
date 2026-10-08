extends RefCounted
## Exact amounts and a bundled numeral face shared by hunt and raid.
const FONT = preload('res://assets/fonts/combat/outfit/Outfit-ExtraBold.ttf')
const PALETTES := {
	'damage': [Color('#d8d5cc'), Color('#d8d5cc')],
	'critical': [Color('#ffd700'), Color('#ffd700')],
	'incoming': [Color('#fff1ea'), Color('#ff777b')],
	'heal': [Color('#effff5'), Color('#72eac3')],
}
static func digits(amount: int) -> String:
	var raw := str(maxi(0, amount)); var result := ''
	for i in raw.length():
		if i > 0 and (raw.length() - i) % 3 == 0: result += ','
		result += raw[i]
	return result
static func parse(message: String) -> Dictionary:
	var raw := message.strip_edges()
	var critical := raw.begins_with('치명! ')
	if critical: raw = raw.trim_prefix('치명! ')
	var incoming := raw.ends_with(' HP')
	raw = raw.trim_suffix(' HP')
	if raw.length() < 2 or raw[0] not in ['-', '+']: return {}
	var number := raw.substr(1)
	if not number.is_valid_int(): return {}
	var kind := 'heal' if raw[0] == '+' else ('incoming' if incoming else 'critical' if critical else 'damage')
	return {'amount':maxi(0, int(number)), 'kind':kind, 'critical':critical}
static func caption(amount: int, kind: String) -> String:
	return ('+' if kind == 'heal' else '-' if kind == 'incoming' else '') + digits(amount)
static func font_size(kind: String) -> int:
	return 16
static func extent(message: String, kind: String) -> Vector2:
	return Vector2(maxf(30, FONT.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size(kind)).x + 14), 32 if kind == 'critical' else 26)
static func priority(kind: String) -> int:
	return 3 if kind == 'critical' else 2 if kind == 'heal' else 1 if kind == 'incoming' else 0
