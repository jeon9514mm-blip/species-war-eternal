extends Node2D
## v76 presentation-only raid mechanic renderer.
## Gameplay ownership remains in Main.gd; this node observes state transitions and
## turns them into readable shield/crystal/eclipse/enrage/finish presentation.
var game: Node
var accent := Color.WHITE
var clock := 0.0
var previous_guard_hp := 0
var previous_add_hp := 0
var previous_dps_active := false
var previous_dps_passes := 0
var previous_dps_fails := 0
var previous_enraged := false
var guard_spawn_remaining := 0.0
var guard_break_remaining := 0.0
var crystal_spawn_remaining := 0.0
var crystal_break_remaining := 0.0
var eclipse_resolve_remaining := 0.0
var eclipse_failed := false
var enrage_burst_remaining := 0.0
var victory_burst_remaining := 0.0

func _ready() -> void:
	z_index = 4

func bind(main: Node, next_accent: Color) -> void:
	game = main
	accent = next_accent
	previous_guard_hp = int(game.raid_guard_hp) if is_instance_valid(game) else 0
	previous_add_hp = int(game.raid_add_hp) if is_instance_valid(game) else 0
	previous_dps_active = bool(is_instance_valid(game) and float(game.raid_dps_check_remaining) > 0.0)
	previous_dps_passes = int(game.raid_dps_checks_passed) if is_instance_valid(game) else 0
	previous_dps_fails = int(game.raid_dps_checks_failed) if is_instance_valid(game) else 0
	previous_enraged = bool(is_instance_valid(game) and game.raid_enraged)
	queue_redraw()

func play_victory_finish() -> void:
	victory_burst_remaining = 1.35
	queue_redraw()

func _transition_events() -> void:
	if not is_instance_valid(game):
		return
	var guard_hp := int(game.raid_guard_hp)
	var add_hp := int(game.raid_add_hp)
	var dps_active := float(game.raid_dps_check_remaining) > 0.0
	var passes := int(game.raid_dps_checks_passed)
	var fails := int(game.raid_dps_checks_failed)
	var enraged := bool(game.raid_enraged)
	if guard_hp > 0 and previous_guard_hp <= 0:
		guard_spawn_remaining = 0.72
	elif guard_hp <= 0 and previous_guard_hp > 0:
		guard_break_remaining = 0.92
	if add_hp > 0 and previous_add_hp <= 0:
		crystal_spawn_remaining = 0.78
	elif add_hp <= 0 and previous_add_hp > 0:
		crystal_break_remaining = 0.96
	if previous_dps_active and not dps_active:
		if passes > previous_dps_passes:
			eclipse_failed = false
			eclipse_resolve_remaining = 0.86
		elif fails > previous_dps_fails:
			eclipse_failed = true
			eclipse_resolve_remaining = 1.05
	if enraged and not previous_enraged:
		enrage_burst_remaining = 1.10
	previous_guard_hp = guard_hp
	previous_add_hp = add_hp
	previous_dps_active = dps_active
	previous_dps_passes = passes
	previous_dps_fails = fails
	previous_enraged = enraged

func _process(delta: float) -> void:
	clock += delta
	_transition_events()
	guard_spawn_remaining = maxf(0.0, guard_spawn_remaining - delta)
	guard_break_remaining = maxf(0.0, guard_break_remaining - delta)
	crystal_spawn_remaining = maxf(0.0, crystal_spawn_remaining - delta)
	crystal_break_remaining = maxf(0.0, crystal_break_remaining - delta)
	eclipse_resolve_remaining = maxf(0.0, eclipse_resolve_remaining - delta)
	enrage_burst_remaining = maxf(0.0, enrage_burst_remaining - delta)
	victory_burst_remaining = maxf(0.0, victory_burst_remaining - delta)
	if is_instance_valid(game) and (bool(game.raid_running) or _has_transient_fx()):
		queue_redraw()

func _has_transient_fx() -> bool:
	return guard_spawn_remaining > 0.0 or guard_break_remaining > 0.0 or crystal_spawn_remaining > 0.0 or crystal_break_remaining > 0.0 or eclipse_resolve_remaining > 0.0 or enrage_burst_remaining > 0.0 or victory_burst_remaining > 0.0

func _diamond(center: Vector2, radius: float, fill: Color, edge: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius * 0.72, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius * 0.72, 0),
	])
	draw_colored_polygon(points, fill)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), edge, 3.0, true)

