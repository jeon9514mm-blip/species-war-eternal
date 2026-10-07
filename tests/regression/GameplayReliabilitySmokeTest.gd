extends "res://tests/support/V83UpgradeTestBase.gd"
const PRODUCTIVITY = preload("res://scripts/hunting/HuntProductivity.gd")
const FIELD = preload("res://scripts/hunting/HuntFieldService.gd")
const ECOLOGY = preload("res://scripts/hunting/FieldEcology.gd")
const VALIDATION = preload("res://scripts/persistence/SaveValidation.gd")
const ZONES = preload("res://scripts/maps/ZoneCatalog.gd")
const CLAIMS = preload("res://scripts/progression/RewardClaimService.gd")

class FailedStore extends SaveStore:
	func write_save(_path: String, _data: Dictionary) -> Dictionary:
		return {"ok":false, "status":"injected_gameplay_write_failure"}

func _init() -> void: _run.call_deferred()

func _run() -> void:
	_test_estimates()
	for faction: String in ["aurelia", "noxfera"]:
		var main = await make_main(faction, 10)
		await _test_save_barrier(main)
		await _test_guide(main)
		await _test_corps_rewards(main)
		await _test_productivity(main)
		await _test_natural_productivity(main)
		await dispose(main)
	done("gameplay_reliability")

func _test_estimates() -> void:
	var estimator := IdleHuntEstimator.new()
	var zone: Dictionary = ZONES.all().moonrest_forest
	var old: Dictionary = estimator.estimate(3600, 10000, 10, zone, 8, 0, 10)
	var measured: Dictionary = estimator.estimate(3600, 10000, 10, zone, 8, 0, 10, {"seconds_per_pack":30.0})
	check(measured.kills == 120 and measured.gold == 105 * 120, "offline rewards respect observed pack throughput and 88% payout")
	check(measured.gold < old.gold and measured.stage_clears <= 5 and measured.gear_rolls <= 32, "measured pace preserves offline safety caps")
	for invalid: Variant in [NAN, INF, "fast", [], {}]:
		check(estimator.estimate(3600, 10000, 10, zone, 8, 0, 10, {"seconds_per_pack":invalid}) == old, "malformed observed pace cannot create rewards")
	check(estimator.estimate(0, 10000, 10, zone, 8, 0, 10).kills == 0, "zero elapsed time has no award")
	check(PRODUCTIVITY.sanitize({"aurelia/moonrest_forest":{"seconds_per_pack":NAN}}).is_empty(), "invalid history rejected")
	check(PRODUCTIVITY.sanitize([]).is_empty(), "non-dictionary history rejected")
	for stage in range(1, 30):
		check(is_equal_approx(ECOLOGY.stage_pressure(stage, 1), 1.0 + minf(0.35, float(stage-1)*0.0125)), "early difficulty unchanged stage " + str(stage))
	check(ECOLOGY.stage_pressure(100,1) > ECOLOGY.stage_pressure(29,1), "late difficulty continues after former cap")
	check(ECOLOGY.stage_pressure(10000,1) > ECOLOGY.stage_pressure(100,1), "late difficulty remains progressive")
	check(ECOLOGY.stage_pressure(10000,1) < 2.5 and ECOLOGY.late_reward_multiplier(10000,1) < 1.4, "late tuning remains bounded across supported stages")
	check(ECOLOGY.late_reward_multiplier(29,1) == 1.0 and ECOLOGY.late_reward_multiplier(100,1) > 1.0, "only late hunting receives extra base rewards")

