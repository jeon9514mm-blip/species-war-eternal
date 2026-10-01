extends RefCounted
class_name WorldAuthorityService

const AUTHORITY_VERSION := 6
const MAX_SERVER_STEP := 1.0
const MAX_PROCESSED_COMMANDS := 256

var server_time_offset_seconds := 0.0
var last_revision := 0
var last_command_id := 0
var processed_commands: Dictionary = {}
var command_log: Array = []
var max_log := 40
var trusted_parties: Dictionary = {}
var local_demo_allies := true
var season_state: WorldSeasonState

func bind_season(season: WorldSeasonState) -> void:
	season_state = season
	if season_state != null:
		season_state.ensure_started(server_now())

func server_now_seconds() -> float:
	return Time.get_unix_time_from_system() + server_time_offset_seconds

func server_now() -> int:
	return int(server_now_seconds())

func next_command_id(prefix := "cmd") -> String:
	last_command_id += 1
	return "%s_%d_%d" % [prefix, server_now(), last_command_id]

func register_trusted_party(player_id: String, faction: String, squad: Array, power: int) -> bool:
	if player_id.is_empty() or faction not in [WorldWarState.FACTION_AURELIA, WorldWarState.FACTION_NOXFERA] or squad.is_empty():
		return false
	trusted_parties[player_id] = {
		"player_id": player_id,
		"faction": faction,
		"squad": squad.duplicate(true),
		"power": maxi(0, power),
		"updated_at": server_now()
	}
	return true

func trusted_force(player_id: String, world: WorldWarState) -> Dictionary:
	if world == null or not trusted_parties.has(player_id):
		return {}
	var party: Dictionary = trusted_parties[player_id]
	if str(party.get("faction", "")) != world.faction:
		return {}
	var wounded_squad: Array = party.get("squad", []).duplicate(true)
	for unit in wounded_squad:
		var ratio := float(world.army_wounds.get(str(unit.get("id", "")), 1.0))
		unit["hp"] = int(ceil(float(unit.get("max_hp", 1)) * ratio))
	return {
		"force_id": "player_local",
		"player_name": "내 원정대",
		"faction": world.faction,
		"squad": wounded_squad,
		"power": maxi(0, int(party.get("power", 0))),
		"fatigue": world.army_fatigue,
		"stance": world.battle_stance,
		"is_npc": false,
		"arrived_at": server_now()
	}

func _fingerprint(command: Dictionary) -> String:
	return "%s|%s|%s|%s|%s|%s" % [
		str(command.get("id", "")),
		str(command.get("type", "")),
		str(command.get("player_id", "")),
		str(command.get("faction", "")),
		str(command.get("target", [])),
		str(command.get("context_id", ""))
	]

func _remember(command: Dictionary, response: Dictionary) -> Dictionary:
	var command_id := str(command.get("id", ""))
	var stored := response.duplicate(true)
	stored["command_id"] = command_id
	stored["revision"] = last_revision
	stored["server_time"] = server_now()
	stored["fingerprint"] = _fingerprint(command)
	processed_commands[command_id] = stored.duplicate(true)
	command_log.push_front({
		"id": command_id,
		"type": str(command.get("type", "")),
		"revision": last_revision,
		"accepted": bool(stored.get("accepted", false)),
		"server_time": int(stored["server_time"])
	})
	while command_log.size() > max_log:
		command_log.pop_back()
	while processed_commands.size() > MAX_PROCESSED_COMMANDS:
		var removable := ""
		for cached_id in processed_commands.keys():
			var keep := false
			for entry in command_log:
				if str(entry.get("id","")) == str(cached_id):
					keep = true
					break
			if not keep:
				removable = str(cached_id)
				break
		if removable.is_empty():
			removable = str(processed_commands.keys()[0])
		processed_commands.erase(removable)
	return stored

func _reject(command: Dictionary, reason: String) -> Dictionary:
	return _remember(command, {"accepted": false, "reason": reason})

func _parse_target(command: Dictionary) -> Vector2i:
	var raw = command.get("target", [])
	if typeof(raw) != TYPE_ARRAY or raw.size() < 2:
		return Vector2i(-999, -999)
	return Vector2i(int(raw[0]), int(raw[1]))

