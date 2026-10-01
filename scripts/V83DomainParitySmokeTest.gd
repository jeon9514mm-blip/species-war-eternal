extends SceneTree
## Characterization fixture intentionally runs unchanged on v82-1 and v83.
## Uses actual domain methods/SaveStore but overrides only presentation hooks.
class Host extends "res://scripts/Main.gd":
	var notices: Array[String] = []
	var refresh_calls: int = 0
	var offline_callbacks: Array = []
	func _ready() -> void: pass
	func _today_key() -> String: return "2026-10-01"
	func _week_key() -> String: return "2960"
	func _show_toast(message: String) -> void: notices.append(message)
	func _refresh_growth_runtime() -> void:
		refresh_calls += 1
		super._refresh_growth_runtime()
	func _build_growth_screen() -> void: pass
	func _build_inventory_screen() -> void: pass
	func _on_offline_hunt_reward(gold: int, xp: int, chest_gold: int, chest_xp: int) -> void:
		offline_callbacks.append([gold, xp, chest_gold, chest_xp])
var checks: int = 0
var failures: Array[String] = []
var snapshots: Array = []
func _init() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func clean(path: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".bak.tmp", ".corrupt"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
func capture(host: Host, label: String, result: Variant = null) -> void:
	# Only deterministic domain state is compared, not wall-clock save timestamps
	# or random cryptographic item identifiers (normalized by the Python runner).
	snapshots.append({"case":label, "result":result, "faction":host.selected_faction,
		"wallet":[host.wallet_gold,host.wallet_xp,host.wallet_gems],
		"pending":[host.unclaimed_gold,host.unclaimed_xp,host.idle_chest_gold,host.idle_chest_xp],
		"progress":host.hero_progress.duplicate(true), "trees":host.hero_skill_tree.duplicate(true),
		"ascension":host.hero_ascension.duplicate(true),"breakthrough":host.hero_breakthrough.duplicate(true),
		"shards":host.hero_shards.duplicate(true),"codex":host.codex_seen.duplicate(true),
		"guardian":host.guardian_collection.duplicate(true), "equipped_guardian":host.guardian_equipped,
		"pity":[host.summon_pity,host.guardian_legendary_pity,host.guardian_mythic_pity],
		"pet":host.pet_progress.duplicate(true),"inventory":host.loot_inventory.duplicate(true),
		"equipment":host.hero_equipment_items.duplicate(true),"crystals":host.raid_crystals,
		"quest":host.quest_claimed.duplicate(true),"power":host._calculate_party_power(),
		"rng":str(host.loot_rng.state),"refreshes":host.refresh_calls,
		"notices":host.notices.duplicate(),"offline":host.offline_callbacks.duplicate(true)})
func run() -> void:
	for faction: String in ["aurelia", "noxfera"]:
		var host: Host = Host.new()
		host.name = "ParityHost"
		host.save_state_path = "user://v83-parity-"+faction+".json"
		clean(host.save_state_path)
		root.add_child(host); host.set_physics_process(false); host.set_process(false)
		host.selected_faction=faction;host.current_zone_id="gray_meadow";host.idle_stage=50
		host.tower_best_floor=5;host.tower_floor=6;host.party_slot_legacy_cap=10
		host.last_idle_timestamp=2000000000;host.loot_rng.seed=832026
		var roster: Array=host._hero_roster_for_faction()
		host._setup_hero_progress(roster)
		var ids: Array=[]
		for index in 10: ids.append(str(roster[index]["id"]))
		host._restore_deployed_heroes(ids)
		check(host.deployed_heroes.size()==10,"ten-hero fixture "+faction)
		check(host._get_hero_progress("not-a-hero")=={"level":1,"xp":0},"invalid hero unchanged")
		for amount in [-1,0,1,9,10,11,100,7777,100000]:
			host._grant_hero_xp(amount);capture(host,"xp_%s_%d"%[faction,amount])
		for hero: Dictionary in roster:
			var id: String=str(hero["id"])
			host.hero_progress[id]={"level":61,"xp":13}
			host.hero_skill_tree[id]={"offense":-5,"survival":99,"utility":99}
			check(host._skill_tree_spent(id)<=host._skill_tree_total_points(id),"tree budget "+id)
			host.wallet_gold=100000
			host._upgrade_skill_tree(id,"offense")
			host._upgrade_skill_tree(id,"not-a-branch")
			var promoted: bool=host._try_ascend_hero(id)
			host.hero_shards[id]=200
			var broken: bool=host._try_breakthrough(id)
			capture(host,"growth_"+id,[promoted,broken,host._hero_grade(id)])
		check(host._try_ascend_hero("not-a-hero")==false,"invalid ascension rejected")
		host.wallet_gems=20000
		for index in 12:
			capture(host,"hero_summon_%s_%d"%[faction,index],host._summon_once())
		host._guardian_ensure_starter()
		for index in 14:
			if index==3: host.guardian_legendary_pity=host.GUARDIANS.LEGENDARY_PITY-1
			if index==8: host.guardian_mythic_pity=host.GUARDIANS.MYTHIC_PITY-1
			var draw: Dictionary=host._summon_guardian()
			check(not draw.is_empty(),"guardian draw with known funded budget")
			if not draw.is_empty():check(host._guardian_equip(str(draw["id"])),"guardian equip")
			capture(host,"guardian_summon_%s_%d"%[faction,index],draw)
		for amount in [0,1,700,10000,10000000]:
			capture(host,"pet_xp_%s_%d"%[faction,amount],host._grant_pet_xp(amount))
		host.wallet_gems=0
		check(host._summon_once().is_empty() and host._summon_guardian().is_empty(),"unfunded summon rejected")
		var reward_button:Button=Button.new();var reward_label:Label=Label.new()
		host._claim_daily_reward(reward_button,reward_label)
		var once:int=host.wallet_gems
		host._claim_daily_reward(reward_button,reward_label)
		check(host.wallet_gems==once,"daily duplicate does not pay")
		for index in 5:host._claim_rewarded_ad(reward_button,reward_label)
		check(host.rewarded_ad_claimed_count==3,"support daily cap")
		host._claim_rewards();var claimed:int=host.wallet_gold;host._claim_rewards()
		check(host.wallet_gold==claimed,"empty repeat claim unchanged")
		host.raid_clears={"gray_meadow":1}
		for id in ["stage5","raid1","tower5"]:
			check(host._claim_quest(id),"legacy claim "+id)
			check(not host._claim_quest(id),"legacy repeat blocked "+id)
		capture(host,"claims_"+faction)
		reward_button.free();reward_label.free()
		host.wallet_gold=100000;host.raid_crystals=10000
		for index in 3:
			var item:Dictionary=host._normalize_inventory_item({"id":"v83_fixed_%d"%index,"slot":["weapon","armor","accessory"][index],"level":1,"rarity":"희귀","name":"회귀 장비","origin":"legacy","set":"초보자"})
			host.loot_inventory.append(item)
			check(host._gear_enhance_item(str(item["id"])).get("ok",false),"inventory enhance")
			capture(host,"equip_%s_%d"%[faction,index],host._gear_equip_item(str(item["id"]),str(ids[0])))
		capture(host,"equipped_enhance_"+faction,host._gear_enhance_item("v83_fixed_0",str(ids[0]),"weapon"))
		check(not host._gear_equip_item("missing-id",str(ids[0])).get("ok",false),"stale equip rejected")
		host.loot_inventory.append(host._normalize_inventory_item({"id":"locked_test","slot":"weapon","level":1,"rarity":"일반","locked":true}))
		check(not host._gear_decompose_item("locked_test",true).get("ok",false),"locked cannot decompose")
		host._gear_workshop_action("locked_test","toggle_lock")
		check(host._gear_decompose_item("locked_test",true).get("ok",false),"unlocked decompose")
		check(not host._gear_decompose_item("locked_test",true).get("ok",false),"stale decompose rejected")
		capture(host,"gear_"+faction)
		host._save_idle_state()
		check(host.last_save_status=="saved","real save coordinator write")
		var loaded:Dictionary=host.save_store.read_save(host.save_state_path)
		check(loaded.get("ok",false),"real save coordinator read")
		var fields:Array=loaded.get("data",{}).keys();fields.sort()
		capture(host,"save_fields_"+faction,fields)
		var copy:Host=Host.new();copy.name="RestoredHost";copy.save_state_path=host.save_state_path;copy.loot_rng.seed=832026
		root.add_child(copy);copy.set_physics_process(false);copy._load_idle_state()
		check(copy.wallet_gold==host.wallet_gold and copy.guardian_equipped==host.guardian_equipped,"restore currency and guardian")
		check(copy._deployed_hero_ids()==host._deployed_hero_ids(),"restore ten hero IDs")
		check(copy.hero_shards==host.hero_shards and copy.hero_breakthrough==host.hero_breakthrough,"restore shards and breakthrough")
		check(copy.quest_claimed==host.quest_claimed and copy.long_term_goals==host.long_term_goals,"restore old and new ledgers")
		capture(copy,"restored_"+faction)
		copy.free()
		host._offline_checked=false;host.last_idle_timestamp=1;host._calculate_offline_reward()
		check(host.offline_callbacks.size()==1,"offline virtual callback once")
		capture(host,"offline_"+faction)
		var after_offline:Array=[host.unclaimed_gold,host.unclaimed_xp,host.idle_stage]
		host._calculate_offline_reward()
		check(after_offline==[host.unclaimed_gold,host.unclaimed_xp,host.idle_stage],"offline idempotent")
		var saved_raw:String=FileAccess.get_file_as_string(host.save_state_path)
		host._save_blocked_for_newer_version=true;host.wallet_gold+=100;host._save_idle_state()
		check(FileAccess.get_file_as_string(host.save_state_path)==saved_raw,"blocked newer save never overwritten")
		clean(host.save_state_path);host.free()
	print("V83_PARITY_JSON "+JSON.stringify(snapshots))
	print("v83_domain_parity checks=%d failures=%s"%[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