func _test_save_barrier(main) -> void:
	var id: String = str(main.deployed_heroes[0].id)
	main.wallet_gems = 400
	main.hero_shards[id] = 100
	main.guardian_free_claimed = false
	main.unclaimed_gold = 120; main.offline_pending_gold = 120
	main.save_store = FailedStore.new()
	var result: Dictionary = main._summon_once()
	check(not result.is_empty() and main.wallet_gems == 300 and SAFETY.pending(main), "failed first summon retains awarded state and sets barrier")
	var before: Dictionary = economic(main)
	var rng_state: int = main.loot_rng.state
	check(main._summon_once().is_empty() and main._summon_guardian().is_empty(), "both summons blocked before RNG/currency consumption")
	check(not main._try_ascend_hero(id) and not main._try_breakthrough(id), "ascension and breakthrough blocked")
	main._recommend_equip_all(); main._bulk_enhance_equipped()
	main._set_auto_salvage("전설")
	check(not bool(main._gear_enhance_item("missing",id,"weapon").get("ok",true)), "manual upgrade blocked")
	check(not bool(main._gear_workshop_action("missing","lock").get("ok",true)), "workshop blocked")
	check(not bool(main._market_submit("buy",{}).get("ok",true)), "market blocked")
	var button := Button.new(); var status := Label.new()
	CLAIMS.claim_daily_reward(main,button,status)
	CLAIMS.claim_rewarded_ad(main,button,status)
	main._claim_offline_rewards()
	check(economic(main) == before and main.loot_rng.state == rng_state, "all blocked actions preserve economy, RNG and existing receipt")
	check(status.text.is_empty(), "blocked claims do not show success")
	button.free(); status.free()
	main.save_store = SaveStore.new()
	check(SAFETY.retry(main) and economic(main) == before, "retry saves retained reward without replay")
	check(not main._summon_once().is_empty() and main.wallet_gems == 200, "summon resumes after successful save")
	main.set_meta("practice_active",true)
	before = economic(main)
	check(main._summon_once().is_empty() and not main._try_breakthrough(id), "practice cannot spend live resources")
	check(economic(main) == before, "practice protection preserves all balances")
	main.set_meta("practice_active",false)
	main._save_blocked_for_newer_version = true
	check(main._summon_once().is_empty(), "newer-version save cannot be mutated by summons")
	main._save_blocked_for_newer_version = false

func _test_guide(main) -> void:
	main.idle_stage=1; main.idle_stage_kills=3; main.combat_kills=3
	main.tutorial_completed=false; main.tutorial_step=0
	main.unclaimed_gold=0; main.unclaimed_xp=0
	main._build_lobby_screen(); await settle()
	check(main.tutorial_step==3 and "자동" in main._tutorial_text(), "guide explains deposited online rewards")
	var action: Button = main.content_root.find_child("LobbyGuideAction",true,false)
	check(action != null, "guide action exists")
	if action != null: action.pressed.emit()
	await settle()
	check(main.active_screen=="combat", "guide action enters hunting instead of looping to lobby")
	main.idle_stage=2; main._refresh_tutorial_state()
	check(main.tutorial_step>3, "reaching stage two advances the guide")

func _test_corps_rewards(main) -> void:
	for count in range(15,21):
		main.idle_stage=1; main.idle_stage_kills=0
		main._build_combat_screen(); await settle()
		main.invasion.serial=count-15
		var fallen: Array = FIELD.generate_corps(main,main._current_zone())
		check(fallen.size()==count, "runtime generates " + str(count) + " members")
		for enemy: Dictionary in fallen: enemy.hp=0
		var before: int=main.combat_kills
		FIELD.settle_corps(main,fallen,{})
		var expected: int=3 if count==15 else 4
		check(main.combat_kills-before==expected and main.idle_stage_kills==expected, "complete and partial packs both advance rewards "+str(count))