func _base_validate(world: WorldWarState, command: Dictionary) -> String:
	if world == null:
		return "월드 상태 없음"
	var command_id := str(command.get("id", ""))
	if command_id.is_empty():
		return "명령 ID 없음"
	var player_id := str(command.get("player_id", ""))
	if player_id.is_empty() or not trusted_parties.has(player_id):
		return "인증되지 않은 플레이어"
	var faction := str(command.get("faction", ""))
	if faction != world.faction or str(trusted_parties[player_id].get("faction", "")) != faction:
		return "진영 불일치"
	var issued_at := int(command.get("issued_at", 0))
	if issued_at > 0 and abs(server_now() - issued_at) > 300:
		return "만료된 명령"
	var expected_revision := int(command.get("expected_revision", last_revision))
	if expected_revision != last_revision:
		return "월드 리비전 충돌"
	return ""

func _season_active() -> bool:
	if season_state == null:
		return true
	return season_state.is_active(server_now())

func submit_command(world: WorldWarState, march: WorldMarchState, conflict: WorldConflictState, supply: WorldSupplyNetwork, command: Dictionary) -> Dictionary:
	var command_id := str(command.get("id", ""))
	if not command_id.is_empty() and processed_commands.has(command_id):
		var cached: Dictionary = processed_commands[command_id].duplicate(true)
		if str(cached.get("fingerprint", "")) != _fingerprint(command):
			return {"accepted": false, "reason": "명령 ID 충돌", "revision": last_revision}
		cached["duplicate"] = true
		return cached
	if march == null or conflict == null or supply == null:
		return _reject(command, "월드 상태 없음")
	var validation := _base_validate(world, command)
	if not validation.is_empty():
		return _reject(command, validation)
	_advance_logistics(world, supply)
	var command_type := str(command.get("type", ""))
	var player_id := str(command.get("player_id", ""))
	var target := _parse_target(command)
	var context_id := str(command.get("context_id", ""))
	var force := trusted_force(player_id, world)
	var accepted := false
	var reason := ""
	match command_type:
		"rest_army":
			var quote: Dictionary = WorldFrontlineRules.rest_quote(world,march,supply,force.get("squad",[]))
			if target != world.army_position: reason = "정비 위치 변경"
			elif not bool(quote["ok"]): reason = str(quote["reason"])
			elif context_id != str(quote["key"]): reason = "정비 조건 변경"
			elif world.consume_rations(int(quote["cost"])):
				# One physical force: detach its old defensive snapshot before recovery.
				conflict.remove_force_everywhere("player_local")
				for rally_id in conflict.rallies.keys():
					conflict.remove_rally_participant(str(rally_id), "player_local")
				world.recover_fatigue(int(quote["fatigue_drop"]))
				for id in quote["wounds"]: world.army_wounds[id] = quote["wounds"][id]
				last_revision += 1
				return _remember(command,{"accepted":true,"type":"rest_army","cost":quote["cost"],"fatigue_drop":quote["fatigue_drop"]})
			else: reason = "군량 부족"
		"set_stance":
			if march.active:reason="이미 행군 중"
			elif context_id not in WorldCampaignRules.STANCES:reason="전술 정보 오류"
			else:
				world.battle_stance=context_id
				accepted=true
		"march":
			if march == null or march.active:
				reason = "이미 행군 중"
			elif force.is_empty():
				reason = "신뢰 부대 없음"
			else:
				var check: Dictionary = WorldCampaignRules.march_check(world, march, supply, target, force.get("squad", []), _season_active(), true)
				if not bool(check["ok"]):
					reason = str(check["reason"])
				elif march.begin(world, target, "", "", server_now_seconds()):
					conflict.remove_force_everywhere("player_local")
					accepted = true
				else:
					reason = "군량 부족"
		"support":
			if not _season_active():
				reason = "시즌 정산 중"
			elif march == null or march.active:
				reason = "이미 행군 중"
			elif not _force_can_fight(force):
				reason = "부상 회복 필요"
			elif not supply.can_reinforce(world, target, world.faction):
				reason = "보급 단절"
			elif conflict.garrison_count(target) >= conflict.capacity_at(world, target):
				reason = "주둔 한도"
			elif march.begin(world, target, "support", "", server_now_seconds()):
				conflict.remove_force_everywhere("player_local")
				accepted = true
			else:
				reason = "지원 행군 실패"
		"register_garrison":
			if march != null and march.active:
				reason = "이미 행군 중"
			elif not _season_active():
				reason = "시즌 정산 중"
			elif not _force_can_fight(force):
				reason = "부상 회복 필요"
			elif target != world.army_position or not supply.can_reinforce(world, target, world.faction):
				reason = "보급 단절"
			elif conflict.add_garrison(world, supply, target, force):
				accepted = true
			else:
				reason = "주둔 한도"
		"rally_march":
			if not _season_active():
				reason = "시즌 정산 중"
			elif context_id.is_empty() or not conflict.rallies.has(context_id):
				reason = "집결 정보 없음"
			elif march == null or march.active:
				reason = "이미 행군 중"
			elif not _rally_matches(conflict, context_id, target, world.faction):
				reason = "집결 정보 없음"
			elif not world.can_attack_enemy_tile(world.faction, target):
				reason = "공격 불가"
			elif not _force_can_fight(force):
				reason = "부상 회복 필요"
			elif not supply.is_supply_connected(world, world.army_position, world.faction):
				reason = "보급 단절"
			elif not world.can_launch_combat():
				reason = "피로 한도"
			elif march.begin(world, target, "", context_id, server_now_seconds()):
				conflict.remove_force_everywhere("player_local")
				accepted = true
			else:
				reason = "집결 행군 실패"
		"forced_retreat":
			if march != null and march.begin_forced_retreat(world, server_now_seconds()):
				conflict.remove_force_everywhere("player_local")
				accepted = true
			else:
				reason = "긴급 후퇴 불가"
		"cancel_march":
			if march == null or not march.active:
				reason = "취소할 행군 없음"
			else:
				var origin := march.origin
				var rally_id := march.context_id
				var refund := march.cancel_and_refund(world, 0.5)
				if not rally_id.is_empty():
					conflict.remove_rally_participant(rally_id, "player_local")
				_restore_origin(world, conflict, supply, origin, force)
				accepted = true
				last_revision += 1
				return _remember(command, {"accepted": true, "reason": "accepted", "type": command_type, "refund": refund})
		"claim_season_reward":
			var reward := season_state.claim_reward(world, player_id, server_now()) if season_state != null else {}
			if reward.is_empty():
				reason = "시즌 보상 수령 불가"
			else:
				last_revision += 1
				return _remember(command, {"accepted": true, "type": command_type, "reward": reward})
		"next_season":
			if season_state == null or season_state.refresh_phase(server_now()) != "ended":
				reason = "시즌 진행 중"
			elif bool(season_state.reward_preview(player_id, world.faction, server_now()).get("claimable", false)):
				reason = "시즌 보상 먼저 수령"
			elif season_state.begin_next_season(world, conflict, march, world.faction, server_now()):
				accepted = true
		"exchange_honor":
			if world.campaign_honor < 50:
				reason = "전쟁 명예 부족"
			else:
				world.campaign_honor -= 50
				world.add_rations(200)
				accepted = true
		_:
			reason = "지원하지 않는 명령"
	if not accepted:
		if command_type == "rally_march" and conflict.remove_rally_participant(context_id, "player_local"):
			last_revision += 1
		return _reject(command, reason)
	last_revision += 1
	return _remember(command, {"accepted": true, "reason": "accepted", "type": command_type})

