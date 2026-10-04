class_name CombatFxDirector
extends RefCounted

const FLASH_META := &"combat_hit_flash"
const CAMERA_META := &"combat_camera_impact"

var host: Control
var layer: Control
var battlefield_ref: WeakRef
var enabled := true
var optional_node_limit: int = 96
var active_projectiles := 0
var active_indicators := 0
var impact_sequence := 0
var projectile_sequence := 0
var aoe_sequence := 0
var boss_telegraph_sequence := 0
var dodge_sequence := 0
var camera_sequence := 0
var hit_spark_sequence := 0
var death_burst_sequence := 0
var loot_burst_sequence := 0
var boss_arrival_sequence := 0

func bind(next_host: Control, next_layer: Control) -> void:
	_restore_camera(host)
	battlefield_ref = null
	host = next_host
	layer = next_layer
	active_projectiles = 0
	active_indicators = 0

func _valid() -> bool:
	return enabled and is_instance_valid(host) and is_instance_valid(layer)

func _circle_style(fill: Color, border: Color, width := 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_left = 999
	style.corner_radius_bottom_right = 999
	style.corner_detail = 4
	style.anti_aliasing = false
	return style

func projectile(start: Vector2, finish: Vector2, color: Color, symbol := "◆", duration := 0.22, heavy := false) -> void:
	if not _fx_budget_available(2):
		return
	active_projectiles += 1
	projectile_sequence += 1
	var core := Panel.new()
	core.name = "CombatProjectile"
	var diameter := 18.0 if heavy else 12.0
	core.size = Vector2(diameter, diameter)
	core.position = start - core.size * 0.5
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	core.z_index = 70
	core.add_theme_stylebox_override("panel", _circle_style(Color(color, 0.95), Color.WHITE, 1))
	layer.add_child(core)
	var glyph := Label.new()
	glyph.text = symbol
	glyph.position = Vector2(-7, -9)
	glyph.size = Vector2(diameter + 14, diameter + 14)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 13 if not heavy else 17)
	glyph.add_theme_color_override("font_color", Color.WHITE)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	core.add_child(glyph)
	var trail := Line2D.new()
	trail.name = "ProjectileTrail"
	trail.width = 3.0 if heavy else 2.0
	trail.default_color = Color(color, 0.55)
	trail.points = PackedVector2Array([start, start])
	trail.z_index = 69
	layer.add_child(trail)
	var midpoint := (start + finish) * 0.5 + Vector2(0, -34.0 if heavy else -20.0)
	var tween := host.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(t: float):
		if not is_instance_valid(core) or not is_instance_valid(trail):
			return
		var a := start.lerp(midpoint, t)
		core.position = (a - core.size * 0.5).round()
		trail.points = PackedVector2Array([start, a])
	, 0.0, 1.0, maxf(0.05, duration * 0.45))
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(func(t: float):
		if not is_instance_valid(core) or not is_instance_valid(trail):
			return
		var b := midpoint.lerp(finish, t)
		core.position = (b - core.size * 0.5).round()
		trail.points = PackedVector2Array([start.lerp(finish, t * 0.55), b])
	, 0.0, 1.0, maxf(0.05, duration * 0.55))
	tween.tween_callback(func():
		impact(finish, color, 30.0 if heavy else 20.0)
		if is_instance_valid(core): core.queue_free()
		if is_instance_valid(trail): trail.queue_free()
		active_projectiles = maxi(0, active_projectiles - 1)
	)

func aoe_indicator(center: Vector2, radius: float, color: Color, duration := 0.42, danger := false, label_text := "") -> void:
	if not _valid():
		return
	active_indicators += 1
	aoe_sequence += 1
	var ring := Panel.new()
	ring.name = "CombatAoeIndicator"
	ring.size = Vector2(radius * 2.0, radius * 2.0)
	ring.position = center - Vector2(radius, radius)
	ring.pivot_offset = Vector2(radius, radius)
	ring.scale = Vector2(0.58, 0.58)
	ring.modulate = Color(1, 1, 1, 0.15)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.z_index = 58
	var fill_alpha := 0.16 if danger else 0.09
	ring.add_theme_stylebox_override("panel", _circle_style(Color(color, fill_alpha), Color(color, 0.92), 3 if danger else 2))
	layer.add_child(ring)
	if not label_text.is_empty():
		var text := Label.new()
		text.text = label_text
		text.position = Vector2(0, radius - 13)
		text.size = Vector2(radius * 2.0, 26)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.add_theme_font_size_override("font_size", 12)
		text.add_theme_color_override("font_color", color)
		text.add_theme_color_override("font_shadow_color", Color.BLACK)
		text.add_theme_constant_override("shadow_offset_x", 1)
		text.add_theme_constant_override("shadow_offset_y", 1)
		ring.add_child(text)
	var tween := host.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE, duration * 0.62).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate", Color.WHITE, 0.08)
	tween.chain().tween_property(ring, "modulate:a", 0.0, duration * 0.38)
	tween.chain().tween_callback(func():
		if is_instance_valid(ring): ring.queue_free()
		active_indicators = maxi(0, active_indicators - 1)
	)

