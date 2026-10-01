extends RefCounted
class_name WorldServerGateway

const GATEWAY_VERSION := 5

var mode := "local_authority"
var connected := true
var latency_ms := 0
var last_error := ""
var last_snapshot: Dictionary = {}
var failure_streak := 0
var last_success_msec := 0
var last_failure_msec := 0

func is_online_authoritative() -> bool:
	return mode == "remote_server"

func status_text() -> String:
	if mode == "remote_server":
		return "서버 권한 연결" if connected else "서버 연결 끊김"
	return "로컬 권한 시뮬레이션" if connected else "로컬 권한 재연결 필요"

func _offline(reason := "원격 서버 어댑터 미구현") -> Dictionary:
	last_error = reason
	return {"accepted": false, "reason": reason}

func _refresh_snapshot_cache(authority: WorldAuthorityService, world: WorldWarState, march: WorldMarchState, conflict: WorldConflictState) -> void:
	if authority == null or world == null or march == null or conflict == null:
		return
	var snapshot := authority.build_snapshot(world, march, conflict)
	if bool(snapshot.get("accepted", false)):
		last_snapshot = snapshot.duplicate(true)

func _mark_success() -> void:
	failure_streak = 0
	last_success_msec = Time.get_ticks_msec()
	last_error = ""

func _mark_failure(reason: String) -> void:
	failure_streak = mini(10, failure_streak + 1)
	last_failure_msec = Time.get_ticks_msec()
	last_error = reason

func heartbeat(authority: WorldAuthorityService) -> Dictionary:
	if not connected:
		_mark_failure("서버 연결 끊김")
		return _offline("서버 연결 끊김")
	if authority == null:
		_mark_failure("권한 서비스 없음")
		return _offline("권한 서비스 없음")
	if mode == "remote_server":
		_mark_failure("원격 heartbeat 어댑터 미구현")
		return _offline("원격 heartbeat 어댑터 미구현")
	var response := authority.heartbeat()
	if bool(response.get("accepted", false)):
		_mark_success()
	else:
		_mark_failure(str(response.get("reason","heartbeat 실패")))
	return response

func submit(authority: WorldAuthorityService, world: WorldWarState, march: WorldMarchState, conflict: WorldConflictState, supply: WorldSupplyNetwork, command: Dictionary) -> Dictionary:
	if not connected:
		return _offline("서버 연결 끊김")
	if authority == null:
		return _offline("권한 서비스 없음")
	if mode == "remote_server":
		return _offline()
	var response := authority.submit_command(world, march, conflict, supply, command)
	if bool(response.get("accepted", false)):
		_mark_success()
		_refresh_snapshot_cache(authority, world, march, conflict)
	else:
		_mark_failure(str(response.get("reason", "거절")))
	return response

func prepare_rally(authority: WorldAuthorityService, world: WorldWarState, conflict: WorldConflictState, resolver: WorldBattleResolver, target: Vector2i, player_id: String) -> Dictionary:
	if not connected:
		return _offline("서버 연결 끊김")
	if authority == null:
		return _offline("권한 서비스 없음")
	if mode == "remote_server":
		return _offline()
	var response := authority.prepare_rally(world, conflict, resolver, target, player_id)
	if bool(response.get("accepted", false)):
		_mark_success()
	else:
		_mark_failure(str(response.get("reason", "거절")))
	return response

func advance(authority: WorldAuthorityService, world: WorldWarState, march: WorldMarchState, conflict: WorldConflictState, supply: WorldSupplyNetwork, resolver: WorldBattleResolver, player_id: String, delta: float) -> Dictionary:
	if not connected:
		return _offline("서버 연결 끊김")
	if authority == null:
		return _offline("권한 서비스 없음")
	if mode == "remote_server":
		return _offline()
	var response := authority.advance_march(world, march, conflict, supply, resolver, player_id, delta)
	if bool(response.get("accepted", false)):
		_mark_success()
		_refresh_snapshot_cache(authority, world, march, conflict)
	else:
		_mark_failure(str(response.get("reason", "행군 동기화 실패")))
	return response

func catch_up(authority: WorldAuthorityService, world: WorldWarState, march: WorldMarchState, conflict: WorldConflictState, supply: WorldSupplyNetwork, resolver: WorldBattleResolver, player_id: String) -> Dictionary:
	if not connected:
		return _offline("서버 연결 끊김")
	if authority == null:
		return _offline("권한 서비스 없음")
	if mode == "remote_server":
		return _offline()
	var response := authority.catch_up_march(world, march, conflict, supply, resolver, player_id)
	if bool(response.get("accepted", false)):
		_mark_success()
		_refresh_snapshot_cache(authority, world, march, conflict)
	else:
		_mark_failure(str(response.get("reason", "행군 복구 실패")))
	return response

func fetch_snapshot(authority: WorldAuthorityService, world: WorldWarState, march: WorldMarchState, conflict: WorldConflictState) -> Dictionary:
	if not connected:
		return _offline("서버 연결 끊김")
	if authority == null:
		return _offline("권한 서비스 없음")
	if mode == "remote_server":
		return _offline("원격 스냅샷 어댑터 미구현")
	var response := authority.build_snapshot(world, march, conflict)
	if bool(response.get("accepted", false)):
		_mark_success()
		last_snapshot = response.duplicate(true)
	else:
		_mark_failure(str(response.get("reason", "동기화 실패")))
	return response

func simulate_disconnect() -> void:
	connected = false
	last_error = "서버 연결 끊김"

func reconnect(authority: WorldAuthorityService, world: WorldWarState, march: WorldMarchState, conflict: WorldConflictState) -> Dictionary:
	if mode == "remote_server":
		connected = false
		_mark_failure("원격 재접속 어댑터 미구현")
		return _offline("원격 재접속 어댑터 미구현")
	connected = true
	# Never restore an old cached world as authoritative after reconnect.
	# Fetch the current authority snapshot; cache is diagnostics/fallback only.
	var response := fetch_snapshot(authority, world, march, conflict)
	if bool(response.get("accepted", false)):
		_mark_success()
	else:
		_mark_failure(str(response.get("reason","재접속 실패")))
	return response

func export_state() -> Dictionary:
	return {
		"gateway_version": GATEWAY_VERSION,
		"mode": mode,
		"connected": connected,
		"latency_ms": latency_ms,
		"last_error": last_error,
		"failure_streak": failure_streak,
		"last_success_msec": last_success_msec
	}

func import_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	mode = str(data.get("mode", "local_authority"))
	if mode not in ["local_authority", "remote_server"]:
		mode = "local_authority"
	# A transient disconnect must not survive an app restart in local-authority mode.
	connected = mode == "local_authority"
	latency_ms = maxi(0, WorldWarState.safe_int(data.get("latency_ms", 0)))
	last_error = str(data.get("last_error", ""))
	failure_streak = 0
	last_success_msec = 0
	last_failure_msec = 0
