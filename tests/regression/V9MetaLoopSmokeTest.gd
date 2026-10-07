extends SceneTree

func _fail(message: String, main) -> void:
	push_error(message)
	if is_instance_valid(main):
		main.free()
	quit(1)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
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
	main._setup_hero_skills()

	# Summon and pity.
	main.wallet_gems = 2000
	main.summon_pity = 9
	var summon = main._summon_once()
	if summon.is_empty() or int(summon.get("shards", 0)) != 30 or main.summon_pity != 0:
		_fail("V9: 10회 소환 천장/조각 보장 실패", main)
		return

	# Breakthrough consumes shards and raises combat power.
	var hero_id = "mira"
	main.hero_shards[hero_id] = 100
	var before_power = main._calculate_party_power()
	if not main._try_breakthrough(hero_id):
		_fail("V9: 영웅 돌파 실패", main)
		return
	if main._hero_breakthrough_rank(hero_id) != 1 or main._calculate_party_power() <= before_power:
		_fail("V9: 돌파 전투력 반영 실패", main)
		return

	# Quest reward.
	main.idle_stage = 5
	main.wallet_gold = 0
	main.wallet_gems = 0
	if not main._claim_quest("stage5"):
		_fail("V9: 스테이지 퀘스트 수령 실패", main)
		return
	if main.wallet_gold != 500 or main.wallet_gems != 20:
		_fail("V9: 퀘스트 보상 수치 실패", main)
		return

	# Daily dungeon.
	main.party_power = 99999
	main.daily_dungeon_day = main._today_key()
	main.daily_dungeon_runs = 0
	var old_calc = main._calculate_party_power()
	if old_calc <= 0:
		_fail("V9: 전투력 계산 실패", main)
		return
	# Give levels so the compact party can clear first dungeon.
	for h in main.deployed_heroes:
		main.hero_progress[str(h["id"])] = {"level": 20, "xp": 0}
	var daily_started: bool = main._run_daily_dungeon()
	var daily_ticks: int = 0
	while main.challenge_session != null and daily_ticks < 2000:
		main._advance_auto_hunt(1.0 / 30.0)
		daily_ticks += 1
	if not daily_started or main.daily_dungeon_runs != 1:
		_fail("V9: 일일 던전 진행 실패", main)
		return

	# Tower.
	main.tower_floor = 1
	main.tower_best_floor = 0
	if not main._challenge_tower():
		_fail("V9: 무한탑 도전 실패", main)
		return
	if main.tower_floor != 1 or main.tower_best_floor != 0:
		_fail("V80: 무한탑 입장 시 즉시 층 상승", main)
		return
	var tower_ticks: int = 0
	while main.challenge_session != null and tower_ticks < 3000:
		main._advance_auto_hunt(1.0 / 30.0)
		tower_ticks += 1
	if main.tower_floor != 2 or main.tower_best_floor != 1:
		_fail("V9: 무한탑 진행 저장 실패", main)
		return

	# Auto salvage threshold.
	main.loot_inventory.clear()
	main.wallet_gold = 0
	main.auto_salvage_min_rarity = "희귀"
	var result = main._store_or_salvage_loot({"name":"테스트 검", "slot":"weapon", "rarity":"일반", "level":1, "power":10})
	if not main.loot_inventory.is_empty() or main.wallet_gold <= 0 or not "자동 분해" in result:
		_fail("V9: 자동 분해 기준 실패", main)
		return

	print("v9_meta_loop_smoke_test_ok summon=ok breakthrough=ok quest=ok dungeon=ok tower=ok salvage=ok")
	main.free()
	quit(0)
