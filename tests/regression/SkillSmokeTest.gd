extends SceneTree

func _init() -> void:
	var scene = preload("res://scenes/Main.tscn")
	var main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.selected_faction = "aurelia"
	var roster: Array = main._hero_roster_for_faction()
	main.deployed_heroes = [roster[0], roster[1], roster[2], roster[3]]
	main.party_power = main._calculate_party_power()
	main.enemy_attack = 100
	main._setup_hero_skills()
	# Auto-use requires a living combat target, rather than the title screen's
	# old aggregate-damage placeholder. Exercise the real single-boss context.
	main.active_screen = "raid"
	main.raid_boss_hp = 10000
	main.raid_boss_max_hp = 10000
	main.raid_boss_attack = 100
	if main.hero_skill_runtime.size() != 4:
		push_error("Expected four hero skill runtimes")
		quit(1)
	var tank_profile: Dictionary = main._hero_skill_profile("leonhardt")
	var damage_profile: Dictionary = main._hero_skill_profile("mira")
	var support_profile: Dictionary = main._hero_skill_profile("elisia")
	if tank_profile["role_group"] != "탱커" or damage_profile["role_group"] != "딜러" or support_profile["role_group"] != "서포터":
		push_error("Role profile mapping failed")
		quit(1)
	var injured: Dictionary = main.hero_battle_state["mira"]
	injured["hp"] = maxi(1, int(injured["max_hp"] * 0.35))
	main._sync_party_hp_from_heroes()
	var hp_before: int = int(injured["hp"])
	var damage: int = main._run_hero_skills()
	var offensive_cooldown: bool = float(main.hero_skill_runtime["mira"]["remaining"]) > 0.0 or float(main.hero_skill_runtime["kairen"]["remaining"]) > 0.0
	if damage <= 0 or not offensive_cooldown:
		push_error("Skill damage or cooldown initialization failed")
		quit(1)
	var before_cooldown: float = float(main.hero_skill_runtime["mira"]["remaining"])
	main._advance_skill_cooldowns(0.5)
	if before_cooldown > 0.0 and float(main.hero_skill_runtime["mira"]["remaining"]) >= before_cooldown:
		push_error("Cooldown did not tick down")
		quit(1)
	print("skill_smoke_test_ok damage=%d cooldown=%.2f" % [damage, float(main.hero_skill_runtime["mira"]["remaining"])])
	main.free()
	# AudioServer releases stopped playback on its next mix, not the render frame.
	await create_timer(0.3).timeout
	quit(0)
