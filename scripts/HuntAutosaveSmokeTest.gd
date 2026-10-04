extends "res://scripts/V83UpgradeTestBase.gd"
class SlowStore extends SaveStore:
	func write_save(path: String, data: Dictionary) -> Dictionary:
		OS.delay_msec(30)
		return super.write_save(path,data)
class FailedStore extends SaveStore:
	func write_save(_path: String, _data: Dictionary) -> Dictionary:
		return {"ok":false,"status":"injected_async_save_failure"}
func _init() -> void: run.call_deferred()
func run() -> void:
	var main = await make_main("aurelia",3)
	main._open_home();await settle()
	var autosave: Node=main.hunt_autosave
	autosave.set_process(false)
	main.save_store=SlowStore.new()
	main.wallet_gold=1000;main.unclaimed_gold=73
	main._queue_hunt_save();autosave._process(1.0)
	check(main.wallet_gold==1073 and main.unclaimed_gold==0,"queued hunt save preserves online wallet deposit")
	check(not SAFETY.pending(main),"a healthy worker does not suspend combat")
	# A newer purchase/receipt must win even if an older snapshot is still writing.
	main.wallet_gold=1040;main._save_idle_state()
	var saved: Dictionary=main.save_store.read_save(main.save_state_path)
	check(saved.get("ok",false) and int(saved.data.wallet_gold)==1040,"critical write waits for older snapshot and durably stores latest balance")
	check(autosave.worker==null,"critical save leaves no older writer that can overwrite a purchase")
	main.save_store=FailedStore.new()
	main._queue_hunt_save();autosave._process(1.0);autosave._collect(true)
	check(SAFETY.pending(main),"failed worker enters the shared save barrier")
	var clock: float=main.invasion.clock;main._advance_auto_hunt(.5)
	check(main.invasion.clock==clock,"failed autosave stops further hunt progression")
	main.save_store=SaveStore.new();main._retry_pending_save()
	check(not SAFETY.pending(main) and main.wallet_gold==1040,"retry persists current progress without replaying rewards")
	var timings: Array=[]
	for total in [0,200,3200]:
		main.loot_inventory.clear();main.equipment_overflow.clear()
		for i in total:
			var item: Dictionary=main.GEAR.normalize({"id":"save-load-"+str(i),"slot":"weapon","rarity":"희귀","level":3,"origin":"raid","source_id":"gray_meadow"})
			if i<200:main.loot_inventory.append(item)
			else:main.equipment_overflow.append(item)
		main._save_idle_state()
		var foreground: Array=[];var synchronous: Array=[]
		for sample in 3:
			var start:=Time.get_ticks_usec();main._queue_hunt_save();autosave._process(1.0)
			foreground.append(float(Time.get_ticks_usec()-start)/1000.0)
			autosave._collect(true)
			start=Time.get_ticks_usec();main._save_idle_state()
			synchronous.append(float(Time.get_ticks_usec()-start)/1000.0)
		foreground.sort();synchronous.sort()
		timings.append({"items":total,"worker_launch_main_thread_median_ms":foreground[1],"synchronous_median_ms":synchronous[1]})
		check(main.last_save_status=="saved","large snapshots pass integrity verification "+str(total))
	print("HUNT_AUTOSAVE_TIMINGS ",JSON.stringify(timings))
	await dispose(main);done("HUNT_AUTOSAVE")
