extends Control
## Standalone review scene: F6, drag to orbit, wheel to zoom, 1–4 to switch.
const LOADER=preload('res://scripts/maps/MapLoader.gd')
var loader: Node
var viewport_3d: SubViewport
var map_root: Node3D
var camera: Camera3D
var yaw:=.18
var pitch:=.79
var distance:=70.0
var labels: Array[String]=['보랏빛 룬 · 사냥터 3','호박 룬 · 사냥터 2','레이드 · 디자인 대기','청록 룬 · 사냥터 1']
var raid_variant:=false
var selected_map:=3
var title: Label
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var container:=SubViewportContainer.new();container.stretch=true;container.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(container);container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_3d=SubViewport.new();viewport_3d.own_world_3d=true;viewport_3d.msaa_3d=Viewport.MSAA_4X;viewport_3d.render_target_update_mode=SubViewport.UPDATE_ALWAYS;container.add_child(viewport_3d)
	loader=LOADER.new();add_child(loader)
	var bar:=HBoxContainer.new();bar.position=Vector2(24,20);bar.add_theme_constant_override('separation',10);add_child(bar)
	for i in 4:
		var button:=Button.new();button.text=str(i+1)+' · '+labels[i];button.custom_minimum_size=Vector2(180,46);bar.add_child(button);button.pressed.connect(select_map.bind(i))
	var variant:=Button.new();variant.name='RaidVariantToggle';variant.text='레이드 맵 보기';variant.toggle_mode=true;variant.position=Vector2(24,78);variant.custom_minimum_size=Vector2(170,42);add_child(variant)
	variant.toggled.connect(func(enabled):raid_variant=enabled;select_map(selected_map))
	title=Label.new();title.position=Vector2(28,130);title.add_theme_font_size_override('font_size',20);title.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(title)
	gui_input.connect(_on_input);select_map(3)
func select_map(id: int) -> void:
	selected_map=id
	map_root=loader.load_map(id,viewport_3d,raid_variant);camera=map_root.get_node('Arena/BattleCamera')
	camera.size=44 if id==3 else 32;camera.current=true
	title.text=labels[id]+(' · 레이드' if raid_variant or id==2 else ' · 사냥')+'  |  드래그: 시점 회전 · 마우스 휠: 확대/축소'
	pose()
func pose() -> void:
	var target:=Vector3(16,1,5)
	camera.position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(target)
func _on_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		yaw-=event.relative.x*.005;pitch=clampf(pitch+event.relative.y*.004,.35,1.35);pose()
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		yaw-=event.relative.x*.005;pitch=clampf(pitch+event.relative.y*.004,.35,1.35);pose()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:camera.size=maxf(15,camera.size-2)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera.size=minf(70,camera.size+2)
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode>=KEY_1 and event.keycode<=KEY_4:select_map(event.keycode-KEY_1)
