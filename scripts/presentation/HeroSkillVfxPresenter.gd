extends Control
## One bounded canvas observes settled casts. Affinity changes paint, never
## damage, targeting, elemental resistance, status duration or combat RNG.
const MAX_CASTS := 12
const MAX_TARGETS := 4
const POOL_CAPACITY := 50
const CATALOG=preload('res://scripts/presentation/HeroSkillVfxCatalog.gd')
const SIGILS=preload('res://assets/vfx/ultra/hero-sigils.svg')
const SIGIL_SHADER=preload('res://shaders/UltraSkillSigil.gdshader')
const ELEMENT_COLORS := {
	'fire':Color('#f19b57'), 'ice':Color('#99d5ee'),
	'light':Color('#e8c99a'), 'dark':Color('#b29bc9')}
const HERO_AFFINITY := {
	'leonhardt':'light','mira':'ice','elisia':'light','kairen':'light',
	'orwin':'light','seria':'ice','astel':'light','darius':'fire',
	'lunea':'ice','caelum':'fire','valeria':'fire','morgas':'dark',
	'ragna':'dark','bron':'fire','nyx':'dark','fenris':'ice',
	'isolde':'light','garm':'fire','veyra':'dark','ulric':'dark',
	'adrien':'ice','tessa':'fire','naia':'light','sael':'light',
	'odelia':'dark','lucien':'fire','corvin':'dark','rokan':'ice',
	'bora':'ice','selene':'light'}
var field: Control
var casts: Array[Dictionary] = []
var accepted_casts := 0
var _seen: Dictionary = {}
var _rune_loop := _circle_points(48)
var _element_rays8 := _element_directions(8)
var _element_rays12 := _element_directions(12)
var _draw_worlds: Dictionary = {}
var _cards: Array[TextureRect]=[]
var _materials: Array[ShaderMaterial]=[]
var _sigil_atlases: Array[AtlasTexture]=[]
var gpu_pool: Node3D
var _cutin: Panel
var _portrait: TextureRect
var _cutin_title: Label
var _cutin_detail: Label
var _cutin_age:=1.0
var _cutin_cooldown:=0.0

static func _circle_points(segments: int) -> PackedVector2Array:
	var result:=PackedVector2Array();result.resize(segments+1)
	for i in segments+1:result[i]=Vector2.from_angle(float(i)*TAU/segments)
	return result

static func _element_directions(amount: int) -> PackedVector2Array:
	var result:=PackedVector2Array();result.resize(amount)
	for i in amount:result[i]=Vector2.from_angle(float(i)*TAU/amount+.37)
	return result

static func element_for(hero_id: String, profile: Dictionary) -> String:
	var selected := str(profile.get('visual_element',HERO_AFFINITY.get(hero_id,'light')))
	# Tessa's cooling round keeps its explicit ice identity in the shared kit.
	if hero_id == 'tessa' and str(profile.get('slot',profile.get('fx_slot',''))) == 'a2':selected='ice'
	return selected if ELEMENT_COLORS.has(selected) else 'light'

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	process_priority=110
	clip_contents=true
	for glyph in CATALOG.THEMES.size():
		var atlas:=AtlasTexture.new();atlas.atlas=SIGILS
		atlas.region=Rect2((glyph%6)*168,(glyph/6)*168,168,168);_sigil_atlases.append(atlas)
	# All nodes and shader instances are warmed once. Casts only lease cards.
	for i in POOL_CAPACITY:
		var card:=TextureRect.new();card.mouse_filter=Control.MOUSE_FILTER_IGNORE
		card.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;card.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var paint:=ShaderMaterial.new();paint.shader=SIGIL_SHADER;card.material=paint
		card.visible=false;add_child(card);_cards.append(card);_materials.append(paint)
	gpu_pool=preload('res://scripts/maps3d/UltraSkillGpuPool.gd').new();gpu_pool.name='UltraSkillGpuPool';gpu_pool.field=field
	field.world.add_child(gpu_pool)
	_build_cutin()

