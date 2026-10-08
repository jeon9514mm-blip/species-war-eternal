extends RefCounted
const RADIUS_PX:=120.0
const HEIGHT_PX:=86.4
const FORMATION=preload('res://scripts/combat/BattleFormation.gd')
const BODY=preload('res://scripts/hunting/HuntBodyCollision.gd')
static func hunt(main,field,place: bool) -> void:
	if not is_instance_valid(field.camera) or field.size.y<1:return
	var center: Vector2=main.expedition_position
	var projected: Vector2=field.project_world(center)
	var rest_size: float=field._rest_camera_size if field._rest_camera_size>0 else field.camera.size
	main.party_movement.body_pixel_scale=rest_size/field.size.y
	var layout: Dictionary=FORMATION.projected_offsets(main.deployed_heroes,main.formation_id,BODY.HERO_PIXELS+6.0)
	# Ignore a transient impact zoom when storing gameplay stations.
	var zoom_correction: float=rest_size/maxf(.001,field.camera.size)
	for id in layout:
		var destination: Vector2=field.local_to_world(projected+Vector2(layout[id])*zoom_correction)
		var offset: Vector2=destination-center
		main.party_movement.travel_offsets[id]=offset
		if place:main.party_movement.positions[id]=main.field_navigation.clamp_to_walkable(main.party_movement.formation_station(id,center))
	main.party_movement.set_meta('formation_pixels',layout)
static func raid(main,view) -> void:
	var field=view.battlefield_3d
	if not is_instance_valid(field.camera) or field.size.y<1:return
	var ids: Array=main._deployed_hero_ids()
	var center: Vector2=field.project_world(field.raid_to_world(Vector2(420,383)))
	for i in ids.size():
		var pixel: Vector2=center+Vector2.from_angle(-PI*.5+i*TAU/maxi(1,ids.size()))*(RADIUS_PX if ids.size()>1 else 0)
		var world: Vector2=field.local_to_world(pixel)
		var position: Vector2=field.world_to_raid(world)
		main.raid_positions[ids[i]]=preload('res://scripts/raid/RaidBattlefield.gd').clamp_to_floor(position)
	var clearances: Vector2=field.raid_clearances()
	preload('res://scripts/raid/RaidBattlefield.gd').stage_positions(main.raid_positions,main.raid_boss_position,clearances.x,clearances.y,field.raid_separation_metric())
	for id in ids:
		if view.hero_actors.has(id):view.hero_actors[id].position=main.raid_positions[id]
