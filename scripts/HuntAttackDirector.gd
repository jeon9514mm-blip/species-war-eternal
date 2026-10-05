extends RefCounted
## Intent lives on the simulation clock. No timer or visual effect applies damage.
const ENEMY_WINDUP := .22

static func refresh_enemy_intent(main, index: int) -> void:
	var enemy: Dictionary = main.enemy_wave[index]
	if not enemy.has('attack_intent'): return
	var id := str(enemy.attack_intent)
	var valid: bool = float(enemy.get('stun_seconds',0)) <= 0
	if id.is_empty():
		valid = valid and not main._select_hero_target_for_enemy(index,true).is_empty()
	else:
		valid = valid and id in main._alive_hero_ids()
		if valid:valid = main.roaming_hunt.enemy_position(index).distance_to(main._hero_field_position(id)) <= main._enemy_attack_range(enemy)
	if not valid:
		enemy.erase('attack_intent')
		enemy['attack_remaining'] = maxf(ENEMY_WINDUP,float(enemy.get('attack_remaining',.9)))

static func committed_target(main, id: String, action: String, prepared: String) -> int:
	if action != prepared: return -1
	var target: int = int(main.hero_skill_runtime[id].get('target_index', -1))
	if action == 'basic': return target if main._can_attack_enemy(id, target) else -1
	var profile: Dictionary = main.HERO_KITS.auto_profile(main, id, action)
	var ranked: Array[int] = main.combat_decisions.rank_skill_targets(main.hero_battle_state[id], main.enemy_wave,
		profile, main._combat_enemy_distances(id), target)
	return target if target in ranked else -1

static func advance_enemy(main, index: int, delta: float) -> Dictionary:
	var enemy: Dictionary = main.enemy_wave[index]
	if float(enemy.get('stun_seconds', 0)) > 0:
		enemy.erase('attack_intent')
		enemy['attack_remaining'] = maxf(ENEMY_WINDUP, float(enemy.get('attack_remaining', .9)))
		return {'ready':false}
	var support := str(enemy.get('archetype', '')) == 'support'
	if not enemy.has('attack_intent'):
		if not preload('res://scripts/HuntBodyCollision.gd').can_commit(main,false,index):return {'ready':false}
		var target: String = main._select_hero_target_for_enemy(index, true)
		if target.is_empty() and not support: return {'ready':false}
		enemy['attack_remaining'] = maxf(0, float(enemy.get('attack_remaining', .9)) - delta)
		if float(enemy.attack_remaining) <= ENEMY_WINDUP:
			enemy['attack_intent'] = target
			if index < main.enemy_wave_sprites.size() and is_instance_valid(main.enemy_wave_sprites[index]):
				var sprite = main.enemy_wave_sprites[index]
				if not target.is_empty(): sprite.set_direction_from_vector(main._hero_field_position(target) - main.roaming_hunt.enemy_position(index))
				sprite.play_attack()
	else:
		enemy['attack_remaining'] = maxf(0, float(enemy.get('attack_remaining', .9)) - delta)
	if float(enemy.attack_remaining) > 0: return {'ready':false}
	var target := str(enemy.get('attack_intent', ''))
	enemy["hunt_recovery"] = .26 if support else (.18 if str(enemy.get("archetype",""))=="assassin" else .30)
	enemy.erase('attack_intent')
	var valid: bool = target in main._alive_hero_ids()
	if valid:
		valid = main.roaming_hunt.enemy_position(index).distance_to(main._hero_field_position(target)) <= main._enemy_attack_range(enemy)
	if not valid and not support:
		# Reacquire and prepare again; never redirect a released hit at another hero.
		enemy['attack_remaining'] = ENEMY_WINDUP
		return {'ready':false}
	return {'ready':true, 'target':target if valid else ''}