func _build_cutin() -> void:
	_cutin=Panel.new();_cutin.mouse_filter=Control.MOUSE_FILTER_IGNORE;_cutin.clip_contents=true
	var style:=StyleBoxFlat.new();style.bg_color=Color('#121c26');style.bg_color.a=.88
	style.border_color=Color('#c4a484');style.set_border_width_all(1);style.set_corner_radius_all(8)
	_cutin.add_theme_stylebox_override('panel',style);add_child(_cutin);_cutin.visible=false
	_portrait=TextureRect.new();_portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.position=Vector2(6,3);_portrait.size=Vector2(90,110);_cutin.add_child(_portrait)
	_cutin_title=Label.new();_cutin_title.mouse_filter=Control.MOUSE_FILTER_IGNORE;_cutin_title.position=Vector2(102,18)
	_cutin_title.add_theme_font_size_override('font_size',18);_cutin_title.add_theme_color_override('font_color',Color('#e8c99a'));_cutin.add_child(_cutin_title)
	_cutin_detail=Label.new();_cutin_detail.mouse_filter=Control.MOUSE_FILTER_IGNORE;_cutin_detail.position=Vector2(102,52)
	_cutin_detail.add_theme_font_size_override('font_size',15);_cutin.add_child(_cutin_detail)

func show_ultimate(hero_id: String, detail: String) -> bool:
	if not _active() or not field.game.combat_effects_enabled or _cutin_cooldown>0:return false
	var anchor:=_hero_anchor(hero_id)
	if anchor.is_empty():return false
	var source=anchor.ref.get_ref();var actor: Sprite3D=field.actors.get(source.get_instance_id())
	if is_instance_valid(actor):
		var pilot=actor.get_node_or_null('HuntFramePilot')
		if is_instance_valid(pilot) and pilot._material is ShaderMaterial:
			var texture: Texture2D=pilot._material.get_shader_parameter('source_texture')
			var region: Vector4=pilot._material.get_shader_parameter('atlas_rect')
			if texture!=null:
				var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=Rect2(region.x*texture.get_width(),region.y*texture.get_height(),region.z*texture.get_width(),region.w*texture.get_height());_portrait.texture=atlas
	_cutin_title.text=str(CATALOG.ROSTER.HEROES.get(hero_id,{}).get('name',hero_id))+' · 궁극기'
	_cutin_detail.text=detail;_cutin_age=0;_cutin_cooldown=3;_cutin.visible=true
	return true

func _lease_card(visual: Dictionary) -> int:
	for i in _cards.size():
		if _cards[i].visible:continue
		var atlas: AtlasTexture=_sigil_atlases[int(visual.glyph)]
		_cards[i].texture=atlas;_cards[i].visible=true
		_materials[i].set_shader_parameter('uv_region',Vector4(atlas.region.position.x/1024.0,atlas.region.position.y/1024.0,168.0/1024.0,168.0/1024.0))
		_materials[i].set_shader_parameter('identity',visual.seed)
		_materials[i].set_shader_parameter('symmetry',float(visual.symmetry))
		_materials[i].set_shader_parameter('core_color',visual.core)
		return i
	return -1

func _retire(index: int) -> void:
	var card:=int(casts[index].card)
	if card>=0:_cards[card].visible=false
	casts.remove_at(index)

func _active() -> bool:
	return is_instance_valid(field) and is_instance_valid(field.game) and field.battle_clock_running()

func cast(hero_id: String, target_index: int, _aoe: bool, profile: Dictionary, ultimate := false) -> bool:
	if not _active() or not field.game.combat_effects_enabled:return false
	var game = field.game
	if not game.hero_battle_state.has(hero_id) or int(game.hero_battle_state[hero_id].get('hp',0))<=0:return false
	var caster := _hero_anchor(hero_id)
	if caster.is_empty():return false
	var serial := int(profile.get('fx_cast_serial',0))
	if serial>0:
		var key := '%s:%s:%s:%d' % [str(game.raid_encounter_serial) if field.raid_mode else str(game.hunt_ai.encounter_id),hero_id,str(profile.get('fx_slot',profile.get('slot','a1'))),serial]
		if _seen.has(key):return false
		if _seen.size()>=64:_seen.clear()
		_seen[key]=true
	var destinations: Array[Dictionary]=[]
	for index in profile.get('fx_targets',[target_index]):
		var anchor := _enemy_anchor(int(index))
		if not anchor.is_empty():destinations.append(anchor)
		if destinations.size()>=MAX_TARGETS:break
	for ally in profile.get('fx_allies',[]):
		if destinations.size()>=MAX_TARGETS:break
		var anchor := _hero_anchor(str(ally.get('hero_id','')))
		if not anchor.is_empty():destinations.append(anchor)
	if destinations.is_empty():destinations.append(caster)
	if casts.size()>=MAX_CASTS:
		# Ordinary casts cannot evict an ultimate that is still readable.
		var oldest := -1
		for i in casts.size():
			if not bool(casts[i].ultimate):oldest=i;break
		if oldest<0 and not ultimate:return false
		_retire(0 if oldest<0 else oldest)
	var slot:=str(profile.get('fx_slot',profile.get('slot','ultimate' if ultimate else 'a1')))
	var visual: Dictionary=CATALOG.profile(hero_id,slot)
	if visual.is_empty():return false
	var card:=_lease_card(visual)
	if card<0:return false
	casts.append({'caster':caster,'targets':destinations,'element':element_for(hero_id,profile),
		'ultimate':ultimate,'kind':str(profile.get('kind','damage')),'age':0.0,
		'duration':float(visual.charge)+float(visual.flight)+float(visual.impact)+float(visual.tail),
		'visual':visual,'card':card,'impacted':false})
	accepted_casts+=1
	queue_redraw()
	return true