func _force_can_fight(force: Dictionary) -> bool:
	for unit in force.get("squad", []):
		if int(unit.get("hp", 0)) > 0:
			return true
	return false

func _combat_arrival_reason(world: WorldWarState, supply: WorldSupplyNetwork, force: Dictionary, origin: Vector2i, requires_combat := true) -> String:
	if not _force_can_fight(force):
		return "부상 회복 필요"
	if requires_combat and not world.can_launch_combat():
		return "피로 한도"
	if not supply.is_supply_connected(world, origin, world.faction):
		return "보급 단절"
	return ""

func _rally_matches(conflict: WorldConflictState, rally_id: String, target: Vector2i, faction_id: String) -> bool:
	var rally: Dictionary = conflict.rallies.get(rally_id, {})
	var raw = rally.get("target", [])
	if typeof(raw) != TYPE_ARRAY or raw.size() < 2 or Vector2i(int(raw[0]), int(raw[1])) != target or str(rally.get("faction", "")) != faction_id:
		return false
	for force in rally.get("participants", []):
		if str(force.get("force_id", "")) == "player_local":
			return true
	return false

func _advance_logistics(world: WorldWarState, supply: WorldSupplyNetwork) -> Dictionary:
	if world == null:
		return {}
	var now := server_now()
	var active := _season_active()
	var result: Dictionary = {}
	if not active and season_state != null and world.last_logistics_unix > 0 and world.last_logistics_unix < season_state.active_end_unix:
		result = world.advance_logistics(season_state.active_end_unix, supply, true)
		world.advance_logistics(now, supply, false)
	else:
		result = world.advance_logistics(now, supply, active)
	if int(result.get("rations", 0)) > 0 or int(result.get("honor", 0)) > 0:
		last_revision += 1
	return result

