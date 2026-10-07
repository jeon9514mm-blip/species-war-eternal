extends SceneTree
## UI/HP fixtures intentionally set progression values to exercise all screens;
## these are not reported as naturally earned campaign/collection milestones.
const SERVICE = preload("res://scripts/progression/LongTermGoalsService.gd")
var main: Node
var checks: int = 0
var failures: Array[String] = []
func _init() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func settle() -> void:
	for frame in 7: await process_frame
func item(id: String) -> Node:
	return main.content_root.find_child(id, true, false)
func _run() -> void:
	root.content_scale_size = Vector2i(720, 1280); root.size = Vector2i(720, 1280)
	main = preload("res://scenes/PortraitMain.tscn").instantiate()
	main.save_state_path = "user://v81-ui-%d.json" % OS.get_process_id()
	root.add_child(main); await settle()
	main.set_physics_process(false); main.set_process(false); main._offline_checked = true
	main.combat_effects_enabled = false; main.sound_effects_enabled = false
	main.selected_faction = "aurelia"; main.idle_stage = 100; main.party_slot_legacy_cap = 10
	main._restore_deployed_heroes(["leonhardt", "mira", "elisia"])
	check(main._today_key() == Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) + 9 * 3600), "shared daily key is explicitly KST")
	main._build_lobby_screen(); await settle()
	check(item("LobbyLongTermGoals") != null and item("LobbyLongTermGoalAction") != null, "goals reachable from camp")
	item("LobbyLongTermGoalAction").emit_signal("pressed"); await settle()
	check(main.active_screen == "meta_hub" and item("LongTermGoalSummary") != null, "opens actual goal tab")
	for scope in ["guide", "daily", "weekly", "achievement", "legacy"]:
		check(item("GoalTab_" + scope) != null, "goal scope reachable " + scope)
	check(item("GoalClaim_guide_001") != null and item("GoalClaim_guide_001").disabled, "unfinished guide disabled")
	check(item("GoalCard_guide_004") == null, "guide list shows current plus two previews, not 100 cards")
	SERVICE.record(main, "hunt_packs", 5)
	main._open_goal_screen(); await settle()
	var gold: int = main.wallet_gold
	check(not item("GoalClaim_guide_001").disabled, "completed guide enables claim")
	item("GoalClaim_guide_001").emit_signal("pressed"); await settle()
	check(main.long_term_goals["factions"]["aurelia"]["guide_claimed"] == 1 and main.wallet_gold == gold + 120, "UI claim awards exact guide reward")
	check(item("GoalCard_guide_002") != null and item("GoalCard_guide_001") == null, "next guide replaces completed guide")
	item("GoalGo_guide_002").emit_signal("pressed"); await settle()
	check(main.active_screen == "growth", "guide routes to real growth page")
	main.set_meta("goal_scope", "achievement"); main._open_goal_screen(); await settle()
	check(item("GoalTitleSelection") != null and item("GoalClaimAll_achievement") != null, "achievement titles and claim-all visible")
	var before_hp: int = main._hero_combat_stats("leonhardt")["max_hp"]
	check(is_equal_approx(main._goal_hp_multiplier("leonhardt"), 1.0), "unclaimed collection never buffs stats")
	# Stage-100 fixture discovers the existing 15 heroes; only collection
	# achievements are ready before claiming, hence exactly three.
	var collected: Dictionary = main._claim_all_goals("achievement", main._goal_claim_context("achievement"))
	check(collected.get("ok", false) and collected["count"] == 3, "all three collection tiers claimed")
	check(is_equal_approx(main._goal_hp_multiplier("leonhardt"), 1.015), "collection bonus capped at 1.5 percent")
	check(main._hero_combat_stats("leonhardt")["max_hp"] == int(round(float(before_hp) * 1.015)), "bonus connected to real hero HP computation")
	check(is_equal_approx(main._goal_hp_multiplier("valeria"), 1.0), "foreign hero never gets active-faction bonus")
	check(SERVICE.equip_title(main, "collection_15", "aurelia"), "earned collection title equips")
	main._build_combat_screen(); await settle()
	var hud: Node = main.find_child("PortraitHud", true, false)
	check(hud != null and hud.profile_name.text == "진영의 기록자", "equipped title displayed in actual HUD")
	var title_hp: int = main._hero_combat_stats("leonhardt")["max_hp"]
	SERVICE.equip_title(main, "", "aurelia")
	check(main._hero_combat_stats("leonhardt")["max_hp"] == title_hp, "title itself has no stat modifier")
	var goal_button: Node = hud.find_child("PortraitQuestButton", true, false)
	goal_button.emit_signal("pressed"); await settle()
	check(item("LongTermGoalSummary") != null, "HUD goal button goes to goal tab instead of stale dungeon")
	main._build_codex_screen(); await settle()
	check(item("CodexCollectionProgress") != null and item("CodexOpenGoals") != null, "codex shows collection progress and shortcut")
	main.set_meta("goal_scope", "legacy"); main._open_goal_screen(); await settle()
	check(item("ContentQuestClaim_stage5") != null and not item("ContentQuestClaim_stage5").disabled, "old three quests remain accessible")
	gold = main.wallet_gold
	item("ContentQuestClaim_stage5").emit_signal("pressed"); await settle()
	check(main.quest_claimed.get("stage5", false) and main.wallet_gold == gold + 500, "old quest amount preserved")
	check(item("ContentQuestClaim_stage5").disabled, "old quest remains single claim")
	# Load guard test: unsaved goal receipts cannot be overwritten by an older save.
	main.goals_save_pending = true
	var state: String = JSON.stringify(main.long_term_goals)
	main._load_idle_state()
	check(main.save_load_status == "goals_save_pending" and JSON.stringify(main.long_term_goals) == state, "pending rewards block loading older save")
	main._open_goal_screen(); await settle()
	check(item("GoalPendingSaveNotice") != null and item("GoalRetrySave") != null, "pending IO warning and retry reachable")
	item("GoalRetrySave").emit_signal("pressed"); await settle()
	check(not main.goals_save_pending and main.last_save_status == "saved", "actual UI retry writes without new award")
	main.selected_faction = "noxfera"
	SERVICE.refresh(main)
	check(is_equal_approx(main._goal_hp_multiplier("valeria"), 1.0), "opposite faction cannot inherit claimed HP bonus")
	main.free(); await settle()
	# v82: audio playback teardown is asynchronous even with the Dummy driver.
	await create_timer(0.3).timeout
	# Verify legacy entry uses the same functional goal widget, not an orphaned API.
	main = preload("res://scenes/Main.tscn").instantiate()
	main.save_state_path = "user://v81-legacy-ui-%d.json" % OS.get_process_id()
	root.add_child(main); await settle()
	main.set_process(false); main.set_physics_process(false); main.selected_faction = "aurelia"
	main._open_goal_screen(); await settle()
	check(item("LongTermGoalSummary") != null and item("GoalTab_daily") != null, "legacy goal entry renders shared behavior")
	main.free(); await settle()
	# v82: audio playback teardown is asynchronous even with the Dummy driver.
	await create_timer(0.3).timeout
	print("v81_goal_ui checks=%d failures=%s" % [checks, JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
