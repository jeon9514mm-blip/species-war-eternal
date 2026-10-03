extends "res://scripts/V83UpgradeTestBase.gd"
## Public raid catalog input, visibility and encounter preview consistency.
const BOSSES: Dictionary = {
	"gray_meadow":{"max_hp":36000,"attack":600,"recommended_power":5400},
	"forgotten_mine":{"max_hp":72000,"attack":1200,"recommended_power":10800},
	"moonrest_forest":{"max_hp":124000,"attack":2060,"recommended_power":18600},
}
var main: Node

func _init() -> void: run.call_deferred()

func node(named: String) -> Node:
	return main.content_root.find_child(named, true, false)

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new(); motion.position = point; root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = down; event.position = point
		root.push_input(event, true)

func press(named: String) -> void:
	var target: Button = node(named)
	check(target != null, "raid UI control exists " + named)
	if target == null: return
	check(target.is_visible_in_tree() and not target.disabled, "raid UI control is available " + named)
	var clip: Rect2 = main.get_viewport_rect()
	var ancestor: Node = target.get_parent()
	while ancestor is Control:
		if ancestor.clip_contents: clip = clip.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	check(clip.grow(1).encloses(target.get_global_rect()), "raid UI control is visible without scrolling " + named)
	click(target.get_global_rect().get_center()); await settle()

func rewards() -> Dictionary:
	return {"gold":main.wallet_gold,"xp":main.wallet_xp,"gems":main.wallet_gems,"crystals":main.raid_crystals,
		"unclaimed_gold":main.unclaimed_gold,"unclaimed_xp":main.unclaimed_xp,
		"clears":main.raid_clears.duplicate(true),"items":main.loot_inventory.duplicate(true),"overflow":main.equipment_overflow.duplicate(true)}

func audit_catalog(label: String) -> void:
	check(main.active_screen == "meta_hub" and str(main.get_meta("content_meta_tab", "")) == "raids", label + " retains the raid content tab")
	var grid: GridContainer = node("RaidCatalogGrid")
	var scroll: ScrollContainer = node("PortraitContentScroll")
	check(grid != null and grid.columns == 3 and grid.get_child_count() == 3, label + " shows three bosses in one row")
	if grid == null or scroll == null: return
	var visible: Rect2 = main.get_viewport_rect().intersection(scroll.get_global_rect()).grow(1)
	check(scroll.scroll_vertical == 0, label + " starts with all actions visible without vertical scrolling")
	check(node("PracticeOpen") == null and node("CombatPresetsOpen") == null, label + " gives the catalog its own space without unrelated practice controls")
	check(visible.encloses(node("RaidPartySummary").get_global_rect()), label + " party status and formation action remain visible")
	for tab: String in ["daily", "tower", "weekly", "raids", "quests"]:
		check(node("ContentTab_" + tab) != null and visible.encloses(node("ContentTab_" + tab).get_global_rect()), label + " keeps content tab " + tab + " accessible")
	var prior: Control
	for zone: String in BOSSES:
		var card: Control = node("RaidCatalog_" + zone)
		var enter: Button = node("RaidCatalogEnter_" + zone)
		var scene: Control = node("RaidCatalogScene_" + zone)
		check(card != null and scene != null and enter != null, label + " retains existing named catalog controls " + zone)
		if card == null or scene == null or enter == null: continue
		check(visible.encloses(card.get_global_rect()), label + " full boss card fits alongside the other bosses " + zone)
		check(visible.encloses(enter.get_global_rect()) and enter.size.y >= 48, label + " boss entry is a visible touch target " + zone)
		check(card.get_global_rect().grow(1).encloses(scene.get_global_rect()), label + " boss artwork stays inside its card " + zone)
		if prior != null:
			check(is_equal_approx(card.get_global_rect().position.y, prior.get_global_rect().position.y) and prior.get_global_rect().end.x <= card.get_global_rect().position.x + 1, label + " cards share a row without overlap " + zone)
		prior = card
		var stats: Label = node("RaidCatalogStats_" + zone)
		var preview: Dictionary = stats.get_meta("raid_stats", {}) if stats != null else {}
		for key: String in ["max_hp", "attack", "recommended_power"]:
			check(int(preview.get(key, -1)) == int(BOSSES[zone][key]), label + " preview matches the tenfold base " + zone + " " + key)
		check(stats != null and stats.tooltip_text.contains("HP %d" % BOSSES[zone].max_hp) and stats.tooltip_text.contains("공격력 %d" % BOSSES[zone].attack), label + " displayed boss stats retain exact numeric details " + zone)
		for text: Label in card.find_children("*", "Label", true, false):
			if not text.is_visible_in_tree(): continue
			check(card.get_global_rect().grow(1).encloses(text.get_global_rect()), label + " card text stays within the card " + text.text.left(28))
			check(text.get_line_count() * text.get_line_height() <= text.size.y + 2 or (text.max_lines_visible > 0 and text.tooltip_text == text.text), label + " card text has readable height " + text.text.left(28))

