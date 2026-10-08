extends 'res://tests/support/V83UpgradeTestBase.gd'
## Native raid display bridges50ms snapshots without changing combat feet.
func _init() -> void:run.call_deferred()
func run() -> void:
	var main=await make_main('aurelia',10)
	root.size=Vector2i(1280,720);await settle()
	main.selected_raid_id='gray_meadow';main._build_raid_screen();await settle()
	main._start_raid();main.combat_timer.stop()
	var view=main.content_root.get_node('PortraitRaidView')
	var field=view.battlefield_3d
	view.set_process(false);field.set_process(false)
	main._raid_realtime_loop=true
	main.combat_effects_enabled=false
	var id: String=main._deployed_hero_ids()[0]
	var actor: AnimatedSprite2D=view.hero_actors[id]
	actor.set_process(false);actor.play_idle('right')
	var before: Vector2=main.raid_positions[id]
	var after:=before+Vector2(6,0)
	main._raid_accumulator=0;field._process(0)
	field.begin_raid_step()
	main.raid_positions[id]=after;actor.position=after
	field.finish_raid_step(.05)
	var original_rng: int=main.loot_rng.state
	var hp: Dictionary=main.hero_battle_state.duplicate(true)
	var previous: Vector2=field.raid_to_world(before)
	for fraction in [.0,.33,.66,1.0]:
		main._raid_accumulator=fraction*.05
		field._process(0)
		var shown: Vector2=field.raid_display_world(actor,after)
		print('RAID_INTERPOLATION_SAMPLE ',JSON.stringify({'fraction':fraction,'shown':shown,'before':field.raid_to_world(before),'after':field.raid_to_world(after),'active':field.battle_clock_running(),'paused':field.raid_interpolation.paused,'suspended':main._application_suspended,'visible':field.presentation_visible,'pending':SAFETY.pending(main),'engine_fraction':Engine.get_physics_interpolation_fraction()}))
		check(shown.x>=previous.x-.0001 and shown.x<=field.raid_to_world(after).x+.0001,'rendered raid foot advances monotonically '+str(fraction))
		var sprite: Sprite3D=field.actors[actor.get_instance_id()]
		check(Vector2(sprite.position.x,sprite.position.z).distance_to(shown)<.0001,'actual3D body and its child shadow share interpolated foot '+str(fraction))
		if fraction>.0 and fraction<1.0:check(shown.x>field.raid_to_world(before).x and shown.x<field.raid_to_world(after).x,'movement progresses between fixed physics steps '+str(fraction))
		previous=shown
	check(previous.distance_to(field.raid_to_world(after))<.0001,'render reaches exact simulation endpoint')
	check(main.raid_positions[id]==after and actor.position==after and main.hero_battle_state==hp and main.loot_rng.state==original_rng,'render smoothing never moves authoritative feet, warnings, HP or loot RNG')
	field.begin_raid_step();main.raid_positions[id]=after+Vector2(6,0);actor.position=main.raid_positions[id];field.finish_raid_step(.05)
	main._raid_accumulator=.02;field._process(0)
	var held: Vector2=field.raid_display_world(actor,actor.position)
	main.raid_running=false;main._raid_accumulator=.05;field._process(0)
	check(field.raid_display_world(actor,actor.position)==held,'pause holds raid display without jumping to the next endpoint')
	main.raid_running=true;field._process(0)
	check(field.raid_display_world(actor,actor.position)==held,'resume starts at the held foot')
	main.raid_encounter_serial+=1;field.begin_raid_step()
	check(not field.raid_interpolation.enabled and field._raid_display.is_empty(),'retry clears previous encounter movement history')
	main._raid_realtime_loop=false;field._process(0)
	check(field.raid_display_world(actor,actor.position)==field.raid_to_world(actor.position),'manual deterministic callers keep exact source projection')
	main.raid_running=false;await dispose(main);done('RAID_RENDER_INTERPOLATION')
