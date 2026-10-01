extends Control
class_name HeroSkillEffect

# v31 presentation only. This node never reads/writes HP, cooldowns or targeting.
# Every point is captured by HeroKitRuntime while the real effect is applied.
const VISUALS = preload("res://scripts/HeroVisualCatalog.gd")
const PIXEL_FX = preload("res://scripts/PixelFxAtlas.gd")
const ACCENTS := {
	"leonhardt":"#608DC1", "mira":"#7AACCE", "elisia":"#6DAB83", "kairen":"#A7C9D8", "orwin":"#C8AB61",
	"seria":"#63B6AA", "astel":"#DDA598", "darius":"#BA7966", "lunea":"#86B4A5", "caelum":"#D5A455",
	"adrien":"#ACC3D0", "tessa":"#8FCAEA", "naia":"#B5A6D7", "sael":"#A4C789", "odelia":"#B9A06A",
	"valeria":"#B9687D", "morgas":"#AF8BA8", "ragna":"#D59B61", "bron":"#B69E7A", "nyx":"#A783B0",
	"fenris":"#86BFCC", "isolde":"#CD879C", "garm":"#7595B2", "veyra":"#66B5B2", "ulric":"#6875B6",
	"lucien":"#D86E75", "corvin":"#D7A65F", "rokan":"#D9AE62", "bora":"#90C9DF", "selene":"#C76C91"
}
var game: Control
var hero_id := ""
var slot := "a1"
var source := Vector2.ZERO
var targets: Array[Dictionary] = []
var profile: Dictionary = {}
var icon: Texture2D
var tint := Color.WHITE
var elapsed := 0.0
var lifetime := 0.55
var screen := "combat"
var power := 1.0
var variant := 0

func configure(next_game: Control, id: String, next_slot: String, start: Vector2, points: Array[Dictionary], data: Dictionary, bounds: Rect2) -> void:
	game = next_game
	hero_id = id
	slot = next_slot
	source = start - bounds.position
	# HeroSkillClip already starts at bounds.position. A second offset pushed
	# these hero effects outside the field and clipped away on portrait screens.
	position = Vector2.ZERO
	size = bounds.size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 73
	profile = data
	tint = Color(ACCENTS.get(id, "#829C8B"))
	icon = VISUALS.skill_texture(id, slot)
	screen = str(game.active_screen)
	variant = 1 if slot == "a2" else (2 if slot == "ultimate" else 0)
	power = 1.35 if slot == "ultimate" else (0.62 if slot == "passive" else 1.0)
	lifetime = 0.74 if slot == "ultimate" else (0.38 if slot == "passive" else 0.54)
	for item in points:
		targets.append({"point":Vector2(item["point"]) - bounds.position, "mode":str(item["mode"]), "hits":int(item.get("hits",1))})
	set_meta("hero_id", id)
	set_meta("skill_slot", slot)
	set_meta("skill_id", str(data.get("id", id + "_" + slot)))
	set_meta("actual_target_count", targets.size())

func _process(delta: float) -> void:
	if not is_instance_valid(game) or str(game.active_screen) != screen or not bool(game.combat_effects_enabled):
		queue_free()
		return
	if bool(game._application_suspended) or (screen == "combat" and not bool(game.combat_running)):
		return
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var t := clampf(elapsed / lifetime, 0.0, 1.0)
	var opacity := minf(1.0, (1.0 - t) * 3.5)
	var color := Color(tint, opacity * 0.88)
	if not targets.is_empty() and slot != 'passive':
		var target_point: Vector2 = targets[0]['point']
		if Rect2(Vector2.ZERO,size).has_point(source) and Rect2(Vector2.ZERO,size).has_point(target_point):
			var progress := smoothstep(0.02,0.38,t)
			var head := source.lerp(target_point,progress)
			var tail := source.lerp(target_point,maxf(0.0,progress-.18))
			if str(targets[0]['mode']) == 'enemy':
				draw_line(tail,head,Color(tint,opacity*.46),2.2 if slot!='ultimate' else 3.5,true)
	for item in targets:
		var p: Vector2 = item["point"]
		if not Rect2(Vector2.ZERO, size).grow(40).has_point(p): continue
		var mode := str(item["mode"])
		_draw_raster_burst(p, mode, t, opacity)
		var halo_radius := (18.0 if slot=='ultimate' else 12.0) + 12.0*t
		draw_arc(p,halo_radius,-PI*.75+t*.4,PI*.35+t*.4,20,Color(tint,opacity*.42),1.6,true)
		if mode == "enemy":
			_draw_attack(p, t, color, int(item.get("hits",1)))
		else:
			_draw_support(p, mode, t, color)
	# The small badge identifies a real cast/proc, never an always-on passive.
	if icon != null and Rect2(Vector2.ZERO, size).has_point(source):
		var edge := 24.0 if slot == "ultimate" else (14.0 if slot == "passive" else 19.0)
		var origin := (source + Vector2(-edge * .5, -26.0 - t * 8.0)).round()
		if slot == "ultimate":
			draw_rect(Rect2(origin - Vector2(2, 2), Vector2.ONE * (edge + 4)), Color("#D5B26A"), false, 2)
		draw_texture_rect(icon, Rect2(origin, Vector2.ONE * edge), false, Color(1, 1, 1, opacity))

