extends RefCounted
class_name WorldSeasonState

const SEASON_VERSION := 2
const ACTIVE_SECONDS := 28 * 24 * 60 * 60
const SETTLEMENT_SECONDS := 2 * 24 * 60 * 60

var season_number := 1
var season_id := ""
var phase := "active"
var start_unix := 0
var active_end_unix := 0
var settlement_end_unix := 0
var faction_scores := {
	WorldWarState.FACTION_AURELIA: 0,
	WorldWarState.FACTION_NOXFERA: 0
}
var player_contribution: Dictionary = {}
var captures := 0
var defenses := 0
var last_event := ""
var last_observed_unix := 0
var reward_claims: Dictionary = {}

func ensure_started(now_unix: int) -> void:
	if start_unix > 0 and not season_id.is_empty():
		refresh_phase(now_unix)
		return
	_start(season_number, now_unix)

func _start(number: int, now_unix: int) -> void:
	season_number = maxi(1, number)
	season_id = "S%03d" % season_number
	phase = "active"
	last_observed_unix = maxi(1, now_unix)
	reward_claims.clear()
	start_unix = maxi(1, now_unix)
	active_end_unix = start_unix + ACTIVE_SECONDS
	settlement_end_unix = active_end_unix + SETTLEMENT_SECONDS
	faction_scores = {
		WorldWarState.FACTION_AURELIA: 0,
		WorldWarState.FACTION_NOXFERA: 0
	}
	player_contribution.clear()
	captures = 0
	defenses = 0
	last_event = "새 시즌 시작"

func refresh_phase(now_unix: int) -> String:
	if start_unix <= 0:
		ensure_started(now_unix)
	last_observed_unix = maxi(last_observed_unix, now_unix)
	if last_observed_unix < active_end_unix:
		phase = "active"
	elif last_observed_unix < settlement_end_unix:
		phase = "settlement"
	else:
		phase = "ended"
	return phase

func is_active(now_unix: int) -> bool:
	return refresh_phase(now_unix) == "active"

func tile_score(tile_type: String, enemy_capture := true) -> int:
	var base := 5
	match tile_type:
		"mine", "forest_resource":
			base = 12
		"ruins":
			base = 15
		"fort":
			base = 30
		"citadel":
			base = 60
		"capital":
			base = 0
		_:
			base = 5
	if not enemy_capture:
		base = maxi(1, int(ceil(float(base) * 0.5)))
	return base

func record_capture(faction: String, tile_type: String, player_id: String, enemy_capture := true, now_unix := 0) -> int:
	var now := now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	if faction not in [WorldWarState.FACTION_AURELIA, WorldWarState.FACTION_NOXFERA] or not is_active(now):
		return 0
	var points := tile_score(tile_type, enemy_capture)
	if points <= 0:
		return 0
	faction_scores[faction] = int(faction_scores.get(faction, 0)) + points
	if not player_id.is_empty():
		player_contribution[player_id] = int(player_contribution.get(player_id, 0)) + points
	captures += 1
	last_event = "%s 점령 +%d" % [tile_type, points]
	return points

func record_defense(faction: String, player_id: String, defeated_forces: int, now_unix := 0) -> int:
	var now := now_unix if now_unix > 0 else int(Time.get_unix_time_from_system())
	if faction not in [WorldWarState.FACTION_AURELIA, WorldWarState.FACTION_NOXFERA] or not is_active(now):
		return 0
	var points := 3 + maxi(0, defeated_forces) * 2
	faction_scores[faction] = int(faction_scores.get(faction, 0)) + points
	if not player_id.is_empty():
		player_contribution[player_id] = int(player_contribution.get(player_id, 0)) + points
	defenses += 1
	last_event = "방어전 +%d" % points
	return points

func score_for(faction: String) -> int:
	return maxi(0, int(faction_scores.get(faction, 0)))

func contribution_for(player_id: String) -> int:
	return maxi(0, int(player_contribution.get(player_id, 0)))

func leader() -> String:
	var a := score_for(WorldWarState.FACTION_AURELIA)
	var n := score_for(WorldWarState.FACTION_NOXFERA)
	if a == n:
		return "tie"
	return WorldWarState.FACTION_AURELIA if a > n else WorldWarState.FACTION_NOXFERA

func seconds_remaining(now_unix: int) -> int:
	refresh_phase(now_unix)
	if phase == "active":
		return maxi(0, active_end_unix - last_observed_unix)
	if phase == "settlement":
		return maxi(0, settlement_end_unix - last_observed_unix)
	return 0

func status_text(now_unix: int) -> String:
	refresh_phase(now_unix)
	var remaining := seconds_remaining(now_unix)
	var days := int(remaining / 86400)
	var hours := int((remaining % 86400) / 3600)
	var phase_text := "진행" if phase == "active" else ("정산" if phase == "settlement" else "종료")
	return "%s · %s · %d일 %d시간" % [season_id, phase_text, days, hours]

