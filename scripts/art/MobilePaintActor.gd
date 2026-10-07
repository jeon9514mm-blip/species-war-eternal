extends 'res://scripts/heroes/HeroSpriteController.gd'
## Combat source controller uses the same single 1024 atlas as its 3D billboard.
const CATALOG=preload('res://scripts/art/HuntFrameCatalog.gd')
var visual_action:='idle'
var _entry: Dictionary={}
func configure_mobile(id: String) -> void:
	atlas_key=id;sheet_layout='mobile25d';texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;material=null
	_entry=CATALOG.new().load_entry(id);_build_sprite_frames();play_state('idle','right')
func _build_sprite_frames() -> void:
	if _entry.is_empty():return
	var next:=SpriteFrames.new();next.remove_animation('default')
	sprite_sheet=load(_entry.motion.atlas);native_visual_height=float(_entry.motion.native_height)
	for facing in DIRECTIONS:
		for action in STATES:
			var kind: String='attack' if action=='attack' else 'motion'
			var indices: Array=[0,1]
			if action=='walk':indices=[2,3,4,5]
			elif action=='attack':indices=[0,1,2,3,4,5,6,7]
			elif action=='hit':indices=[6]
			elif action=='death':indices=[7]
			var key: String=action+'_'+facing;next.add_animation(key);next.set_animation_loop(key,action in ['idle','walk'])
			next.set_animation_speed(key,8 if action=='walk' else (12 if action=='attack' else 2))
			for i in indices:
				var frame: Dictionary=_entry[kind].frames[i];var tile:=AtlasTexture.new();tile.atlas=sprite_sheet;tile.filter_clip=true
				tile.region=Rect2(frame.region[0],frame.region[1],frame.region[2],frame.region[3]);next.add_frame(key,tile)
	sprite_frames=next;centered=false;offset=-Vector2(_entry.motion.frames[0].anchor[0],_entry.motion.frames[0].anchor[1]);_frames_ready=true
func play_visual(action: String) -> void:
	visual_action=action
	if action in ['attack_1','attack_2','skill','ultimate']:super.play_attack()
	elif action=='hit':super.play_hit()
	elif action=='death':super.play_death()
	elif action in ['walk','run']:super.play_state('walk')
	else:super.play_state('idle')
func play_state(action: String, facing: String='') -> void:
	super.play_state(action,facing);flip_h=direction=='left'
func play_attack(facing: String='') -> void:
	visual_action='attack_1';super.play_attack(facing)
