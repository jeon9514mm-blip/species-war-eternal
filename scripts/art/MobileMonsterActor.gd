extends 'res://scripts/monsters/MonsterSpriteController.gd'
## The hidden simulation controller and relief share one compressed atlas.
const CATALOG=preload('res://scripts/art/HuntFrameCatalog.gd')
var _entry: Dictionary={}
func configure_mobile(monster_name: String,display_scale: Vector2) -> void:
	pixel_monster_name=monster_name;sheet_layout='mobile25d';presentation_scale=display_scale;material=null;texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	_entry=CATALOG.new().load_entry(str(CATALOG.MONSTERS.get(monster_name,'')));_build_sprite_frames()
	var profile: Dictionary=MonsterPixelAtlasLayout.PROFILES.get(monster_name,{'target_height':44,'reference_scale':.09})
	set_presentation_scale(display_scale*float(profile.target_height)/float(profile.reference_scale)/maxf(1,native_visual_height));set_meta('mobile25d',true)
func _build_sprite_frames() -> void:
	if _entry.is_empty():return
	sprite_sheet=load(_entry.motion.atlas);native_visual_height=float(_entry.motion.native_height)
	var frames:=SpriteFrames.new();frames.remove_animation('default')
	for facing in DIRECTIONS:
		for action in STATES:
			var kind: String='attack' if action=='attack' else 'motion';var indices: Array=[0,1]
			if action=='walk':indices=[2,3,4,5]
			elif action=='attack':indices=[0,1,2,3,4,5,6,7]
			elif action=='hit':indices=[6]
			elif action=='death':indices=[7]
			var key: String=action+'_'+facing;frames.add_animation(key);frames.set_animation_loop(key,action in ['idle','walk']);frames.set_animation_speed(key,10 if action in ['walk','attack'] else 2)
			for i in indices:
				var pose: Dictionary=_entry[kind].frames[i];var texture:=AtlasTexture.new();texture.atlas=sprite_sheet;texture.filter_clip=true;texture.region=Rect2(pose.region[0],pose.region[1],pose.region[2],pose.region[3]);frames.add_frame(key,texture)
	sprite_frames=frames;centered=false;offset=-Vector2(_entry.motion.frames[0].anchor[0],_entry.motion.frames[0].anchor[1]);_frames_ready=true;_single_image_mode=false
func play_state(action: String,facing: String='') -> void:
	super.play_state(action,facing);flip_h=direction=='left'