func _draw_raster_burst(p: Vector2, mode: String, t: float, opacity: float) -> void:
	var effect := PIXEL_FX.effect_for(hero_id, slot, mode)
	if effect.is_empty(): return
	var texture := PIXEL_FX.frame_texture(effect, mini(3, int(t * 4.0)))
	if texture == null: return
	# One compact burst per captured recipient; no invented projectiles or repeats.
	var edge := 76.0 if slot == "ultimate" else 58.0
	var origin := (p - Vector2(edge * 0.5, edge * 0.62)).round()
	draw_texture_rect(texture, Rect2(origin, Vector2.ONE * edge), false, Color(1, 1, 1, opacity * 0.92))

func _snap(p: Vector2) -> Vector2:
	return (p / 2.0).round() * 2.0

func _line(a: Vector2, b: Vector2, c: Color, width := 2.0) -> void:
	draw_line(_snap(a), _snap(b), c, width, false)

func _path(points: Array[Vector2], c: Color, width := 2.0, close := false) -> void:
	for i in range(points.size() - 1): _line(points[i], points[i + 1], c, width)
	if close and points.size() > 2: _line(points[-1], points[0], c, width)

func _ring(p: Vector2, r: float, c: Color, sides := 12, start := 0.0, sweep := TAU) -> void:
	var pts: Array[Vector2] = []
	for i in range(sides + 1):
		var angle := start + sweep * float(i) / float(sides)
		pts.append(p + Vector2(cos(angle), sin(angle)) * r)
	_path(pts, c)

func _diamond(p: Vector2, r: float, c: Color) -> void:
	_path([p + Vector2(0,-r), p + Vector2(r,0), p + Vector2(0,r), p + Vector2(-r,0)], c, 2, true)

func _star(p: Vector2, r: float, c: Color) -> void:
	_line(p - Vector2(r,0), p + Vector2(r,0), c)
	_line(p - Vector2(0,r), p + Vector2(0,r), c)
	_diamond(p, r * .4, c)

func _box(p: Vector2, r: float, c: Color, closed := true) -> void:
	if closed:
		_path([p + Vector2(-r,-r),p + Vector2(r,-r),p + Vector2(r,r),p + Vector2(-r,r)],c,2,true)
	else:
		for x in [-1.0,1.0]:
			for y in [-1.0,1.0]:
				var q := p + Vector2(x,y) * r
				_line(q,q-Vector2(x*r*.5,0),c)
				_line(q,q-Vector2(0,y*r*.5),c)

func _leaf(p: Vector2, r: float, c: Color, angle := 0.0) -> void:
	var v := Vector2(cos(angle),sin(angle))
	var side := v.orthogonal()
	_path([p-v*r,p+side*r*.42,p+v*r,p-side*r*.42],c,2,true)
	_line(p-v*r,p+v*r,c)

func _note(p: Vector2, r: float, c: Color) -> void:
	_line(p+Vector2(0,-r),p,c)
	_line(p+Vector2(0,-r),p+Vector2(r*.6,-r*.6),c)
	draw_rect(Rect2(_snap(p-Vector2(r*.45,1)),Vector2(6,4)),c)

func _shield(p: Vector2, r: float, c: Color) -> void:
	_path([p+Vector2(-r,-r*.8),p+Vector2(r,-r*.8),p+Vector2(r*.8,r*.3),p+Vector2(0,r),p+Vector2(-r*.8,r*.3)],c,2,true)

