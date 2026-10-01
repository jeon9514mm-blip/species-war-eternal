extends "res://scripts/V83UpgradeTestBase.gd"
class RecordingStore extends SaveStore:
	var snapshots: Array = []
	var fail_next: bool = false
	func write_save(path: String, data: Dictionary) -> Dictionary:
		snapshots.append(data.duplicate(true))
		if fail_next:
			fail_next=false
			return {"ok":false,"status":"injected_offline_write_failure"}
		return super.write_save(path,data)
func _init() -> void: _run.call_deferred()
func state(main) -> Dictionary:
	var result: Dictionary={}
	for key: String in ["hero_progress","pet_progress","hero_equipment_items","loot_inventory","equipment_overflow","wallet_gold","wallet_xp","unclaimed_gold","unclaimed_xp","idle_chest_gold","idle_chest_xp","offline_pending_gold","offline_pending_xp","offline_pending_chest_gold","offline_pending_chest_xp","idle_stage","idle_stage_kills","long_term_goals"]:
		var value: Variant=main.get(key)
		result[key]=value.duplicate(true) if value is Dictionary or value is Array else value
	result["rations"]=main.faction_war_state.rations
	return result
func _run() -> void:
	for faction: String in ["aurelia","noxfera"]:
		var main=await make_main(faction,10)
		main.gear_auto_equip=true;main.loot_rng.seed=8361002
		main._save_idle_state()
		var recorder:=RecordingStore.new();main.save_store=recorder
		main.last_idle_timestamp=int(Time.get_unix_time_from_system())-3600;main._offline_checked=false
		main._calculate_offline_reward()
		check(main.offline_reward_gold>0 and main.offline_reward_xp>0 and main.last_save_status=="saved","real offline service grants and saves "+faction)
		print("offline-save-observation faction=%s writes=%d gear_rolls=%d" % [faction,recorder.snapshots.size(),main.offline_gear_rolls])
		check(recorder.snapshots.size()==1,"offline auto-equipment must not commit a partial settlement")
		for record: Dictionary in recorder.snapshots:
			check(int(record.offline_pending_gold)==main.offline_pending_gold and int(record.offline_pending_xp)==main.offline_pending_xp,"every committed snapshot includes the complete offline receipt")
		var credited: Dictionary=state(main);var writes: int=recorder.snapshots.size()
		main._calculate_offline_reward()
		check(state(main)==credited and recorder.snapshots.size()==writes,"repeat callback cannot repeat XP/gear/rations/stages")
		var saved: Dictionary=recorder.read_save(main.save_state_path).get("data",{})
		check(not saved.is_empty() and int(saved.last_idle_timestamp)==main.last_idle_timestamp,"actual file contains consumed timestamp")
		check(int(saved.unclaimed_gold)==main.unclaimed_gold and int(saved.offline_pending_gold)==main.offline_pending_gold,"actual file contains complete reward buckets")
		var growth: Dictionary=main.hero_progress.duplicate(true);var item_ids: Array[String]=items(main)
		main._load_idle_state()
		check(main.hero_progress==growth and items(main)==item_ids,"game loader restores rewarded growth and item IDs")
		main._calculate_offline_reward()
		check(main.offline_reward_seconds<60,"reloaded receipt does not replay previous hour")
		var resumed: Dictionary=state(main);main._calculate_offline_reward()
		check(state(main)==resumed,"reload follow-up callback idempotent")
		# No real-time wait is simulated here: pass an earlier saved timestamp.
		main.gear_auto_equip=false
		main._save_idle_state();recorder.snapshots.clear()
		var disk_before: PackedByteArray=FileAccess.get_file_as_bytes(main.save_state_path)
		main.last_idle_timestamp=int(Time.get_unix_time_from_system())-60;main._offline_checked=false
		recorder.fail_next=true;main._calculate_offline_reward()
		check(SAFETY.pending(main) and main.last_save_status=="injected_offline_write_failure","offline final-write failure sets shared pending barrier")
		check(FileAccess.get_file_as_bytes(main.save_state_path)==disk_before,"injected failed write leaves last good disk snapshot unchanged")
		var pending: Dictionary=state(main)
		main._load_idle_state();main._calculate_offline_reward()
		check(state(main)==pending and SAFETY.pending(main),"pending load/repeated callback cannot overwrite or duplicate granted state")
		check(SAFETY.retry(main) and state(main)==pending,"retry saves only current state, no regrant")
		growth=main.hero_progress.duplicate(true)
		var claim_gold: int=main.offline_pending_gold+main.offline_pending_chest_gold
		var wallet: int=main.wallet_gold
		main._claim_offline_rewards()
		check(main.wallet_gold==wallet+claim_gold and main.hero_progress==growth,"claim moves only wallet balances, not hero XP again")
		var claimed: Dictionary=state(main);main._claim_offline_rewards()
		check(state(main)==claimed,"duplicate claim is inert")
		# A full protected bag must preserve original IDs during offline rolls.
		main.loot_inventory.clear();var protected_ids: Array[String]=[]
		for i in main.INVENTORY_CAP:
			var item: Dictionary=main.GEAR.hunt_item(main._current_zone(),"weapon","일반",main.loot_rng,"탱커")
			item.locked=true;item=main._normalize_inventory_item(item)
			main.loot_inventory.append(item);protected_ids.append(item.id)
		main.last_idle_timestamp=int(Time.get_unix_time_from_system())-3600;main._offline_checked=false
		main._calculate_offline_reward()
		var current_ids: Array[String]=items(main)
		for id: String in protected_ids:check(id in current_ids,"protected bag item not destroyed "+faction+id)
		check(main.loot_inventory.size()<=main.INVENTORY_CAP,"offline rolls respect bag capacity")
		check(main.last_save_status=="saved","full bag result persisted")
		# Clock rollback never produces negative time or fabricated old rewards.
		main.last_idle_timestamp=int(Time.get_unix_time_from_system())+600;main._offline_checked=false
		var future: int=main.last_idle_timestamp;var stable: Dictionary=state(main)
		main._calculate_offline_reward()
		check(state(main)==stable and main.last_idle_timestamp==future,"clock rollback preserves high-water mark and economy")
		await dispose(main)
	done("v8361_offline_save")