func boss_telegraph(center: Vector2, radius: float, color: Color, seconds: float, skill_name: String) -> void:
	if not _valid():
		return
	active_indicators += 1
	boss_telegraph_sequence += 1
	var ring := Panel.new()
	ring.name = "BossRangeTelegraph"
	ring.size = Vector2(radius * 2.0, radius * 2.0)
	ring.position = center - Vector2(radius, radius)
	ring.pivot_offset = Vector2(radius, radius)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.z_index = 61
	ring.add_theme_stylebox_override("panel", _circle_style(Color(color, 0.18), Color(color, 0.95), 4))
	layer.add_child(ring)
	var label := Label.new()
	label.text = "⚠ %s" % skill_name
	label.position = Vector2(0, radius - 16)
	label.size = Vector2(radius * 2.0, 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("#fff0dc"))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	ring.add_child(label)
	var pulse := host.create_tween()
	pulse.set_loops(maxi(1, int(ceil(seconds / 0.24))))
	pulse.tween_property(ring, "scale", Vector2(1.05, 1.05), 0.12)
	pulse.tween_property(ring, "scale", Vector2(0.96, 0.96), 0.12)
	var life := host.create_tween()
	life.tween_interval(maxf(0.2, seconds))
	life.tween_property(ring, "modulate:a", 0.0, 0.12)
	life.tween_callback(func():
		if is_instance_valid(pulse): pulse.kill()
		if is_instance_valid(ring): ring.queue_free()
		active_indicators = maxi(0, active_indicators - 1)
	)

func impact(position: Vector2, color: Color, radius := 24.0) -> void:
	if not _fx_budget_available():
		return
	impact_sequence += 1
	var burst := Panel.new()
	burst.name = "CombatImpact"
	burst.size = Vector2(radius * 2.0, radius * 2.0)
	burst.position = position - Vector2(radius, radius)
	burst.pivot_offset = Vector2(radius, radius)
	burst.scale = Vector2(0.25, 0.25)
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.z_index = 72
	burst.add_theme_stylebox_override("panel", _circle_style(Color(color, 0.20), Color(color, 0.95), 2))
	layer.add_child(burst)
	var tween := host.create_tween().set_parallel(true)
	tween.tween_property(burst, "scale", Vector2(1.35, 1.35), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "modulate:a", 0.0, 0.24)
	tween.chain().tween_callback(burst.queue_free)

func hit_flash(target: CanvasItem, color: Color = Color.WHITE) -> void:
	if not _valid() or not is_instance_valid(target):
		return
	# Repeated hits restore the actor's pre-flash tint, never an intermediate
	# color from another flash. Binding the tween to the actor also cancels it
	# when that actor is removed before the effect finishes.
	var previous: Dictionary = target.get_meta(FLASH_META, {})
	var original: Color = previous.get("original", target.modulate)
	var previous_tween: Tween = previous.get("tween") as Tween
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
	var flash := Color(color.r * 1.2, color.g * 1.2, color.b * 1.2, target.modulate.a)
	target.modulate = flash
	var tween := target.create_tween()
	target.set_meta(FLASH_META, {"original": original, "tween": tween})
	var target_ref: WeakRef = weakref(target)
	tween.tween_method(func(value: Color):
		var actor := target_ref.get_ref() as CanvasItem
		if is_instance_valid(actor):
			# Death fades and spawn effects own alpha throughout this RGB flash.
			actor.modulate = Color(value.r, value.g, value.b, actor.modulate.a)
	, flash, original, 0.13)
	tween.tween_callback(func():
		var actor := target_ref.get_ref() as CanvasItem
		if is_instance_valid(actor):
			actor.modulate = Color(original.r, original.g, original.b, actor.modulate.a)
			actor.remove_meta(FLASH_META)
	)

func dodge(position: Vector2, color: Color = Color("#9fe5ff")) -> void:
	if not _valid():
		return
	dodge_sequence += 1
	var ghost := Label.new()
	ghost.name = "CombatDodgeText"
	ghost.text = "회피"
	ghost.position = position - Vector2(48, 42)
	ghost.size = Vector2(96, 28)
	ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost.add_theme_font_size_override("font_size", 16)
	ghost.add_theme_color_override("font_color", color)
	ghost.add_theme_color_override("font_shadow_color", Color.BLACK)
	ghost.add_theme_constant_override("shadow_offset_x", 2)
	ghost.add_theme_constant_override("shadow_offset_y", 2)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 75
	layer.add_child(ghost)
	var tween := host.create_tween().set_parallel(true)
	tween.tween_property(ghost, "position", ghost.position + Vector2(22, -30), 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "modulate:a", 0.0, 0.40).set_delay(0.10)
	tween.chain().tween_callback(ghost.queue_free)