func _radial_shards(center: Vector2, progress: float, color: Color, count: int = 12, reach: float = 92.0) -> void:
	for i in count:
		var angle := TAU * float(i) / float(count) + float(i % 3) * 0.11
		var direction := Vector2.from_angle(angle)
		var start := center + direction * (28.0 + reach * progress * 0.35)
		var finish := center + direction * (42.0 + reach * progress)
		draw_line(start, finish, Color(color, (1.0 - progress) * 0.88), 2.5 + float(i % 2), true)
		draw_circle(finish, 3.0 + float(i % 3), Color(color, (1.0 - progress) * 0.72))

func _draw_guard(center: Vector2) -> void:
	var ratio: float = clampf(float(game.raid_guard_hp) / maxf(1.0, float(game.raid_guard_max_hp)), 0.0, 1.0)
	var pulse := 1.0 + 0.035 * sin(clock * 5.6)
	var radius := 82.0 * pulse
	draw_circle(center, radius, Color(accent, 0.07 + 0.025 * sin(clock * 4.0)))
	draw_arc(center, radius, 0.0, TAU, 64, Color(accent, 0.25), 10.0, true)
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * ratio, 64, accent.lightened(0.12), 5.5, true)
	for i in 6:
		var a := TAU * float(i) / 6.0 + clock * 0.18
		draw_circle(center + Vector2(cos(a), sin(a)) * radius, 5.0, accent.lightened(0.20))
	# Cracks become visible as the barrier weakens, so shield HP is readable without UI text.
	if ratio < 0.68:
		var crack_count := 3 if ratio > 0.34 else 6
		for i in crack_count:
			var a := -1.25 + float(i) * 0.47
			var root := center + Vector2.from_angle(a) * (radius * 0.34)
			var mid := root + Vector2.from_angle(a + (0.20 if i % 2 == 0 else -0.18)) * 22.0
			var tip := mid + Vector2.from_angle(a - 0.12) * (18.0 + 8.0 * (1.0 - ratio))
			draw_polyline(PackedVector2Array([root, mid, tip]), Color('#fff1bfcc'), 2.2, true)
	if guard_spawn_remaining > 0.0:
		var t := 1.0 - guard_spawn_remaining / 0.72
		draw_arc(center, 38.0 + 70.0 * t, 0.0, TAU, 56, Color(accent, (1.0 - t) * 0.8), 7.0, true)

func _draw_crystals(center: Vector2) -> void:
	var count: int = clampi(int(game.raid_add_count), 1, 3)
	for i in count:
		var a: float = -0.85 + 1.70 * (float(i) / maxf(1.0, float(count - 1))) if count > 1 else 0.0
		var bob := sin(clock * 4.2 + float(i) * 1.7) * 7.0
		var orbit := sin(clock * 1.4 + float(i)) * 6.0
		var crystal := center + Vector2(cos(a) * (105.0 + orbit), sin(a) * 58.0 - 6.0 + bob)
		draw_line(crystal, center, Color(accent, 0.16 + 0.08 * sin(clock * 3.0 + i)), 2.0, true)
		var glow := 20.0 + 4.0 * sin(clock * 5.0 + i)
		draw_circle(crystal, glow, Color(accent, 0.055))
		_diamond(crystal, 17.0, Color(accent, 0.58), accent.lightened(0.22))
	var ratio: float = clampf(float(game.raid_add_hp) / maxf(1.0, float(game.raid_add_max_hp)), 0.0, 1.0)
	draw_rect(Rect2(center + Vector2(-72, 88), Vector2(144, 7)), Color('#111a28cc'), true)
	draw_rect(Rect2(center + Vector2(-72, 88), Vector2(144.0 * ratio, 7)), accent.lightened(0.08), true)
	if crystal_spawn_remaining > 0.0:
		var t := 1.0 - crystal_spawn_remaining / 0.78
		for i in count:
			var a := TAU * float(i) / float(count) + 0.25
			var point := center + Vector2.from_angle(a) * (32.0 + t * 92.0)
			draw_line(center, point, Color(accent, (1.0 - t) * 0.72), 4.0, true)