func begin_next_season(world: WorldWarState, conflict: WorldConflictState, march: WorldMarchState, faction: String, now_unix: int) -> bool:
	if refresh_phase(now_unix) != "ended":
		return false
	if world == null or conflict == null or march == null:
		return false
	world.initialize_new(faction)
	# War-only consumables and fatigue reset with territory. Account/hero growth lives
	# outside WorldWarState and therefore persists across seasons.
	world.rations = WorldWarState.STARTING_RATIONS
	world.army_fatigue = 0
	conflict.reset_for_new_season()
	march.reset()
	_start(season_number + 1, now_unix)
	return true

func reward_preview(player_id: String, faction: String, now_unix: int) -> Dictionary:
	if player_id.is_empty() or faction not in [WorldWarState.FACTION_AURELIA, WorldWarState.FACTION_NOXFERA]:
		return {}
	refresh_phase(now_unix)
	var contribution := contribution_for(player_id)
	if contribution <= 0:
		return {}
	var victory_bonus := 100 if leader() == faction else (50 if leader() == "tie" else 0)
	return {
		"season_id": season_id,
		"rations": 200 + mini(800, contribution * 2),
		"honor": 50 + mini(500, contribution) + victory_bonus,
		"contribution": contribution,
		"claimable": phase in ["settlement", "ended"] and not reward_claims.has(player_id),
		"claimed": reward_claims.has(player_id)
	}

func claim_reward(world: WorldWarState, player_id: String, now_unix: int) -> Dictionary:
	if world == null:
		return {}
	var reward := reward_preview(player_id, world.faction, now_unix)
	if not bool(reward.get("claimable", false)):
		return {}
	# Credit and receipt are persisted together in the world save/snapshot.
	world.add_rations(int(reward["rations"]))
	world.campaign_honor += int(reward["honor"])
	reward_claims[player_id] = reward.duplicate(true)
	last_event = "%s 시즌 보상 수령" % player_id
	return reward

func export_state() -> Dictionary:
	return {
		"season_version": SEASON_VERSION,
		"season_number": season_number,
		"season_id": season_id,
		"phase": phase,
		"start_unix": start_unix,
		"active_end_unix": active_end_unix,
		"settlement_end_unix": settlement_end_unix,
		"faction_scores": faction_scores.duplicate(true),
		"player_contribution": player_contribution.duplicate(true),
		"captures": captures,
		"defenses": defenses,
		"last_event": last_event,
		"last_observed_unix": last_observed_unix,
		"reward_claims": reward_claims.duplicate(true)
	}

func import_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	season_number = maxi(1, WorldWarState.safe_int(data.get("season_number", 1), 1))
	season_id = "S%03d" % season_number
	start_unix = maxi(0, WorldWarState.safe_int(data.get("start_unix", 0)))
	active_end_unix = maxi(start_unix, WorldWarState.safe_int(data.get("active_end_unix", start_unix + ACTIVE_SECONDS), start_unix + ACTIVE_SECONDS))
	settlement_end_unix = maxi(active_end_unix, WorldWarState.safe_int(data.get("settlement_end_unix", active_end_unix + SETTLEMENT_SECONDS), active_end_unix + SETTLEMENT_SECONDS))
	last_observed_unix = maxi(start_unix, WorldWarState.safe_int(data.get("last_observed_unix", start_unix), start_unix))
	# Preserve an already closed phase even for legacy saves without a watermark.
	var saved_phase := str(data.get("phase", "active"))
	if saved_phase == "settlement":
		last_observed_unix = maxi(last_observed_unix, active_end_unix)
	elif saved_phase == "ended":
		last_observed_unix = maxi(last_observed_unix, settlement_end_unix)
	var scores = data.get("faction_scores", {})
	faction_scores = {WorldWarState.FACTION_AURELIA: 0, WorldWarState.FACTION_NOXFERA: 0}
	if typeof(scores) == TYPE_DICTIONARY:
		for key in faction_scores:
			faction_scores[key] = maxi(0, WorldWarState.safe_int(scores.get(key, 0)))
	player_contribution.clear()
	var contribution = data.get("player_contribution", {})
	if typeof(contribution) == TYPE_DICTIONARY:
		for key in contribution.keys().slice(0, 1000):
			player_contribution[str(key)] = maxi(0, WorldWarState.safe_int(contribution[key]))
	reward_claims.clear()
	var claims = data.get("reward_claims", {})
	if typeof(claims) == TYPE_DICTIONARY:
		for key in claims.keys().slice(0, 1000):
			if typeof(claims[key]) == TYPE_DICTIONARY:
				reward_claims[str(key)] = claims[key].duplicate(true)
	captures = maxi(0, WorldWarState.safe_int(data.get("captures", 0)))
	defenses = maxi(0, WorldWarState.safe_int(data.get("defenses", 0)))
	last_event = str(data.get("last_event", ""))
	if start_unix > 0:
		refresh_phase(last_observed_unix)
