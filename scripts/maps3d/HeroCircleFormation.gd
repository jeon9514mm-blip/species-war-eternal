extends RefCounted
const RADIUS_PX:=120.0
const HEIGHT_PX:=86.4
static func hunt(main,field,place: bool) -> void:
	if not is_instance_valid(field.camera) or field.size.y<1:return
	var ids: Array=main._deployed_hero_ids();var center: Vector2=main.expedition_position
	var projected: Vector2=field.project_world(center)
	for i in ids.size():
		var angle: float=-PI*.5+i*TAU/maxi(1,ids.size())
		var destination: Vector2=field.local_to_world(projected+Vector2.from_angle(angle)*(RADIUS_PX if ids.size()>1 else 0))
		var offset: Vector2=destination-center
		main.party_movement.travel_offsets[ids[i]]=offset
		if place:main.party_movement.positions[ids[i]]=main.field_navigation.clamp_to_walkable(destination)
	main.party_movement.set_meta('circle_pixels',RADIUS_PX)
static func raid(main,view) -> void:
	var field=view.battlefield_3d
	if not is_instance_valid(field.camera) or field.size.y<1:return
	var ids: Array=main._deployed_hero_ids()
	var center: Vector2=field.project_world(field.raid_to_world(Vector2(420,383)))
	for i in ids.size():
		var pixel: Vector2=center+Vector2.from_angle(-PI*.5+i*TAU/maxi(1,ids.size()))*(RADIUS_PX if ids.size()>1 else 0)
		var world: Vector2=field.local_to_world(pixel)
		var sin_pitch: float=absf(field.camera.global_basis.z.y)
		var position: Vector2=field.RAID_PIVOT+(world-Vector2(16,10))*Vector2(field.RAID_UNITS,field.RAID_UNITS*sin_pitch)
		main.raid_positions[ids[i]]=preload('res://scripts/raid/RaidBattlefield.gd').clamp_to_floor(position)
		if view.hero_actors.has(ids[i]):view.hero_actors[ids[i]].position=main.raid_positions[ids[i]]
