extends "res://tests/support/V83UpgradeTestBase.gd"
const W=preload("res://scripts/hunting/InvasionWaveState.gd")
class FailingStore extends SaveStore:
	var fail: bool=true
	func write_save(path: String,data: Dictionary) -> Dictionary:
		if fail: return {"ok":false,"status":"injected_corps_save_failure"}
		return super.write_save(path,data)
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var w=W.new();w.serial=5
	check(w.next_size()==20 and w.can_enter(5) and not w.can_enter(6),"20 incoming plus 5 survivors reaches exact 25 cap")
	for faction: String in ["aurelia","noxfera"]:
		var main=await make_main(faction,3)
		main.idle_stage=1
		for hero in main.deployed_heroes: main.hero_progress[hero.id]={"level":1,"xp":0}
		main._build_combat_screen();await settle()
		for step in 3000:
			main._advance_auto_hunt(.1)
			if step%100==0: await process_frame
			if main.combat_hunt_cycle>0: break
		check(main.combat_hunt_cycle>0,"level-one starter party can clear invading corps "+faction)
		print("starter faction=%s game_seconds=%.2f clears=%d"%[faction,main.invasion.clock,main.combat_hunt_cycle])
		# Failure injection at corps settlement: receipt and economic state survive retry.
		var store=FailingStore.new();main.save_store=store
		for enemy in main.enemy_wave: enemy.hp=0
		main._finish_hunt_target()
		check(SAFETY.pending(main),"corps reward save failure activates write barrier")
		var snapshot: Dictionary=economic(main);var clock: float=main.invasion.clock
		main._advance_auto_hunt(.5);main._finish_hunt_target()
		check(economic(main)==snapshot and main.invasion.clock==clock,"failed-save reward is not repeated and battle freezes")
		store.fail=false;check(SAFETY.retry(main),"reward snapshot retry succeeds")
		check(economic(main)==snapshot,"retry saves without regranting reward")
		main._advance_auto_hunt(.1);check(main.invasion.clock>clock,"combat resumes after save recovery")
		# Every habitat uses the same invasion mode and navigable perimeter.
		for zone: String in ["gray_meadow","forgotten_mine","moonrest_forest"]:
			main.current_zone_id=zone;main.idle_stage=20
			for hero in main.deployed_heroes: main.hero_progress[hero.id]={"level":60,"xp":0}
			main._build_combat_screen();await settle()
			check(main.enemy_wave.size()==15,"zone starts with one corps "+zone)
			for point in main.roaming_hunt.enemy_positions:
				check(main.field_navigation.is_walkable(point),"perimeter spawn walkable "+zone)
			for step in 2400:
				main._advance_auto_hunt(.1)
				if step%100==0: await process_frame
				if main.combat_hunt_cycle>0: break
			check(main.combat_hunt_cycle>0,"natural corps clear in "+zone+" "+faction)
		await dispose(main)
	done("v8362_field_safety")
