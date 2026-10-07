extends "res://tests/support/V83UpgradeTestBase.gd"
const OBSERVER = preload("res://tests/support/V836RaidObserveHost.gd")
var natural_healing: int = 0
var natural_guard_damage: int = 0
var natural_core_damage: int = 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for faction: String in ["aurelia", "noxfera"]:
		var main = OBSERVER.new()
		main.save_state_path = "user://raid-real-" + faction + ".json"
		root.add_child(main)
		await settle()
		main.set_process(false)
		main.set_physics_process(false)
		main.selected_faction = faction
		main.current_zone_id = "gray_meadow"
		main.idle_stage = 100
		main.party_slot_legacy_cap = 10
		var ids: Array[String] = []
		for hero in ROSTER.roster(faction):
			if ids.size() < 10: ids.append(str(hero.id))
		main._restore_deployed_heroes(ids)
		for id in ids: main.hero_progress[id] = {"level": 60, "xp": 0}
		main.combat_effects_enabled = false
		main.sound_effects_enabled = false
		main.skill_auto = true
		main.ultimate_auto = true
		main._offline_checked = true
		for zone: String in ["gray_meadow", "forgotten_mine", "moonrest_forest"]:
			await one_raid(main, faction, zone, "10hero-Lv60")
		# Lower-power, role-based fixture lets bosses act; no HP edits or forced victory.
		var roles: Array[String] = ["탱커", "서포터", "컨트롤러"]
		var small: Array[String] = []
		for role in roles:
			for hero in ROSTER.roster(faction):
				if str(hero.role_group) == role:
					small.append(str(hero.id))
					break
		main._restore_deployed_heroes(small)
		for id in small: main.hero_progress[id] = {"level": 1, "xp": 0}
		for zone: String in ["forgotten_mine", "moonrest_forest"]:
			await one_raid(main, faction, zone, "3hero-Lv1-initial")
		await dispose(main)
	check(natural_healing > 0, "healing actually occurs in natural raid fixtures")
	check(natural_guard_damage > 0, "natural guard phase exercised")
	check(natural_core_damage > 0, "natural crystal phase exercised")
	done("v836_raid_battle")

func one_raid(main, faction: String, zone: String, fixture: String) -> void:
	main.selected_raid_id = zone
	main._build_raid_screen()
	await settle()
	main.raid_observed = {"boss_damage": 0, "guard_damage": 0, "add_damage": 0, "healing": 0}
	main._start_raid()
	check(main.raid_running, "raid starts " + faction + zone)
	main.combat_timer.stop()
	var steps: int = 0
	while main.raid_running and steps < 7500:
		main._advance_raid_encounter(1.0 / 30.0)
		steps += 1
		if steps % 120 == 0: await process_frame
	check(not main.raid_running and main.raid_outcome in ["victory", "timeout", "defeat"], "natural raid termination " + faction + zone)
	var report: Dictionary = main.get_meta("last_raid_contribution", {})
	check(not report.is_empty() and report.entry.zone == zone, "report emitted with correct boss")
	if report.is_empty(): return
	for metric: String in ["boss_damage", "guard_damage", "add_damage"]:
		check(int(report.totals[metric]) == int(main.raid_observed[metric]), "independently observed HP " + metric + faction + zone)
	check(report.total_damage == main.raid_damage_dealt, "sum equals existing raid applied damage")
	check(int(report.totals.healing_given) == int(main.raid_observed.healing), "actual not nominal provider healing")
	check(int(report.totals.interrupts) == main.raid_interrupt_count, "actual interrupt count match")
	var sum: int = 0
	for row in report.actors: sum += int(row.damage)
	check(sum == report.total_damage, "source totals conservation")
	var before: Dictionary = economic(main)
	main._open_raid_report()
	await settle()
	main._open_raid_report()
	await settle()
	check(economic(main) == before, "viewing report cannot grant rewards or mutate growth")
	check(main.get_meta("raid_report_saved", false), "real report persisted " + zone)
	natural_healing += int(report.totals.healing_given)
	natural_guard_damage += int(report.totals.guard_damage)
	natural_core_damage += int(report.totals.add_damage)
	print("raid_natural faction=%s zone=%s fixture=%s outcome=%s seconds=%.3f damage=%d healing=%d guard=%d cores=%d" % [faction, zone, fixture, main.raid_outcome, report.elapsed, report.total_damage, report.totals.healing_given, report.totals.guard_damage, report.totals.add_damage])