func _hero_anchor(hero_id: String) -> Dictionary:
	var game = field.game
	var source: AnimatedSprite2D
	var point := Vector2.ZERO
	if field.raid_mode:
		if not is_instance_valid(field.raid_view):return {}
		source=field.raid_view.hero_actors.get(hero_id)
		if not is_instance_valid(source):return {}
		point=field.raid_to_world(source.position)
	else:
		# Production slots already index the painted roster; avoid allocating an
		# ID array for each status/gauge on every frame. Legacy callers can fall back.
		var index: int=int(game.hero_battle_state.get(hero_id,{}).get('slot',-1))
		if index<0 or index>=game.deployed_heroes.size() or str(game.deployed_heroes[index].id)!=hero_id:index=game._deployed_hero_ids().find(hero_id)
		if index<0 or index>=game.hero_map_sprites.size():return {}
		source=game.hero_map_sprites[index]
		if not is_instance_valid(source):return {}
		point=field.display_world(source,game._hero_field_position(hero_id))
	return {'ref':weakref(source),'world':point,'hero':hero_id,'enemy':-2,'height':field.actor_world_height(source,true)}

func _enemy_anchor(index: int) -> Dictionary:
	var game = field.game
	var source: AnimatedSprite2D
	var point := Vector2.ZERO
	if field.raid_mode:
		source=game.raid_boss_sprite
		if not is_instance_valid(source):return {}
		point=field.raid_to_world(source.position)
	else:
		if index<0 or index>=game.enemy_wave_sprites.size():return {}
		source=game.enemy_wave_sprites[index]
		if not is_instance_valid(source):return {}
		point=field.display_world(source,game.roaming_hunt.enemy_position(index))
	return {'ref':weakref(source),'world':point,'hero':'','enemy':index,'height':field.actor_world_height(source,false)}

func _world(anchor: Dictionary) -> Vector2:
	var source = anchor.ref.get_ref()
	if not is_instance_valid(source):return anchor.world
	if field.raid_mode:return field.raid_to_world(source.position)
	var game = field.game
	if not str(anchor.hero).is_empty():return field.display_world(source,game._hero_field_position(str(anchor.hero)))
	var index := int(anchor.enemy)
	# A wave replacement must not redirect the old impact onto a new enemy.
	if index<0 or index>=game.enemy_wave_sprites.size() or game.enemy_wave_sprites[index]!=source:return anchor.world
	return field.display_world(source,game.roaming_hunt.enemy_position(index))

func _draw_world(anchor: Dictionary) -> Vector2:
	var source=anchor.ref.get_ref()
	if not is_instance_valid(source):return anchor.world
	var key: int=source.get_instance_id()
	if not _draw_worlds.has(key):_draw_worlds[key]=_world(anchor)
	return _draw_worlds[key]

func advance(delta: float) -> void:
	if not is_instance_valid(field) or not is_instance_valid(field.game):return
	if not field.game.combat_effects_enabled:
		for card in _cards:card.visible=false
		casts.clear();_seen.clear();_cutin.visible=false;queue_redraw();return
	if _active():
		var elapsed: float = maxf(0,delta)*field.visual_speed()
		_cutin_cooldown=maxf(0,_cutin_cooldown-elapsed)
		_cutin_age+=elapsed
		_cutin.visible=_cutin_age<.70
		if _cutin.visible:
			_cutin.position=Vector2(12,12);_cutin.size=Vector2(minf(390,size.x-24),116)
			_cutin.modulate.a=minf(1,_cutin_age/.08)*clampf((.70-_cutin_age)/.15,0,1)
		for item in casts:
			item.age+=elapsed;_update_card(item)
			if not item.impacted and float(item.age)>=float(item.visual.charge)+float(item.visual.flight):
				item.impacted=true
				var target: Dictionary=item.targets[0]
				gpu_pool.burst(_world(target),float(target.height)*.45,item.visual)
				if bool(item.ultimate):_ultimate_impact(item)
		for i in range(casts.size()-1,-1,-1):
			if float(casts[i].age)>=float(casts[i].duration):_retire(i)
	queue_redraw()

