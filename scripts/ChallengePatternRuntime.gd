extends RefCounted
## Game-clock-only behavior. Markers have no Tween/wall-clock expiry.
const RULES = preload("res://scripts/ChallengePatternRules.gd")

static func valid(main: Node, index: int) -> bool:
	var session: ChallengeBattleSession = main.challenge_session
	return (session != null and session.is_running() and session.elapsed < session.limit_seconds
		and session.serial == int(main.challenge_serial) and session.active_wave_token == int(main.hunt_ai.encounter_id)
		and str(main.active_screen) == "combat" and main.combat_running and not main._application_suspended
		and index >= 0 and index < main.enemy_wave.size() and int(main.enemy_wave[index].get("hp", 0)) > 0)

static func _metric(main: Node, key: String, amount: int = 1) -> void:
	var metrics: Dictionary = main.challenge_session.pattern_metrics
	metrics[key] = int(metrics.get(key, 0)) + amount

static func _cue(main: Node, index: int, text: String) -> void:
	if index >= main.enemy_wave_sprites.size() or not is_instance_valid(main.enemy_wave_sprites[index]): return
	var sprite: Node = main.enemy_wave_sprites[index]
	var label: Label = sprite.get_node_or_null("ChallengePatternCue")
	if label == null:
		label = Label.new(); label.name = "ChallengePatternCue"
		label.position = Vector2(-100, -105); label.size = Vector2(200, 48)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE; label.z_index = 65
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color("#fff0dc"))
		label.add_theme_color_override("font_outline_color", Color("#1e2230"))
		label.add_theme_constant_override("outline_size", 4)
		sprite.add_child(label)
	label.text = text; label.visible = not text.is_empty()

static func initialize_cues(main: Node) -> void:
	for index in main.enemy_wave.size():
		var role: String = str(main.enemy_wave[index].get("challenge_pattern_role", ""))
		if role == "healer": _cue(main, index, "회복 지원 · 3회")
		elif role == "charger": _cue(main, index, "강타 · 기절로 차단")
		elif role == "split": _cue(main, index, "분산 진형")

static func interrupt(main: Node, index: int) -> void:
	if not valid(main, index): return
	var enemy: Dictionary = main.enemy_wave[index]
	if float(enemy.get("pattern_cast_remaining", 0.0)) <= 0.0: return
	enemy["pattern_cast_remaining"] = 0.0; enemy["pattern_cooldown"] = 7.0
	enemy["pattern_target"] = ""
	_metric(main, "interrupts")
	main.skill_event_text = "강타 차단 성공 · 준비한 공격 취소"
	_cue(main, index, "차단 성공")

# True means this enemy consumed its action through pattern behavior.
static func tick_enemy(main: Node, index: int, delta: float) -> bool:
	if not valid(main, index) or not is_finite(delta) or delta <= 0.0: return false
	var enemy: Dictionary = main.enemy_wave[index]
	var role: String = str(enemy.get("challenge_pattern_role", ""))
	if role not in ["healer", "charger"]: return false
	if main.roaming_hunt.is_returning(index):
		enemy["pattern_cast_remaining"] = 0.0; enemy["pattern_target"] = ""
		_cue(main, index, "귀환 · 시전 취소" if role == "charger" else "귀환 · 회복 대기")
		return true
	if float(enemy.get("stun_seconds", 0.0)) > 0.0:
		interrupt(main, index)
		return true
	if role == "healer":
		# Do not fall through to the generic support heal, which is unlimited.
		if int(enemy.get("pattern_heals_left", 0)) <= 0: return true
		enemy["pattern_cooldown"] = maxf(0.0, float(enemy.get("pattern_cooldown", 4.0)) - delta)
		if float(enemy["pattern_cooldown"]) > 0.0: return true
		enemy["pattern_cooldown"] = 4.0
		for ally_index in main.enemy_wave.size():
			var ally: Dictionary = main.enemy_wave[ally_index]
			if str(ally.get("id", "")) != str(enemy.get("pattern_leader_id", "")) or int(ally["hp"]) <= 0: continue
			if main.roaming_hunt.is_returning(ally_index) or main.roaming_hunt.enemy_position(index).distance_to(main.roaming_hunt.enemy_position(ally_index)) > 4.5: continue
			var healed: int = main._heal_enemy(ally_index, maxi(1, int(float(ally["max_hp"]) * 0.04)))
			if healed > 0:
				enemy["pattern_heals_left"] -= 1
				_metric(main, "heals"); _metric(main, "healed_hp", healed)
				_cue(main, index, "회복 지원 · 남은 %d회" % int(enemy["pattern_heals_left"]))
				main.skill_event_text = "지원몹 회복 +%d · 지원몹 우선 처치 또는 집중 공격" % healed
			break
		return true
	var remaining: float = float(enemy.get("pattern_cast_remaining", 0.0))
	if remaining > 0.0:
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0.00001: remaining = 0.0
		enemy["pattern_cast_remaining"] = remaining
		var id: String = str(enemy.get("pattern_target", ""))
		_cue(main, index, "강타 %.1f초 · 기절로 차단" % remaining)
		if remaining <= 0.0:
			enemy["pattern_cooldown"] = 7.0; enemy["pattern_target"] = ""
			var hit: bool = main.hero_battle_state.has(id) and int(main.hero_battle_state[id].get("hp", 0)) > 0
			if hit: hit = main._hero_field_position(id).distance_to(main.roaming_hunt.enemy_position(index)) <= main._enemy_attack_range(enemy) + 0.35
			if hit:
				main._incoming_damage_to_hero(id, maxi(1, int(enemy["attack"]) * 2), index)
				_metric(main, "casts_completed"); _cue(main, index, "강타 발동")
			else:
				_metric(main, "casts_missed"); _cue(main, index, "대상 이탈 · 불발")
		return true
	enemy["pattern_cooldown"] = maxf(0.0, float(enemy.get("pattern_cooldown", 5.0)) - delta)
	if float(enemy["pattern_cooldown"]) <= 0.0:
		var target: String = main._select_hero_target_for_enemy(index, true)
		if not target.is_empty():
			enemy["pattern_target"] = target; enemy["pattern_cast_remaining"] = 2.0
			_metric(main, "casts_started")
			_cue(main, index, "강타 2.0초 · 기절로 차단")
			main.skill_event_text = "강타 시전 · 기절로 차단하거나 방어·회복으로 대비하세요."
			main._presentation_event("boss_warning")
			return true
	return false

static func clear_cues(main: Node) -> void:
	for sprite in main.enemy_wave_sprites:
		if not is_instance_valid(sprite): continue
		var cue: Node = sprite.get_node_or_null("ChallengePatternCue")
		if cue != null: cue.queue_free()

static func enemy_defeated(main: Node, index: int) -> void:
	if index < 0 or index >= main.enemy_wave.size(): return
	main.enemy_wave[index]["pattern_cast_remaining"] = 0.0
	if index >= main.enemy_wave_sprites.size() or not is_instance_valid(main.enemy_wave_sprites[index]): return
	var cue: Node = main.enemy_wave_sprites[index].get_node_or_null("ChallengePatternCue")
	if cue != null: cue.queue_free()
