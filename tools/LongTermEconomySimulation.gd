extends SceneTree
const HOST=preload("res://tools/EconomySimulationHost.gd")
var rows: Array[Dictionary]=[]
var first_session: Dictionary={}
func _init() -> void: run.call_deferred()
func run() -> void:
	var arguments:=OS.get_cmdline_user_args()
	var faction: String=arguments[0] if arguments.size()>0 else "aurelia"
	var fixture_seed:=int(arguments[1]) if arguments.size()>1 else 3401
	var days:=int(arguments[2]) if arguments.size()>2 else 30
	var main=HOST.new();root.add_child(main);main.boot(faction,fixture_seed)
	for day in range(1,days+1):
		main.simulation_day=day
		# One 10-minute active session plus one capped 8-hour offline receipt/day.
		# No cash, support-ad payouts, purchased summons or manually gifted stats.
		var daily_button:=Button.new();var daily_status:=Label.new()
		main._claim_daily_reward(daily_button,daily_status);daily_button.free();daily_status.free()
		main.manage()
		for step in 1200:
			main.elapsed_online+=.5;main._advance_auto_hunt(.5)
			if main.combat_kills>0 and main.first_pack_seconds<0:main.first_pack_seconds=main.elapsed_online
			if step%120==119:main.manage()
			if step%240==0:await process_frame
		if day==1:first_session=main.checkpoint();print("FIRST_TEN_MINUTES ",faction," ",fixture_seed," ",JSON.stringify(first_session))
		main._offline_checked=false;main.last_idle_timestamp=int(Time.get_unix_time_from_system())-28800
		main._calculate_offline_reward();main._claim_offline_rewards();main.manage()
		print("ECONOMY_DAY_DONE ",faction," ",fixture_seed," day=",day)
		if day in [1,7,30]:rows.append(main.checkpoint());print("ECONOMY_CHECKPOINT ",faction," ",fixture_seed," ",JSON.stringify(rows[-1]))
	var report={"schema":1,"economy_revision":preload("res://scripts/GrowthEconomyRules.gd").REVISION,"first_ten_minutes":first_session,"faction":faction,"seed":fixture_seed,"active_seconds_per_day":600,"offline_seconds_per_day":28800,"assumptions":"Fixed starter guardian; fill unlocked slots, spend research, recommend gear and upgrade once/minute. No real-money/ad payouts or extra dungeon rewards. Full active combat and production offline receipts; visual nodes and disk saves omitted.","rows":rows}
	for argument in arguments:
		if argument.begins_with("--report="):FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	main.free();print("ECONOMY_SIMULATION_COMPLETE ",faction," ",fixture_seed);quit()