func _draw_attack(p: Vector2, t: float, c: Color, actual_hits: int) -> void:
	var r := (12.0 + sin(t * PI) * 8.0) * power
	var white := Color("#EEEADF")
	white.a = c.a * .75
	var hit_count := maxi(1, actual_hits)
	var beat := mini(hit_count - 1, int(t * hit_count))
	var local_t := fmod(t * hit_count, 1.0)
	var angle := -.8 + t * 1.1
	if hero_id in ["mira","seria","tessa","naia","rokan","lucien"] and t < .42:
		var travel := minf(1.0,t / .32)
		var tip := source.lerp(p, travel)
		var tail := source.lerp(p, maxf(0,travel-.16))
		_line(tail,tip,Color(c,.6), 2 if slot != "ultimate" else 3)
	match hero_id:
		"mira":
			# One precise line; A2 squares show the separately captured pierced enemies.
			if variant == 1: _box(p,r*.5,c,false)
			elif variant == 2: _diamond(p,r*.75,c)
			else: _star(p,r*.7,c)
			_line(p-Vector2(r*1.2,0),p+Vector2(r*.7,0),white)
		"kairen":
			_ring(p,r,c,16)
			for i in range(8):
				var v := Vector2.from_angle(TAU * i / 8.0)
				_line(p+v*r*.8,p+v*r,c)
			_line(p,p+Vector2.from_angle(t*PI)*r*.7,c)
			_line(p,p+Vector2(0,-r*.65),white)
			if variant == 1: _diamond(p,r*.45,c)
			if variant == 2: _ring(p,r*1.3,Color(c,.55),16)
		"seria":
			var y := float(beat % 3 - 1) * 5.0
			_line(p+Vector2(-r,y+5),p+Vector2(r*.3,y),c)
			_path([p+Vector2(r*.0,y-5),p+Vector2(r*.4,y),p+Vector2(0,y+5)],c)
			_ring(p,r*(.65+local_t*.4),Color(c,.35),6,-.8,1.6)
		"darius":
			_line(p+Vector2(0,-r*1.3),p+Vector2(0,r),c,5 if variant == 2 else 3)
			_line(p+Vector2(-r*.5,-r*.5),p+Vector2(r*.5,-r*.5),white)
			if variant == 1: _box(p+Vector2(r*.55,0),5,c,false)
			if variant == 2: _path([p+Vector2(-12,-r),p+Vector2(-8,-r-6),p+Vector2(0,-r),p+Vector2(8,-r-6),p+Vector2(12,-r)],c)
		"lunea":
			for i in range(3 if variant == 2 else 2):
				var y := float(i)*6-2
				_path([p+Vector2(-r,y),p+Vector2(-r*.5,y-3),p+Vector2(0,y),p+Vector2(r*.6,y-3),p+Vector2(r,y)],Color(c,c.a*.7))
			if variant == 1: _diamond(p,5,c)
		"caelum":
			_ring(p,r,c,12,angle,PI*1.5 if variant != 1 else PI)
			if variant == 2:
				for i in range(6):
					var v := Vector2.from_angle(TAU*i/6.0+angle)
					_line(p+v*r*.9,p+v*r*1.3,c)
			_star(p,5,white)
		"adrien":
			_line(p+Vector2(-r,r*.4),p+Vector2(r,-r*.4),white,3 if variant == 2 else 2)
			_path([p+Vector2(-r,-r*.5),p+Vector2(0,r*.5),p+Vector2(r,-r*.5)],c)
			if variant == 1: _diamond(p,4,c)
		"tessa":
			_box(p,r*.7,c,variant != 2)
			if variant == 1: _path([p+Vector2(-6,4),p+Vector2(0,10),p+Vector2(6,4)],c)
			else: _box(p,r*.35,white)
			if variant == 2: _line(p-Vector2(0,r*1.7),p-Vector2(0,r*.7),white,3)
		"naia":
			_line(p-Vector2(r*1.1,r*.65),p+Vector2(r*.2,r*.2),c,3 if variant == 2 else 2)
			_diamond(p,r*.45,c)
			for i in range(3): _ring(p-Vector2(r*(.6+i*.35),r*.35),2+i,white,6)
			if variant == 1: _path([p+Vector2(-5,-r),p+Vector2(5,-r),p+Vector2(0,r*.3)],c)
		"sael":
			for i in range(3 if variant > 0 else 2):
				var a := angle+TAU*i/(3.0 if variant>0 else 2.0)
				_leaf(p+Vector2.from_angle(a)*r*.6,r*.45,c,a+PI*.5)
			if variant == 2: _ring(p,r,Color(c,.4),10,angle,PI*1.6)
		"odelia":
			_box(p,r*.75,c,variant == 0)
			if variant > 0: _box(p,r*.45,Color("#927B99"),false)
			_line(p+Vector2(-4,r),p+Vector2(4,r),c)
		"valeria":
			_ring(p,r,c,10,-2.0+t*.3,PI*1.25)
			if variant == 1: _line(p+Vector2(-r,r*.7),p+Vector2(r,-r*.7),c)
			if variant == 2: _diamond(p,r*.65,white)
		"morgas":
			_path([p+Vector2(0,-r),p+Vector2(r*.8,r*.5),p+Vector2(-r*.8,r*.5)],c,2,variant == 1)
			for i in range(2 if variant<2 else 4):
				_ring(p+Vector2((i%2*2-1)*r*.45,-t*10-i*3),3+i%2,Color(c,.6),6)
		"ragna":
			for i in range(2 if variant<2 else 3):
				var x := -r+i*r*.65
				_path([p+Vector2(x,-r*.5),p+Vector2(x+r*.45,0),p+Vector2(x,r*.5)],c,3 if variant==2 else 2)
			if variant==1: _line(p-Vector2(r,0),p+Vector2(r,0),white)
		"bron":
			for i in range(3):
				var q := p+Vector2((i-1)*r*.6,4)
				_path([q+Vector2(-5,0),q+Vector2(-4,-r*.7),q+Vector2(5,-r),q+Vector2(7,0)],c,3)
		"nyx":
			_diamond(p,r,c)
			_path([p+Vector2(-r*.65,0),p+Vector2(0,-r*.3),p+Vector2(r*.65,0),p+Vector2(0,r*.3)],c,2,true)
			_diamond(p,3,white)
			if variant==2: _diamond(p,r*1.3,Color(c,.5))
			if variant==1: _line(p+Vector2(-r,r),p+Vector2(r,-r),c)
		"fenris":
			for i in range(4):
				var x := float(i-2)*5
				_line(p+Vector2(x-r*.5,-r*.8),p+Vector2(x+r*.5,r*.8),Color(c,c.a*(1.0-i*.1)),3 if variant==2 else 2)
			if variant==1: _path([p+Vector2(-r,0),p,p+Vector2(r,-r*.5)],white)
		"veyra":
			_leaf(p,r,c,-.7)
			if variant==2: _leaf(p,r,c,.7)
			if variant==1: _line(p-Vector2(r*1.3,0),p+Vector2(r*.5,0),white)
		"ulric":
			_ring(p,r,c,10,-2.0,PI*1.25)
			_ring(p,r*.75,Color(c,.55),8,.5,PI*.8)
			if variant==1: _path([p+Vector2(-5,0),p+Vector2(0,6),p+Vector2(5,0)],c)
			else: _line(p+Vector2(0,-r),p+Vector2(0,r*.7),white)
		"lucien":
			_line(p-Vector2(r*1.4,0),p+Vector2(r*.4,0),c,3 if variant==2 else 2)
			_diamond(p+Vector2(r*.3,0),r*.35,c)
			if variant!=0: _path([p+Vector2(-r,5),p+Vector2(-r*.4,9),p+Vector2(0,5)],Color(c,.5))
		"corvin":
			for i in range(3): _ring(p,r*(1.2-t*.45)-i*4,c if i%2==0 else Color("#8B719E"),12)
			if variant==2:
				_line(p+Vector2(-r,-8),p+Vector2(-r,8),c)
				_line(p+Vector2(r,-8),p+Vector2(r,8),c)
		"rokan":
			var y := float(beat%2)*5-2
			_path([p+Vector2(-r,y-5),p+Vector2(r*.4,y),p+Vector2(-r,y+5)],c,2,true)
			for i in range(3): _line(p+Vector2(-r-6-i*5,y),p+Vector2(-r-3-i*5,y),Color(c,.5))
			if variant==1: _diamond(p,5,white)
		"bora":
			_ring(p,r*(.55+local_t*.4),c,12)
			_star(p+Vector2((beat%2*2-1)*r*.2,0),r*.35,Color("#DD918D") if variant==1 else white)
			if variant==2: _ring(p,r*1.25,Color(c,.5),12)
		_:
			_diamond(p,r*.6,c)

