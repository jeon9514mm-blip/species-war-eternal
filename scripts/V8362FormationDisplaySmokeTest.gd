extends "res://scripts/V83UpgradeTestBase.gd"
const B=preload("res://scripts/BattleFormation.gd")
const D=preload("res://scripts/DisplayOrientation.gd")
func _init() -> void: _run.call_deferred()
func _run() -> void:
	check(B.sanitize("invalid")=="balanced" and B.sanitize(null)=="balanced","invalid formation defaults")
	var old: Dictionary=SaveValidation.sanitize({"save_version":36,"selected_faction":"aurelia"},["gray_meadow"])
	check(old.formation_id=="balanced","older save receives default")
	for faction: String in ["aurelia","noxfera"]:
		var main=await make_main(faction,10)
		main.idle_stage=1;main.formation_id="volley";main._build_combat_screen();await settle()
		for hero in main.deployed_heroes:
			var hero_id: String=hero.id
			var station: Vector2=main.field_navigation.clamp_to_walkable(main.expedition_position+Vector2(main.party_movement.travel_offsets[hero_id]))
			check(main._hero_field_position(hero_id).is_equal_approx(station),"initial placement uses selected formation "+hero_id)
		var live_positions: Dictionary=main.party_movement.positions.duplicate()
		var id: String=main.deployed_heroes[0].id
		var base: Dictionary=main.hero_battle_state[id].duplicate(true)
		check(B.select(main,"assault"),"formation selection")
		check(main.party_movement.positions==live_positions,"live formation changes do not teleport heroes")
		var assault: Dictionary=main.hero_battle_state[id].duplicate(true)
		check(assault.attack==roundi(base.attack*1.2),"assault attack +20%")
		check(is_equal_approx(assault.attack_interval_mult/base.attack_interval_mult,1.2),"volley increases base attack speed 20%")
		main.hero_battle_state[id].hp=137
		var dead: String=main.deployed_heroes[1].id;main.hero_battle_state[dead].hp=0
		check(B.select(main,"bulwark"),"bulwark selection")
		check(main.hero_battle_state[id].max_hp==roundi(base.max_hp*1.2),"bulwark hp +20%")
		for i in 8: B.select(main,"assault");B.select(main,"bulwark")
		B.select(main,"assault")
		check(main.hero_battle_state[id].hp<=137 and main.hero_battle_state[dead].hp==0,"repeated switching cannot heal or revive")
		var saved: Dictionary=main.save_store.read_save(main.save_state_path)
		check(saved.get("ok",false) and saved.data.formation_id=="assault" and int(saved.data.save_version)==37,"schema37 persists formation")
		var before: Dictionary={"heroes":main.hero_battle_state.duplicate(true),"enemies":main.enemy_wave.duplicate(true),"clock":main.invasion.clock,"positions":main.roaming_hunt.enemy_positions.duplicate(),"gold":main.unclaimed_gold}
		for choice: String in ["landscape","portrait","auto"]:
			main.presentation_options.orientation=choice;D.apply(main,false)
			root.size=Vector2i(1280,720) if choice=="landscape" else Vector2i(720,1280)
			await settle(); main._apply_portrait_resize();await settle()
			check(main.presentation_options.orientation=="landscape" and root.content_scale_size==Vector2i(1280,720) and main.get_viewport_rect().size.x>main.get_viewport_rect().size.y,"legacy choice stays landscape "+choice)
			check(main.hero_battle_state==before.heroes and main.enemy_wave==before.enemies and main.invasion.clock==before.clock and main.roaming_hunt.enemy_positions==before.positions and main.unclaimed_gold==before.gold,"resizing preserves battle state "+choice)
			check(is_instance_valid(main.portrait_hud),"HUD rebuilt")
			var button=main.portrait_hud.find_child("HuntFormation",true,false)
			check(button!=null and Rect2(Vector2.ZERO,main.get_viewport_rect().size).encloses(button.get_global_rect()),"formation command on screen "+choice)
		main.presentation_options.orientation="auto";root.size=Vector2i(720,1280);D.apply(main,false);await settle()
		check(root.content_scale_size==Vector2i(1280,720) and root.content_scale_aspect==Window.CONTENT_SCALE_ASPECT_KEEP,"portrait physical window preserves landscape content")
		root.size=Vector2i(1280,720);D.apply(main,false);await settle()
		check(root.content_scale_size==Vector2i(1280,720) and root.content_scale_aspect==Window.CONTENT_SCALE_ASPECT_EXPAND,"landscape physical window expands combat space")
		var pref: String="user://orientation-test.cfg"
		for old_choice: String in ["portrait","auto"]:
			var legacy:=ConfigFile.new()
			legacy.set_value("presentation_v82","orientation",old_choice)
			legacy.set_value("presentation_v82","music_volume",0.23)
			legacy.set_value("presentation_v82","performance","battery")
			check(legacy.save(pref)==OK,"legacy preferences fixture writes")
			var normalized: Dictionary=PresentationSettings.load_preferences(pref).options
			check(normalized.orientation=="landscape" and is_equal_approx(normalized.music_volume,0.23) and normalized.performance=="battery","legacy preference migrates without changing sound/performance "+old_choice)
			check(PresentationSettings.save_preferences(true,false,normalized,pref)==OK,"landscape local preferences save")
			var written:=ConfigFile.new();written.load(pref)
			check(written.get_value("presentation_v82","orientation")=="landscape","saved file replaces legacy orientation "+old_choice)
		main.idle_stage=100;main._build_lobby_screen();await settle();B.select(main,"bulwark")
		check(PRESET.save(main,0).get("ok",false),"preset stores formation")
		B.select(main,"assault")
		var preview: Dictionary=PRESET.plan(main,0)
		check(bool(preview.get("ok",false)),"preset preview")
		# Existing preset suite exercises apply transaction; model must retain formation ID.
		check(PRESET.get_preset(main,0).formation_id=="bulwark","preset formation survives sanitize")
		check(PRESET.apply(main,0).get("ok",false) and main.formation_id=="bulwark","preset applies saved formation")
		await dispose(main)
	done("v8362_formation_display")
