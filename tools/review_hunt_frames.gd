extends SceneTree
## Labelled enlarged full-pose preview. This is an animation inspection, not
## footage claiming a real hit. The separate hunt movie uses actual simulation.
const PILOT=preload('res://scripts/art/HuntFramePilot.gd')
var output: String
var frames: String
var game: Node
var camera: Camera3D
var hero: MeshInstance3D
var goblin: MeshInstance3D
var label: Label
var records: Array[Dictionary]=[]
func _init() -> void:run.call_deferred()
func settle() -> void:
	for i in 3:await process_frame
func draw_pose(kind: String,index: int) -> void:
	hero._apply_frame(camera,1.55,Color.WHITE,kind,index)
	goblin._apply_frame(camera,1.20,Color.WHITE,kind,index)
func capture(name: String,kind: String,index: int) -> void:
	draw_pose(kind,index);label.text='전신 동작 확대 검수 · '+name+'  /  별도 동작 시연'
	await settle();await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name+'.png'))==OK)
	records.append({'name':name,'sheet':kind,'frame':index,'full_painted_bodies':2,'bones':0,'not_live_combat':true})
func run() -> void:
	if DisplayServer.get_name()=='headless':quit(1);return
	output=OS.get_environment('MAP_CAPTURE_OUTPUT');frames=OS.get_environment('PILOT_MOVIE_FRAMES')
	assert(not output.is_empty() and not frames.is_empty())
	DirAccess.make_dir_recursive_absolute(output);DirAccess.make_dir_recursive_absolute(frames)
	root.content_scale_size=Vector2i(1280,720);root.size=Vector2i(1280,720)
	game=load('res://scenes/PortraitMain.tscn').instantiate()
	game.save_state_path=OS.get_environment('MAP_CAPTURE_USER_DATA').path_join('frame-review.json');game._offline_checked=true
	root.add_child(game);await settle();game.set_process(false);game.set_physics_process(false);game.sound_effects_enabled=false
	game.selected_faction='aurelia';game.idle_stage=1;game.current_zone_id='gray_meadow'
	var ids: Array[String]=['leonhardt'];game._restore_deployed_heroes(ids);game._build_combat_screen();await settle()
	game.combat_running=false;game.hide();game.combat_labels.terrain.set_process(false)
	var board:=SubViewportContainer.new();board.stretch=true;board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(board)
	var viewport:=SubViewport.new();viewport.own_world_3d=true;viewport.size=Vector2i(1280,720);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.msaa_3d=Viewport.MSAA_4X;board.add_child(viewport)
	var world:=Node3D.new();viewport.add_child(world)
	var environment_node:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color('#182731');env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;environment_node.environment=env;world.add_child(environment_node)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.4;camera.current=true
	world.add_child(camera);camera.position=Vector3(0,2.1,6);camera.look_at(Vector3(0,.9,0))
	hero=PILOT.new();world.add_child(hero);assert(hero.bind(game.hero_map_sprites[0],true));hero.position=Vector3(-.70,.08,0)
	var source=game.enemy_wave_sprites[0];MonsterSpriteFactory.apply_casual(source,'초원 고블린',source.presentation_scale);source.flip_h=true
	goblin=PILOT.new();world.add_child(goblin);assert(goblin.bind(source,false));goblin.position=Vector3(.70,.08,0)
	for actor in [hero.source,goblin.source]:actor.set_process(false);actor.speed_scale=1.0
	label=Label.new();label.position=Vector2(36,24);label.add_theme_font_size_override('font_size',24);root.add_child(label)
	for i in 8:await capture('attack-%02d'%i,'attack',i)
	for i in 8:await capture('motion-%02d'%i,'motion',i)
	hero.source.flip_h=true;goblin.source.flip_h=false
	await capture('attack-mirrored','attack',3)
	hero.source.flip_h=false;goblin.source.flip_h=true
	for n in 168:
		var loop:=fposmod(float(n)/24.0,1.4)
		var phase:=clampf((loop-.15)/.85,0.0,1.0)
		var index:=PILOT.CATALOG.attack_frame(phase)
		draw_pose('attack',index);label.text='전신 동작 시연 · 느린 재생  /  레온하르트 + 초원 고블린'
		await process_frame;await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(frames.path_join('frame-%04d.png'%n))==OK)
	var file:=FileAccess.open(output.path_join('whole-pose-review.json'),FileAccess.WRITE)
	file.store_string(JSON.stringify({'scene':'full-pose inspection','renderer':RenderingServer.get_current_rendering_method(),'fps':24,'slow_preview':true,'captures':records,'no_skeletal_articulation':true},'  '));file.close()
	game.presentation_runtime.audio.shutdown();game.background_hunt.discard();game.queue_free();board.queue_free();label.queue_free();await settle()
	print('HUNT_FRAME_REVIEW_OK');quit.call_deferred()
