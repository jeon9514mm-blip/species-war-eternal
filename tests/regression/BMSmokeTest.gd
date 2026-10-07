extends SceneTree

func _init() -> void:
	var scene = preload("res://scenes/Main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.daily_reward_claimed_day = ""
	main.rewarded_ad_day = ""
	main.rewarded_ad_claimed_count = 0
	main.wallet_gems = 0
	main.unclaimed_gold = 0
	var daily_button = Button.new()
	var daily_status = Label.new()
	main._claim_daily_reward(daily_button, daily_status)
	if main.wallet_gems != 30 or main.unclaimed_gold != 100:
		push_error("Daily reward failed")
		quit(1)
	main._claim_daily_reward(daily_button, daily_status)
	if main.wallet_gems != 30:
		push_error("Daily reward was claimable twice")
		quit(1)
	var ad_button = Button.new()
	var ad_status = Label.new()
	for _i in range(3):
		main._claim_rewarded_ad(ad_button, ad_status)
	if main.wallet_gems != 45 or main.unclaimed_gold != 250:
		push_error("Rewarded ad reward total is incorrect")
		quit(1)
	main._claim_rewarded_ad(ad_button, ad_status)
	if main.wallet_gems != 45:
		push_error("Rewarded ad daily cap failed")
		quit(1)
	print("bm_smoke_test_ok gems=%d unclaimed_gold=%d ad_count=%d" % [main.wallet_gems, main.unclaimed_gold, main.rewarded_ad_claimed_count])
	daily_button.free()
	daily_status.free()
	ad_button.free()
	ad_status.free()
	main.presentation_runtime.audio.shutdown()
	await create_timer(.1).timeout
	main.free()
	await create_timer(.1).timeout
	quit(0)
