extends "res://scripts/V83UpgradeTestBase.gd"
## Observations only. Isolated temporary player data is required by the runner.
const SAVE = preload("res://scripts/GameSaveCoordinator.gd")
var observations: Dictionary = {}
func _init() -> void: run.call_deferred()
func nodes_under(node: Node) -> int:
	var count := 1
	for child: Node in node.get_children(): count += nodes_under(child)
	return count
func run() -> void:
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	var main = await make_main("aurelia",3)
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	main._offline_checked=true;main.loot_inventory=[]
	var base: Dictionary=main._gear_item("","leonhardt","weapon").duplicate(true)
	base["locked"]=true
	var cases: Array=[]
	var quick: bool="--quick-stash" in OS.get_cmdline_user_args()
	var sizes: Array=[50,500] if quick else [50,500,1900]
	for count: int in sizes:
		main.equipment_overflow=[]
		for index: int in count:
			var item: Dictionary=base.duplicate(true);item["id"]="audit-stash-%d"%index;main.equipment_overflow.append(item)
		main._build_lobby_screen();await settle()
		var start: int=Time.get_ticks_usec();main._build_equipment_stash()
		var build_ms: float=(Time.get_ticks_usec()-start)/1000.0
		await settle()
		var scroll: ScrollContainer=main.content_root.find_child("PortraitContentScroll",true,false)
		var row: Dictionary={"items":count,"synchronous_build_ms":build_ms,"content_nodes":nodes_under(main.content_root),"save_bytes":JSON.stringify(SAVE.snapshot(main)).to_utf8_buffer().size()}
		if count==500:
			scroll.scroll_vertical=2000;await settle();row["scroll_before_claim"]=scroll.scroll_vertical
			var result: Dictionary=main._gear_claim_overflow("audit-stash-20")
			main._build_equipment_stash();await settle()
			row["claim_ok"]=result.ok;row["scroll_after_claim"]=main.content_root.find_child("PortraitContentScroll",true,false).scroll_vertical
		cases.append(row)
	observations["stash"]=cases
	main.equipment_overflow=[];main.idle_stage=3
	for id: String in main._deployed_hero_ids():main.hero_progress[id]={"level":10,"xp":0}
	observations["first_raid_readiness"]={"party_power":main._calculate_party_power(),"recommended":preload("res://scripts/RaidBalance.gd").stats(main._zone_data().gray_meadow).recommended_power}
	main._build_lobby_screen();await settle()
	observations["challenge_report_persistence"]="Runtime-only: ChallengeReportScreens explicitly states records disappear on app exit."
	var output: String="quick-performance.json" if quick else "performance.json"
	var path: String=ProjectSettings.globalize_path("res://checks/stash-improvement/"+output)
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(observations,"  ")+"\n");file.close()
	print("AUDIT_OBSERVATIONS "+JSON.stringify(observations))
	await dispose(main);quit()
