extends SceneTree
## Deterministic captures of the production GPU skin. No image compositing or mock poses.
const FACTORY=preload('res://scripts/HeroSpriteFactory.gd')
const RIG=preload('res://scripts/portrait/PortraitHeroSkeletalRig.gd')
const MOTIONS=preload('res://scripts/portrait/HeroRigMotionCatalog.gd')
const SKIN=preload('res://scripts/maps3d/HeroSkeletalBillboard.gd')
const LABELS=['대기','걷기','달리기','공격 1','공격 2','스킬','궁극기','피격','넉백','회피','방어','강화','약화','승리','사망','등장']
var rigs: Array=[]
var skins: Array=[]
var camera: Camera3D
var title: Label
func _initialize() -> void:run.call_deferred()
func label(text_value: String,point: Vector2,font_size: int) -> Label:
	var l:=Label.new();l.text=text_value;l.position=point;l.add_theme_font_size_override('font_size',font_size)
	root.add_child(l);return l
func run() -> void:
	root.content_scale_size=Vector2i(720,960);root.size=Vector2i(720,960)
	var world:=Node3D.new();root.add_child(world)
	var env:=WorldEnvironment.new();var e:=Environment.new()
	e.background_mode=Environment.BG_COLOR;e.background_color=Color('#172631');env.environment=e;world.add_child(env)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=12.0
	world.add_child(camera);camera.position=Vector3(0,6,30);camera.current=true
	label('HERO SKELETAL MOTION',Vector2(38,25),27)
	title=label('21 joints · 16 actions',Vector2(38,65),22)
	var ids: Array=['leonhardt','mira','elisia','valeria','bron','tessa']
	var args:=OS.get_cmdline_user_args()
	if '--roster' in args:ids=MOTIONS.PROFILES.keys()
	var roster:=ids.size()>6
	var cols:=5 if roster else 2
	var rows:=6 if roster else 3
	var h:=1.0 if roster else 2.25
	for i in ids.size():
		var id: String=ids[i]
		var hero: HeroSpriteController=FACTORY.create_hero(id)
		hero.observe_game=false;hero.hold_demo=true;root.add_child(hero);hero.set_process(false);hero.stop()
		var rig:=RIG.new();rig.install(hero);rig.set_process(false);hero.hide();rigs.append(rig)
		var skin:=SKIN.new();world.add_child(skin);skin.bind(rig)
		var cell_w:=9.0/cols;var cell_h:=8.55/rows
		skin.position=Vector3(-4.5+cell_w*(float(i%cols)+.5),10.9-cell_h*(floorf(float(i)/cols)+1),0)
		skin.sync(camera,h/rig.body_height,Color.WHITE);skins.append(skin)
		var name_text: String=preload('res://scripts/HeroRosterCatalog.gd').HEROES[id].name
		var foot:=camera.unproject_position(skin.position)
		label(name_text.split(' ')[0] if roster else name_text,Vector2(20+float(i%cols)*(720.0/cols),foot.y+8),15 if roster else 21)
	label('Godot 4.7.2 · 실제 3D 렌더링',Vector2(38,921),18)
	var output:='res://checks/hero-rig/captures'
	for arg in args:
		if arg.begins_with('--output='):output=arg.trim_prefix('--output=')
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if '--video' in args:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output+'/frames'))
		for action_index in MOTIONS.ACTIONS.size():
			for frame in 24:
				var action: String=MOTIONS.ACTIONS[action_index]
				title.text='%02d / 16  ·  %s' %[action_index+1,LABELS[action_index]]
				for i in rigs.size():
					var rig=rigs[i]
					var duration: float=rig.action_duration(action)
					var t: float=float(frame)/23.0*(1.0 if action in MOTIONS.LOOPS else duration)
					rig.apply_pose(MOTIONS.sample(rig.profile,action,t,duration));skins[i].sync(camera,h/rig.body_height,Color.WHITE)
				await process_frame;await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output+'/frames/%04d.png' %(action_index*24+frame))
	else:
		var action: String='attack_1' if '--attack' in args else 'idle'
		for arg in args:
			if arg.begins_with('--action=') and arg.trim_prefix('--action=') in MOTIONS.ACTIONS:action=arg.trim_prefix('--action=')
		title.text='30 HEROES · 21 JOINTS' if roster else '관절 동작 · '+('공격' if action=='attack_1' else '대기')
		for i in rigs.size():
			var rig=rigs[i];rig.apply_pose(MOTIONS.sample(rig.profile,action,rig.action_duration(action)*.48,rig.action_duration(action)))
			skins[i].sync(camera,h/rig.body_height,Color.WHITE)
		for k in 3:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+('/roster.png' if roster else '/'+action+'.png'))
	root.remove_child(world);world.free()
	for rig in rigs:rig.actor.free()
	rigs.clear();skins.clear()
	await process_frame
	quit()
