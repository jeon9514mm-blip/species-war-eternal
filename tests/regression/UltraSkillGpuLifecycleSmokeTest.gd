extends SceneTree
const POOL=preload("res://scripts/maps3d/UltraSkillGpuPool.gd")
const PROFILE={"color":Color("#e8c99a"),"core":Color.WHITE,"power":1.0,"seed":2}
var checks:=0
var failures: Array[String]=[]

class Host extends Node:
	var combat_effects_enabled:=true
	var presentation_options: Dictionary={"performance":"balanced"}
	var _application_suspended:=false
	var combat_running:=true
	var hp:=137
	var wallet:=777

class Field extends Control:
	var game: Node
	var presentation_visible:=true
	var presentation_suspended:=false
	func battle_clock_running() -> bool:
		return is_instance_valid(game) and game.combat_running
	func visual_speed() -> float:return 1.5

func _init() -> void:run.call_deferred()
func check(ok: bool,note: String) -> void:
	checks+=1
	if not ok:failures.append(note);push_error(note)
func stopped(pool: Node,note: String) -> void:
	for item in pool.bursts:
		check(not item.busy,note+" releases the burst lease")
		for emitter: GPUParticles3D in [item.main,item.secondary]:
			check(not emitter.visible and not emitter.emitting and emitter.speed_scale==0,note+" stops and hides the native emitter")
func emit(pool: Node,note: String) -> void:
	check(pool.burst(Vector2(16,10),.2,PROFILE),note+" can reuse the prewarmed pool")
func run() -> void:
	var host:=Host.new();root.add_child(host)
	var field:=Field.new();field.game=host;root.add_child(field)
	var pool:=POOL.new();pool.field=field
	check(not pool.burst(Vector2.ZERO,0,PROFILE),"before-ready admission cannot index an empty pool")
	root.add_child(pool);pool.set_process(false)
	check(pool.bursts.size()==6,"six GPU bursts are prewarmed")
	var children: int=pool.get_child_count()
	emit(pool,"initial field")
	pool._process(.10)
	var age: float=pool.bursts[0].age
	host.combat_running=false;pool._process(.4)
	check(is_equal_approx(pool.bursts[0].age,age) and pool.bursts[0].main.visible and pool.bursts[0].main.speed_scale==0,"ordinary pause freezes the existing burst")
	host.combat_running=true
	field.game=null;pool._process(.016);stopped(pool,"missing host")
	check(not pool.burst(Vector2.ZERO,0,PROFILE),"missing host rejects new effects")
	field.game=host;emit(pool,"reattached host")
	host.combat_effects_enabled=false;pool._process(.016);stopped(pool,"effects opt out")
	host.combat_effects_enabled=true;emit(pool,"effects restored")
	host.presentation_options.performance="battery";pool._process(.016);stopped(pool,"battery profile")
	host.presentation_options.performance="balanced";emit(pool,"balanced profile")
	field.presentation_suspended=true;pool._process(.016);stopped(pool,"suspended view")
	field.presentation_suspended=false;emit(pool,"foreground view")
	field.presentation_visible=false;pool._process(.016);stopped(pool,"hidden background field")
	field.presentation_visible=true;emit(pool,"visible field")
	host._application_suspended=true;pool._process(.016);stopped(pool,"application suspension")
	host._application_suspended=false;emit(pool,"application resumed")
	root.remove_child(host);pool._process(.016);stopped(pool,"detached host")
	root.add_child(host);emit(pool,"returned host")
	check(host.hp==137 and host.wallet==777,"view transitions never change gameplay state")
	host.queue_free();pool._process(.016);stopped(pool,"queued host")
	await process_frame
	pool._process(.016);stopped(pool,"freed host reference")
	host=Host.new();root.add_child(host);field.game=host;emit(pool,"replacement host")
	field.queue_free();pool._process(.016);stopped(pool,"queued field")
	await process_frame
	pool._process(.016);stopped(pool,"freed field reference")
	field=Field.new();field.game=host;root.add_child(field);pool.field=field;emit(pool,"replacement field")
	root.remove_child(pool);stopped(pool,"pool exit")
	check(not pool.burst(Vector2.ZERO,0,PROFILE),"a detached pool cannot restart a stale native burst")
	check(pool.get_child_count()==children,"all replacements preserve the native node budget")
	pool.free();field.free();host.free()
	print("ULTRA_SKILL_GPU_LIFECYCLE checks=%d failures=%s"%[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
