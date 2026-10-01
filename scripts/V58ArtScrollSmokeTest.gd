extends SceneTree
## Checks the illustrated combat terrain and real touch scrolling over actions.
const PAGES := preload('res://scripts/portrait/PortraitPages.gd')
const SCENERY := preload('res://scripts/portrait/PortraitScenery.gd')
var main: Node
var failures: Array[String] = []
var taps := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, reason: String) -> void:
	if not ok:
		failures.append(reason)
		push_error('V58 art/scroll: '+reason)
func settle() -> void:
	for i in 8: await process_frame
func _action() -> void: taps += 1
func build_list() -> ScrollContainer:
	var box: VBoxContainer=PAGES.begin(main,'v58_scroll','긴 메뉴 입력 검사','목록을 스크롤하고 탭합니다.')
	for i in 28: PAGES.action(box,'메뉴 동작 %d'%i,_action)
	return main.content_root.get_node('PortraitContentScroll')
func touch_drag(from: Vector2, to: Vector2) -> void:
	var down:=InputEventScreenTouch.new();down.index=0;down.position=from;down.pressed=true
	root.push_input(down,true)
	for i in 8:
		var move:=InputEventScreenDrag.new();move.index=0
		move.position=from.lerp(to,float(i+1)/8.0)
		move.relative=(to-from)/8.0
		move.screen_relative=move.relative
		move.screen_velocity=move.screen_relative*60.0
		root.push_input(move,true)
		await process_frame
	var up:=InputEventScreenTouch.new();up.index=0;up.position=to;up.pressed=false
	root.push_input(up,true)
func run() -> void:
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
	main=preload('res://scenes/PortraitMain.tscn').instantiate()
	main.save_state_path='user://v58-art-scroll.json'
	root.add_child(main);await settle()
	main.set_physics_process(false);main.set_process(false);main._offline_checked=true;main.tutorial_completed=true
	main.selected_faction='aurelia';main.combat_effects_enabled=false
	for zone: String in SCENERY.CASUAL_ART:
		var field:=SCENERY.new();field.configure(zone,Color.WHITE)
		root.add_child(field);await settle()
		check(field.field_texture==SCENERY.CASUAL_ART[zone],zone+' uses painted field')
		check(field.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR,zone+' uses smooth texture filtering')
		field.queue_free();await process_frame
	for monster_name: String in MonsterSpriteFactory.MONSTER_SPRITES:
		var sprite:=MonsterSpriteFactory.create_monster(monster_name)
		check(MonsterSpriteFactory.apply_casual(sprite,monster_name),'painted art available for '+monster_name)
		check(sprite.sheet_layout=='casual_v58' and sprite._frames_ready,'painted action atlas loads for '+monster_name)
		check(sprite.sprite_frames.get_frame_count('walk_down')==2 and sprite.sprite_frames.get_frame_count('attack_down')==3,'walk and attack poses available for '+monster_name)
		var portrait:=MonsterSpriteFactory.get_casual_portrait_texture(monster_name)
		check(portrait is AtlasTexture and (portrait as AtlasTexture).filter_clip,'painted portrait clips to its atlas cell for '+monster_name)
		sprite.free()
	var roster: Array=main._hero_roster_for_faction()
	main.deployed_heroes=roster.slice(0,3)
	main._setup_hero_progress(roster)
	main._build_combat_screen();await settle()
	if is_instance_valid(main.combat_timer):main.combat_timer.stop()
	check(not main.enemy_wave_sprites.is_empty(),'hunt has visible monsters')
	for sprite: MonsterSpriteController in main.enemy_wave_sprites:
		check(sprite.sheet_layout=='casual_v58','portrait hunt uses painted monster atlas')
		check(sprite.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR and sprite.material==null,'painted monster avoids pixel shader')
		check(sprite.sprite_frames.get_frame_count('attack_down')==3,'painted monster preserves action poses')
	check(main.content_root.get_node_or_null('RoamingTerrainPortrait')!=null,'live combat has the new terrain')
	var scroll:=build_list();await settle()
	check(scroll.get_v_scroll_bar().max_value>scroll.size.y,'long menu has content below the fold')
	check(scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_RESERVE,'vertical thumb reserves stable space')
	check(not scroll.follow_focus and scroll.scroll_deadzone==0,'focus and drag deadzone cannot interrupt touch scroll')
	var button: Button=scroll.find_children('*','Button',true,false).front()
	check(button!=null and button.mouse_filter==Control.MOUSE_FILTER_PASS,'actions pass touch drag to scroll')
	if button!=null:
		var from:=button.get_global_rect().get_center()
		await touch_drag(from,from+Vector2(0,-340));await settle()
		check(scroll.scroll_vertical>0,'touch drag beginning on an action scrolls the list')
		check(taps==0,'touch drag does not fire the action')
	var position:=scroll.scroll_vertical
	scroll=build_list();await settle()
	check(abs(scroll.scroll_vertical-position)<=1,'same screen rebuild preserves scroll position')
	var wheel:=InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true
	wheel.position=scroll.get_global_rect().get_center()
	root.push_input(wheel,true);await settle()
	check(scroll.scroll_vertical>position,'mouse wheel remains responsive after touch scrolling')
	main._clear_screen();main.free();await process_frame
	print('V58 ART SCROLL ',('PASS' if failures.is_empty() else 'FAIL'),'; ',failures.size(),' failures')
	quit(0 if failures.is_empty() else 1)
