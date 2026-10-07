extends "res://tests/support/V83UpgradeTestBase.gd"
const DIRECTOR=preload('res://scripts/hunting/InvasionHuntDirector.gd')
func _init() -> void:_run.call_deferred()
func _run() -> void:
	var seen: Dictionary={}
	for serial in range(1,17):
		var director:=DIRECTOR.new()
		var enemies: Array=[]
		for i in 20:enemies.append({'hp':100,'archetype':'brute'})
		director.append_corps(enemies,serial)
		var side:=DIRECTOR.entry_side(serial);seen[side.id]=true
		check(director.enemy_positions.size()==20,'all members enter '+side.id)
		check(side.id==DIRECTOR.entry_side(serial+8).id,'stable cycle '+side.id)
		for i in 20:
			var p: Vector2=director.enemy_positions[i]
			check(p==p.clamp(director.FIELD_MIN,director.FIELD_MAX),'inside navigation '+side.id)
			check(p.distance_to(director.FIELD_CENTER)>5.,'entrance separated from party '+side.id)
			check(enemies[i].entry_side==side.id,'entry metadata '+side.id)
			for j in i:check(p.distance_to(director.enemy_positions[j])>.7,'no corner overlap '+side.id)
		var before:=director.enemy_positions.duplicate()
		var alive: Array=[];alive.resize(20);alive.fill(true)
		director.advance(.25,alive)
		for i in 20:check(director.enemy_positions[i].distance_to(director.FIELD_CENTER)<before[i].distance_to(director.FIELD_CENTER),'approaches from '+side.id)
	check(seen.size()==8,'eight distinct entrances')
	for faction: String in ['aurelia','noxfera']:
		var main=await make_main(faction,10);main._build_combat_screen();await settle()
		main.combat_running=true
		var visited: Dictionary={};var serial:=0;var steps:=0
		while main.invasion.serial<9 and steps<4000:
			main._advance_auto_hunt(.1);steps+=1
			if main.invasion.serial!=serial:
				serial=main.invasion.serial;visited[DIRECTOR.entry_side(serial).id]=true
				check(main._enemy_wave_alive_count()<=25 and main.invasion.groups.size()<=2,'admission caps '+faction)
				check(main.enemy_wave.size()==main.roaming_hunt.enemy_positions.size(),'indices aligned '+faction)
			if steps%100==0:await process_frame
		check(visited.size()==8 and main.combat_hunt_cycle>=7,'natural combat clears all approaches '+faction)
		await dispose(main)
	done('multidirection_hunt')
