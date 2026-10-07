extends RefCounted
class_name WorldWarClientSession

var world: WorldWarState
var march: WorldMarchState
var conflict: WorldConflictState
var season: WorldSeasonState
var authority: WorldAuthorityService
var gateway: WorldServerGateway
var supply := WorldSupplyNetwork.new()
var resolver := WorldBattleResolver.new()
var faction := ""
var player_id := "local_player"
var revision := 0
var command_sequence := 0
var last_server_time := 0.0
var server_time_offset_seconds := 0.0
var sync_count := 0
var desynced := false
var sync_guard := WorldSyncGuard.new()
var failure_count := 0
var clock_skew_warning := false
var last_heartbeat_msec := 0

func bind(world_state: WorldWarState, march_state: WorldMarchState, conflict_state: WorldConflictState, authority_service: WorldAuthorityService, server_gateway: WorldServerGateway, faction_id: String, bound_player_id := "local_player", season_state: WorldSeasonState = null) -> void:
	world = world_state
	march = march_state
	conflict = conflict_state
	season = season_state
	authority = authority_service
	gateway = server_gateway
	faction = faction_id
	player_id = bound_player_id
	revision = authority.last_revision if authority != null else 0
	if authority != null:
		last_server_time = authority.server_now_seconds()
		server_time_offset_seconds = last_server_time - Time.get_unix_time_from_system()
	desynced = false

func _apply_snapshot(snapshot: Dictionary) -> Dictionary:
	if not bool(snapshot.get("accepted", false)):
		desynced = true
		return {"ok": false, "error": "sync_failed", "revision": revision}
	if authority == null or not authority.verify_snapshot(snapshot):
		desynced = true
		return {"ok": false, "error": "snapshot_integrity_failed", "revision": revision}
	var incoming_revision := int(snapshot.get("revision", revision))
	if not sync_guard.snapshot_revision_valid(revision, incoming_revision):
		desynced = true
		return {"ok": false, "error": "stale_snapshot", "revision": revision, "incoming_revision": incoming_revision}
	var world_data = snapshot.get("world", {})
	var march_data = snapshot.get("march", {})
	var conflict_data = snapshot.get("conflict", {})
	var season_data = snapshot.get("season", {})
	if typeof(world_data) != TYPE_DICTIONARY or typeof(march_data) != TYPE_DICTIONARY or typeof(conflict_data) != TYPE_DICTIONARY:
		desynced = true
		return {"ok": false, "error": "invalid_snapshot", "revision": revision}
	world.import_state(world_data)
	march.import_state(march_data)
	conflict.import_state(conflict_data)
	if season != null and typeof(season_data) == TYPE_DICTIONARY and not season_data.is_empty():
		season.import_state(season_data)
	revision = maxi(0, incoming_revision)
	last_server_time = float(snapshot.get("server_time", Time.get_unix_time_from_system()))
	var measured_offset := last_server_time - Time.get_unix_time_from_system()
	clock_skew_warning = sync_guard.clock_skew_warning(server_time_offset_seconds, measured_offset) if sync_count > 0 else false
	server_time_offset_seconds = sync_guard.smooth_clock_offset(server_time_offset_seconds, measured_offset, sync_count == 0)
	sync_count += 1
	failure_count = 0
	desynced = false
	return {"ok": true, "event": "resynced", "revision": revision, "server_time": last_server_time, "sync_count": sync_count}

func resync_from_server() -> Dictionary:
	if gateway == null or authority == null or world == null or march == null or conflict == null:
		return {"ok": false, "error": "authority_not_bound", "revision": revision}
	return _apply_snapshot(gateway.fetch_snapshot(authority, world, march, conflict))

func reconnect_and_resync() -> Dictionary:
	if gateway == null or authority == null:
		return {"ok": false, "error": "authority_not_bound", "revision": revision}
	return _apply_snapshot(gateway.reconnect(authority, world, march, conflict))

func _next_client_command_id(kind: String) -> String:
	command_sequence += 1
	return authority.next_command_id(kind) if authority != null else "%s_%d_%d" % [kind, int(Time.get_unix_time_from_system()), command_sequence]

func server_now_estimate() -> float:
	return Time.get_unix_time_from_system() + server_time_offset_seconds

func _command(kind: String, target := Vector2i(-1, -1), context_id := "") -> Dictionary:
	return {
		"id": _next_client_command_id(kind),
		"type": kind,
		"player_id": player_id,
		"faction": faction,
		"target": [target.x, target.y],
		"context_id": context_id,
		"issued_at": int(server_now_estimate()),
		"expected_revision": revision
	}

