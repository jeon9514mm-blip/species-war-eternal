extends SceneTree

func _fail(message: String, main = null) -> void:
	push_error(message)
	if is_instance_valid(main):
		main.free()
	quit(1)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var world = WorldWarState.new()
	world.initialize_new(WorldWarState.FACTION_AURELIA)
	var march = WorldMarchState.new()
	var resolver = WorldBattleResolver.new()

	# Build a legal front: own route to x=6, enemy target at x=7 (outside sanctuary).
	for x in range(3, 7):
		world._set_owner(Vector2i(x, 10), WorldWarState.FACTION_AURELIA)
	world.army_position = Vector2i(6, 10)
	var target = Vector2i(7, 10)
	world._set_owner(target, WorldWarState.FACTION_NOXFERA)
	if not world.can_attack_enemy_tile(WorldWarState.FACTION_AURELIA, target):
		_fail("V14: 적 타일 공격 가능 판정 실패")
		return
	var plan = march.plan(world, target)
	if plan.is_empty() or str(plan.get("action", "")) != "attack_enemy":
		_fail("V14: 적 영토 공격 행군 계획 실패")
		return
	if not march.begin(world, target):
		_fail("V14: 적 영토 공격 행군 시작 실패")
		return
	var arrival = march.advance(march.duration_seconds + 0.1, world)
	if not bool(arrival.get("battle_required", false)):
		_fail("V14: 공격 행군 도착 후 전투 요구 실패")
		return
	if world.tile_owner(target) != WorldWarState.FACTION_NOXFERA:
		_fail("V14: 전투 전 타일이 조기 점령됨")
		return

	var attackers: Array = []
	for i in 10:
		attackers.append({"id":"a%d"%i, "name":"공격%d"%i, "role":"딜러", "row":"중열", "max_hp":700, "hp":700, "attack":120, "defense":20})
	var defenders = resolver.make_garrison(WorldWarState.FACTION_NOXFERA, target, "plain", 800)
	world.set_garrison(target, defenders)
	var result = resolver.resolve(attackers, world.garrison_at(target), world.army_fatigue, 1.0, 777)
	if not bool(result.get("victory", false)):
		_fail("V14: 테스트 공격대 승리 실패")
		return
	world.add_fatigue(12)
	if not world.capture_enemy_after_battle(target, WorldWarState.FACTION_AURELIA):
		_fail("V14: 승리 후 적 영토 점령 실패")
		return
	var report = result.duplicate(true)
	report["tile_name"] = world.tile_display_name(target)
	report["fatigue_after"] = world.army_fatigue
	world.record_battle_report(report)
	if world.tile_owner(target) != WorldWarState.FACTION_AURELIA or not world.garrison_at(target).is_empty():
		_fail("V14: 점령 소유권/수비대 정리 실패")
		return
	if world.latest_battle_report().is_empty() or world.army_fatigue != 12:
		_fail("V14: 전투 리포트/피로도 기록 실패")
		return

	var scene = preload("res://scenes/Main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.set_physics_process(false)
	# Combat fixture keeps its original stage difficulty with a valid legacy party capacity.
	main.party_slot_legacy_cap = 10
	main.selected_faction = "aurelia"
	main._restore_deployed_heroes(["leonhardt", "mira", "elisia"])
	main._setup_hero_progress(main._hero_roster_for_faction())
	var snapshot = main._world_party_snapshot()
	if snapshot.size() != 3 or int(snapshot[0].get("max_hp", 0)) <= 0:
		_fail("V14: 실제 영웅 월드전 스냅샷 생성 실패", main)
		return
	main._build_faction_war_screen()
	await process_frame
	var war_screen: WorldWarScreen = null
	for child in main.content_root.get_children():
		if child is WorldWarScreen:
			war_screen = child
			break
	if war_screen == null or war_screen.attacker_squad.size() != 3:
		_fail("V14: PvP 스냅샷 UI 전달 실패", main)
		return
	print("v14_async_pvp_smoke_test_ok march=attack battle=ok capture=ok fatigue=ok report=ok snapshot=ok")
	main.free()
	quit(0)
