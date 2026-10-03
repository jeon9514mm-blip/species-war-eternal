extends Control
## Bounded camera parallax for the art laboratory. There is no time-driven
## endless scrolling, and this node never owns simulation coordinates or RNG.
const ART_ROOT := "res://assets/art-direction/pilot-01/layers/"
const LAYERS := [
	{"name":"Sky", "ratio":.02, "source":"sky.png", "kind":"painted", "rect":Rect2(-.08,-.04,1.16,.47)},
	{"name":"FarClouds", "ratio":.035, "source":"clouds.png", "kind":"painted", "rect":Rect2(-.12,-.035,1.24,.18)},
	{"name":"Mountains", "ratio":.10, "source":"mountains.png", "kind":"painted", "rect":Rect2(-.10,.018,1.20,.29)},
	{"name":"NearClouds", "ratio":.065, "source":"clouds.png", "kind":"reused", "rect":Rect2(-.18,.045,1.36,.18)},
	{"name":"Foothills", "ratio":.17, "source":"foothills.png", "kind":"painted", "rect":Rect2(-.09,.125,1.18,.225)},
	{"name":"Treeline", "ratio":.25, "source":"treeline.png", "kind":"painted", "rect":Rect2(-.09,.205,1.18,.15)},
	{"name":"Village", "ratio":.40, "source":"village.png", "kind":"painted", "rect":Rect2(-.10,-.075,1.20,.375)},
	{"name":"Midtrees", "ratio":.58, "source":"midtrees.png", "kind":"painted", "rect":Rect2(-.10,-.14,1.20,.44)},
	{"name":"HorizonHaze", "ratio":.30, "source":"procedural", "kind":"procedural"},
	{"name":"Ground", "ratio":1.0, "camera_bound":true, "world_anchored":true, "source":"world/QuietPlayLawn", "kind":"world"},
	{"name":"GroundDapple", "ratio":1.0, "camera_bound":true, "world_anchored":true, "source":"world/GroundDapple", "kind":"world"},
	{"name":"GroundDetails", "ratio":1.0, "camera_bound":true, "world_anchored":true, "source":"world/GroundDetails", "kind":"world"},
	{"name":"LightShafts", "ratio":.65, "source":"procedural", "kind":"procedural"},
	{"name":"ForegroundFar", "ratio":1.05, "source":"foreground.png", "kind":"painted", "rect":Rect2(-.08,-.04,1.16,1.10)},
	{"name":"ForegroundNear", "ratio":1.50, "source":"foreground.png", "kind":"reused", "rect":Rect2(-.15,-.07,1.30,1.16)},
	{"name":"EdgeDust", "ratio":1.20, "source":"procedural", "kind":"procedural"},
	{"name":"AmbientButterflies", "ratio":1.08, "source":"procedural", "kind":"procedural"},
	{"name":"ForegroundBokeh", "ratio":1.62, "source":"procedural", "kind":"procedural"}
]
var field: Control
var foreground_root: Control
var _nodes: Dictionary = {}
var _textures: Dictionary = {}
var _focus := Vector2(16,10)
var _dust_points: PackedVector2Array = []
var _dust: Control
var _front_shader: Shader
var _butterflies: Control
var _bokeh: Control
var _active := true
var atmosphere_time := 0.0

func bind(next_field: Control) -> void:
	field = next_field
	name = "LayeredMeadowBackdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -1
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	foreground_root = Control.new()
	foreground_root.name = "ParallaxForegroundLayers"
	foreground_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foreground_root.z_index = 20
	field.add_child(foreground_root)
	foreground_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_front_shader = _make_foreground_shader()
	for definition: Dictionary in LAYERS:
		var named := str(definition.name)
		if definition.kind == "world": continue
		if named == "HorizonHaze":
			_build_haze()
			continue
		if named == "EdgeDust":
			_build_dust()
			continue
		if named == "LightShafts":
			_build_light_shafts()
			continue
		if named == "AmbientButterflies":
			_butterflies = _build_overlay(named, float(definition.ratio))
			_butterflies.draw.connect(_draw_butterflies)
			continue
		if named == "ForegroundBokeh":
			_bokeh = _build_overlay(named, float(definition.ratio))
			_bokeh.draw.connect(_draw_bokeh)
			continue
		var picture := TextureRect.new()
		picture.name = named
		picture.texture = _texture(str(definition.source), named != "Sky" and not named.begins_with("Foreground"))
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_SCALE
		picture.set_meta("parallax_ratio", float(definition.ratio))
		if named.begins_with("Foreground"):
			var material := ShaderMaterial.new()
			material.shader = _front_shader
			material.set_shader_parameter("softness", 1.2 if named == "ForegroundFar" else 2.0)
			picture.material = material
			picture.modulate.a = .50 if named == "ForegroundFar" else .94
			foreground_root.add_child(picture)
		else:
			if named == "FarClouds": picture.modulate = Color(.93,.96,1,.53)
			if named == "NearClouds": picture.modulate.a = .45
			if named == "Mountains":
				var material := ShaderMaterial.new()
				material.shader = _make_distance_shader()
				picture.material = material
			add_child(picture)
		_nodes[named] = picture
	resized.connect(_sync_layout)
	_sync_layout()