func _update_card(item: Dictionary) -> void:
	var visual: Dictionary=item.visual;var card: TextureRect=_cards[int(item.card)]
	var phase:=clampf(float(item.age)/float(item.duration),0,1)
	var charge: bool=float(item.age)<float(visual.charge)
	var anchor: Dictionary=item.caster if charge else item.targets[0]
	var point: Vector2=field.project_world(_world(anchor),0 if charge else float(anchor.height)*.48)
	var diameter: float=(48 if charge else 56)*float(visual.power)
	card.size=Vector2.ONE*diameter;card.pivot_offset=card.size*.5;card.position=point-card.size*.5
	card.rotation=float(visual.twist)*sin(phase*PI)
	card.modulate=Color(visual.color,sin(phase*PI)*.8)
	_materials[int(item.card)].set_shader_parameter('phase',phase)

func _ultimate_impact(item: Dictionary) -> void:
	if is_instance_valid(field.mobile_camera):field.mobile_camera.impact(true)
	field.ultra_post_impact()
	var runtime=field.game.presentation_runtime
	if is_instance_valid(runtime) and is_instance_valid(runtime.contact_time):runtime.contact_time.request_ultra()
	if is_instance_valid(field.contact_flash):field.contact_flash.flash_ultra(item.visual.color)

func _process(delta: float) -> void:advance(delta)

func _draw() -> void:
	if not is_instance_valid(field) or not is_instance_valid(field.game) or not field.game.combat_effects_enabled:return
	if not field.presentation_visible or field.game.active_screen!=('raid' if field.raid_mode else 'combat'):return
	_draw_worlds.clear()
	_draw_states()
	for item in casts:_draw_cast(item)

func _draw_cast(item: Dictionary) -> void:
	var age := float(item.age)
	var progress := clampf(age/float(item.duration),0,1)
	var opacity := sin(progress*PI)*.8
	var tint: Color=item.visual.color
	var caster_world:=_draw_world(item.caster)
	var origin: Vector2=field.project_world(caster_world)
	var power := float(item.visual.power)
	var radius := (24.0+minf(1,progress*4)*6)*power
	_draw_rune(origin,radius,tint,opacity,age)
	var start: Vector2=field.project_world(caster_world,float(item.caster.height)*.52)
	for target in item.targets:
		var finish: Vector2=field.project_world(_draw_world(target),float(target.height)*.48)
		if progress<.62 and start.distance_squared_to(finish)>25:
			_draw_trail(start,finish,tint,progress/.62,opacity,power,float(item.visual.twist),int(item.visual.echoes))
		if progress>=.20:
			_draw_element(finish,str(item.element),tint,clampf((progress-.20)/.8,0,1),opacity,power)
	if bool(item.ultimate) and age<.06:
		# Short, low-alpha elemental flash leaves character silhouettes readable.
		draw_rect(Rect2(Vector2.ZERO,size),Color(tint,.045*(1-age/.06)))
	if bool(item.ultimate) and item.impacted:
		var flare:=clampf(1-(age-float(item.visual.charge)-float(item.visual.flight))/.18,0,1)
		var center: Vector2=field.project_world(_draw_world(item.targets[0]),float(item.targets[0].height)*.48)
		draw_line(center-Vector2(65,0),center+Vector2(65,0),Color(tint,flare*.24),3,true)
		draw_line(center-Vector2(0,25),center+Vector2(0,25),Color(item.visual.core,flare*.35),2,true)

