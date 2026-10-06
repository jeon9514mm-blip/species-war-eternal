extends Node
## Adapted from the supplied MapLoader. Owns only maps it instantiated;
## HUD, actors and unrelated siblings in the destination parent survive swaps.
enum MapId { ELVEN_RUINS, CANYON_MINE, FOREST_MEADOW, ICE_CAVERN }
## Preserve historical numeric IDs for tools; ID 2 now previews the raid arena.
const MAP_NAMES: Dictionary={0:'EmptyHunt3',1:'EmptyHunt2',2:'EmptyRaid',3:'EmptyHunt1'}
const MAP_ZONES: Dictionary={0:'moonrest_forest',1:'forgotten_mine',2:'gray_meadow',3:'gray_meadow'}
const GENERATED=preload('res://scripts/maps/GeneratedMapScene.gd')
const ZONE_MAPS: Dictionary={'gray_meadow':3,'forgotten_mine':1,'moonrest_forest':0}
const RAID_MAP_TITLES: Dictionary={'gray_meadow':'레이드 1','forgotten_mine':'레이드 2','moonrest_forest':'레이드 3'}
const RAID_ZONE_MAPS: Dictionary={'gray_meadow':2,'forgotten_mine':1,'moonrest_forest':0}
var _owned_maps: Dictionary={}
func load_zone(zone_id: String,parent: Node,raid: bool=false) -> Node3D:
	var choices: Dictionary=RAID_ZONE_MAPS if raid else ZONE_MAPS
	return load_map(int(choices.get(zone_id,MapId.ICE_CAVERN)),parent,raid)
func load_map(map_id: int,parent: Node,raid: bool=false) -> Node3D:
	if not is_instance_valid(parent) or not MAP_NAMES.has(map_id):return null
	var key:=parent.get_instance_id()
	var previous: Node=_owned_maps[key].get_ref() if _owned_maps.has(key) else null
	if is_instance_valid(previous):
		if previous.get_parent()!=null:previous.get_parent().remove_child(previous)
		previous.queue_free()
	var next:=GENERATED.build(str(MAP_ZONES[map_id]),parent,raid or map_id==2)
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
