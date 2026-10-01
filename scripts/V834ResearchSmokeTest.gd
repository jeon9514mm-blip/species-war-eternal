extends "res://scripts/V83UpgradeTestBase.gd"
const RESEARCH = preload("res://scripts/ResearchAllocationService.gd")
func _init() -> void: _run.call_deferred()
func _run() -> void:
	for faction: String in ["aurelia", "noxfera"]:
		var main = await make_main(faction, 3)
		main._build_growth_screen(); await settle()
		for hero: Dictionary in ROSTER.roster(faction):
			var id: String = hero["id"]
			for level: int in [1, 3, 4, 30, 31, 60, 90, 91, 100]:
				main.hero_progress[id] = {"level":level, "xp": 7}
				var earned: int = clampi(int((level-1)/3.0),0,30)
				check(RESEARCH.budget(main,id)==earned,"real budget boundary "+id+str(level))
				var draft: Dictionary = {"offense":mini(10,earned),"survival":mini(10,maxi(0,earned-10)),"utility":mini(10,maxi(0,earned-20))}
				var old: Dictionary = economic(main)
				var result: Dictionary = RESEARCH.preview(main,id,draft)
				check(result.get("ok",false) and result.available==0,"all earned points can be allocated "+id+str(level))
				check(old==economic(main),"pure preview "+id+str(level))
		var first: String = main._deployed_hero_ids()[0]
		main.hero_progress[first] = {"level":60,"xp":25}
		main.hero_skill_tree[first] = {"offense":6,"survival":6,"utility":6}
		main._refresh_growth_runtime(); main._save_idle_state()
		var before: Dictionary = economic(main)
		var file_before: PackedByteArray = FileAccess.get_file_as_bytes(main.save_state_path)
		var proposed: Dictionary = {"offense":10,"survival":3,"utility":6}
		var view: Dictionary = RESEARCH.preview(main,first,proposed)
		check(view.ok and before==economic(main) and file_before==FileAccess.get_file_as_bytes(main.save_state_path),"preview leaves RAM and file unchanged")
		var old_stats: Dictionary = main._hero_combat_stats(first)
		check(RESEARCH.apply(main,first,proposed,view.token).ok,"confirm applies")
		check(main._skill_tree_total_points(first)==19 and main._skill_tree_spent(first)==19,"earned point total conserved")
		check(main._hero_combat_stats(first).attack>old_stats.attack and main._hero_combat_stats(first).max_hp<old_stats.max_hp,"actual combat stats respond to allocation")
		check(not RESEARCH.apply(main,first,proposed,view.token).ok,"duplicate token rejected")
		var after: Dictionary = economic(main)
		for key in before:
			if key!="hero_skill_tree": check(after[key]==before[key],"respec preserves "+key)
		var stored: Dictionary = main.save_store.read_save(main.save_state_path).data
		check(stored.hero_skill_tree[first]==JSON.parse_string(JSON.stringify(proposed)) and stored.hero_progress[first]==JSON.parse_string(JSON.stringify(before.hero_progress[first])),"real save stores allocation but no XP or level change")
		main.hero_skill_tree[first]={"offense":0,"survival":0,"utility":0}
		main._load_idle_state()
		check(main.hero_skill_tree[first]==proposed,"actual game loader restores respec")
		for bad: Dictionary in [{"offense":11,"survival":0,"utility":0},{"offense":-1,"survival":0,"utility":0},{"offense":1.5,"survival":0,"utility":0},{"offense":10,"survival":10,"utility":10},{"offense":0},{"offense":0,"survival":0,"utility":0,"fake":1}]:
			check(not RESEARCH.preview(main,first,bad).ok,"invalid draft rejected "+str(bad))
		var foreign: String = ROSTER.roster("noxfera" if faction=="aurelia" else "aurelia")[0]["id"]
		check(not RESEARCH.preview(main,foreign,proposed).ok,"other faction rejected")
		check(not RESEARCH.apply(main,first,proposed,"").ok,"confirmation token required")
		var reset: Dictionary = {"offense":0,"survival":0,"utility":0}
		var stale: Dictionary = RESEARCH.preview(main,first,reset)
		main.hero_progress[first].xp += 1
		check(not RESEARCH.apply(main,first,reset,stale.token).ok,"changed progression rejects stale confirm")
		stale = RESEARCH.preview(main,first,reset)
		main._build_growth_screen(); await settle()
		check(not RESEARCH.apply(main,first,reset,stale.token).ok,"old screen rejected")
		var reset_view: Dictionary = RESEARCH.preview(main,first,reset)
		var good_path: String = main.save_state_path
		main.save_state_path = "/proc/species-war-intentional-readonly-test/save.json"
		var failed: Dictionary = RESEARCH.apply(main,first,reset,reset_view.token)
		check(failed.get("applied",false) and not failed.ok and SAFETY.pending(main),"actual write failure retains pending allocation")
		check(RESEARCH.current(main,first)==reset and main._skill_tree_available_points(first)==19,"all points now unspent exactly once")
		check(not RESEARCH.preview(main,first,proposed).ok and not PRESET.save(main,0).ok,"pending barrier blocks further allocations and preset writes")
		main.save_state_path = good_path
		check(SAFETY.retry(main) and not SAFETY.pending(main),"retry persists only allocation")
		check(main.save_store.read_save(good_path).data.hero_skill_tree[first]==JSON.parse_string(JSON.stringify(reset)),"retry actual disk roundtrip")
		check(not RESEARCH.apply(main,first,reset,RESEARCH.fingerprint(main,first)).ok,"no-op does not create a save transaction")
		main._open_practice_screen(); await settle()
		check(main._start_practice("daily",1,"gold_rush"),"practice begins")
		var in_practice: Dictionary = main.hero_skill_tree.duplicate(true)
		check(not RESEARCH.preview(main,first,proposed).ok,"respec denied during practice")
		main._upgrade_skill_tree(first,"offense")
		check(main.hero_skill_tree==in_practice,"stale ordinary upgrade cannot mutate practice")
		main._build_lobby_screen(); await settle()
		main._build_combat_screen()
		check(not RESEARCH.preview(main,first,proposed).ok,"respec denied during normal combat")
		main._build_lobby_screen(); await settle()
		await dispose(main)
	done("v834_research")