func prepare_rally(world: WorldWarState, conflict: WorldConflictState, resolver: WorldBattleResolver, target: Vector2i, player_id: String) -> Dictionary:
	if not _season_active():
		return {"accepted": false, "reason": "시즌 정산 중", "revision": last_revision}
	var force := trusted_force(player_id, world)
	if force.is_empty():
		return {"accepted": false, "reason": "신뢰 부대 없음", "revision": last_revision}
	if not world.can_attack_enemy_tile(world.faction, target) or world.find_march_path(target).size() < 2 or not _force_can_fight(force):
		return {"accepted": false, "reason": "공격 불가", "revision": last_revision}
	if not WorldSupplyNetwork.new().is_supply_connected(world, world.army_position, world.faction):
		return {"accepted": false, "reason": "보급 단절", "revision": last_revision}
	if not world.can_launch_combat():
		return {"accepted": false, "reason": "피로 한도", "revision": last_revision}
	var existing := conflict.rally_at_target(target, world.faction)
	var rally_id := ""
	if existing.is_empty():
		rally_id = conflict.create_rally(world, target, force)
		if rally_id.is_empty():
			return {"accepted": false, "reason": "집결 생성 실패", "revision": last_revision}
		if local_demo_allies:
			for index in 2:
				var scale := 0.78 + float(index) * 0.10
				var ally := {
					"force_id": "demo_ally_%d_%d_%d" % [target.x, target.y, index],
					"player_name": "프로토타입 동맹 %s" % ["A", "B"][index],
					"faction": world.faction,
					"squad": resolver.make_garrison(world.faction, target + Vector2i(30 + index, 40 + index), "plain", int(float(force.get("power", 700)) * scale)),
					"power": int(float(force.get("power", 700)) * scale),
					"fatigue": 5 + index * 4,
					"is_npc": true,
					"arrived_at": server_now()
				}
				conflict.join_rally(rally_id, ally)
	else:
		rally_id = str(existing.get("id", ""))
		var already_joined := false
		var participants = existing.get("participants", [])
		if typeof(participants) == TYPE_ARRAY:
			for participant in participants:
				if str(participant.get("force_id", "")) == "player_local":
					already_joined = true
					break
		if not already_joined and not conflict.join_rally(rally_id, force):
			return {"accepted": false, "reason": "집결 참여 한도", "revision": last_revision}
	last_revision += 1
	var prepared = conflict.rallies.get(rally_id, {})
	var count := 0
	if typeof(prepared) == TYPE_DICTIONARY:
		var participants = prepared.get("participants", [])
		if typeof(participants) == TYPE_ARRAY:
			count = participants.size()
	return {"accepted": true, "rally_id": rally_id, "participants": count, "revision": last_revision, "server_time": server_now()}

func _battle_seed(target: Vector2i) -> int:
	last_command_id += 1
	return maxi(1, (target.x + 31) * 1613 + (target.y + 47) * 1877 + last_revision * 101 + last_command_id * 17)

