extends 'res://tests/support/V83UpgradeTestBase.gd'
## Real continuous feet, reachable goals and interpolation-safe separation.
const FIELD=preload('res://scripts/raid/RaidBattlefield.gd')
func _init() -> void:run.call_deferred()

func nearest_segment(before: Dictionary,after: Dictionary,a: String,b: String,metric: Vector2) -> float:
	var start: Vector2=(Vector2(before[a])-Vector2(before[b]))*metric
	var velocity: Vector2=((Vector2(after[a])-Vector2(before[a]))-(Vector2(after[b])-Vector2(before[b])))*metric
	var fraction:=clampf(-start.dot(velocity)/velocity.length_squared(),0.0,1.0) if velocity.length_squared()>.000001 else 0.0
	return (start+velocity*fraction).length()

func bounded(positions: Dictionary,goals: Dictionary,speeds: Dictionary,boss: Vector2,danger: Dictionary={},metric:=Vector2(2,1)) -> bool:
	var before: Dictionary=positions.duplicate()
	FIELD.advance_positions(positions,goals,speeds,boss,.05,danger,80,110,metric)
	for id in positions:
		if Vector2(positions[id]).distance_to(before[id])>float(speeds[id])*.05+.001:return false
		if not FIELD.FLOOR.has_point(positions[id]):return false
	return true

func isolated_geometry() -> void:
	var boss:=Vector2(790,450)
	var positions: Dictionary={'a':Vector2(350,350),'b':Vector2(450,350)}
	var goals: Dictionary={'a':Vector2(550,350),'b':Vector2(650,350)}
	var speeds: Dictionary={'a':128.0,'b':128.0}
	var first: Dictionary=positions.duplicate();var continuous:=true;var separated:=true
	for step in 25:
		var before: Dictionary=positions.duplicate()
		continuous=bounded(positions,goals,speeds,boss) and continuous
		separated=nearest_segment(before,positions,'a','b',Vector2(2,1))>=79.85 and separated
	check(continuous and separated,'close parallel actors walk continuously without an interpolated crossing')
	check(Vector2(positions.a).x>first.a.x+100 and Vector2(positions.b).x>first.b.x+100,'local separation leaves a shared travel direction usable')
	positions={'a':Vector2(380,380),'b':Vector2(480,380)};goals={'a':Vector2(480,380),'b':Vector2(380,380)}
	first=positions.duplicate();continuous=true;separated=true
	for step in 160:
		var before: Dictionary=positions.duplicate()
		continuous=bounded(positions,goals,speeds,boss) and continuous
		separated=nearest_segment(before,positions,'a','b',Vector2(2,1))>=79.85 and separated
	check(continuous and separated,'crossing goals cannot jump or cross painted feet between snapshots')
	print('RAID_CROSSING '+JSON.stringify({'a':[positions.a.x,positions.a.y],'b':[positions.b.x,positions.b.y],'a_distance':Vector2(positions.a).distance_to(goals.a),'b_distance':Vector2(positions.b).distance_to(goals.b)}))
	check(Vector2(positions.a).distance_to(goals.a)<2.0 and Vector2(positions.b).distance_to(goals.b)<2.0,'crossing actors yield or slide until both reachable goals are reached')
	var danger: Dictionary={'shape':'lane','rect':Rect2(430,280,40,206)}
	positions={'a':Vector2(442,390)};goals={'a':Vector2(370,390)};speeds={'a':128.0};continuous=true
	for step in 30:continuous=bounded(positions,goals,speeds,boss,danger) and continuous
	check(continuous and not FIELD.contains(danger,positions.a),'an already threatened actor exits the warning continuously')
	goals.a=Vector2(510,390);var remains_safe:=true
	for step in 50:
		var before: Vector2=positions.a
		continuous=bounded(positions,goals,speeds,boss,danger) and continuous
		for sample in [.25,.5,.75,1.0]:remains_safe=not FIELD.contains(danger,before.lerp(positions.a,sample)) and remains_safe
	check(continuous and remains_safe,'walking from a safe point never enters the active lane while interpolating')
	positions={'a':Vector2(500,383)};goals={'a':Vector2(640,383)};boss=Vector2(640,383)
	continuous=true
	for step in 80:continuous=bounded(positions,goals,speeds,boss) and continuous
	check(continuous and ((Vector2(positions.a)-boss)*Vector2(2,1)).length()>=109.85,'a fixed boss blocks feet without changing the boss position')
	positions={'a':Vector2(240,302)};goals={'a':Vector2(-100,-100)};continuous=true
	for step in 12:continuous=bounded(positions,goals,speeds,boss) and continuous
	check(continuous and positions.a==Vector2(226,290),'floor edges clamp each step without a jump beyond the movement budget')

