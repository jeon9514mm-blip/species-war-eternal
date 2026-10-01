extends SceneTree

var checks := 0
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _advance(seconds: float) -> void:
	for tween in get_processed_tweens():
		if tween.is_valid():
			tween.custom_step(seconds)

func _run() -> void:
	var host := Control.new()
	host.position = Vector2(100, 200)
	host.size = Vector2(600, 800)
	host.scale = Vector2(1.2, 0.8)
	host.pivot_offset = Vector2(7, 11)
	root.add_child(host)
	var layer := Control.new()
	host.add_child(layer)
	var target := Node2D.new()
	var original_tint := Color(0.8, 0.9, 0.7, 0.75)
	target.modulate = original_tint
	host.add_child(target)
	var fx := CombatFxDirector.new()
	fx.bind(host, layer)
	await process_frame
	var rest_position := host.position
	var rest_scale := host.scale
	var rest_pivot := host.pivot_offset
	for repeat in range(24):
		fx.camera_impact(10.0, 0.4, 0.1)
		fx.hit_flash(target, Color.RED if repeat % 2 == 0 else Color.BLUE)
		_advance(0.04)
	_check(host.position != rest_position, "camera effect still moves the viewport temporarily")
	_check(target.modulate != original_tint, "hit flash still changes the actor tint temporarily")
	target.modulate.a = 0.22
	_advance(1.0)
	_check(host.position.is_equal_approx(rest_position), "rapid impacts restore the original camera position")
	_check(host.scale.is_equal_approx(rest_scale), "rapid impacts restore the original camera scale")
	_check(host.pivot_offset.is_equal_approx(rest_pivot), "camera impact restores the previous pivot")
	_check(target.modulate.is_equal_approx(Color(original_tint, 0.22)), "overlapping flashes restore base RGB while preserving death fade alpha")
	_check(not host.has_meta(CombatFxDirector.CAMERA_META), "finished camera effect releases its state")
	_check(not target.has_meta(CombatFxDirector.FLASH_META), "finished hit flash releases its state")
	# A later flash captures a genuinely changed gameplay tint after the prior flash ended.
	target.modulate = Color(0.3, 0.5, 0.9, 0.4)
	fx.hit_flash(target)
	_advance(1.0)
	_check(target.modulate.is_equal_approx(Color(0.3, 0.5, 0.9, 0.4)), "later flashes respect new base tints")
	var second_target := Node2D.new()
	second_target.modulate = Color(0.2, 0.4, 0.6, 0.8)
	host.add_child(second_target)
	fx.hit_flash(target, Color.RED)
	fx.hit_flash(second_target, Color.BLUE)
	_advance(1.0)
	_check(target.modulate.is_equal_approx(Color(0.3, 0.5, 0.9, 0.4)) and second_target.modulate.is_equal_approx(Color(0.2, 0.4, 0.6, 0.8)), "different actors retain independent tint baselines")
	fx.hit_flash(second_target, Color.RED)
	second_target.free()
	_advance(1.0)
	# Changing screens while the old control is still pending deletion must also
	# stop the old shake; its completion cannot write to the new screen.
	fx.camera_impact(10, 0.4, 0.1)
	_advance(0.04)
	var next_host := Control.new()
	next_host.position = Vector2(20, 30)
	root.add_child(next_host)
	var next_layer := Control.new()
	next_host.add_child(next_layer)
	fx.bind(next_host, next_layer)
	_check(host.position.is_equal_approx(rest_position) and host.scale.is_equal_approx(rest_scale) and host.pivot_offset.is_equal_approx(rest_pivot), "screen rebind restores an interrupted camera effect")
	_advance(1.0)
	_check(next_host.position.is_equal_approx(Vector2(20, 30)) and next_host.scale.is_equal_approx(Vector2.ONE), "old camera callbacks cannot alter a newly bound screen")
	# Existing finite projectiles, rings and labels must release their nodes and counters.
	fx.projectile(Vector2.ZERO, Vector2(60, 40), Color.RED)
	fx.aoe_indicator(Vector2(60, 40), 20, Color.BLUE)
	fx.boss_telegraph(Vector2(60, 40), 20, Color.RED, 0.3, "검증")
	fx.dodge(Vector2(60, 40))
	_check(fx.active_projectiles == 1 and fx.active_indicators == 2, "effect counters reflect active projectiles and indicators")
	_advance(2.0)
	await process_frame
	_advance(2.0)
	await process_frame
	_check(fx.active_projectiles == 0 and fx.active_indicators == 0, "finished effects release their active counters")
	_check(next_layer.get_child_count() == 0, "projectiles, impact bursts, rings and dodge labels all leave the scene")
	host.free()
	next_host.free()
	print("v51_fx_lifecycle checks=%d failures=%d rapid_hits=24 alpha_preserved=true" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