func _draw_rune(point: Vector2,radius: float,tint: Color,opacity: float,age: float) -> void:
	# Transform cached 49-point loops in native code, with the same ellipse and
	# segment count, instead of evaluating 196 sine/cosine calls per cast/frame.
	var ring: PackedVector2Array=Transform2D(Vector2(radius,0),Vector2(0,radius*.42),point)*_rune_loop
	var inner: PackedVector2Array=Transform2D(Vector2(radius*.80,0),Vector2(0,radius*.34),point)*_rune_loop
	draw_polyline(ring,Color(tint,opacity*.12),5,true)
	draw_polyline(ring,Color(tint,opacity*.8),1.1,true)
	draw_polyline(inner,Color(tint,opacity*.25),.8,true)
	var glyphs:=PackedVector2Array();glyphs.resize(64)
	for i in 8:
		var angle:=float(i)*TAU/8+age*.24
		var center:=point+Vector2(cos(angle)*radius*.91,sin(angle)*radius*.385)
		var side:=Vector2.from_angle(angle).orthogonal()*2
		var up:=Vector2(0,3)
		var vertices:=PackedVector2Array([center-up,center+side,center+up,center-side,center-up])
		for edge in 4:
			glyphs[i*8+edge*2]=vertices[edge];glyphs[i*8+edge*2+1]=vertices[edge+1]
	draw_multiline(glyphs,Color(Color('#e8c99a'),opacity*.7),.9,true)

func _draw_trail(start: Vector2,finish: Vector2,tint: Color,phase: float,opacity: float,power: float,twist:=0.0,echoes:=5) -> void:
	var points:=PackedVector2Array()
	var side: Vector2=(finish-start).orthogonal().normalized()
	var leading:=clampf(phase*1.4,0,1)
	for i in 13:
		var t:=lerpf(maxf(0,leading-.34),leading,float(i)/12)
		points.append(start.lerp(finish,t)+side*sin(t*PI)*(9+twist*18)*power)
	for echo in echoes:
		var offset:=side*float(echo-2)*1.4
		draw_polyline(Transform2D(0,offset)*points,Color(tint,opacity*.025*(1-float(echo)/echoes)),5*power,true)
	draw_polyline(Transform2D(0,Vector2(0,2))*points,Color('#10161c',opacity*.15),7*power,true)
	draw_polyline(points,Color(tint,opacity*.12),9*power,true)
	draw_polyline(points,Color(tint,opacity*.48),3*power,true)
	draw_polyline(points,Color(Color('#fff5df'),opacity*.75),1.0,true)
	draw_circle(points[points.size()-1],2.4*power,Color(Color('#fff7e5'),opacity))

func _draw_element(point: Vector2,element: String,tint: Color,phase: float,opacity: float,power: float) -> void:
	var radius := (5+phase*18)*power
	var amount := 12 if power>1.0 else 8
	var rays: PackedVector2Array=_element_rays12 if amount==12 else _element_rays8
	var accents:=PackedVector2Array();accents.resize(amount*2)
	var light_crosses:=PackedVector2Array()
	if element=='light':light_crosses.resize(amount*2)
	var alpha:=opacity*(1-phase*.55)
	for i in amount:
		var angle:=float(i)*TAU/float(amount)+.37
		var offset:=rays[i]*radius
		var tip:=point+offset-Vector2(0,phase*7)
		match element:
			'ice':
				var length: float=(5-phase*2)*power
				var direction:=rays[i]
				var side:=direction.orthogonal()*1.8
				draw_colored_polygon(PackedVector2Array([tip-direction*length,tip+side,tip+direction*length,tip-side]),Color(tint,alpha*.7))
				accents[i*2]=tip-direction*length;accents[i*2+1]=tip+direction*length
			'fire':
				var length: float=(6-phase*3)*power
				draw_colored_polygon(PackedVector2Array([tip+Vector2(-2,2),tip+Vector2(0,-length),tip+Vector2(2,2)]),Color(tint,alpha*.75))
				accents[i*2]=tip+Vector2(0,1);accents[i*2+1]=tip+Vector2(0,-length*.5)
			'light':
				accents[i*2]=tip-Vector2(0,3)*power;accents[i*2+1]=tip+Vector2(0,3)*power
				light_crosses[i*2]=tip-Vector2(2,0)*power;light_crosses[i*2+1]=tip+Vector2(2,0)*power
			'dark':
				draw_arc(tip,2.5*power,angle,angle+PI*1.15,9,Color(tint,alpha),1.5,true)
	match element:
		'ice':draw_multiline(accents,Color(Color('#f1fbff'),alpha),.8,true)
		'fire':draw_multiline(accents,Color(Color('#fff0b8'),alpha),1.2,true)
		'light':
			draw_multiline(accents,Color(tint,alpha),1,true)
			draw_multiline(light_crosses,Color(Color('#fff7e5'),alpha),1,true)
	draw_arc(point,radius*.7,-phase*2,TAU-phase*2,24,Color(tint,opacity*.28),1.2,true)
	if phase<.15:
		draw_circle(point,3.0*power,Color(Color('#fff8e8'),opacity*(1-phase/.15)))