func _restore_origin(world: WorldWarState, conflict: WorldConflictState, supply: WorldSupplyNetwork, origin: Vector2i, force: Dictionary) -> void:
	var safe_origin := origin
	if not world.in_bounds(safe_origin) or world.tile_owner(safe_origin) != world.faction:
		safe_origin = world.capital_for(world.faction)
		world.army_wounds.clear()
	world.army_position = safe_origin
	conflict.remove_force_everywhere("player_local")
	var return_force := force.duplicate(true)
	for unit in return_force.get("squad", []):
		unit["hp"] = int(ceil(float(unit.get("max_hp", 1)) * float(world.army_wounds.get(str(unit.get("id", "")), 1.0))))
	return_force["fatigue"] = world.army_fatigue
	conflict.add_garrison(world, supply, safe_origin, return_force)

func resolve_attack(world: WorldWarState, conflict: WorldConflictState, supply: WorldSupplyNetwork, resolver: WorldBattleResolver, target: Vector2i, player_id: String, origin: Vector2i) -> Dictionary:
	var force := trusted_force(player_id, world)
	if not _season_active():
		if not force.is_empty():
			_restore_origin(world, conflict, supply, origin, force)
		return {"accepted": false, "reason": "시즌 정산 중", "revision": last_revision}
	var arrival_reason := _combat_arrival_reason(world, supply, force, origin)
	if not arrival_reason.is_empty():
		_restore_origin(world, conflict, supply, origin, force)
		return {"accepted": false, "reason": arrival_reason, "revision": last_revision}
	if force.is_empty() or not world.can_attack_enemy_tile(world.faction, target):
		_restore_origin(world, conflict, supply, origin, force)
		return {"accepted": false, "reason": "공격 불가", "revision": last_revision}
	if not conflict.enqueue_attack(target, force):
		_restore_origin(world, conflict, supply, origin, force)
		return {"accepted": false, "reason": "공격 대기열", "revision": last_revision}
	var result := conflict.process_next_attack(world, supply, resolver, target, _battle_seed(target))
	if result.is_empty():
		_restore_origin(world, conflict, supply, origin, force)
		return {"accepted": false, "reason": "전투 계산 실패", "revision": last_revision}
	world.record_army_wounds(force.get("squad", []), result.get("attacker_units", []))
	var defeated := int(result.get("defeated_forces", 0))
	if bool(result.get("captured", false)):
		world.add_fatigue(12 + defeated * 3)
		if season_state != null:
			season_state.record_capture(world.faction, world.tile_type(target), player_id, true, server_now())
	else:
		world.add_fatigue(20 + defeated * 4)
		if season_state != null:
			season_state.record_defense(world.enemy_faction(), "", 1, server_now())
		_restore_origin(world, conflict, supply, origin, force)
	var report := result.duplicate(true)
	report["tile_name"] = world.tile_display_name(target)
	report["fatigue_after"] = world.army_fatigue
	report["timestamp"] = server_now()
	world.record_battle_report(report)
	last_revision += 1
	return {"accepted": true, "captured": bool(result.get("captured", false)), "report": report, "revision": last_revision, "server_time": server_now()}

