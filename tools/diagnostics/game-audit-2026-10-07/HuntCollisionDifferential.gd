extends SceneTree
## Pass the original HuntBodyCollision.gd Git blob as the first user argument.
## Isolated crowded-body CPU benchmark and exact-state oracle, not GPU FPS.
const BODY=preload('res://scripts/hunting/HuntBodyCollision.gd')
const PARTY=preload('res://scripts/hunting/PartyMovementDirector.gd')
const NAV=preload('res://scripts/hunting/MeadowNavigation.gd')
const ROAM=preload('res://scripts/hunting/RoamingHuntDirector.gd')
class World extends RefCounted:
	var challenge_session=null
	var party_movement=PARTY.new()
	var field_navigation=NAV.new()
	var combat_labels: Dictionary={}
	var hero_battle_state: Dictionary={}
	var hero_skill_runtime: Dictionary={}
	var enemy_wave: Array=[]
	var roaming_hunt=ROAM.new()
	var expedition_position:=Vector2(16,10)
	var combat_tick_count:=0
	var ids: Array[String]=[]
	func _alive_hero_ids() -> Array[String]:return ids
	func _hero_field_position(id: String) -> Vector2:return party_movement.positions[id]
func fixture(seed_number: int):
	var world:=World.new();world.party_movement.independent_hunt=true
	var random:=RandomNumberGenerator.new();random.seed=seed_number
	for i in 10:
		var id: String='hero_'+str(i);world.ids.append(id)
		world.hero_battle_state[id]={'hp':100}
		world.hero_skill_runtime[id]={'windup':.2 if i%7==0 else -1.}
		world.party_movement.positions[id]=Vector2(16+random.randf_range(-3.8,3.8),10+random.randf_range(-1.6,1.6))
		world.party_movement.velocities[id]=Vector2(random.randf(),random.randf())
		world.party_movement.distance_walked[id]=random.randf()*10
	for i in 14:
		world.enemy_wave.append({'hp':100,'stun_seconds':.2 if i%8==0 else 0.,'hunt_recovery':.1 if i%11==0 else 0.})
		world.roaming_hunt.enemy_positions.append(Vector2(16+random.randf_range(-4,4),10+random.randf_range(-3,3)))
	world.combat_tick_count=seed_number
	return world
func _initialize() -> void:
	var before=load(OS.get_cmdline_user_args()[0])
	var before_us:=0;var after_us:=0;var same:=true
	for sample in 120:
		var left=fixture(sample+20261008);var right=fixture(sample+20261008)
		var start:=Time.get_ticks_usec();before.resolve(left,.05);before_us+=Time.get_ticks_usec()-start
		start=Time.get_ticks_usec();BODY.resolve(right,.05);after_us+=Time.get_ticks_usec()-start
		same=same and left.party_movement.positions==right.party_movement.positions and left.party_movement.velocities==right.party_movement.velocities and left.party_movement.distance_walked==right.party_movement.distance_walked and left.roaming_hunt.enemy_positions==right.roaming_hunt.enemy_positions
	print('HUNT_COLLISION_DIFFERENTIAL '+JSON.stringify({'samples':120,'actors':24,'before_ms':before_us/1000.,'after_ms':after_us/1000.,'exact_state_match':same}))
	quit(0 if same else 1)