func _test_productivity(main) -> void:
	main.idle_stage=8; main.current_zone_id="moonrest_forest"
	main._build_combat_screen(); await settle()
	main.hunt_productivity.clear()
	PRODUCTIVITY.begin_sample(main)
	main.invasion.clock=20.0; PRODUCTIVITY.record(main,3)
	check(PRODUCTIVITY.observed(main,main.current_zone_id).is_empty(), "one fast clear does not unlock a measured region")
	main.invasion.clock=120.0; PRODUCTIVITY.record(main,9)
	var measured: Dictionary=PRODUCTIVITY.observed(main,main.current_zone_id)
	check(not measured.is_empty() and measured.seconds_per_pack==10.0, "twelve completed packs record elapsed game time")
	main.idle_stage=58
	check(PRODUCTIVITY.observed(main,main.current_zone_id).seconds_per_pack>10.0, "later enemy pressure slows the reused offline pace")
	main.idle_stage=8
	main._save_idle_state(); var saved: Dictionary=main.hunt_productivity.duplicate(true)
	main.hunt_productivity.clear(); main._load_idle_state()
	check(main.hunt_productivity==saved, "productivity survives actual save and game loader")
	check(not PRODUCTIVITY.observed(main,main.current_zone_id).is_empty(), "loadout fingerprint survives JSON numeric normalization")
	var id: String=str(main.deployed_heroes[0].id)
	var old_tree: Dictionary=main.hero_skill_tree[id].duplicate(true)
	main.hero_skill_tree[id]={"offense":0,"survival":0,"utility":0}
	check(PRODUCTIVITY.observed(main,main.current_zone_id).is_empty() or old_tree==main.hero_skill_tree[id], "changed research cannot reuse old defensive pace")
	main.hero_skill_tree[id]=old_tree
	var old_level: int=int(main.hero_equipment[id].armor)
	main.hero_equipment[id].armor=mini(10,old_level+1)
	check(PRODUCTIVITY.observed(main,main.current_zone_id).is_empty() or old_level==10, "changing armor invalidates the measured loadout")
	main.hero_equipment[id].armor=old_level
	main.last_idle_timestamp=int(Time.get_unix_time_from_system())-3600; main._offline_checked=false
	main.gear_auto_equip=false; main._calculate_offline_reward()
	check("최근 사냥" in main.offline_reward_basis and main.offline_reward_basis.begins_with(ZONES.display_name("moonrest_forest") + " · "), "proven region used for offline rewards")
	check(main.offline_reward_gold<=int(floor(360.0*0.88))*120*1.3, "observed throughput bounds high-region gold including guardian")
	main.skill_auto=not main.skill_auto
	check(PRODUCTIVITY.observed(main,main.current_zone_id).is_empty(), "changing automation invalidates recorded pace")
	main.last_idle_timestamp=int(Time.get_unix_time_from_system())-3600; main._offline_checked=false
	main._calculate_offline_reward()
	check("기본 사냥" in main.offline_reward_basis and main.offline_reward_basis.begins_with(ZONES.display_name("gray_meadow") + " · "), "unproven party falls back to starter region")
	check(main.current_zone_id=="moonrest_forest", "offline fallback preserves selected online region")
	main.skill_auto=not main.skill_auto
	for hero: Dictionary in main.deployed_heroes: main.hero_progress[str(hero.id)]={"level":1,"xp":0}
	check(PRODUCTIVITY.observed(main,main.current_zone_id).is_empty(), "weaker party cannot reuse stronger pace")
	var malformed: Dictionary=saved.duplicate(true)
	for entry: Dictionary in malformed.values(): entry.seconds_per_pack=INF
	check(VALIDATION.sanitize({"hunt_productivity":malformed},ZONES.all().keys()).hunt_productivity.is_empty(), "save validation discards malformed pace")

func _test_natural_productivity(main) -> void:
	for hero: Dictionary in main.deployed_heroes: main.hero_progress[str(hero.id)]={"level":60,"xp":0}
	main.hunt_productivity.clear(); main.skill_auto=true; main.ultimate_auto=true
	main.idle_stage=8; main.gear_auto_equip=false
	main._build_combat_screen(); await settle()
	for tick in 4000:
		main._advance_auto_hunt(0.1)
		if tick%100==0: await process_frame
		if not PRODUCTIVITY.observed(main,main.current_zone_id).is_empty(): break
	var entry: Dictionary=PRODUCTIVITY.observed(main,main.current_zone_id)
	check(not entry.is_empty(), "natural HP combat produces a usable offline measurement "+str(main.selected_faction))
	check(main.combat_kills>=PRODUCTIVITY.MIN_PACKS, "measurement requires actual pack victories")
	if not entry.is_empty():
		print("natural-productivity faction=%s packs=%d game_seconds=%.2f seconds_per_pack=%.3f" % [main.selected_faction,main.combat_kills,main.invasion.clock,entry.seconds_per_pack])
