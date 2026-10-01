extends RefCounted
## Painted 4-pose atlases for the portrait game. The original navigation and
## monster identities remain shared with the landscape renderer.
const SOURCE := preload('res://scripts/MonsterPixelAtlasLayout.gd')
const V60_MEADOW_MONSTERS := {
	'초원 고블린': preload('res://assets/monsters/meadow-v60/goblin-four.png'),
	'들개 무리': preload('res://assets/monsters/meadow-v60/wild-dog-four.png'),
	'가시 멧돼지': preload('res://assets/monsters/meadow-v60/bristle-boar-four.png'),
}
const SHEETS := {
	'meadow': preload('res://assets/monsters/casual-v58/meadow-six-atlas.png'),
	'depths': preload('res://assets/monsters/casual-v58/depths-seven-atlas.png'),
	'boss': preload('res://assets/monsters/casual-v58/boss-three-atlas.png'),
}
static var _frame_cache: Dictionary = {}
static var cache_misses: int = 0
static func has_monster(name: String) -> bool:
	return SOURCE.PROFILES.has(name)
static func uses_four_pose_sheet(name: String) -> bool:
	return V60_MEADOW_MONSTERS.has(name)
static func texture(name: String) -> Texture2D:
	if uses_four_pose_sheet(name):return V60_MEADOW_MONSTERS[name]
	return SHEETS[SOURCE.PROFILES[name]['sheet']] if has_monster(name) else null
static func frame(name: String, pose: int) -> AtlasTexture:
	var key: String = name + ":" + str(clampi(pose, 0, 3))
	if _frame_cache.has(key): return _frame_cache[key]
	if not has_monster(name): return null
	cache_misses += 1
	var profile: Dictionary=SOURCE.PROFILES[name]
	var atlas: Texture2D=texture(name)
	if uses_four_pose_sheet(name):
		var cell: Vector2=atlas.get_size()/Vector2(2,2)
		var solo:=AtlasTexture.new()
		solo.atlas=atlas
		solo.region=Rect2(Vector2(clampi(pose,0,3)%2,int(clampi(pose,0,3)/2.0))*cell,cell)
		solo.filter_clip=true
		_frame_cache[key] = solo
		return solo
	var columns: int=profile['columns']
	var width: float=atlas.get_width()/float(columns)
	var height: float=atlas.get_height()/4.0
	var result:=AtlasTexture.new()
	result.atlas=atlas
	result.region=Rect2(Vector2(width*int(profile['column']),height*clampi(pose,0,3)),Vector2(width,height))
	result.filter_clip=true
	_frame_cache[key] = result
	return result