func resolve_rally(world: WorldWarState, conflict: WorldConflictState, supply: WorldSupplyNetwork, resolver: WorldBattleResolver, target: Vector2i, rally_id: String, player_id: String, origin: Vector2i) -> Dictionary:
	var force := trusted_force(player_id, world)
	if not _season_active():
		if not force.is_empty():
			_restore_origin(world, conflict, supply, origin, force)
		if not rally_id.is_empty():
			conflict.cancel_rally(rally_id)
		return {"accepted": false, "reason": "시즌 정산 중", "revision": last_revision}
	if force.is_empty() or rally_id.is_empty() or not _rally_matches(conflict, rally_id, target, world.faction):
		_restore_origin(world, conflict, supply, origin, force)
		conflict.cancel_rally(rally_id)
		return {"accepted": false, "reason": "집결 만료", "revision": last_revision}
	var arrival_reason := _combat_arrival_reason(world, supply, force, origin)
	if arrival_reason.is_empty() and not world.can_attack_enemy_tile(world.faction, target):
		arrival_reason = "공격 불가"
	if not arrival_reason.is_empty():
		_restore_origin(world, conflict, supply, origin, force)
		conflict.cancel_rally(rally_id)
		return {"accepted": false, "reason": arrival_reason, "revision": last_revision}
	# Rally preparation reserves participation, not a permanent copy of health,
	# equipment or tactics. Resolve the player's wave from the trusted live force.
	conflict.refresh_rally_participant(rally_id, force)
	var result := conflict.resolve_rally(world, supply, resolver, rally_id, _battle_seed(target))
	if result.is_empty():
		_restore_origin(world, conflict, supply, origin, force)
		return {"accepted": false, "reason": "집결 전투 실패", "revision": last_revision}
	var participant_reports: Array = result.get("participant_reports", [])
	for participant_report in participant_reports:
		if str(participant_report.get("attacker_force_id", "")) == "player_local":
			world.record_army_wounds(force.get("squad", []), participant_report.get("attacker_units", []))
	force = trusted_force(player_id, world)
	var used := int(result.get("participants_used", 0))
	if bool(result.get("captured", false)):
		world.add_fatigue(10 + used * 2)
		world.army_position = target
		conflict.remove_force_everywhere("player_local")
		conflict.add_garrison(world, supply, target, force)
		if season_state != null:
			season_state.record_capture(world.faction, world.tile_type(target), player_id, true, server_now())
	else:
		world.add_fatigue(15 + used * 3)
		if season_state != null:
			season_state.record_defense(world.enemy_faction(), "", 1, server_now())
		_restore_origin(world, conflict, supply, origin, force)
	var report := {
		"victory": bool(result.get("victory", false)),
		"captured": bool(result.get("captured", false)),
		"tile_name": world.tile_display_name(target),
		"participants_used": used,
		"battle_summaries": result.get("participant_reports", []),
		"logs": ["집결 전투 · %d부대 순차 투입" % used],
		"fatigue_after": world.army_fatigue,
		"timestamp": server_now()
	}
	world.record_battle_report(report)
	last_revision += 1
	return {"accepted": true, "captured": bool(result.get("captured", false)), "report": report, "revision": last_revision, "server_time": server_now()}

func advance_march(world: WorldWarState, march: WorldMarchState, conflict: WorldConflictState, supply: WorldSupplyNetwork, resolver: WorldBattleResolver, player_id: String, _delta: float) -> Dictionary:
	_advance_logistics(world, supply)
	if march == null or not march.active:
		return {"accepted": true, "event": "idle", "revision": last_revision}
	var origin := march.origin
	# Client delta is intentionally ignored for authoritative time progression.
	# Only the server clock may move a march forward.
	var authority_now := server_now_seconds()
	var result := march.advance_authoritative(authority_now, world)
	if not bool(result.get("arrived", false)):
		return {"accepted": true, "event": "march_progress", "progress": march.progress_ratio(), "revision": last_revision}
	return _finalize_arrival(world, march, conflict, supply, resolver, player_id, origin, result)

func catch_up_march(world: WorldWarState, march: WorldMarchState, conflict: WorldConflictState, supply: WorldSupplyNetwork, resolver: WorldBattleResolver, player_id: String) -> Dictionary:
	_advance_logistics(world, supply)
	if march == null or not march.active:
		return {"accepted": true, "event": "idle", "revision": last_revision}
	var origin := march.origin
	var result := march.catch_up_authoritative(server_now_seconds(), world)
	if not bool(result.get("arrived", false)):
		return {"accepted": true, "event": "march_progress", "progress": march.progress_ratio(), "revision": last_revision}
	return _finalize_arrival(world, march, conflict, supply, resolver, player_id, origin, result)

