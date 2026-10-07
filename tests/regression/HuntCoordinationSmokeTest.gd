extends "res://tests/support/V83UpgradeTestBase.gd"
const RESERVATIONS=preload('res://scripts/hunting/HuntDamageReservations.gd')
const BULK=preload('res://scripts/equipment/BulkEnhancePreview.gd')
const COLLISION=preload('res://scripts/hunting/HuntBodyCollision.gd')
const EFFICIENCY=preload('res://scripts/hunting/HuntEfficiency.gd')
class ClosedNavigation extends "res://scripts/hunting/MeadowNavigation.gd":
	func is_walkable(_point: Vector2) -> bool:return false
	func has_clear_path(_from: Vector2,_to: Vector2) -> bool:return false
func _init() -> void:run.call_deferred()
func touch(main, named: String) -> void:
	var button: Control=main.content_root.find_child(named,true,false)
	check(button!=null and button.is_visible_in_tree(),'visible command '+named)
	if button==null:return
	var point:=root.get_final_transform()*button.get_global_rect().get_center()
	for down in [true,false]:
		var event:=InputEventScreenTouch.new();event.position=point;event.pressed=down;Input.parse_input_event(event)
	await settle()
func run() -> void:
	var main=await make_main('aurelia',3)
	main._build_combat_screen();await settle()
	var ids: Array=main._deployed_hero_ids()
	for id in ids:main.party_movement.positions[id]=Vector2(16,10);main.hero_skill_runtime[id].windup=-1
	main.roaming_hunt.enemy_positions[0]=Vector2(16.5,10)
	main.roaming_hunt.enemy_positions[1]=Vector2(16.5,10.3)
	main.enemy_wave[0].hp=1;main.enemy_wave[0].elite=false
	main.enemy_wave[1].hp=1000;main.enemy_wave[1].elite=false
	main.hero_skill_runtime[ids[0]].windup=.1;main.hero_skill_runtime[ids[0]].target_index=0;main.hero_skill_runtime[ids[0]].prepared_action='basic'
	check(RESERVATIONS.pending(main,0,ids[1])>1,'pending hero hit covers fragile enemy without RNG')
	check(RESERVATIONS.choose(main,ids[2],0)!=0,'unreserved reachable enemy is selected before duplicate kill')
	var hp: int=main.enemy_wave[0].hp;var rng_state: int=main.loot_rng.state
	RESERVATIONS.choose(main,ids[2],0)
	check(main.enemy_wave[0].hp==hp and main.loot_rng.state==rng_state,'prediction applies no damage and consumes no RNG')
	main.hero_skill_runtime[ids[0]].windup=-1
	check(RESERVATIONS.pending(main,0,ids[2])==0,'finished/cancelled preparations release damage reservation')
	main.enemy_wave[0].elite=true
	check(RESERVATIONS.choose(main,ids[2],0)==0,'elite focus remains available')
	main._build_combat_screen();await settle()
	var fixed: String=ids[0];main.hero_skill_runtime[fixed].windup=1
	var position: Vector2=main._hero_field_position(fixed)
	main.party_movement.advance(.1,main.deployed_heroes,main.hero_battle_state,main.hero_skill_runtime,main.expedition_position,main.enemy_wave,main.roaming_hunt.enemy_positions,main.roaming_hunt.enemy_returning,true)
	check(main._hero_field_position(fixed)==position,'casting hero is not pushed or redirected')
	var before: Dictionary=main.party_movement.positions.duplicate()
	main.party_movement.advance(.1,main.deployed_heroes,main.hero_battle_state,main.hero_skill_runtime,main.expedition_position,main.enemy_wave,main.roaming_hunt.enemy_positions,main.roaming_hunt.enemy_returning,true,true)
	check(main.party_movement.positions==before,'pause freezes reservations and steering')
	for id in main.party_movement.hunt_slots:
		var target: int=main.party_movement.hunt_slots[id].target
		var goal: Vector2=main.party_movement.combat_goals[id].goal
		check(main.field_navigation.is_walkable(goal),'attack goal is on walkable terrain')
		check(goal.distance_to(main.roaming_hunt.enemy_position(target))<=main.combat_decisions.spatial_range(int(main.hero_battle_state[id].range))+.01,'reserved goal remains inside real attack reach')
	# Deliberately coincident walkers must yield to a fixed caster on both teams.
	for id in ids:main.hero_skill_runtime[id].windup=-1;main.party_movement.positions[id]=Vector2(16,10)
	main.hero_skill_runtime[ids[0]].windup=.2
	main.roaming_hunt.enemy_positions[0]=Vector2(16,10)
	main.roaming_hunt.enemy_positions[1]=Vector2(16.05,10)
	for enemy in main.enemy_wave:enemy.erase('attack_intent');enemy.stun_seconds=0;enemy.hunt_recovery=0
	check(not COLLISION.can_commit(main,true,ids[1]) and not COLLISION.can_commit(main,false,0),'overlapping walkers do not freeze in a new attack windup')
	COLLISION.resolve(main,.1)
	var overlaps:=COLLISION.overlapping(main)
	check(overlaps.hero_hero==0 and overlaps.enemy_enemy==0 and overlaps.hero_enemy==0,'body solver separates both teams and cross-team contacts')
	check(main.party_movement.positions[ids[0]]==Vector2(16,10),'body solver keeps a committed caster fixed')
	for id in ids:check(main.field_navigation.is_walkable(main.party_movement.positions[id]),'body correction remains on navigable terrain')
	EFFICIENCY.begin(main);EFFICIENCY.advance(main,30);EFFICIENCY.kill(main);EFFICIENCY.reward(main,90)
	EFFICIENCY.advance(main,30)
	var summary:=EFFICIENCY.summary(main)
	check(summary.seconds==60 and summary.kills_per_minute==1 and summary.gold_per_minute==90,'efficiency reports observed kills and receipts in game time')
	main.current_zone_id='forgotten_mine';EFFICIENCY.advance(main,1)
	check(EFFICIENCY.summary(main).seconds==1 and EFFICIENCY.summary(main).kills_per_minute==0,'region change starts a fresh efficiency comparison')
	main.current_zone_id='gray_meadow'
	var balance: int=main.wallet_gold
	main._build_inventory_screen();await settle();main._bulk_enhance_equipped();await settle()
	check(main.wallet_gold==balance and main.content_root.has_node('BulkEnhancePreview'),'opening bulk preview spends nothing')
	await touch(main,'BulkEnhanceCancel')
	check(main.wallet_gold==balance,'cancelling bulk preview spends nothing')
	var plan:=BULK.preview(main,balance)
	check(plan.cost<=balance and not plan.rows.is_empty(),'bulk plan respects explicit budget')
	var first: Dictionary=plan.rows[0]
	var result:=BULK.execute(main,plan)
	check(result.ok and main.wallet_gold==balance-int(plan.cost),'bulk execution spends exactly confirmed total')
	check(int(main._gear_item('',first.id,first.slot).level)==int(first.item.level)+1,'bulk upgrade updates complete item and legacy maps together')
	var after: int=main.wallet_gold
	check(not BULK.execute(main,plan).ok and main.wallet_gold==after,'repeated stale confirmation cannot spend twice')
	var stale:=BULK.preview(main,main.wallet_gold);main.wallet_gold=0
	check(not BULK.execute(main,stale).ok and main.wallet_gold==0,'changed wallet rejects a stale bulk plan')
	main.wallet_gold=after
	var too_small:=BULK.preview(main,0)
	check(too_small.rows.is_empty() and too_small.cost==0,'zero budget cannot upgrade anything')
	var confirmed:=BULK.preview(main,int(main.wallet_gold*.5));var before_touch: int=main.wallet_gold
	main._bulk_enhance_equipped();await settle();await touch(main,'DialogConfirm')
	check(main.wallet_gold==before_touch-int(confirmed.cost),'touch confirmation applies precisely the displayed bulk budget once')
	main._open_home();await settle()
	var field: Control=main.combat_labels.terrain
	var gold: int=main.wallet_gold;var hp_states: Dictionary=main.hero_battle_state.duplicate(true);var reward_rng: int=main.loot_rng.state
	main.presentation_options.performance='battery';main.presentation_runtime.apply();await settle()
	check(field.viewport_3d.msaa_3d==Viewport.MSAA_DISABLED and field.viewport_3d.positional_shadow_atlas_size==256,'battery mode reduces 3D antialiasing and shadow budget')
	check(field._render_container.stretch_shrink==2,'battery renders the 3D field at half resolution')
	var lights: Array=field.map_root.find_children('*','DirectionalLight3D',true,false)
	var environments: Array=field.map_root.find_children('*','WorldEnvironment',true,false)
	check(not lights.is_empty() and not environments.is_empty(),'profile includes map root lighting and atmosphere')
	for light in lights:check(not light.shadow_enabled,'battery disables map directional shadows')
	for environment in environments:check(not environment.environment.ssao_enabled and not environment.environment.ssil_enabled and not environment.environment.volumetric_fog_enabled,'battery disables map environment post-processing')
	var point:=Vector2(16,10)
	check(field.local_to_world(field.project_world(point)).distance_to(point)<.02,'reduced rendering resolution preserves world/touch projection')
	main._build_inventory_screen();await settle()
	check(field.viewport_3d.render_target_update_mode==SubViewport.UPDATE_DISABLED,'hidden retained hunt stops rendering')
	main._open_home();await settle()
	check(field.viewport_3d.render_target_update_mode==SubViewport.UPDATE_ALWAYS,'returning to hunt restores rendering')
	main.presentation_options.performance='balanced';main.presentation_runtime.apply();await settle()
	check(field.viewport_3d.msaa_3d==Viewport.MSAA_2X and field.viewport_3d.positional_shadow_atlas_size==2048,'balanced mode restores the current 2.5D hunting quality')
	for light in lights:check(light.shadow_enabled==bool(field._render_defaults[light]),'balanced restores authored directional shadows')
	for environment in environments:
		for property in field._render_defaults[environment.environment]:check(environment.environment.get(property)==field._render_defaults[environment.environment][property],'balanced restores authored environment '+property)
	check(main.wallet_gold==gold and main.hero_battle_state==hp_states and main.loot_rng.state==reward_rng,'presentation changes leave combat HP, wallet and RNG untouched')
	# A frame with no legal correction must hold the previous clear pose and
	# must not award movement distance or shift a committed actor.
	for id in ids:main.hero_skill_runtime[id].windup=-1;main.hero_battle_state[id].hp=0
	for enemy in main.enemy_wave:enemy.hp=0
	main.hero_battle_state[ids[0]].hp=100;main.hero_battle_state[ids[1]].hp=100
	var previous_point:=Vector2(16+COLLISION.HERO_CLEARANCE+.06,10)
	main.party_movement.positions[ids[0]]=Vector2(16,10);main.party_movement.positions[ids[1]]=previous_point
	var previous:=COLLISION.actors(main)
	var walked: float=main.party_movement.distance_walked[ids[1]]
	main.party_movement.positions[ids[1]]=Vector2(16.1,10);main.party_movement.distance_walked[ids[1]]+=1.1
	var navigation=main.field_navigation;main.field_navigation=ClosedNavigation.new()
	COLLISION.resolve(main,.1,previous);main.field_navigation=navigation
	check(main.party_movement.positions[ids[1]]==previous_point and COLLISION.clear(COLLISION.actors(main)),'blocked crowd holds the previous non-overlapping frame')
	check(main.party_movement.distance_walked[ids[1]]==walked and main.party_movement.velocities[ids[1]]==Vector2.ZERO,'blocked movement cannot grant travelled-distance passives')
	await dispose(main);done('HUNT_COORDINATION')