func hero_statuses(state: Dictionary) -> Array[String]:
	var result: Array[String]=[]
	if float(state.get('guard',0))>0:result.append('guard')
	if int(state.get('shield',0))>0 and float(state.get('shield_seconds',0))>0:result.append('shield')
	return result

func enemy_statuses(state: Dictionary) -> Array[String]:
	var result: Array[String]=[]
	for kind in ['stun','weaken','vulnerable']:
		if float(state.get(kind+'_seconds',0))>0:result.append(kind)
	return result

func _draw_states() -> void:
	var game=field.game
	for hero in game.deployed_heroes:
		var id:=str(hero.id)
		var state: Dictionary=game.hero_battle_state.get(id,{})
		if int(state.get('hp',0))<=0:continue
		var anchor:=_hero_anchor(id)
		if anchor.is_empty():continue
		var foot: Vector2=field.project_world(_draw_world(anchor))
		var source=anchor.ref.get_ref()
		if is_instance_valid(source) and field._paint_rects.has(source.get_instance_id()):foot.y=field._paint_rects[source.get_instance_id()].end.y-field.position.y
		var gauge:=clampf(float(state.get('ultimate',0))/100,0,1)
		var width:=36.0
		draw_rect(Rect2(foot+Vector2(-width*.5,16),Vector2(width,3)),Color('#191d22'))
		if gauge>0:draw_rect(Rect2(foot+Vector2(-width*.5,16),Vector2(width*gauge,3)),Color('#e8c99a') if gauge>=1 else Color('#8fa7b2'))
		_draw_badges(anchor,hero_statuses(state))
	if field.raid_mode:
		if game.raid_boss_hp>0:
			var anchor:=_enemy_anchor(-1)
			if not anchor.is_empty():_draw_badges(anchor,enemy_statuses({'stun_seconds':game._stun_seconds,'weaken_seconds':game._weaken_seconds,'vulnerable_seconds':game._vulnerable_seconds}))
	else:
		for i in game.enemy_wave.size():
			if int(game.enemy_wave[i].get('hp',0))<=0:continue
			var statuses:=enemy_statuses(game.enemy_wave[i])
			if statuses.is_empty():continue
			var anchor:=_enemy_anchor(i)
			if not anchor.is_empty():_draw_badges(anchor,statuses)

func _draw_badges(anchor: Dictionary,statuses: Array[String]) -> void:
	if statuses.is_empty():return
	var source=anchor.ref.get_ref()
	var point: Vector2=field.project_world(_draw_world(anchor))-Vector2(0,float(anchor.height)*field.size.y/field.camera.size+22)
	if is_instance_valid(source) and field._paint_rects.has(source.get_instance_id()):point.y=field._paint_rects[source.get_instance_id()].position.y-field.position.y-22
	point.x-=float(statuses.size()-1)*7
	for kind in statuses:
		var tint:=Color('#a8b89e') if kind in ['guard','shield'] else Color('#dba38b')
		draw_circle(point,6,Color('#151b20'))
		draw_arc(point,5.5,0,TAU,16,Color(tint,.8),.8,true)
		match kind:
			'guard','shield':
				var shape:=PackedVector2Array([point+Vector2(-3,-3),point+Vector2(3,-3),point+Vector2(2,2),point+Vector2(0,4),point+Vector2(-2,2),point+Vector2(-3,-3)])
				draw_polyline(shape,tint,1,true)
				if kind=='guard':draw_line(point-Vector2(0,2),point+Vector2(0,2),tint,1,true)
			'stun':
				var star:=PackedVector2Array()
				for i in 11:star.append(point+Vector2.from_angle(float(i)*PI/5-PI*.5)*(4 if i%2==0 else 1.7))
				draw_polyline(star,tint,1,true)
			'weaken':
				draw_line(point-Vector2(0,3),point+Vector2(0,3),tint,1,true)
				draw_polyline(PackedVector2Array([point+Vector2(-3,0),point+Vector2(0,3),point+Vector2(3,0)]),tint,1,true)
			'vulnerable':
				draw_arc(point,3,0,TAU,12,tint,1,true)
				draw_line(point-Vector2(4,0),point+Vector2(4,0),tint,1,true)
				draw_line(point-Vector2(0,4),point+Vector2(0,4),tint,1,true)
		point.x+=14
