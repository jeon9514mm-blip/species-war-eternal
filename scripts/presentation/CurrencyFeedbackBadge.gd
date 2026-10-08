extends Control
## A presentation-only wallet readout. Two persistent widgets; no per-frame nodes.
const FONT=preload('res://assets/fonts/combat/outfit/Outfit-ExtraBold.ttf')
const ICON=preload('res://scripts/ui/GameUiIcon.gd')
var game: Node
var currency: String='gold'
var caption: Label
var icon: Control
var target_amount:=0
var shown_amount:=0.0
var count_start:=0.0
var count_age:=1.0
var pulse_age:=1.0
var shimmer_age:=0.0
var initialized:=false
var positive_changes:=0
var _last_text: String=''

func bind(host: Node,kind: String,box: Rect2,points: int=16) -> void:
	game=host;currency=kind;name='WalletGoldBadge' if kind=='gold' else 'WalletGemBadge'
	position=box.position;size=box.size;mouse_filter=Control.MOUSE_FILTER_IGNORE;clip_contents=true
	icon=ICON.new();icon.name='CurrencyIcon';icon.icon_name=kind;icon.ink=Color('#E8C99A') if kind=='gold' else Color('#A8DCD5')
	icon.position=Vector2(0,(size.y-22)*.5);icon.size=Vector2(22,22);icon.pivot_offset=icon.size*.5;add_child(icon)
	caption=Label.new();caption.name='WalletAmount';caption.position=Vector2(29,0);caption.size=Vector2(maxf(0,size.x-29),size.y)
	caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_override('font',FONT);caption.add_theme_font_size_override('font_size',points)
	caption.add_theme_color_override('font_color',Color('#D8D5CC'));caption.add_theme_color_override('font_outline_color',Color('#00000099'))
	caption.add_theme_constant_override('outline_size',1);caption.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;add_child(caption)
	caption.pivot_offset=Vector2(0,size.y*.5);sync_wallet()

func _amount() -> int:return int(game.wallet_gold) if currency=='gold' else int(game.wallet_gems)
func _feedback_active() -> bool:
	return is_instance_valid(game) and game.combat_effects_enabled and not game._application_suspended and not bool(game.get_meta('background_hunt_tick',false))

func sync_wallet() -> void:
	if not is_instance_valid(game):return
	var amount:=_amount()
	if not initialized:
		target_amount=amount;shown_amount=amount;initialized=true
	elif amount!=target_amount:
		var increased:=amount>target_amount
		target_amount=amount
		if increased and _feedback_active():
			count_start=shown_amount;count_age=0;pulse_age=0;positive_changes+=1
		else:
			shown_amount=amount;count_age=1;pulse_age=1;caption.scale=Vector2.ONE;icon.scale=Vector2.ONE
	_update_text()

func _process(delta: float) -> void:
	if not is_instance_valid(game):return
	sync_wallet()
	if not _feedback_active():
		shown_amount=target_amount;count_age=1;pulse_age=1;caption.scale=Vector2.ONE;icon.scale=Vector2.ONE;_update_text();queue_redraw();return
	# Wallet presentation follows wall time, including any local cinematic slowdown.
	var elapsed:=maxf(0,delta)/maxf(.01,Engine.time_scale)
	var was_pulsing:=pulse_age<1
	count_age=minf(1,count_age+elapsed/.38);pulse_age=minf(1,pulse_age+elapsed/.38);shimmer_age+=elapsed
	shown_amount=lerpf(count_start,float(target_amount),1-pow(1-count_age,3)) if count_age<1 else float(target_amount)
	var pop:=1+.2*sin(pulse_age*PI) if pulse_age<1 else 1.0
	caption.scale=Vector2.ONE*pop;icon.scale=Vector2(1+.025*sin(shimmer_age*2.5),1)*pop
	_update_text()
	# Idle glow is static; redraw only while the short reward pulse changes.
	if was_pulsing or count_age<1:queue_redraw()

func _update_text() -> void:
	var value:=maxi(0,roundi(shown_amount))
	var text: String=game._compact_hud_amount(value) if is_instance_valid(game) and game.has_method('_compact_hud_amount') else str(value)
	if text!=_last_text:caption.text=text;_last_text=text
	tooltip_text=('골드 ' if currency=='gold' else '젬 ')+str(target_amount)

func _draw() -> void:
	if not initialized or not _feedback_active():return
	var tint:=Color('#C4A484') if currency=='gold' else Color('#A8B89E')
	var strength:=sin(pulse_age*PI) if pulse_age<1 else 0.0
	var center:=Vector2(11,size.y*.5)
	for layer in 3:
		draw_circle(center,12+layer*3,Color(tint,.025+strength*.055/float(layer+1)))
	if pulse_age<1:
		for i in 6:
			var phase:=TAU*float(i)/6.0
			var point:=center+Vector2.from_angle(phase)*lerpf(10,29,pulse_age)
			draw_circle(point,1.0,Color(tint,(1-pulse_age)*.7))