func _map_reason(reason: String) -> String:
	var mapping := {
		"이미 행군 중":"march_already_active",
		"전술 정보 오류":"invalid_stance",
		"행군 경로 없음":"illegal_route",
		"군량 부족":"insufficient_rations",
		"보급 단절":"supply_disconnected",
		"주둔 한도":"garrison_full",
		"집결 정보 없음":"rally_expired",
		"집결 생성 실패":"rally_create_failed",
		"집결 참여 한도":"rally_full",
		"긴급 후퇴 불가":"return_failed",
		"월드 리비전 충돌":"stale_revision",
		"피로 한도":"fatigue_limit",
		"인증되지 않은 플레이어":"unauthorized_player",
		"신뢰 부대 없음":"empty_squad",
		"공격 대기열":"attack_queue_full",
		"공격 불가":"attack_condition_changed",
		"전투 계산 실패":"battle_failed",
		"집결 전투 실패":"rally_battle_failed",
		"도착 처리 실패":"arrival_failed",
		"취소할 행군 없음":"no_active_march",
		"서버 연결 끊김":"server_disconnected",
		"시즌 정산 중":"season_locked",
		"스냅샷 무결성 실패":"snapshot_integrity_failed",
		"명령 ID 충돌":"command_id_conflict",
		"부상 회복 필요":"wounded_army",
		"지원 도착 조건 변경":"support_conditions_changed",
		"시즌 보상 수령 불가":"season_reward_unavailable",
		"시즌 진행 중":"season_still_active",
		"시즌 보상 먼저 수령":"season_reward_pending",
		"전쟁 명예 부족":"insufficient_honor",
		"지원 행군 실패":"support_failed",
		"집결 행군 실패":"rally_march_failed",
		"집결 만료":"rally_expired",
		"진영 불일치":"faction_mismatch",
		"만료된 명령":"expired_command"
	}
	return str(mapping.get(reason, "authority_not_bound"))

func _accepted(response: Dictionary, event: String, extra := {}) -> Dictionary:
	revision = int(response.get("revision", authority.last_revision if authority != null else revision))
	if response.has("server_time"):
		last_server_time = float(response.get("server_time", last_server_time))
		var measured_offset := last_server_time - Time.get_unix_time_from_system()
		clock_skew_warning = sync_guard.clock_skew_warning(server_time_offset_seconds, measured_offset)
		server_time_offset_seconds = sync_guard.smooth_clock_offset(server_time_offset_seconds, measured_offset, false)
	failure_count = 0
	desynced = false
	var result := {"ok": true, "event": event, "revision": revision}
	if typeof(extra) == TYPE_DICTIONARY:
		for key in extra:
			result[key] = extra[key]
	return result

func _rejected(response: Dictionary) -> Dictionary:
	var error := _map_reason(str(response.get("reason", "")))
	var server_revision := int(response.get("revision", revision))
	if error == "stale_revision":
		desynced = true
		var sync := resync_from_server()
		return {"ok": false, "error": error, "revision": revision, "server_revision": server_revision, "resynced": bool(sync.get("ok", false))}
	revision = server_revision
	failure_count = mini(10, failure_count + 1)
	return {"ok": false, "error": error, "revision": revision}

func heartbeat_server() -> Dictionary:
	if gateway == null or authority == null:
		failure_count = mini(10, failure_count + 1)
		return {"ok": false, "error": "authority_not_bound", "revision": revision}
	var response := gateway.heartbeat(authority)
	last_heartbeat_msec = Time.get_ticks_msec()
	if not bool(response.get("accepted", false)):
		failure_count = mini(10, failure_count + 1)
		return {"ok": false, "error": _map_reason(str(response.get("reason",""))), "revision": revision}
	var server_revision := int(response.get("revision", revision))
	var sample_server_time := float(response.get("server_time", server_now_estimate()))
	var measured_offset := sample_server_time - Time.get_unix_time_from_system()
	clock_skew_warning = sync_guard.clock_skew_warning(server_time_offset_seconds, measured_offset)
	server_time_offset_seconds = sync_guard.smooth_clock_offset(server_time_offset_seconds, measured_offset, sync_count == 0)
	last_server_time = sample_server_time
	failure_count = 0
	if sync_guard.needs_resync(revision, server_revision):
		var sync := resync_from_server()
		return {"ok": bool(sync.get("ok",false)), "event":"heartbeat_resync", "revision":revision}
	return {"ok": true, "event":"heartbeat", "revision":revision, "server_revision":server_revision}

func connection_health_text() -> String:
	var connected := gateway != null and gateway.connected
	return sync_guard.health_text(connected, desynced, failure_count, clock_skew_warning)

func retry_delay_seconds() -> float:
	return sync_guard.retry_delay_seconds(failure_count)

