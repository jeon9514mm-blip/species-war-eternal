extends "res://scripts/V83UpgradeTestBase.gd"
const W = preload("res://scripts/InvasionWaveState.gd")
const F = preload("res://scripts/HuntFieldService.gd")
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var planner = W.new()
	check(planner.can_enter(0) and planner.next_size()==15,"first corps immediate and 15")
	planner.register({}); planner.advance(3.999)
	check(not planner.can_enter(5),"4 game seconds hard boundary")
	planner.advance(.001)
	check(planner.can_enter(5) and not planner.can_enter(6),"remaining 5 boundary")
	planner.register({});planner.advance(4)
	check(not planner.can_enter(0),"two corps hard cap")
	check(planner.take_finished([{"corps_id":1,"hp":0},{"corps_id":2,"hp":1}]).size()==1,"settles one corps while other lives")
	check(planner.take_finished([{"corps_id":1,"hp":0},{"corps_id":2,"hp":1}]).is_empty(),"receipt consumed once")
	planner.advance(-1);planner.advance(INF);check(is_equal_approx(planner.clock,8),"invalid time rejected")
	for faction: String in ["aurelia","noxfera"]:
		var main = await make_main(faction,10)
		main.idle_stage=1;main._build_combat_screen();await settle()
		check(main.enemy_wave.size()==15 and main.invasion.groups.size()==1,"initial runtime corps "+faction)
		var anchor: Vector2=main.expedition_position
		var initial: Vector2=main.roaming_hunt.enemy_positions[0]
		main.combat_running=false;main._advance_auto_hunt(.5)
		check(main.invasion.clock==0,"pause freezes game clock")
		main.combat_running=true;main.battle_speed=2;main._advance_auto_hunt(.5)
		check(is_equal_approx(main.invasion.clock,1),"double speed uses game seconds")
		check(main.expedition_position==anchor and main.roaming_hunt.enemy_positions[0].distance_to(anchor)<initial.distance_to(anchor),"enemies approach stationary formation")
		main.battle_speed=1
		# Boundary fixture: five survivors with damaged health and stable positions.
		for i in main.enemy_wave.size(): main.enemy_wave[i].hp=7 if i<5 else 0
		main.invasion.clock=3.999;F.admit(main)
		check(main.invasion.serial==1,"runtime early admission refused")
		main.invasion.clock=4
		var positions: Array=main.roaming_hunt.enemy_positions.duplicate()
		F.admit(main)
		check(main.invasion.serial==2 and main._enemy_wave_alive_count()==21,"16 newcomers plus five survivors")
		check(main.enemy_wave[0].hp==7 and main.roaming_hunt.enemy_positions[0]==positions[0],"reinforcement preserves existing enemy hp and position")
		for i in range(15,main.enemy_wave.size()): main.enemy_wave[i].hp=0
		main.invasion.clock=8;F.admit(main)
		check(main.invasion.serial==2,"third corps refused before reward receipt settled")
		var gold: int=(main.unclaimed_gold+main.wallet_gold);var cycles: int=main.combat_hunt_cycle
		main._finish_hunt_target()
		check(main.combat_hunt_cycle==cycles+1 and (main.unclaimed_gold+main.wallet_gold)>gold,"dead second corps rewarded while first alive")
		gold=(main.unclaimed_gold+main.wallet_gold);main._finish_hunt_target()
		check((main.unclaimed_gold+main.wallet_gold)==gold,"repeat settlement has no reward")
		F.admit(main)
		check(main.invasion.serial==3 and main._enemy_wave_alive_count()==22,"ongoing first plus third corps")
		check(main.enemy_wave[0].hp==7,"compaction preserves survivor state")
		# Repeated progression exercises slot retirement, receipt identity and caps.
		for cycle in 20:
			for enemy in main.enemy_wave: enemy.hp=0
			main._finish_hunt_target();main.invasion.advance(4);F.admit(main)
			check(main.enemy_wave.size()>=15 and main.enemy_wave.size()<=20,"bounded slots after long hunting")
			check(main._enemy_wave_alive_count()<=25 and main.invasion.groups.size()<=2,"live and corps caps")
			check(main.enemy_wave.size()==main.enemy_wave_sprites.size() and main.enemy_wave.size()==main.roaming_hunt.enemy_positions.size(),"parallel arrays stay aligned")
			await process_frame
		# Natural combat: no forced kills, heroes defend and clear an approaching group.
		main.idle_stage=1;main._build_combat_screen();await settle()
		for step in 1600:
			main._advance_auto_hunt(.1)
			if step%100==0: await process_frame
			if main.combat_hunt_cycle>0: break
		check(main.combat_hunt_cycle>0,"natural defensive AI clears corps "+faction)
		check(main.expedition_position==anchor,"anchor never pursues monsters")
		for id in main.party_movement.positions:
			var station: Vector2=main.party_movement.formation_station(id,anchor)
			check(Vector2(main.party_movement.positions[id]).distance_to(station)<2.0,"hero stays near formation "+id)
		await dispose(main)
	done("v8362_invasion")
