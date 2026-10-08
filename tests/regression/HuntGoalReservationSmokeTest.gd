extends 'res://tests/support/V83UpgradeTestBase.gd'
const BODY=preload('res://scripts/hunting/HuntBodyCollision.gd')
func _init() -> void:run.call_deferred()
func run() -> void:
	var main=await make_main('aurelia',3);main._build_combat_screen();await settle()
	var id: String=main.deployed_heroes[0].id
	main.skill_auto=false;main.ultimate_auto=false;main.combat_running=true
	for hero_id in main.hero_battle_state:
		main.hero_battle_state[hero_id].hp=1000 if hero_id==id else 0
		main.hero_skill_runtime[hero_id].windup=-1.0;main.hero_skill_runtime[hero_id].attack_remaining=99.0
	main.hero_battle_state[id].range=1;main.hero_battle_state[id].attack=20
	main.party_movement.positions[id]=Vector2(16,10)
	for i in main.enemy_wave.size():
		main.enemy_wave[i].hp=1000 if i==0 else 0;main.enemy_wave[i].max_hp=1000;main.enemy_wave[i].attack_remaining=99.0
	main.roaming_hunt.enemy_positions[0]=Vector2(25,10)
	main.party_movement.advance(.05,main.deployed_heroes,main.hero_battle_state,main.hero_skill_runtime,main.expedition_position,main.enemy_wave,main.roaming_hunt.enemy_positions,main.roaming_hunt.enemy_returning,true)
	var movement=main.party_movement
	var goal: Vector2=movement.combat_goals[id].goal
	var planned: Vector2=movement.combat_goals[id].planned_attack_goal
	check(movement.combat_goals[id].kind=='approach' and not movement.hunt_slots[id].in_range,'distant waiting destination is marked as approach')
	check(goal==movement.goal_reservations[id] and goal.is_equal_approx(main.roaming_hunt.enemy_positions[0]+Vector2(movement.hunt_slots[id].offset)),'actual movement and slot reservation use one destination')
	check(planned.distance_to(main.roaming_hunt.enemy_positions[0])<=main.combat_decisions.spatial_range(1)+.001,'future firing stance remains inside strict gameplay reach')
	check(not main._can_attack_enemy(id,0),'approach reservation cannot grant artificial range')
	var runtime: Dictionary=main.hero_skill_runtime[id]
	runtime.windup=.01;runtime.prepared_action='basic';runtime.target_index=0;runtime.cast=false;runtime.cast_secondary=false;runtime.cast_ultimate=false
	var enemy_hp: int=main.enemy_wave[0].hp
	main._advance_hunt_attacks(.02)
	check(main.enemy_wave[0].hp==enemy_hp,'a forced prepared attack still causes no damage outside actual reach')
	runtime.windup=.2
	var before: Vector2=main._hero_field_position(id)
	movement.advance(.05,main.deployed_heroes,main.hero_battle_state,main.hero_skill_runtime,main.expedition_position,main.enemy_wave,main.roaming_hunt.enemy_positions,main.roaming_hunt.enemy_returning,true)
	check(main._hero_field_position(id)==before and movement.goal_reservations[id]==before,'committed caster reserves and holds its current body')
	check(not movement.hunt_slots.has(id) and not movement.combat_goals.has(id),'committed caster releases obsolete travel reservations')
	movement.positions.erase(id);movement.velocities.erase(id);movement.distance_walked.erase(id)
	var caster_hp: int=main.hero_battle_state[id].hp
	var reward_rng: int=main.loot_rng.state;var wallet: int=main.wallet_gold
	BODY.resolve(main,.05)
	check(movement.positions[id]==main.expedition_position and movement.velocities[id]==Vector2.ZERO and movement.distance_walked[id]==0.0,'restored caster initializes missing movement entries at its existing spawn fallback')
	check(main.hero_battle_state[id].hp==caster_hp and runtime.windup==.2,'initial body solve preserves health and committed cast')
	var revived: String=main.deployed_heroes[1].id
	main.hero_battle_state[revived].hp=450
	main.hero_skill_runtime[revived].windup=-1.0
	movement.positions.erase(revived);movement.velocities.erase(revived);movement.distance_walked.erase(revived)
	BODY.resolve(main,.05)
	check(movement.positions.has(revived) and movement.velocities.has(revived) and is_finite(movement.distance_walked[revived]),'same-frame revived walker initializes position velocity and walked distance')
	check(movement.positions[id]==main.expedition_position and BODY.clear(BODY.actors(main)),'new walker yields to the committed caster without moving its body')
	check(main.hero_battle_state[revived].hp==450 and main.loot_rng.state==reward_rng and main.wallet_gold==wallet,'missing-entry repair changes neither health nor reward state')
	await dispose(main);done('HUNT_GOAL_RESERVATION')