func layer_manifest() -> Array[Dictionary]:
	var manifest: Array[Dictionary] = []
	for definition: Dictionary in LAYERS:
		var entry := definition.duplicate(true)
		entry.erase("rect")
		manifest.append(entry)
	return manifest

func _texture(file_name: String, trim_alpha: bool) -> Texture2D:
	var key := file_name + str(trim_alpha)
	if _textures.has(key): return _textures[key]
	var path := ART_ROOT + file_name
	if not ResourceLoader.exists(path): return null
	var texture := load(path) as Texture2D
	if texture == null: return null
	if trim_alpha:
		var image := texture.get_image()
		if image != null:
			var bounds := image.get_used_rect()
			if bounds.has_area():
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = bounds
				texture = atlas
	_textures[key] = texture
	return texture

func sync_camera(next_focus: Vector2, delta: float) -> void:
	_focus = next_focus
	# Use the caller's simulation presentation step, never TIME or global RNG.
	# Pause/menu/original-map views freeze atmosphere instead of jumping on return.
	if _atmosphere_is_running() and is_finite(delta):
		atmosphere_time += clampf(delta, 0.0, .10)
	_sync_layout()

func _atmosphere_is_running() -> bool:
	if not _active or not is_visible_in_tree() or not is_instance_valid(field): return false
	if is_inside_tree() and get_tree().paused: return false
	var game: Node = field.get("game")
	if not is_instance_valid(game): return false
	# Main advances the hunt in _physics_process; it has no regular _process.
	# Either live loop may own a preview, while a fully frozen capture owns none.
	var game_loop_active := game.is_physics_processing() or game.is_processing()
	return bool(field.get("animate_environment")) and game_loop_active and bool(game.get("combat_running")) and str(game.get("active_screen")) == "combat" and not bool(game.get("_application_suspended"))

func atmosphere_state() -> Dictionary:
	return {"elapsed": atmosphere_time, "running": _atmosphere_is_running(), "dust_count": _dust_points.size(), "butterfly_count": 3, "bokeh_count": 6, "light_safe_alpha_max": .026}

func _sync_layout() -> void:
	if not is_instance_valid(field) or size.x < 1 or size.y < 1: return
	var camera_delta := (_focus - Vector2(16,10)).clamp(Vector2(-12,-8),Vector2(12,8))
	var clear: Rect2 = field.safe_play_rect()
	for definition: Dictionary in LAYERS:
		var named := str(definition.name)
		if not _nodes.has(named): continue
		var picture: Control = _nodes[named]
		var offset := Vector2(-camera_delta.x * 3.0, camera_delta.y * 1.5) * float(definition.ratio)
		offset = offset.clamp(-size * Vector2(.07,.055), size * Vector2(.07,.055))
		picture.set_meta("parallax_offset", offset)
		if definition.has("rect"):
			var rect: Rect2 = definition.rect
			picture.position = rect.position * size + offset
			picture.size = rect.size * size
		if named.begins_with("Foreground"):
			if not picture is TextureRect: continue
			picture.position += Vector2(sin(atmosphere_time*.43)*1.4, sin(atmosphere_time*.67 + (0.7 if named == "ForegroundFar" else 0.0))*2.0)
			var material := picture.material as ShaderMaterial
			material.set_shader_parameter("clear_rect", Vector4(clear.position.x/size.x,clear.position.y/size.y,clear.end.x/size.x,clear.end.y/size.y))
			material.set_shader_parameter("canvas_origin", picture.position / size)
			material.set_shader_parameter("canvas_extent", picture.size / size)
		elif named == "HorizonHaze":
			picture.position = Vector2(0,size.y*.165)
			picture.size = Vector2(size.x,size.y*.17)
		elif named == "LightShafts":
			var material := picture.material as ShaderMaterial
			material.set_shader_parameter("clear_rect", Vector4(clear.position.x/size.x,clear.position.y/size.y,clear.end.x/size.x,clear.end.y/size.y))
			material.set_shader_parameter("art_time", atmosphere_time)
			material.set_shader_parameter("camera_shift", offset/size)
	if is_instance_valid(_dust): _dust.queue_redraw()
	if is_instance_valid(_butterflies): _butterflies.queue_redraw()
	if is_instance_valid(_bokeh): _bokeh.queue_redraw()

