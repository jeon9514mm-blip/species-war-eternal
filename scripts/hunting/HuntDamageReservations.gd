extends RefCounted
## Short-lived intent estimates only. No RNG, damage, timers or saved state.
static func enabled(main) -> bool:
	return main.active_screen=='combat' and main.challenge_session==null and main.party_movement.independent_hunt
static func pending(main, target: int, excluding: String) -> float:
	var total:=0.0
	for id in main.hero_skill_runtime:
		if id==excluding or int(main.hero_battle_state.get(id,{}).get('hp',0))<=0:continue
		var runtime: Dictionary=main.hero_skill_runtime[id]
		var windup: float=runtime.get('windup',-1)
		if windup<0 or windup>.16 or int(runtime.get('target_index',-1))!=target:continue
		if not main._can_attack_enemy(id,target):continue
		var action:=str(runtime.get('prepared_action','basic'))
		var scale:=1.0
		if action!='basic':
			var profile: Dictionary=main.HERO_KITS.auto_profile(main,id,action)
			if str(profile.get('kind',''))!='damage':continue
			scale=maxf(0,float(profile.get('value',0)))*.80
		total+=maxf(0,float(main.hero_battle_state[id].get('attack',0)))*scale
	return total
static func choose(main, id: String, primary: int, profile: Dictionary = {}, ranked: Array[int] = []) -> int:
	if not enabled(main) or primary<0:return primary
	var enemy: Dictionary=main.enemy_wave[primary]
	# A dedicated combo/finisher and a dangerous elite keep deliberate focus.
	if bool(enemy.get('elite',false)) or str(main.hero_battle_state[id].get('ai_style',''))=='finisher' or str(main.HERO_KITS.CATALOG.skill(id,'passive').get('condition',''))=='same_target':return primary
	if pending(main,primary,id)<float(enemy.get('hp',1)):return primary
	var candidates:=ranked
	if candidates.is_empty():
		candidates=main.combat_decisions.rank_skill_targets(main.hero_battle_state[id],main.enemy_wave,profile,main._combat_enemy_distances(id),primary)
	for candidate in candidates:
		if candidate==primary:continue
		if pending(main,candidate,id)<float(main.enemy_wave[candidate].get('hp',1)):return candidate
	# When every target is covered, keep attacking; estimates never gate damage.
	return primary
