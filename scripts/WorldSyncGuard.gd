extends RefCounted
class_name WorldSyncGuard

const MAX_CLOCK_CORRECTION_PER_SAMPLE := 0.75
const MAX_ACCEPTABLE_CLOCK_SKEW := 8.0
const HEARTBEAT_INTERVAL_SECONDS := 5.0
const MAX_RETRY_SECONDS := 15.0

func snapshot_revision_valid(current_revision: int, incoming_revision: int) -> bool:
	return incoming_revision >= current_revision

func needs_resync(current_revision: int, server_revision: int) -> bool:
	return server_revision > current_revision

func smooth_clock_offset(current_offset: float, measured_offset: float, first_sample := false) -> float:
	if first_sample:
		return measured_offset
	var delta := measured_offset - current_offset
	return current_offset + clampf(delta, -MAX_CLOCK_CORRECTION_PER_SAMPLE, MAX_CLOCK_CORRECTION_PER_SAMPLE)

func clock_skew_warning(current_offset: float, measured_offset: float) -> bool:
	return absf(measured_offset - current_offset) > MAX_ACCEPTABLE_CLOCK_SKEW

func retry_delay_seconds(failure_count: int) -> float:
	if failure_count <= 0:
		return 0.0
	return minf(MAX_RETRY_SECONDS, pow(2.0, float(mini(failure_count - 1, 4))))

func health_text(connected: bool, desynced: bool, failure_count: int, clock_warning: bool) -> String:
	if not connected:
		return "연결 끊김 · 재접속 대기"
	if desynced:
		return "상태 불일치 · 재동기화 필요"
	if clock_warning:
		return "서버 시간 보정 중"
	if failure_count > 0:
		return "응답 불안정 · 재시도 중"
	return "서버 상태 안정"