func foreground_clear_rect() -> Rect2:
	var front: TextureRect = _nodes.get("ForegroundNear")
	if front == null: return Rect2()
	var material := front.material as ShaderMaterial
	var box: Vector4 = material.get_shader_parameter("clear_rect")
	return Rect2(Vector2(box.x,box.y)*size,Vector2(box.z-box.x,box.w-box.y)*size)

func set_active(active: bool) -> void:
	_active = active
	visible = active
	if is_instance_valid(foreground_root): foreground_root.visible = active

func _make_foreground_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 clear_rect=vec4(.03,.31,.97,.96);
uniform vec2 canvas_origin=vec2(0.0);
uniform vec2 canvas_extent=vec2(1.0);
uniform float softness=1.5;
varying vec4 vertex_tint;
void vertex() { vertex_tint=COLOR; }
void fragment() {
    vec2 step_uv=TEXTURE_PIXEL_SIZE*softness;
    vec4 color=texture(TEXTURE,UV)*.40;
    color+=texture(TEXTURE,UV+vec2(step_uv.x,0.0))*.15;
    color+=texture(TEXTURE,UV-vec2(step_uv.x,0.0))*.15;
    color+=texture(TEXTURE,UV+vec2(0.0,step_uv.y))*.15;
    color+=texture(TEXTURE,UV-vec2(0.0,step_uv.y))*.15;
    vec2 field_uv=canvas_origin+UV*canvas_extent;
    float outside=max(max(clear_rect.x-field_uv.x,field_uv.x-clear_rect.z),max(clear_rect.y-field_uv.y,field_uv.y-clear_rect.w));
    // Strictly clear inside the combat rectangle; feather only outward.
    color.a*=smoothstep(0.0,.025,outside);
    COLOR=color*vertex_tint;
}
"""
	return shader

func _make_distance_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
varying vec4 vertex_tint;
void vertex() { vertex_tint=COLOR; }
void fragment() {
    vec2 tap=TEXTURE_PIXEL_SIZE*1.5;
    vec4 c=texture(TEXTURE,UV)*.40;
    c+=texture(TEXTURE,UV+vec2(tap.x,0.0))*.15;
    c+=texture(TEXTURE,UV-vec2(tap.x,0.0))*.15;
    c+=texture(TEXTURE,UV+vec2(0.0,tap.y))*.15;
    c+=texture(TEXTURE,UV-vec2(0.0,tap.y))*.15;
    float grey=dot(c.rgb,vec3(.2126,.7152,.0722));
    c.rgb=mix(c.rgb,vec3(grey),.23);
    // Paint-distance treatment, confined to the mountain texture itself.
    c.rgb=mix(c.rgb,vec3(.63,.77,.85),.27);
    c.a*=.91;
    COLOR=c*vertex_tint;
}
"""
	return shader

func _build_haze() -> void:
	var band := ColorRect.new()
	band.name = "HorizonHaze"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.set_meta("parallax_ratio", .30)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
    float band=smoothstep(0.0,.40,UV.y)*(1.0-smoothstep(.55,1.0,UV.y));
    float sun=1.0-smoothstep(.0,.8,UV.x);
    vec3 haze=mix(vec3(.76,.85,.79),vec3(.97,.91,.72),sun*.26);
    COLOR=vec4(haze,band*.18);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	band.material = material
	add_child(band)
	_nodes[band.name] = band

func _build_overlay(node_name: String, ratio: float) -> Control:
	var overlay := Control.new()
	overlay.name = node_name
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_meta("parallax_ratio", ratio)
	foreground_root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_nodes[node_name] = overlay
	return overlay

func _build_light_shafts() -> void:
	var rays := ColorRect.new()
	rays.name = "LightShafts"
	rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rays.set_meta("parallax_ratio", .65)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 clear_rect=vec4(.03,.31,.97,.96);
