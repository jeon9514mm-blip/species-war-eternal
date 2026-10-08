extends SceneTree
## Fixed wall intervals remain accurate through hit-stop, pause and ring wrap.
class Host extends Node:
	var _application_suspended := false
var checks := 0
var failures: Array[String] = []
func _init() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func run() -> void:
	var host := Host.new()
	var runtime := PresentationRuntime.new()
	runtime.game = host
	check(runtime._record_frame(1000000) == 0, 'first frame establishes wall origin')
	var original_scale := Engine.time_scale
	Engine.time_scale = .08
	check(is_equal_approx(runtime._record_frame(1020000), .02), 'ultimate slowdown preserves a20ms render interval')
	Engine.time_scale = 1
	check(is_equal_approx(runtime._record_frame(1040000), .02), 'restoring time scale preserves same render interval')
	check(is_equal_approx(runtime.diagnostics().frame_ms_mean, 20), 'diagnostics reports50fps rather than625fps')
	check(runtime._record_frame(1040000) == 0 and runtime.diagnostics().sample_count == 2, 'duplicate clock sample ignored')
	host._application_suspended = true
	check(runtime._record_frame(2000000) == 0, 'suspended frame excluded')
	host._application_suspended = false
	check(runtime._record_frame(11000000) == 0, 'resume excludes ten-second background gap')
	check(is_equal_approx(runtime._record_frame(11020000), .02), 'resume follows new wall origin')
	for i in 200: runtime._record_frame(11040000 + i * 20000)
	var report := runtime.diagnostics()
	check(report.sample_count == 180, 'fixed bounded history after ring wrap')
	check(is_equal_approx(report.frame_ms_mean, 20) and is_equal_approx(report.frame_ms_p95, 20), 'wrapped history keeps mean andp95 accurate')
	host._application_suspended = true
	runtime.sync_context()
	host._application_suspended = false
	check(runtime._record_frame(40000000) == 0, 'pause notification alone clears origin when callbacks stop')
	Engine.time_scale = original_scale
	runtime.free(); host.free()
	print('presentation_wall_clock checks=%d failures=%s' % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