func _draw_eclipse(center: Vector2) -> void:
	var progress: float = clampf(float(game.raid_dps_check_damage) / maxf(1.0, float(game.raid_dps_check_target)), 0.0, 1.0)
	var mechanic: Dictionary = game._raid_mechanic_profile()
	var duration: float = maxf(0.1, float(mechanic.get('duration', 8.0)))
	var time_ratio: float = clampf(float(game.raid_dps_check_remaining) / duration, 0.0, 1.0)
	var throb := 1.0 + 0.025 * sin(clock * 6.5)
	draw_circle(center, 176.0, Color(Color('#1c0b2e'), 0.12 + 0.035 * sin(clock * 3.0)))
	draw_circle(center + Vector2(10, -8), 63.0 * throb, Color('#130b20e8'))
	draw_circle(center + Vector2(29, -21), 53.0 * throb, Color('#b35b8f55'))
	draw_arc(center, 92.0, 0.0, TAU, 64, Color(accent, 0.22), 8.0, true)
	draw_arc(center, 92.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, accent.lightened(0.18), 5.0, true)
	draw_arc(center, 103.0, -PI * 0.5, -PI * 0.5 + TAU * time_ratio, 64, Color('#ff6a87'), 3.5, true)
	for i in 8:
		var a := clock * 0.55 + TAU * float(i) / 8.0
		var p := center + Vector2(cos(a) * 118.0, sin(a) * 54.0)
		draw_circle(p, 2.5, Color('#e8b5ff88'))

func _draw() -> void:
	if not is_instance_valid(game):
		return
	if not bool(game.raid_running) and not _has_transient_fx():
		return
	var center: Vector2 = game.raid_boss_position - Vector2(0, 42)
	if bool(game.raid_enraged):
		var rage_pulse := 0.52 + 0.18 * sin(clock * 8.0)
		draw_arc(center, 106.0 + 8.0 * sin(clock * 5.0), 0.0, TAU, 72, Color(Color('#ff4b62'), rage_pulse), 5.0, true)
		for i in 10:
			var a := -PI * 0.92 + float(i) * 0.21 + sin(clock * 2.0 + i) * 0.04
			var base := center + Vector2.from_angle(a) * 74.0
			draw_line(base, base + Vector2.from_angle(a) * (20.0 + 12.0 * sin(clock * 4.0 + i)), Color('#ff765fcc'), 3.0, true)
	if int(game.raid_guard_hp) > 0 and int(game.raid_guard_max_hp) > 0:
		_draw_guard(center)
	elif int(game.raid_add_hp) > 0 and int(game.raid_add_count) > 0:
		_draw_crystals(center)
	elif float(game.raid_dps_check_remaining) > 0.0 and int(game.raid_dps_check_target) > 0:
		_draw_eclipse(center)
	if guard_break_remaining > 0.0:
		var p := 1.0 - guard_break_remaining / 0.92
		draw_arc(center, 76.0 + p * 92.0, 0.0, TAU, 64, Color(Color('#ffe3a8'), (1.0 - p) * 0.90), 7.0, true)
		_radial_shards(center, p, Color('#ffd783'), 16, 112.0)
	if crystal_break_remaining > 0.0:
		var p := 1.0 - crystal_break_remaining / 0.96
		_radial_shards(center, p, Color('#ffb56d'), 18, 128.0)
		for i in 5:
			var a := TAU * float(i) / 5.0 + 0.4
			_diamond(center + Vector2.from_angle(a) * (38.0 + p * 96.0), 9.0 * (1.0 - p * 0.55), Color('#f0a15c99'), Color('#ffd4a8cc'))
	if eclipse_resolve_remaining > 0.0:
		var duration := 1.05 if eclipse_failed else 0.86
		var p := 1.0 - eclipse_resolve_remaining / duration
		var color := Color('#ff4d6f') if eclipse_failed else Color('#d6b7ff')
		draw_arc(center, 72.0 + p * 118.0, 0.0, TAU, 72, Color(color, (1.0 - p) * 0.85), 8.0 if eclipse_failed else 5.0, true)
		if eclipse_failed:
			draw_circle(center, 55.0 + p * 36.0, Color(Color('#6a102d'), (1.0 - p) * 0.32))
	if enrage_burst_remaining > 0.0:
		var p := 1.0 - enrage_burst_remaining / 1.10
		draw_arc(center, 52.0 + p * 150.0, 0.0, TAU, 72, Color(Color('#ff4a5f'), (1.0 - p) * 0.92), 9.0, true)
		_radial_shards(center, p, Color('#ff775f'), 14, 138.0)
	if victory_burst_remaining > 0.0:
		var p := 1.0 - victory_burst_remaining / 1.35
		for ring in 3:
			var local_p := clampf(p - float(ring) * 0.12, 0.0, 1.0)
			draw_arc(center, 38.0 + local_p * (145.0 + ring * 24.0), 0.0, TAU, 80, Color(Color('#ffe0a0'), (1.0 - local_p) * (0.92 - ring * 0.18)), 7.0 - ring, true)
		_radial_shards(center, clampf(p * 1.08, 0.0, 1.0), Color('#fff0bd'), 20, 164.0)
