extends Node
## One serial writer. Gameplay snapshots are copied on the main thread; JSON,
## checksums and disk IO run on the worker. Critical actions synchronously flush.
const FLOW = preload("res://scripts/GameSaveCoordinator.gd")
const INTERVAL := 1.0
var dirty := false
var elapsed := 0.0
var worker: Thread
var timestamp: int = 0
var queued_writes: int = 0

func request() -> void:
	dirty = true

func _process(delta: float) -> void:
	_collect()
	if not dirty: return
	elapsed += delta
	if elapsed < INTERVAL or worker != null: return
	var main := get_parent()
	if main.SAVE_SAFETY.pending(main) or bool(main.get_meta("practice_active", false)): return
	var data := FLOW.snapshot(main)
	if data.is_empty(): return
	# Deep-copy before handing ownership to another thread.
	data = data.duplicate(true)
	timestamp = int(data["last_idle_timestamp"])
	dirty = false; elapsed = 0.0
	worker = Thread.new()
	var error := worker.start(_write.bind(main.save_store, main.save_state_path, data))
	if error != OK:
		worker = null; dirty = true
		main._save_idle_state()
	else: queued_writes += 1

func _write(store: RefCounted, path: String, data: Dictionary) -> Dictionary:
	return store.write_save(path, data)

func _collect(block: bool = false) -> void:
	if worker == null or (worker.is_alive() and not block): return
	var result: Dictionary = worker.wait_to_finish()
	worker = null
	if is_inside_tree(): FLOW.accept_result(get_parent(), result, timestamp)

func before_critical_save() -> void:
	_collect(true)
	dirty = false; elapsed = 0.0

func _exit_tree() -> void:
	if worker != null:
		worker.wait_to_finish()
		worker = null
