extends 'res://tools/diagnostics/game-audit-2026-10-07/MovementPacingProbe.gd'
## Production timings first; explicit art-review fixture captures afterwards.
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join(name+'.png'))
func run() -> void:
	assert(DisplayServer.get_name()!='headless');output=OS.get_environment('GAME_AUDIT_OUTPUT');DirAccess.make_dir_recursive_absolute(output)
	game=load('res://scenes/PortraitMain.tscn').instantiate();game.save_state_path='user://final-polish-review.json';game._offline_checked=true;root.add_child(game);await settle()
	game.sound_effects_enabled=false;game.combat_effects_enabled=true;game.combat_fx.enabled=true;game.tutorial_completed=true;game._set_presentation_option('music_enabled',false,false);game._set_presentation_option('performance','balanced',false)
	report.renderer=RenderingServer.get_current_rendering_method();report.device=RenderingServer.get_video_adapter_name();report.engine=Engine.get_version_info().string;report.assets=[]
	if OS.get_environment('FINAL_CAPTURES_ONLY')!='1':
		if OS.get_environment('FINAL_RAID_ONLY')!='1':
			for faction in ['aurelia','noxfera']:
				await fixture(faction);game.combat_running=true;await measure('hunt-'+faction,8)
		else:await fixture('noxfera')
		game.selected_raid_id='gray_meadow';game._build_raid_screen();await settle();game._start_raid();await measure('raid',6)
		game.raid_running=false;game.combat_running=false;game.presentation_runtime.contact_time.restore()
		# A valid equipped guardian enables natural critical rolls. Its bonuses
		# are unchanged; this additional fixture measures the bounded slowdown.
		if OS.get_environment('FINAL_RAID_ONLY')!='1':
			game.guardian_collection['eclipse']={'copies':7};game.guardian_equipped='eclipse';game.loot_rng.seed=20261008
			await fixture('noxfera');game.combat_running=true;await measure('hunt-natural-crits',10)
			report.crit_fixture={'guardian':'eclipse','copies':7,'seed':20261008,'natural_crit_chance':game._guardian_bonus('crit')}
		report.raid_only=OS.get_environment('FINAL_RAID_ONLY')=='1'
		game.combat_running=false;game.presentation_runtime.contact_time.restore()
		var timing_file=FileAccess.open(output.path_join('performance.json'),FileAccess.WRITE);timing_file.store_string(JSON.stringify(report,'  '));timing_file.close()
	# Wallet/levels here are review fixtures, not rewards or a player's save.
	game.set_physics_process(false);game.set_process(false);game.presentation_runtime.contact_time.enabled=false
	game.wallet_gold=48260;game.wallet_gems=840;game.skill_auto=false;game.ultimate_auto=false
	await fixture('aurelia');game.combat_running=true
	game.set_physics_process(false);game.set_process(false)
	if is_instance_valid(game.combat_timer):game.combat_timer.stop()
	for i in 90:game._advance_auto_hunt(1.0/30)
	game.wallet_gold+=350;game.wallet_gems+=5;game.presentation_runtime.get_node('LootRewardFeedback')._process(0)
	var field=game.combat_labels.terrain;field._process(0)
	var notes: Dictionary={'art_review_fixture':true,'wallet_start':[48260,840],'showcase_uses_actual_skill_cast':true,'skills':[]}
	for i in mini(4,game.deployed_heroes.size()):
		var id: String=str(game.deployed_heroes[i].id)
		var target: int=game._select_enemy_target(id)
		var accepted: int=field.skill_overlay.accepted_casts
		preload('res://scripts/heroes/HeroKitRuntime.gd').cast(game,id,'a1',target)
		notes.skills.append({'hero':id,'accepted':field.skill_overlay.accepted_casts>accepted})
	field.skill_overlay.advance(.18);field.hunt_overlay._process(.08);field._process(.08)
	await process_frame;await capture('hunt-final-review')
	game.combat_running=false;await fixture('noxfera');game.combat_running=true
	game.set_physics_process(false);game.set_process(false)
	if is_instance_valid(game.combat_timer):game.combat_timer.stop()
	for i in 90:game._advance_auto_hunt(1.0/30)
	field=game.combat_labels.terrain;field._process(0);notes.element_casts=[]
	# Explicit four-element pose fixture: valid living targets in skill range,
	# ready cooldowns and wounded allies. Still use the real kit settlement.
	notes.element_layout_fixture=true
	preload('res://scripts/maps3d/HeroCircleFormation.gd').hunt(game,field,true)
	for state in game.hero_battle_state.values():state.hp=maxi(1,int(state.max_hp*.7))
	for runtime in game.hero_skill_runtime.values():runtime.remaining=0
	var caster_slots: Array=[0,1,5,6]
	for index in caster_slots.size():
		var id: String=str(game.deployed_heroes[caster_slots[index]].id)
		game.enemy_wave[index].hp=100000;game.enemy_wave[index].max_hp=100000
		game.roaming_hunt.enemy_positions[index]=game._hero_field_position(id)+Vector2(.35,0)
	field.hunt_interpolation=preload('res://scripts/maps3d/HuntRenderInterpolation.gd').new();field._process(0)
	for index in caster_slots.size():
		var i: int=int(caster_slots[index])
		var id: String=str(game.deployed_heroes[i].id)
		var accepted: int=field.skill_overlay.accepted_casts
		preload('res://scripts/heroes/HeroKitRuntime.gd').cast(game,id,'a1',index)
		notes.element_casts.append({'hero':id,'element':field.skill_overlay.element_for(id,{}),'accepted':field.skill_overlay.accepted_casts>accepted})
	field.skill_overlay.advance(.08);field._process(.02);await process_frame;await capture('skill-elements-review')
	game.combat_running=false;game.selected_raid_id='gray_meadow';game._build_raid_screen();await settle();game._start_raid();game.combat_timer.stop()
	game.set_physics_process(false);game.set_process(false)
	field=game.content_root.get_node('PortraitRaidView').battlefield_3d
	# Entry curtains use a real presentation Tween, not manual combat steps.
	# Freeze simulation while waiting for its .77 second opening to finish.
	await create_timer(.9,true,false,true).timeout
	notes.raid_entry_wait_seconds=.9
	for i in 30:
		game._advance_raid_encounter(.05)
		field.raid_view._process(.05);field._process(.05)
	notes.raid_manual_steps=30;notes.raid_step_seconds=.05
	field._process(.02)
	await create_timer(.25,true,false,true).timeout
	field._process(.02);await process_frame;await capture('raid-final-review')
	var boss_paint=field.actors[game.raid_boss_sprite.get_instance_id()].get_node('HuntFramePilot')
	notes.raid_paint={'id':boss_paint.entry.id,'flash':boss_paint.material_override.get_shader_parameter('hit_flash'),'tint':str(boss_paint.material_override.get_shader_parameter('actor_tint')),'snapshot':boss_paint.debug_snapshot()}
	game.combat_effects_enabled=false;field._process(0);await process_frame;await capture('raid-clean-body')
	game.raid_running=false;var file=FileAccess.open(output.path_join('review-fixture.json'),FileAccess.WRITE);file.store_string(JSON.stringify(notes,'  '));file.close()
	game.presentation_runtime.audio.shutdown();game.background_hunt.discard();game.queue_free();await settle();print('FINAL_POLISH_REVIEW_OK');quit()
