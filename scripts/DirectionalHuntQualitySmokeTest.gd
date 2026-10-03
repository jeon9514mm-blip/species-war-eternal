extends "res://scripts/V83UpgradeTestBase.gd"
const DIRECTOR=preload('res://scripts/InvasionHuntDirector.gd')
## Low-level fixtures change only the first entrance; combat and rewards run normally.
func _init() -> void:_run.call_deferred()
func _run() -> void:
	var rows: Array=[]
	for faction: String in ['aurelia','noxfera']:
		for serial in range(1,9):
			var main=await make_main(faction,3)
			main.loot_rng.seed=83067
			main.idle_stage=1
			for hero in main.deployed_heroes:main.hero_progress[hero.id]={'level':1,'xp':0}
			main._build_combat_screen();await settle();main.combat_running=true
			main.roaming_hunt.clear_enemies();main.roaming_hunt.append_corps(main.enemy_wave,serial)
			var start_cycle: int=main.combat_hunt_cycle;var damage:=0;var steps:=0
			while main.combat_hunt_cycle==start_cycle and steps<3000:
				var before: Dictionary={}
				for id in main.hero_battle_state:before[id]=int(main.hero_battle_state[id].hp)
				main._advance_auto_hunt(.1);steps+=1
				for id in before:damage+=maxi(0,int(before[id])-int(main.hero_battle_state.get(id,{}).get('hp',0)))
				if steps%150==0:await process_frame
			check(main.combat_hunt_cycle>start_cycle,'starter party clears '+faction+DIRECTOR.entry_side(serial).id)
			check(main._enemy_wave_alive_count()<=25 and main.invasion.groups.size()<=2,'caps respected '+faction+str(serial))
			var row: Dictionary={'faction':faction,'entrance':DIRECTOR.entry_side(serial).id,'seconds':steps*.1,'hp_removed':damage,'survivors':main._alive_hero_ids().size()}
			rows.append(row);print('DIRECTION_RESULT ',JSON.stringify(row))
			await dispose(main)
	var folder: String=ProjectSettings.globalize_path('user://')
	FileAccess.open(folder.path_join('direction-results.json'),FileAccess.WRITE).store_string(JSON.stringify(rows,'  '))
	done('directional_hunt_quality')