func _draw_support(p: Vector2, mode: String, t: float, c: Color) -> void:
	var r := (10.0 + sin(t*PI)*4.0) * power
	if mode in ["energy","cooldown"]:
		if mode == "energy":
			draw_rect(Rect2(_snap(p+Vector2(-2,-t*16)),Vector2(4,4)),c)
		else:
			_ring(p,r*.7,c,8,-PI*.8-t,PI*1.3)
			_line(p+Vector2(-r*.5,-r*.5),p+Vector2(-r*.5,0),c)
		return
	if mode == "return":
		_diamond(p+Vector2(0,-t*12),4*power,c)
		_ring(p,r*(1.0-t*.6),Color(c,.5),8,.3,PI)
		return
	match hero_id:
		"leonhardt":
			if mode=="shield": _shield(p,r,c)
			else:
				_path([p+Vector2(-r,5),p+Vector2(-r,-6),p+Vector2(-r*.5,-6),p+Vector2(-r*.5,0),p+Vector2(0,0),p+Vector2(0,-8),p+Vector2(r*.5,-8),p+Vector2(r*.5,0),p+Vector2(r,0),p+Vector2(r,5)],c,3)
		"elisia":
			if mode=="shield":
				_ring(p,r,c,10)
				_leaf(p-Vector2(0,r),5,c,-PI*.35)
			elif mode=="guard":
				_leaf(p+Vector2(-6,0),8,c,-.6)
				_leaf(p+Vector2(6,0),8,c,.6)
			else:
				var q := p-Vector2(0,t*9)
				_line(q+Vector2(0,7),q-Vector2(0,5),c)
				_leaf(q-Vector2(4,4),6,c,.5)
				_leaf(q+Vector2(4,-5),6,c,-.5)
		"orwin":
			_box(p,r,c,mode=="shield")
			if mode=="heal": _line(p+Vector2(0,5),p-Vector2(0,t*16),c)
		"astel":
			if mode=="shield": _ring(p,r,c,12,-PI,PI)
			else: _note(p-Vector2(0,t*12),10*power,c)
		"bron":
			_path([p+Vector2(-r,r*.6),p+Vector2(-r*.9,-r*.6),p+Vector2(-r*.2,-r),p+Vector2(r*.7,-r*.7),p+Vector2(r,r*.6)],c,3,mode=="shield")
		"isolde":
			var q := p-Vector2(0,t*8)
			_path([q+Vector2(-r*.6,-r*.4),q+Vector2(-r*.4,r*.2),q+Vector2(r*.4,r*.2),q+Vector2(r*.6,-r*.4)],c)
			_line(q+Vector2(0,r*.2),q+Vector2(0,r*.7),c)
			for i in range(4): _ring(q+Vector2.from_angle(TAU*i/4)*r*.32,3,c,6)
			if mode=="shield": _ring(p,r,Color(c,.5),12)
		"garm":
			_path([p+Vector2(-r*.5,-r),p+Vector2(-r,-r*.5),p+Vector2(-r,r*.5),p+Vector2(-r*.5,r)],c,3)
			_path([p+Vector2(r*.5,-r),p+Vector2(r,-r*.5),p+Vector2(r,r*.5),p+Vector2(r*.5,r)],c,3)
			if mode=="shield": _line(p+Vector2(-r*.5,r),p+Vector2(r*.5,r),c)
		"selene":
			if mode=="heal":
				_box(p-Vector2(0,t*8),r*.5,Color("#D8B36B"))
				for i in range(3): _line(p+Vector2(-6+i*6,-3-t*8),p+Vector2(-2+i*6,3-t*8),c)
			else:
				_diamond(p,r,c)
				_line(p+Vector2(-r*.5,-r*.5),p+Vector2(r*.5,r*.5),c)
				_line(p+Vector2(r*.5,-r*.5),p+Vector2(-r*.5,r*.5),c)
				_diamond(p,3,c)
		"adrien": _path([p+Vector2(-r,-4),p+Vector2(0,r*.7),p+Vector2(r,-4)],c)
		"tessa": _box(p,r,c)
		"ulric": _ring(p,r,c,8,-2.3,PI*1.2)
		"caelum": _ring(p,r,c,12,0,PI*1.8)
		"bora":
			_ring(p,r,c,12,0,TAU if mode=="heal" else PI)
			if mode=="heal": _star(p-Vector2(0,t*10),4,Color("#DD918D"))
		_:
			if mode=="heal": _diamond(p-Vector2(0,t*10),4,c)
			elif mode=="shield": _shield(p,r,c)
			else: _ring(p,r,c,8,-PI,PI)
