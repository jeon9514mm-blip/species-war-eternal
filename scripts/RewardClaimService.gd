extends RefCounted

## v83: RewardClaimService. Main remains the single owner of mutable game state.
## The injected host supplies state, virtual UI hooks and runtime refreshes.
## No cached host reference, duplicate wallet, RNG or save schema is introduced.

static func claim_daily_reward(main: Node, button: Button, status: Label) -> void:
	if not preload("res://scripts/SaveSafety.gd").allow_mutation(main): return
	var today = main._today_key()
	if not main.daily_reward_claimed_day.is_empty() and today <= main.daily_reward_claimed_day:
		status.text = "오늘의 보상은 이미 받았습니다."
		return
	main.daily_reward_claimed_day = today
	main.wallet_gems += 30
	main.unclaimed_gold += 100
	status.text = "일일 보상 획득 · 젬 +30 · 골드 +100"
	button.text = "오늘의 보상 수령 완료"
	button.disabled = true
	main._save_idle_state()


static func claim_rewarded_ad(main: Node, button: Button, status: Label) -> void:
	if not preload("res://scripts/SaveSafety.gd").allow_mutation(main): return
	var today = main._today_key()
	if main.rewarded_ad_day.is_empty() or today > main.rewarded_ad_day:
		main.rewarded_ad_day = today
		main.rewarded_ad_claimed_count = 0
	if main.rewarded_ad_claimed_count >= 3:
		status.text = "오늘의 지원 보상을 모두 받았습니다."
		return
	main.rewarded_ad_claimed_count += 1
	main.wallet_gems += 5
	main.unclaimed_gold += 50
	status.text = "지원 보상 획득 · 젬 +5 · 골드 +50 (%d/3)" % main.rewarded_ad_claimed_count
	button.text = "지원 보상  %d/3" % main.rewarded_ad_claimed_count
	main._save_idle_state()


static func claim_rewards(main: Node) -> void:
	if not preload("res://scripts/SaveSafety.gd").allow_mutation(main): return
	if main.unclaimed_gold == 0 and main.unclaimed_xp == 0 and main.idle_chest_gold == 0 and main.idle_chest_xp == 0:
		main._show_toast("받을 보상이 없습니다.")
		return
	main.wallet_gold += main.unclaimed_gold
	main.wallet_xp += main.unclaimed_xp
	main.wallet_gold += main.idle_chest_gold
	main.wallet_xp += main.idle_chest_xp
	main.unclaimed_gold = 0
	main.unclaimed_xp = 0
	main.idle_chest_gold = 0
	main.idle_chest_xp = 0
	main._update_reward_labels()
	main._update_stage_label()
	var latest: Label = main.combat_labels.get("latest")
	if latest != null:
		latest.text = "최근 기록\n사냥 보상을 수령했습니다.\n현재 골드 %d  ·  경험치 %d" % [main.wallet_gold, main.wallet_xp]
	main._save_idle_state()
