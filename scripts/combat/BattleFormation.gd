extends RefCounted
## Stable IDs are persisted. Bonuses are applied once to freshly calculated stats.
const DEFAULT := "balanced"
const BODY=preload('res://scripts/hunting/HuntBodyCollision.gd')
const PROFILES := {
	"balanced": {"name":"균형 진형", "description":"공격력 +10% · 최대 체력 +10%", "attack":1.10, "hp":1.10, "speed":1.0},
	"assault": {"name":"돌격 진형", "description":"부대 공격력 +20%", "attack":1.20, "hp":1.0, "speed":1.0},
	"bulwark": {"name":"방벽 진형", "description":"부대 최대 체력 +20%", "attack":1.0, "hp":1.20, "speed":1.0},
	"volley": {"name":"속공 진형", "description":"기본 공격 주기 단축 · 공격 속도 +20%", "attack":1.0, "hp":1.0, "speed":1.20}
}
static func sanitize(value: Variant) -> String:
	return value if value is String and PROFILES.has(value) else DEFAULT
static func profile(id: String) -> Dictionary:
	return PROFILES[sanitize(id)].duplicate(true)
static func offsets(heroes: Array, id: String) -> Dictionary:
	var ordered: Array = heroes.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _rank(a) < _rank(b))
	var result: Dictionary = {}
	for i in ordered.size():
		# At most three depth lanes leave room for fixed 86.4px originals and
		# impact zooms. Incomplete columns center their members instead of leaning.
		var column: int = i / 3
		var members:=mini(3,ordered.size()-column*3)
		var lane: float=i%3-(members-1)*.5
		var point := Vector2(2.0 - column * 2.3, lane * 2.95)
		match sanitize(id):
			"assault": point.x += 1.2 - absf(point.y) * 0.40
			"bulwark": point = Vector2(1.8 - column * 2.1, lane * 3.0)
			"volley": point = Vector2(1.0 - column * 2.7, lane * 3.5+(0.9 if column%2==1 else 0.0))
		result[str(ordered[i].get("id", ""))] = point
	return result
static func projected_offsets(heroes: Array,id: String,gap_pixels: float=72.0) -> Dictionary:
	# The menu diagram and hunting feet share the same layout and role order.
	# Center partial parties too; scaling preserves each preset's exact shape.
	var layout:=offsets(heroes,id)
	if layout.is_empty():return layout
	var points: Array=layout.values()
	var low: Vector2=points[0];var high:=low;var nearest:=INF
	var clearance_axes:=Vector2(gap_pixels,BODY.HERO_HEIGHT_PIXELS+maxf(0,gap_pixels-BODY.HERO_PIXELS))
	for a in points.size():
		low=low.min(points[a]);high=high.max(points[a])
		for b in range(a+1,points.size()):nearest=minf(nearest,((Vector2(points[a])-Vector2(points[b]))/clearance_axes).length())
	var middle: Vector2=(low+high)*.5
	var scale: float=1.0/nearest if is_finite(nearest) and nearest>.0001 else 1.0
	for hero_id in layout:layout[hero_id]=(Vector2(layout[hero_id])-middle)*scale
	return layout
static func _rank(hero: Dictionary) -> int:
	var role: String = str(hero.get("role_group", ""))
	if role == "탱커": return 0
	if str(hero.get("reach", "ranged")) == "melee": return 1
	return 3 if role == "서포터" else 2
static func select(main: Node, id: String) -> bool:
	if not PROFILES.has(id) or main._save_blocked_for_newer_version or preload("res://scripts/persistence/SaveSafety.gd").pending(main): return false
	if main.challenge_session != null or main.raid_running or bool(main.get_meta("practice_active", false)):
		main._show_toast("도전·레이드·연습 전투를 마친 뒤 진형을 변경하세요."); return false
	if main.formation_id == id: return true
	var previous: Dictionary = main.hero_battle_state.duplicate(true)
	main.formation_id = id
	main._refresh_growth_runtime() # preserves current HP ratio; never a free heal.
	for hero_id in previous:
		if not main.hero_battle_state.has(hero_id): continue
		var old: Dictionary = previous[hero_id]
		var fresh: Dictionary = main.hero_battle_state[hero_id]
		var ratio: float = float(old.get("hp", 0)) / maxf(1.0, float(old.get("max_hp", 1)))
		fresh["hp"] = maxi(1, floori(float(fresh.max_hp) * ratio + 0.000001)) if int(old.get("hp", 0)) > 0 else 0
	main._sync_party_hp_from_heroes()
	if main.active_screen == "combat":
		main.party_movement.apply_formation(main.deployed_heroes, id)
		var field: Control=main.combat_labels.get('terrain')
		if is_instance_valid(field) and field.has_method('actor_world_height'):preload('res://scripts/maps3d/HeroCircleFormation.gd').hunt(main,field,false)
	main._save_idle_state()
	return not preload("res://scripts/persistence/SaveSafety.gd").pending(main)
