extends SceneTree

func _init() -> void:
	var scene = preload("res://scenes/Main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.combat_effects_enabled = false
	await process_frame
	main._build_faction_screen()
	await process_frame
	main._select_faction("aurelia")
	main._confirm_faction()
	await process_frame
	main.idle_stage = 8
	main._build_hero_select_screen()
	await process_frame
	var roster: Array = main._hero_roster_for_faction()
	main._deploy_hero(roster[0])
	main._deploy_hero(roster[1])
	main._deploy_hero(roster[2])
	main._build_combat_screen()
	await process_frame
	for _step in 4800:
		main._advance_auto_hunt(0.05)
		if main.combat_kills > 0:
			break
	if main.combat_kills <= 0:
		push_error("Open-map combat did not defeat any monster")
		quit(1)
	elif main.unclaimed_gold <= 0 or main.unclaimed_xp <= 0:
		push_error("Open-map reward did not accumulate")
		quit(1)
	else:
		print("open_map_smoke_test_ok zone=%s kills=%d gold=%d xp=%d" % [main.current_zone_id, main.combat_kills, main.unclaimed_gold, main.unclaimed_xp])
		main._claim_rewards()
		if main.wallet_gold <= 0 or main.wallet_xp <= 0:
			push_error("Reward claim failed")
			quit(1)
		print("reward_claim_ok wallet_gold=%d wallet_xp=%d" % [main.wallet_gold, main.wallet_xp])

	var gray_reward: int = int(main._zone_data()["gray_meadow"]["gold"])
	var mine_reward: int = int(main._zone_data()["forgotten_mine"]["gold"])
	var forest_difficulty: int = int(main._zone_data()["moonrest_forest"]["difficulty"])
	if mine_reward <= gray_reward or forest_difficulty <= int(main._zone_data()["gray_meadow"]["difficulty"]):
		push_error("Zone reward or difficulty progression is invalid")
		quit(1)
	main.idle_stage = 4
	main._cycle_zone()
	await process_frame
	if main.current_zone_id != "forgotten_mine":
		push_error("Zone cycling did not move to forgotten mine")
		quit(1)
	print("zone_progression_ok gray_gold=%d mine_gold=%d forest_difficulty=%d" % [gray_reward, mine_reward, forest_difficulty])
	main._clear_screen()
	quit(0)