func _finalize_arrival(world: WorldWarState, march: WorldMarchState, conflict: WorldConflictState, supply: WorldSupplyNetwork, resolver: WorldBattleResolver, player_id: String, origin: Vector2i, arrival: Dictionary) -> Dictionary:
	# The march has ended even when conquest is rejected by a changed world.
	last_revision += 1
	var target: Vector2i = arrival.get("target", Vector2i(-1, -1))
	if bool(arrival.get("battle_required", false)):
		var rally_id := str(arrival.get("context_id", ""))
		if rally_id.is_empty():
			var battle := resolve_attack(world, conflict, supply, resolver, target, player_id, origin)
			battle["event"] = "battle_resolved"
			return battle
		var rally := resolve_rally(world, conflict, supply, resolver, target, rally_id, player_id, origin)
		rally["event"] = "rally_resolved"
		return rally
	if not bool(arrival.get("success", false)):
		_restore_origin(world, conflict, supply, origin, trusted_force(player_id, world))
		if not march.context_id.is_empty():
			conflict.cancel_rally(march.context_id)
		last_revision += 1
		return {"accepted": false, "reason": "도착 처리 실패", "revision": last_revision}
	if str(arrival.get("action", "")) == "capture_neutral":
		if not _season_active():
			var return_force := trusted_force(player_id, world)
			if not return_force.is_empty():
				_restore_origin(world, conflict, supply, origin, return_force)
			return {"accepted": false, "reason": "시즌 정산 중", "revision": last_revision}
		var capture_force := trusted_force(player_id, world)
		var arrival_reason := _combat_arrival_reason(world, supply, capture_force, origin, world.neutral_guard_level(target) > 0)
		if not arrival_reason.is_empty():
			_restore_origin(world, conflict, supply, origin, capture_force)
			return {"accepted": false, "reason": arrival_reason, "revision": last_revision}
		if world.neutral_guard_level(target)>0:
			return _resolve_neutral_campaign(world,conflict,supply,resolver,target,player_id,origin)
		if not world.apply_march_arrival(target, "capture_neutral"):
			return {"accepted": false, "reason": "도착 처리 실패", "revision": last_revision}
		if season_state != null:
			season_state.record_capture(world.faction, world.tile_type(target), player_id, false, server_now())
	var force := trusted_force(player_id, world)
	if str(arrival.get("action", "")) == "support":
		if not _force_can_fight(force) or not supply.can_reinforce(world, target, world.faction) or conflict.garrison_count(target) >= conflict.capacity_at(world, target):
			_restore_origin(world, conflict, supply, origin, force)
			last_revision += 1
			return {"accepted": false, "reason": "지원 도착 조건 변경", "revision": last_revision}
		# Commit movement and capital recovery only after support is accepted.
		if not world.apply_march_arrival(target, "move"):
			_restore_origin(world, conflict, supply, origin, force)
			return {"accepted": false, "reason": "도착 처리 실패", "revision": last_revision}
		force = trusted_force(player_id, world)
	var registered := false
	if not force.is_empty() and supply.can_reinforce(world, world.army_position, world.faction):
		registered = conflict.add_garrison(world, supply, world.army_position, force)
	last_revision += 1
	return {"accepted": true, "event": "arrival_completed", "registered": registered, "revision": last_revision, "server_time": server_now()}

func _snapshot_digest(snapshot: Dictionary) -> String:
	var payload := "%d|%s|%s|%s|%s" % [
		int(snapshot.get("revision", 0)),
		JSON.stringify(snapshot.get("world", {})),
		JSON.stringify(snapshot.get("march", {})),
		JSON.stringify(snapshot.get("conflict", {})),
		JSON.stringify(snapshot.get("season", {}))
	]
	return payload.sha256_text()

func heartbeat() -> Dictionary:
	if season_state != null:
		season_state.refresh_phase(server_now())
	return {
		"accepted": true,
		"revision": last_revision,
		"server_time": server_now_seconds(),
		"season_phase": season_state.phase if season_state != null else "none"
	}

func build_snapshot(world: WorldWarState, march: WorldMarchState, conflict: WorldConflictState) -> Dictionary:
	if world == null or march == null or conflict == null:
		return {"accepted": false, "reason": "월드 상태 없음", "revision": last_revision}
	if season_state != null:
		season_state.refresh_phase(server_now())
	var snapshot := {
		"accepted": true,
		"protocol_version": 1,
		"revision": last_revision,
		"server_time": server_now_seconds(),
		"world": world.export_state(),
		"march": march.export_state(),
		"conflict": conflict.export_state(),
		"season": season_state.export_state() if season_state != null else {}
	}
	snapshot["snapshot_digest"] = _snapshot_digest(snapshot)
	return snapshot