uniform vec2 camera_shift=vec2(0.0);
uniform float art_time=0.0;
void fragment() {
    vec2 p=UV-camera_shift*.15;
    float drift=sin(art_time*.18)*.009;
    float diagonal=p.x-p.y*.48-drift;
    float rays=exp(-pow((diagonal-.065)/.055,2.0))*.70;
    rays+=exp(-pow((diagonal-.285)/.085,2.0))*.55;
    rays+=exp(-pow((diagonal-.56)/.035,2.0))*.33;
    float vertical=smoothstep(0.0,.08,p.y)*(1.0-smoothstep(.27,.90,p.y));
    float outside=max(max(clear_rect.x-UV.x,UV.x-clear_rect.z),max(clear_rect.y-UV.y,UV.y-clear_rect.w));
    float alpha_limit=mix(.026,.065,smoothstep(0.0,.05,outside));
    float a=min(rays*vertical*.060,alpha_limit);
    COLOR=vec4(1.0,.94,.73,a);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	rays.material = material
	foreground_root.add_child(rays)
	rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_nodes[rays.name] = rays

func _build_dust() -> void:
	_dust = _build_overlay("EdgeDust", 1.20)
	var art_rng := RandomNumberGenerator.new()
	art_rng.seed = 10032614
	for i in 28:
		var point := Vector2(art_rng.randf(),art_rng.randf())
		if i%2 == 0: point.x = art_rng.randf_range(.002,.016) if i%4 == 0 else art_rng.randf_range(.984,.998)
		else: point.y = art_rng.randf_range(.978,.998)
		_dust_points.append(point)
	_dust.draw.connect(_draw_dust)

func _draw_dust() -> void:
	var protected := foreground_clear_rect()
	var offset: Vector2 = _dust.get_meta("parallax_offset",Vector2.ZERO)
	for i in _dust_points.size():
		var phase := float(i)*2.399
		var drift := Vector2(sin(atmosphere_time*.38+phase)*3.0, sin(atmosphere_time*.23+phase*.7)*4.0)
		var point := (_dust_points[i]*size + offset + drift).clamp(Vector2(2,2),size-Vector2(2,2))
		if protected.grow(3).has_point(point): continue
		var alpha := .12 + .08*(.5+.5*sin(atmosphere_time*.6+phase))
		_dust.draw_circle(point, 1.1 if i%3 else 1.8, Color(.98,.94,.73,alpha))

func _draw_butterflies() -> void:
	var protected := foreground_clear_rect().grow(7)
	var anchors := [Vector2(.26,.273), Vector2(.75,.26), Vector2(.013,.63)]
	var offset: Vector2 = _butterflies.get_meta("parallax_offset",Vector2.ZERO)
	for i in 3:
		var phase := float(i)*2.7
		var center: Vector2 = anchors[i]*size + offset + Vector2(sin(atmosphere_time*.55+phase)*6.0, sin(atmosphere_time*.8+phase)*3.0)
		center = center.clamp(Vector2(5,5),size-Vector2(5,5))
		if protected.has_point(center): continue
		var opening := .25+.75*absf(sin(atmosphere_time*7.0+phase))
		var angle := sin(atmosphere_time*.6+phase)*.3
		var tint := Color(.99,.89,.58,.65) if i%2 == 0 else Color(.82,.92,.99,.60)
		for side in [-1.0,1.0]:
			var wing := PackedVector2Array()
			for point: Vector2 in [Vector2(0,0),Vector2(2.9,-2.4),Vector2(3.7,-.5),Vector2(2.0,2.0),Vector2(0,.8)]:
				wing.append(center + Vector2(point.x*side*opening,point.y).rotated(angle))
			_butterflies.draw_colored_polygon(wing,tint)
		_butterflies.draw_line(center-Vector2(0,1.0),center+Vector2(0,1.5),Color(.42,.47,.24,.50),.8,true)

func _draw_bokeh() -> void:
	var protected := foreground_clear_rect()
	var anchors := [Vector2(.009,.89),Vector2(.05,.99),Vector2(.12,.995),Vector2(.995,.76),Vector2(.983,.995),Vector2(.875,.998)]
	var offset: Vector2 = _bokeh.get_meta("parallax_offset",Vector2.ZERO)
	for i in anchors.size():
		var phase := float(i)*1.8
		var center: Vector2 = anchors[i]*size + offset*.18 + Vector2(sin(atmosphere_time*.19+phase)*2,cos(atmosphere_time*.25+phase)*2)
		var radius := 8.0 + float(i%3)*4.0
		if protected.grow(radius).has_point(center): continue
		var pulse := .70 + .30*sin(atmosphere_time*.32+phase)
		# Eight nested soft discs, six lights total: no viewport-wide blur pass.
		for ring in range(8,0,-1):
			var fraction := float(ring)/8.0
			_bokeh.draw_circle(center,radius*fraction,Color(.98,.95,.68,.014*pulse))