func _fx_budget_available(extra_nodes: int = 1) -> bool:
	if not _valid(): return false
	var clip: Node = layer.get_node_or_null("HeroSkillClip")
	var nested: int = clip.get_child_count() if clip != null else 0
	return layer.get_child_count() + nested + maxi(1, extra_nodes) <= optional_node_limit

func _spawn_spark_shard(origin: Vector2, direction: Vector2, color: Color, length: float, duration: float, thickness: float = 3.0, z := 76) -> void:
	if not _fx_budget_available():
		return
	var shard := ColorRect.new()
	shard.name = "CombatSparkShard"
	shard.color = Color(color, 0.95)
	shard.size = Vector2(maxf(4.0, length), maxf(2.0, thickness))
	shard.position = origin - Vector2(shard.size.x * 0.15, shard.size.y * 0.5)
	shard.pivot_offset = Vector2(shard.size.x * 0.15, shard.size.y * 0.5)
	shard.rotation = direction.angle()
	shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shard.z_index = z
	layer.add_child(shard)
	var travel := direction.normalized() * (22.0 + length * 0.55)
	var tween := host.create_tween().set_parallel(true)
	tween.tween_property(shard, "position", shard.position + travel, maxf(0.10, duration)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(shard, "modulate:a", 0.0, maxf(0.10, duration)).set_delay(duration * 0.18)
	tween.tween_property(shard, "scale", Vector2(0.55, 0.55), maxf(0.10, duration))
	tween.chain().tween_callback(shard.queue_free)

func hit_spark(position: Vector2, color: Color, critical := false, heavy := false) -> void:
	if not _fx_budget_available(4):
		return
	hit_spark_sequence += 1
	var shard_count := 8 if critical or heavy else 4
	var base_length := 24.0 if critical else (20.0 if heavy else 13.0)
	for index in shard_count:
		var angle := TAU * float(index) / float(shard_count) + (0.18 if index % 2 == 0 else -0.08)
		var direction := Vector2.from_angle(angle)
		_spawn_spark_shard(position, direction, Color.WHITE if index % 3 == 0 else color, base_length + float(index % 3) * 3.0, 0.22 if critical else 0.17, 4.0 if critical else 3.0)
	impact(position, color, 25.0 if critical or heavy else 15.0)

func death_burst(position: Vector2, color: Color, elite := false) -> void:
	if not _fx_budget_available(8):
		return
	death_burst_sequence += 1
	impact(position, color, 34.0 if elite else 25.0)
	var shard_count := 12 if elite else 8
	for index in shard_count:
		var angle := TAU * float(index) / float(shard_count) - PI * 0.5
		var direction := Vector2.from_angle(angle)
		_spawn_spark_shard(position, direction, Color.WHITE if index % 4 == 0 else color, 20.0 + float(index % 4) * 4.0, 0.34 if elite else 0.27, 3.0, 77)
	var sigil := Label.new()
	sigil.name = "CombatDeathSigil"
	sigil.text = "✦" if not elite else "✦  ELITE  ✦"
	sigil.position = position - Vector2(70, 38)
	sigil.size = Vector2(140, 38)
	sigil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sigil.add_theme_font_size_override("font_size", 20 if not elite else 17)
	sigil.add_theme_color_override("font_color", color)
	sigil.add_theme_color_override("font_outline_color", Color("#171b22"))
	sigil.add_theme_constant_override("outline_size", 4)
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sigil.z_index = 79
	layer.add_child(sigil)
	var tween := host.create_tween().set_parallel(true)
	tween.tween_property(sigil, "position", sigil.position + Vector2(0, -28), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sigil, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sigil, "modulate:a", 0.0, 0.30).set_delay(0.16)
	tween.chain().tween_callback(sigil.queue_free)

func loot_burst(position: Vector2, gold: int, xp: int, drops: int, stage_clear := false) -> void:
	if not _fx_budget_available(4):
		return
	loot_burst_sequence += 1
	var entries: Array[Dictionary] = []
	if gold > 0:
		entries.append({"text":"●  골드 +%d" % gold, "color":Color("#f2c96b")})
	if xp > 0:
		entries.append({"text":"✦  경험치 +%d" % xp, "color":Color("#8fd9b0")})
	if drops > 0:
		entries.append({"text":"◆  장비 +%d" % drops, "color":Color("#8fc8f2")})
	if stage_clear:
		entries.append({"text":"▣  STAGE CLEAR", "color":Color("#fff0a8")})
	for index in mini(entries.size(), 4):
		var entry: Dictionary = entries[index]
		var label := Label.new()
		label.name = "CombatLootBurst"
		label.text = str(entry["text"])
		label.position = position + Vector2(-105, -20 + index * 23)
		label.size = Vector2(210, 30)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18 if not stage_clear else 19)
		var entry_color: Color = entry["color"]
		label.add_theme_color_override("font_color", entry_color)
		label.add_theme_color_override("font_outline_color", Color("#171b22"))
		label.add_theme_constant_override("outline_size", 4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 82
		layer.add_child(label)
		var tween := host.create_tween().set_parallel(true)
		tween.tween_property(label, "position", label.position + Vector2(0, -46 - index * 4), 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "modulate:a", 0.0, 0.34).set_delay(0.32 + index * 0.04)
		tween.chain().tween_callback(label.queue_free)

func boss_arrival(position: Vector2, color: Color) -> void:
	if not _fx_budget_available(12):
		return
	boss_arrival_sequence += 1
	for radius in [42.0, 78.0, 122.0]:
		impact(position, color, radius)
	for index in 16:
		var angle := TAU * float(index) / 16.0
		_spawn_spark_shard(position, Vector2.from_angle(angle), Color.WHITE if index % 5 == 0 else color, 30.0 + float(index % 4) * 7.0, 0.42, 4.0, 80)

func _restore_camera(target: Control) -> void:
	if not is_instance_valid(target) or not target.has_meta(CAMERA_META):
		return
	var previous: Dictionary = target.get_meta(CAMERA_META)
	var tween: Tween = previous.get("tween") as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	target.position = previous["position"]
	target.scale = previous["scale"]
	target.pivot_offset = previous["pivot"]
	target.remove_meta(CAMERA_META)

func camera_impact(intensity := 5.0, duration := 0.16, zoom := 0.012) -> void:
	if not _valid():
		return
	camera_sequence += 1
	var battlefield = battlefield_ref.get_ref() if battlefield_ref != null else null
	if is_instance_valid(battlefield) and battlefield.has_method('camera_impact'):
		battlefield.camera_impact(intensity,duration,zoom)
		return
	# A new impact replaces the current shake from its real resting transform.
	# Otherwise rapid hits accumulate screen offset and zoom permanently.
	_restore_camera(host)
	var original_position := host.position
	var original_scale := host.scale
	var original_pivot := host.pivot_offset
	host.pivot_offset = host.size * 0.5
	var tween := host.create_tween()
	host.set_meta(CAMERA_META, {"position": original_position, "scale": original_scale,
		"pivot": original_pivot, "tween": tween})
	var step := maxf(0.025, duration / 5.0)
	tween.tween_property(host, "position", original_position + Vector2(intensity, -intensity * 0.55), step)
	tween.parallel().tween_property(host, "scale", original_scale + Vector2(zoom, zoom), step)
	tween.tween_property(host, "position", original_position + Vector2(-intensity * 0.72, intensity * 0.45), step)
	tween.tween_property(host, "position", original_position + Vector2(intensity * 0.35, intensity * 0.18), step)
	tween.tween_property(host, "position", original_position, step)
	tween.parallel().tween_property(host, "scale", original_scale, step)
	var host_ref: WeakRef = weakref(host)
	tween.tween_callback(func():
		var current_host := host_ref.get_ref() as Control
		if is_instance_valid(current_host):
			current_host.position = original_position
			current_host.scale = original_scale
			current_host.pivot_offset = original_pivot
			current_host.remove_meta(CAMERA_META)
	)

# Hero-specific short signatures share the existing effect layer and settings.
func hero_skill(game: Control, hero_id: String, slot: String, start: Vector2, points: Array[Dictionary], profile: Dictionary, bounds: Rect2) -> void:
	if not _fx_budget_available() or not bool(game.combat_effects_enabled):
		return
	var clip := layer.get_node_or_null("HeroSkillClip") as Control
	if clip == null:
		clip = Control.new()
		clip.name = "HeroSkillClip"
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.clip_contents = true
		clip.z_index = 73
		layer.add_child(clip)
	clip.position = bounds.position
	clip.size = bounds.size
	if clip.get_child_count() >= 32:
		return
	var signature := preload("res://scripts/HeroSkillEffect.gd").new()
	signature.name = "HeroSkill_%s_%s" % [hero_id, slot]
	signature.configure(game, hero_id, slot, start, points, profile, bounds)
	signature.position = Vector2.ZERO
	clip.add_child(signature)
