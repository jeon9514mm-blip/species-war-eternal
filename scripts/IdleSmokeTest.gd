extends SceneTree

func _init() -> void:
	var scene = preload("res://scenes/Main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.selected_faction = "aurelia"
	main.deployed_heroes = main._hero_roster_for_faction().slice(0, 3)
	main.last_idle_timestamp = int(Time.get_unix_time_from_system()) - 60
	main._build_combat_screen()
	await process_frame
	if main.unclaimed_gold <= 0 or main.unclaimed_xp <= 0:
		push_error("Offline idle reward did not arrive")
		quit(1)
	print("offline_reward_ok gold=%d xp=%d" % [main.unclaimed_gold, main.unclaimed_xp])
	main.idle_stage_kills = main.idle_stage_target - 1
	# Advance the actual movement/windup/death loop rather than teleporting
	# only the old display coordinate (navigation now has one authority).
	main.set_physics_process(false)
	for _step in 1200:
		main._advance_auto_hunt(1.0 / 60.0)
		if main.idle_chest_gold > 0:
			break
	if main.idle_stage <= 1 or main.idle_chest_gold <= 0 or main.idle_chest_xp <= 0:
		push_error("Idle stage chest did not unlock")
		quit(1)
	print("idle_chest_ok stage=%d chest_gold=%d chest_xp=%d" % [main.idle_stage, main.idle_chest_gold, main.idle_chest_xp])
	main._claim_rewards()
	if main.wallet_gold <= 0 or main.wallet_xp <= 0:
		push_error("Idle reward claim failed")
		quit(1)
	print("idle_claim_ok wallet_gold=%d wallet_xp=%d" % [main.wallet_gold, main.wallet_xp])
	main.queue_free()
	await process_frame
	quit(0)
