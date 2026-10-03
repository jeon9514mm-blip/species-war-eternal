extends RefCounted
const LEDGER = preload("res://scripts/RaidContributionLedger.gd")
const ARCHIVE = preload("res://scripts/RaidReportArchive.gd")
static func active(main) -> bool:
	# Godot treats a null default as a missing-key error; non-raid calls are normal.
	if not main.has_meta("raid_contribution"): return false
	var ledger = main.get_meta("raid_contribution")
	return ledger != null and not ledger.closed and ledger.serial == main.raid_encounter_serial and main.raid_running and main.active_screen == "raid" and not main._application_suspended
static func begin(main) -> void:
	var ledger = LEDGER.new()
	ledger.begin(main.raid_encounter_serial, main.deployed_heroes, main.hero_battle_state,
		{"faction":main.selected_faction,"zone":main.raid_encounter_zone,"name":main.raid_boss_name,
		"max_hp":main.raid_boss_max_hp,"attack":main.raid_boss_attack,"balance_revision":preload("res://scripts/RaidBalance.gd").REVISION,
		"auto_skill":main.skill_auto,"auto_ultimate":main.ultimate_auto})
	main.set_meta("raid_contribution",ledger)
static func add(main, source: String, kind: String, amount: int) -> void:
	if active(main): main.get_meta("raid_contribution").add(main.raid_encounter_serial,source,kind,amount)
static func incoming(main, id: String, before: int, after: int, absorbed: int) -> void:
	if active(main): main.get_meta("raid_contribution").incoming(main.raid_encounter_serial,id,before,after,absorbed,main.raid_elapsed)
static func healed(main, id: String, amount: int) -> void:
	if active(main): main.get_meta("raid_contribution").healed(main.raid_encounter_serial,id,amount)
static func finish(main, outcome: String) -> void:
	if not main.has_meta("raid_contribution"): return
	var ledger = main.get_meta("raid_contribution")
	if ledger == null: return
	if not ledger.closed and ledger.serial == main.raid_encounter_serial:
		var received: int = 0
		for id in ledger.actors:
			if not str(id).begins_with("$"): received += int(ledger.actors[id].get("healing_received",0))
		ledger.add(main.raid_encounter_serial,"$unknown","healing_given",maxi(0,received-int(ledger.totals.get("healing_given",0))))
	var report: Dictionary = ledger.finish(main.raid_encounter_serial,outcome,main.raid_elapsed,main.hero_battle_state)
	if report.is_empty(): return
	report["stamp"] = "%d-%d-%d" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec(),main.raid_encounter_serial]
	main.set_meta("last_raid_contribution",report)
	var path: String = str(main.get_meta("raid_report_path",ARCHIVE.PATH))
	main.set_meta("raid_report_saved",ARCHIVE.append(path,report))