func run() -> void:
	main = await make_main("aurelia", 3)
	root.size = Vector2i(1280,720); await settle()
	main._build_boss_select_screen(); await settle()
	audit_catalog("1280 catalog")
	var before: Dictionary = rewards()
	for dimensions: Vector2i in [Vector2i(1600,720), Vector2i(960,540), Vector2i(1280,720)]:
		root.size = dimensions; await settle()
		check(main.get_viewport_rect().size.x >= 1280 and main.get_viewport_rect().size.x > main.get_viewport_rect().size.y, "physical resize preserves landscape production canvas " + str(dimensions))
		audit_catalog("resized catalog " + str(dimensions))
		check(rewards() == before, "catalog resizing cannot alter rewards or equipment " + str(dimensions))
	await press("ContentTab_daily")
	check(main.active_screen == "meta_hub" and node("DungeonDetailCard") != null and node("PracticeOpen") != null, "switching to daily content retains existing dungeon and practice controls")
	await press("ContentTab_raids"); audit_catalog("return from daily")
	await press("ContentPartyButton")
	check(main.active_screen == "hero_select" and main.content_party_context.get("kind") == "meta" and str(main.get_meta("content_meta_tab", "")) == "raids", "catalog formation records the meta return route and raid tab")
	await press("RosterConfirm")
	check(main.content_party_context.is_empty(), "formation confirmation consumes its return context")
	audit_catalog("formation return")
	check(rewards() == before, "formation round trip grants no raid rewards")
	main._restore_deployed_heroes(["leonhardt"]); main.hero_progress["leonhardt"] = {"level":1,"xp":0}
	main.idle_stage = 1; main._build_boss_select_screen(); await settle()
	check(not node("RaidCatalogEnter_gray_meadow").disabled, "first unlocked boss remains available to a low-level party")
	for zone: String in ["forgotten_mine", "moonrest_forest"]:
		var locked: Button = node("RaidCatalogEnter_" + zone)
		check(locked.disabled and locked.text.contains("스테이지"), "locked boss explains its unlock requirement " + zone)
		var selected_zone: String = main.selected_raid_id
		click(locked.get_global_rect().get_center()); await settle()
		check(main.active_screen == "meta_hub" and main.selected_raid_id == selected_zone, "locked boss tap cannot enter or change target " + zone)
	main.idle_stage = 100; main.deployed_heroes.clear(); main._build_boss_select_screen(); await settle()
	audit_catalog("empty party")
	for zone: String in BOSSES:
		check(node("RaidCatalogEnter_" + zone).disabled and node("RaidCatalogReadiness_" + zone).text.contains("편성 필요"), "empty party disables entry with a clear reason " + zone)
		click(node("RaidCatalogEnter_" + zone).get_global_rect().get_center()); await settle()
		check(main.active_screen == "meta_hub" and not main.raid_running, "empty-party boss tap stays in catalog " + zone)
	check(not node("ContentPartyButton").disabled, "empty party can still reach formation")
	main._restore_deployed_heroes(["leonhardt"])
	for zone: String in BOSSES:
		main._build_boss_select_screen(); await settle()
		check(main._calculate_party_power() < int(BOSSES[zone].recommended_power), "fixture is below this boss recommendation " + zone)
		check(not node("RaidCatalogEnter_" + zone).disabled and node("RaidCatalogReadiness_" + zone).text.contains("전투력 부족"), "unlocked underpowered party receives guidance and can still enter " + zone)
		before = rewards()
		var hunt_zone: String = main.current_zone_id
		await press("RaidCatalogEnter_" + zone)
		check(main.active_screen == "raid" and main.selected_raid_id == zone and not main.raid_running, "boss card opens the correct preparation screen without starting combat " + zone)
		var view: Node = node("PortraitRaidView")
		check(view != null, "raid preparation presenter exists " + zone)
		if view == null: continue
		check(view.information.tooltip_text.contains("HP %d" % BOSSES[zone].max_hp) and view.information.tooltip_text.contains("공격력 %d" % BOSSES[zone].attack), "preparation stats match catalog values before the first encounter " + zone)
		check(view.hp.value == 100.0 and view.party_summary.text.contains(main._compact_hud_amount(int(BOSSES[zone].recommended_power))), "preparation shows full initial health and the same recommendation " + zone)
		await press("PortraitRaidStart")
		if is_instance_valid(main.combat_timer): main.combat_timer.stop()
		check(main.raid_running and main.raid_boss_max_hp == int(BOSSES[zone].max_hp) and main.raid_boss_attack == int(BOSSES[zone].attack), "actual encounter starts with exactly the shown HP and attack " + zone)
		main._finish_raid("cancelled"); await settle()
		await press("PortraitMenuBack")
		audit_catalog("return from " + zone)
		check(main.current_zone_id == hunt_zone and rewards() == before, "preparation and cancelled encounter preserve hunting region and rewards " + zone)
	await dispose(main); done("raid_catalog_ui")
