extends SceneTree
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		push_error("Guardian: "+label)

func _run() -> void:
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
	var catalog:=preload("res://scripts/GuardianCatalog.gd")
	var game:=preload("res://scenes/PortraitMain.tscn").instantiate()
	game.save_state_path="user://v65-guardian-smoke.json"
	root.add_child(game)
	for i in 6:await process_frame
	game.selected_faction="aurelia";game.idle_stage=40
	game.deployed_heroes=game._hero_roster_for_faction().slice(0,3)
	game._guardian_ensure_starter()
	check(game.guardian_equipped=="lumi" and game.guardian_collection.has("lumi"),"legacy faction gains its original starter")
	check(is_equal_approx(game._guardian_bonus("online_xp"),0.04),"starter experience option is equipped")
	var rng:=RandomNumberGenerator.new();rng.seed=3001
	var totals: Dictionary={}
	for tier in catalog.TIERS:totals[tier]=0
	for roll in 10000:
		var id: String=catalog.draw_id(rng,0,0)
		totals[catalog.profile(id)["tier"]]+=1
	for i in catalog.TIERS.size():
		check(absf(float(totals[catalog.TIERS[i]])/10000.0 - float(catalog.WEIGHTS[i])/100.0)<.022,"weighted rate "+str(catalog.TIERS[i]))
	game.wallet_gems=0
	game.guardian_legendary_pity=29
	var free: Dictionary=game._summon_guardian()
	check(str(free.get("tier",""))=="전설" and game.wallet_gems==0 and game.guardian_legendary_pity==0 and game.guardian_free_claimed,"first free draw respects legendary pity")
	var previous_count: int=game.guardian_collection.size()
	check(game._summon_guardian().is_empty() and game.guardian_collection.size()==previous_count,"insufficient gems do not mutate ownership")
	game.wallet_gems=80;game.guardian_mythic_pity=79
	var mythic: Dictionary=game._summon_guardian()
	check(str(mythic.get("tier",""))=="신화" and game.wallet_gems==0 and game.guardian_mythic_pity==0,"mythic pity charges once and resets")
	var mythic_id: String=str(mythic["id"])
	var basic_power: int=game._calculate_party_power()
	check(game._guardian_equip(mythic_id) and game._calculate_party_power()>basic_power,"guardian attack raises actual party power")
	var buff: float=game._guardian_bonus("offline_xp")
	check(game._guardian_reward(1000,"offline_xp")==int(round(1000.0*(1.0+buff))),"offline experience rewards use equipped bonus")
	check(game._guardian_reward(1000,"online_gold")>1000,"online gold reward uses equipped bonus")
	var zone: Dictionary=game._current_zone()
	var chosen_seed: int=-1
	for seed_value in 5000:
		rng.seed=seed_value
		var roll: float=rng.randf()
		if roll>0.75 and roll<0.82:
			chosen_seed=seed_value;break
	check(chosen_seed>=0,"drop probability probe seed found")
	if chosen_seed>=0:
		game._guardian_equip("lumi")
		game.loot_rng.seed=chosen_seed
		check(game._roll_equipment_drop(zone).is_empty(),"baseline hunting roll misses equipment")
		game._guardian_equip(mythic_id)
		game.loot_rng.seed=chosen_seed
		check(not game._roll_equipment_drop(zone).is_empty(),"guardian item chance makes identical hunt roll succeed")
	var crit_seed: int=-1
	for seed_value in 5000:
		rng.seed=seed_value
		if rng.randf()<game._guardian_bonus("crit"):
			crit_seed=seed_value;break
	check(crit_seed>=0,"critical strike probe seed found")
	if crit_seed>=0:
		game.active_screen="combat"
		game.enemy_wave=[{"name":"검증 표적","hp":5000,"max_hp":5000,"attack":0}]
		game.loot_rng.seed=crit_seed
		check(game._damage_enemy(0,100)==150,"guardian critical chance amplifies live combat damage")
	game.active_screen="lobby"
	var observed: Dictionary=preload("res://scripts/HuntProductivity.gd").observed(game,str(game.current_zone_id))
	if observed.is_empty():
		zone=game._zone_data().gray_meadow
		observed={"seconds_per_pack":preload("res://scripts/GrowthEconomyRules.gd").unmeasured_pack_interval(game.deployed_heroes.size())}
	var estimate: Dictionary=game.idle_hunt_estimator.estimate(3600,game._calculate_party_power(),game.deployed_heroes.size(),zone,game.idle_stage,game.idle_stage_kills,game.idle_stage_target,observed)
	print("GUARDIAN_POLICY expected_gold=%d expected_xp=%d"%[game._guardian_reward(int(estimate["gold"]),"offline_gold"),game._guardian_reward(int(estimate["xp"]),"offline_xp")])
	game.last_idle_timestamp=int(Time.get_unix_time_from_system())-3600
	game._offline_checked=false
	game._calculate_offline_reward()
	print("GUARDIAN_POLICY actual_gold=%d actual_xp=%d basis=%s"%[game.offline_reward_gold,game.offline_reward_xp,game.offline_reward_basis])
	check(game.offline_reward_gold==game._guardian_reward(int(estimate["gold"]),"offline_gold") and game.offline_reward_xp==game._guardian_reward(int(estimate["xp"]),"offline_xp"),"offline hunt pays the guardian-adjusted gold and experience once")
	var saved: Dictionary=game.save_store.read_save(game.save_state_path)
	check(bool(saved.get("ok",false)) and saved["data"]["guardian_equipped"]==mythic_id,"equipped guardian and pity persist")
	var tampered: Dictionary=saved["data"].duplicate(true)
	tampered["guardian_collection"]["invalid_guardian"]={"copies":99999}
	tampered["guardian_collection"][mythic_id]={"copies":100000}
	tampered["guardian_equipped"]="invalid_guardian"
	var clean: Dictionary=preload("res://scripts/SaveValidation.gd").sanitize(tampered,game._zone_data().keys(),game.idle_stage_target)
	check(not clean["guardian_collection"].has("invalid_guardian") and int(clean["guardian_collection"][mythic_id]["copies"])==999 and clean["guardian_equipped"]=="lumi","invalid guardian save data is rejected")
	var legacy: Dictionary=saved["data"].duplicate(true)
	for key in ["guardian_collection","guardian_equipped","guardian_legendary_pity","guardian_mythic_pity","guardian_free_claimed"]:legacy.erase(key)
	legacy["pet_progress"]={"aurelia":{"level":12,"xp":25,"evolution":2}}
	var migrated: Dictionary=preload("res://scripts/SaveValidation.gd").sanitize(legacy,game._zone_data().keys(),game.idle_stage_target)
	check(migrated["guardian_equipped"]=="lumi" and migrated["guardian_collection"].has("lumi") and int(migrated["pet_progress"]["aurelia"]["level"])==12,"older companion save retains levels and receives a starter guardian")
	check(catalog.resonance(4)==2 and catalog.resonance(7)==3 and catalog.resonance(100)==3,"duplicate resonance caps at three levels")
	game.set_meta("summon_mode","guardian");game._build_summon_screen()
	for i in 4:await process_frame
	var summon_button: Button=game.content_root.find_child("GuardianSummonButton",true,false)
	check(summon_button!=null and summon_button.disabled and game.content_root.find_child("GuardianEquip_"+mythic_id,true,false)!=null,"guardian tab presents cost and equipped collection")
	game._show_guardian_reveal(mythic)
	check(game.content_root.find_child("GuardianRevealPanel",true,false)!=null,"summoned guardian opens a tier-colored result panel")
	# Stop playback while players still exist; allow the audio thread to retire Ogg buffers.
	if game.presentation_runtime != null: game.presentation_runtime.audio.shutdown()
	await create_timer(0.5).timeout
	await process_frame
	game.free()
	await create_timer(0.35).timeout
	await process_frame
	print("v65_guardian ",checks-failures.size(),"/",checks," pass")
	quit(0 if failures.is_empty() else 1)