func combat_state(main: Node) -> Dictionary:
	return {'heroes':main.hero_battle_state.duplicate(true),'skills':main.hero_skill_runtime.duplicate(true),'boss_hp':main.raid_boss_hp,'gold':main.wallet_gold,'gems':main.wallet_gems,'crystals':main.raid_crystals,'rng':main.loot_rng.state}

func run() -> void:
	isolated_geometry()
	if OS.get_environment('RAID_MOVEMENT_GEOMETRY_ONLY')=='1':done('RAID_CONTINUOUS_GEOMETRY');return
	for faction: String in ['aurelia','noxfera']:
		var main=await make_main(faction,10);root.size=Vector2i(1280,720);await settle()
		for zone: String in ['gray_meadow','forgotten_mine','moonrest_forest']:
			main.selected_raid_id=zone;main._build_raid_screen();await settle();await settle()
			main._start_raid();main.combat_timer.stop();await settle()
			var view=main.content_root.get_node('PortraitRaidView');var field=view.battlefield_3d
			view.set_process(false);field.set_process(false);field._process(0)
			var original: Dictionary=main.raid_positions.duplicate();var state:=combat_state(main)
			var ids: Array=main._deployed_hero_ids();var maximum:=0.0;var minimum:=INF;var swept:=INF
			for step in 120:
				var before: Dictionary=main.raid_positions.duplicate()
				main.raid_elapsed+=.05;main._raid_move_actors(.05);view._process(.05);field._process(0)
				for id: String in ids:
					maximum=maxf(maximum,Vector2(main.raid_positions[id]).distance_to(before[id]))
					if not FIELD.FLOOR.has_point(main.raid_positions[id]):failures.append('off floor '+faction+'/'+zone+'/'+id)
				if step>=60:
					for i in ids.size():
						for j in range(i+1,ids.size()):
							var metric: Vector2=field.raid_separation_metric()
							var factor: float=field.raid_projection_factor()
							swept=minf(swept,nearest_segment(before,main.raid_positions,ids[i],ids[j],metric)*factor)
							minimum=minf(minimum,field.project_world(field.raid_to_world(main.raid_positions[ids[i]])).distance_to(field.project_world(field.raid_to_world(main.raid_positions[ids[j]]))))
			var traveled:=0.0
			for id: String in ids:traveled+=Vector2(main.raid_positions[id]).distance_to(original[id])
			var label: String=faction+'/'+zone
			check(maximum<=6.401,label+' natural role walking never exceeds its .05s ×128px/s budget')
			check(minimum>=64.0 and swept>=63.8,label+' settled painted feet remain separated between rendered snapshots')
			var in_range:=true
			for id: String in ids:in_range=Vector2(main.raid_positions[id]).distance_to(main.raid_boss_position)<=335.05 and in_range
			check(in_range,label+' walking or holding a legal entry station preserves every hero attack range')
			check(combat_state(main)==state,label+' formation movement preserves HP cooldowns economy and loot RNG')
			var center: Vector2=main._raid_party_center()
			# A reachable retreat tests convoy progress; the boss's occupied body
			# is deliberately not treated as an empty destination for ten heroes.
			var ordered: Dictionary=main.raid_positions.duplicate()
			main._raid_order_move(FIELD.clamp_to_floor(center-Vector2(75,0)))
			var keeps_formation:=true
			for id: String in ids:keeps_formation=Vector2(main.raid_rally_offsets.get(id,Vector2.INF)).distance_to(Vector2(ordered[id])-center)<.001 and keeps_formation
			check(keeps_formation,label+' actual rally command records current formation instead of reassigning crossing slots')
			var initial_distance: float=center.distance_to(main.raid_rally_position);maximum=0
			for step in 160:
				var before: Dictionary=main.raid_positions.duplicate()
				main.raid_elapsed+=.05;main._raid_move_actors(.05)
				for id: String in ids:maximum=maxf(maximum,Vector2(main.raid_positions[id]).distance_to(before[id]))
			check(maximum<=10.251,label+' manual rally remains within its .05s ×205px/s budget')
			var final_distance: float=main._raid_party_center().distance_to(main.raid_rally_position)
			print('RAID_CONTINUOUS '+label+' '+JSON.stringify({'max_rally_step':maximum,'rally_initial_distance':initial_distance,'rally_final_distance':final_distance,'natural_minimum':minimum,'natural_swept_minimum':swept,'natural_traveled':traveled}))
			check(final_distance<initial_distance-8.0,label+' manual rally makes progress instead of freezing a crowded party')
			main._finish_raid('defeat')
		await dispose(main)
	done('RAID_CONTINUOUS_MOVEMENT')