func verify_snapshot(snapshot: Dictionary) -> bool:
	if int(snapshot.get("protocol_version", 0)) != 1:
		return false
	var digest := str(snapshot.get("snapshot_digest", ""))
	return not digest.is_empty() and digest == _snapshot_digest(snapshot)

func export_state() -> Dictionary:
	return {
		"authority_version": AUTHORITY_VERSION,
		"server_time_offset_seconds": server_time_offset_seconds,
		"last_revision": last_revision,
		"last_command_id": last_command_id,
		"processed_commands": processed_commands.duplicate(true),
		"command_log": command_log.duplicate(true),
		"local_demo_allies": local_demo_allies
	}

func import_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	server_time_offset_seconds = WorldWarState.safe_float(data.get("server_time_offset_seconds", 0.0))
	last_revision = maxi(0, WorldWarState.safe_int(data.get("last_revision", 0)))
	last_command_id = maxi(0, WorldWarState.safe_int(data.get("last_command_id", 0)))
	local_demo_allies = bool(data.get("local_demo_allies", true))
	var loaded_processed = data.get("processed_commands", {})
	if typeof(loaded_processed) == TYPE_DICTIONARY:
		processed_commands.clear()
		for key in loaded_processed.keys().slice(-MAX_PROCESSED_COMMANDS):
			if typeof(loaded_processed[key]) == TYPE_DICTIONARY:
				var cached: Dictionary = loaded_processed[key].duplicate(true)
				cached["accepted"] = cached.get("accepted", false) == true
				cached["revision"] = maxi(0, WorldWarState.safe_int(cached.get("revision", 0)))
				cached["server_time"] = maxi(0, WorldWarState.safe_int(cached.get("server_time", 0)))
				cached["refund"] = maxi(0, WorldWarState.safe_int(cached.get("refund", 0)))
				cached["fingerprint"] = str(cached.get("fingerprint", ""))
				processed_commands[str(key)] = cached
	var loaded_log = data.get("command_log", [])
	if typeof(loaded_log) == TYPE_ARRAY:
		command_log.clear()
		for entry in loaded_log.slice(0, max_log):
			if typeof(entry) == TYPE_DICTIONARY:
				command_log.append(entry.duplicate(true))
	trusted_parties.clear()

func _resolve_neutral_campaign(world: WorldWarState, conflict: WorldConflictState, supply: WorldSupplyNetwork, resolver: WorldBattleResolver, target: Vector2i, player_id: String, origin: Vector2i) -> Dictionary:
	var force:=trusted_force(player_id,world)
	if not _force_can_fight(force) or not world.can_launch_combat() or not supply.is_supply_connected(world,origin,world.faction):
		_restore_origin(world,conflict,supply,origin,force)
		return {'accepted':false,'reason':'공격 불가','revision':last_revision}
	var guards:=WorldCampaignRules.neutral_guardians(world,target)
	var result:=resolver.resolve(force['squad'],guards,world.army_fatigue,WorldCampaignRules.terrain_defense(world,target),_battle_seed(target),world.battle_stance)
	var survivors:=conflict._alive_squad(result['attacker_units'])
	world.record_army_wounds(force['squad'],survivors)
	var captured:=bool(result['victory']) and world.apply_march_arrival(target,'capture_neutral',true)
	world.add_fatigue(12 if captured else 20)
	if captured:
		world.clear_garrison(target)
		if season_state!=null:season_state.record_capture(world.faction,world.tile_type(target),player_id,false,server_now())
		conflict.add_garrison(world,supply,target,trusted_force(player_id,world))
	else:
		world.set_garrison(target,conflict._alive_squad(result['defender_units']))
		_restore_origin(world,conflict,supply,origin,force)
	var report:=result.duplicate(true)
	report.merge({'victory':captured,'captured':captured,'tile_name':world.tile_display_name(target),'target':[target.x,target.y],'defeated_forces':1 if captured else 0,'remaining_defenders':0 if captured else 1,'attacker_start_count':force['squad'].size(),'attacker_survivors':survivors.size(),'fatigue_after':world.army_fatigue,'timestamp':server_now(),'neutral_campaign':true},true)
	world.record_battle_report(report)
	last_revision+=1
	return {'accepted':true,'event':'battle_resolved','captured':captured,'report':report,'revision':last_revision,'server_time':server_now()}
