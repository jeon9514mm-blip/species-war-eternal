extends Node
## Adapted from the supplied MapLoader. Owns only maps it instantiated;
## HUD, actors and unrelated siblings in the destination parent survive swaps.
enum MapId { ELVEN_RUINS, CANYON_MINE, FOREST_MEADOW, ICE_CAVERN }
const MAP_NAMES: Dictionary={0:'ElvenRuins',1:'CanyonMine',2:'ForestMeadow',3:'IceCavern'}
const ZONE_MAPS: Dictionary={'gray_meadow':3,'forgotten_mine':1,'moonrest_forest':0}
const RAID_MAP_TITLES: Dictionary={'gray_meadow':'거목의 숲 성역','forgotten_mine':'붉은 협곡 광산','moonrest_forest':'월식 유적'}
const RAID_ZONE_MAPS: Dictionary={'gray_meadow':2,'forgotten_mine':1,'moonrest_forest':0}
var _owned_maps: Dictionary={}
func load_zone(zone_id: String,parent: Node,raid: bool=false) -> Node3D:
	var choices: Dictionary=RAID_ZONE_MAPS if raid else ZONE_MAPS
	return load_map(int(choices.get(zone_id,MapId.ICE_CAVERN)),parent,raid)
func load_map(map_id: int,parent: Node,raid: bool=false) -> Node3D:
	if not is_instance_valid(parent) or not MAP_NAMES.has(map_id):return null
	var path: String='res://scenes/maps/Map_'+str(MAP_NAMES[map_id])+('_Raid' if raid else '')+'.tscn'
	var packed:=load(path) as PackedScene
	if packed==null:return null
	var next:=packed.instantiate() as Node3D
	if next==null:return null
	var key:=parent.get_instance_id()
	var previous: Node=_owned_maps[key].get_ref() if _owned_maps.has(key) else null
	if is_instance_valid(previous):
		if previous.get_parent()!=null:previous.get_parent().remove_child(previous)
		previous.queue_free()
	parent.add_child(next)
	_owned_maps[key]=weakref(next)
	return next
func unload_map(parent: Node) -> void:
	if not is_instance_valid(parent):return
	var key:=parent.get_instance_id()
	if not _owned_maps.has(key):return
	var previous: Node=_owned_maps[key].get_ref()
	if is_instance_valid(previous):
		if previous.get_parent()!=null:previous.get_parent().remove_child(previous)
		previous.queue_free()
	_owned_maps.erase(key)
