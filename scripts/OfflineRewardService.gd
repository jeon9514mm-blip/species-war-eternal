extends RefCounted

## v83: OfflineRewardService. Main remains the single owner of mutable game state.
## The injected host supplies state, virtual UI hooks and runtime refreshes.
## No cached host reference, duplicate wallet, RNG or save schema is introduced.

static func calculate_offline_reward(main: Node) -> void:
	if main._save_blocked_for_newer_version or preload("res://scripts/SaveSafety.gd").pending(main): return
	if main._offline_checked:
		return
	main._offline_checked = true
	var now = int(Time.get_unix_time_from_system())
	var elapsed = clampi(now - main.last_idle_timestamp, 0, main.IDLE_REWARD_CAP_SECONDS) if main.last_idle_timestamp > 0 else 0
	var clock_rolled_back = now < main.last_idle_timestamp
	main.last_idle_timestamp = maxi(now, main.last_idle_timestamp)
	main.offline_reward_gold = 0
	main.offline_reward_xp = 0
	main.offline_reward_seconds = 0
	main.offline_pet_xp = 0
	main.offline_rations = 0
	main.offline_gear_rolls = 0
	main.offline_stage_clears = 0
	main.offline_efficiency = 0
	if elapsed < main.IDLE_KILL_INTERVAL_SECONDS or main.deployed_heroes.is_empty():
		if not clock_rolled_back:
			main._save_idle_state()
		return

	if not main._is_zone_unlocked(main.current_zone_id):
		main.current_zone_id = "gray_meadow"
	var zone: Dictionary = main._current_zone()
	var productivity = preload("res://scripts/HuntProductivity.gd")
	var observed: Dictionary = productivity.observed(main, str(main.current_zone_id))
	if observed.is_empty():
		# New/changed parties must demonstrate the selected region's throughput.
		# Preserve a starter allowance for existing saves without measurements.
		zone = main._zone_data()["gray_meadow"]
		observed = productivity.observed(main, "gray_meadow")
	main.offline_reward_basis = "%s · %s" % [str(zone["name"]), "최근 사냥 기록 기준" if not observed.is_empty() else "기본 사냥 기준"]
	var estimate = main.idle_hunt_estimator.estimate(
		elapsed,
		main._calculate_party_power(),
		main.deployed_heroes.size(),
		zone,
		main.idle_stage,
		main.idle_stage_kills,
		main.idle_stage_target,
		observed
	)
	var kills = int(estimate.get("kills", 0))
	if kills <= 0:
		main._save_idle_state()
		return

	main.offline_reward_gold = main._guardian_reward(int(estimate.get("gold", 0)),"offline_gold")
	main.offline_reward_xp = main._guardian_reward(int(estimate.get("xp", 0)),"offline_xp")
	main.offline_pet_xp = int(estimate.get("pet_xp", 0))
	main.offline_reward_seconds = elapsed
	main.offline_rations = int(estimate.get("rations", 0))
	main.offline_gear_rolls = int(estimate.get("gear_rolls", 0))
	main.offline_stage_clears = int(estimate.get("stage_clears", 0))
	main.offline_efficiency = int(round(float(estimate.get("efficiency", 0.0)) * 100.0))

	main.unclaimed_gold += main.offline_reward_gold
	main.unclaimed_xp += main.offline_reward_xp
	main._grant_hero_xp(main.offline_reward_xp)
	main._grant_pet_xp(main.offline_pet_xp)
	main.faction_war_state.add_rations(main.offline_rations)

	var chest_gold = main._guardian_reward(int(estimate.get("chest_gold", 0)),"offline_gold")
	var chest_xp = main._guardian_reward(int(estimate.get("chest_xp", 0)),"offline_xp")
	if main.offline_stage_clears > 0:
		main.idle_chest_gold += chest_gold
		main.idle_chest_xp += chest_xp
		main._grant_hero_xp(chest_xp)
		main.idle_stage += main.offline_stage_clears
	main.idle_stage_kills = int(estimate.get("stage_kills", main.idle_stage_kills))
	main._refresh_growth_runtime()

	# Full 8-hour idling can represent thousands of kills. Replaying every
	# equipment roll would stall mobile devices and overflow inventory, so use
	# a bounded loot-cache sample while keeping online drops unchanged.
	for _roll in main.offline_gear_rolls:
		main._roll_equipment_drop(zone)

	main._on_offline_hunt_reward(main.offline_reward_gold,main.offline_reward_xp,chest_gold if main.offline_stage_clears>0 else 0,chest_xp if main.offline_stage_clears>0 else 0)
	main._offline_notice_pending = true
	main._save_idle_state()