func send(action: String, payload: Dictionary, _client_squad: Array, _client_power: int) -> Dictionary:
	if world == null or march == null or conflict == null or authority == null or gateway == null:
		return {"ok": false, "error": "authority_not_bound", "revision": revision}
	var raw = payload.get("target", [])
	var target := Vector2i(-1, -1)
	if typeof(raw) == TYPE_ARRAY and raw.size() >= 2:
		target = Vector2i(int(raw[0]), int(raw[1]))
	match action:
		"rest_army":
			var response := gateway.submit(authority,world,march,conflict,supply,_command("rest_army",target,str(payload.get("quote_key",""))))
			if not bool(response.get("accepted",false)):return _rejected(response)
			return _accepted(response,"army_rested",{"cost":response.get("cost",0),"fatigue_drop":response.get("fatigue_drop",0)})
		"set_stance":
			var response:=gateway.submit(authority,world,march,conflict,supply,_command('set_stance',Vector2i(-1,-1),str(payload.get('stance',''))))
			if not bool(response.get('accepted',false)):return _rejected(response)
			return _accepted(response,'stance_changed')
		"begin_march":
			var plan := march.plan(world, target)
			var response := gateway.submit(authority, world, march, conflict, supply, _command("march", target))
			if not bool(response.get("accepted", false)):
				return _rejected(response)
			return _accepted(response, "march_started", {"plan": plan})
		"support":
			var kind := "register_garrison" if target == world.army_position else "support"
			var response := gateway.submit(authority, world, march, conflict, supply, _command(kind, target))
			if not bool(response.get("accepted", false)):
				return _rejected(response)
			return _accepted(response, "garrison_registered" if kind == "register_garrison" else "support_started")
		"rally":
			if march.active:
				return {"ok": false, "error": "march_already_active", "revision": revision}
			var plan := march.plan(world, target)
			if plan.is_empty():
				return {"ok": false, "error": "illegal_route", "revision": revision}
			if world.rations < int(plan.get("ration_cost", 0)):
				return {"ok": false, "error": "insufficient_rations", "revision": revision}
			var prepared := gateway.prepare_rally(authority, world, conflict, resolver, target, player_id)
			if not bool(prepared.get("accepted", false)):
				return _rejected(prepared)
			revision = int(prepared.get("revision", authority.last_revision))
			# prepare_rally mutates authoritative conflict state before the march command;
			# cache it so a disconnect between the two calls can still recover cleanly.
			gateway.fetch_snapshot(authority, world, march, conflict)
			var rally_id := str(prepared.get("rally_id", ""))
			var response := gateway.submit(authority, world, march, conflict, supply, _command("rally_march", target, rally_id))
			if not bool(response.get("accepted", false)):
				return _rejected(response)
			return _accepted(response, "rally_started", {"participants": int(prepared.get("participants", 0)), "rally_id": rally_id})
		"return_capital":
			var capital := world.capital_for(faction)
			if world.army_position == capital:
				return {"ok": false, "error": "already_at_capital", "revision": revision}
			var plan := march.plan(world, capital)
			var affordable := not plan.is_empty() and world.rations >= int(plan.get("ration_cost", 0))
			var kind := "march" if affordable else "forced_retreat"
			var response := gateway.submit(authority, world, march, conflict, supply, _command(kind, capital))
			if not bool(response.get("accepted", false)):
				return _rejected(response)
			return _accepted(response, "return_started", {"forced": kind == "forced_retreat"})
		"claim_season_reward", "next_season", "exchange_honor":
			var response := gateway.submit(authority, world, march, conflict, supply, _command(action))
			if not bool(response.get("accepted", false)):
				return _rejected(response)
			return _accepted(response, action, {"reward": response.get("reward", {})})
		"cancel_march":
			var response := gateway.submit(authority, world, march, conflict, supply, _command("cancel_march", march.origin))
			if not bool(response.get("accepted", false)):
				return _rejected(response)
			return _accepted(response, "march_cancelled", {"refund": int(response.get("refund", 0))})
	return {"ok": false, "error": "invalid_target", "revision": revision}

func advance_server(delta: float, _client_squad: Array, _client_power: int) -> Dictionary:
	if gateway == null or authority == null:
		return {"ok": false, "error": "authority_not_bound", "revision": revision}
	var response := gateway.advance(authority, world, march, conflict, supply, resolver, player_id, delta)
	revision = int(response.get("revision", authority.last_revision))
	if not bool(response.get("accepted", false)):
		return _rejected(response)
	var event := str(response.get("event", "idle"))
	if event == "battle_resolved" or event == "rally_resolved":
		return {"ok": true, "event": event, "captured": bool(response.get("captured", false)), "report": response.get("report", {}), "revision": revision}
	return {"ok": true, "event": event, "registered": bool(response.get("registered", false)), "progress": float(response.get("progress", 0.0)), "revision": revision}

func catch_up_server(_client_squad: Array, _client_power: int) -> Dictionary:
	if gateway == null or authority == null:
		return {"ok": false, "error": "authority_not_bound", "revision": revision}
	var response := gateway.catch_up(authority, world, march, conflict, supply, resolver, player_id)
	revision = int(response.get("revision", authority.last_revision))
	if not bool(response.get("accepted", false)):
		return _rejected(response)
	var event := str(response.get("event", "idle"))
	if event == "battle_resolved" or event == "rally_resolved":
		return {"ok": true, "event": event, "captured": bool(response.get("captured", false)), "report": response.get("report", {}), "revision": revision}
	return {"ok": true, "event": event, "registered": bool(response.get("registered", false)), "progress": float(response.get("progress", 0.0)), "revision": revision}
