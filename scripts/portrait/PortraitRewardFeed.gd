extends Control
## Encounter rewards are grouped in a lower screen strip; collection stays in
## the existing reward button. The equipment line follows actual drop delivery.
const SKIN := preload('res://scripts/portrait/PortraitSkin.gd')
const ICON := preload('res://scripts/portrait/PortraitIcon.gd')
var gold_line: Panel
var gold_text: Label
var item_line: Panel
var item_text: Label
var gold_total := 0
var xp_total := 0
var gold_until := 0.0
var item_until := 0.0
var item_queue: Array[Dictionary] = []

func build(width: float) -> void:
	name='PortraitRewardFeed'
	size=Vector2(minf(370.0,width-28.0),94)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	gold_line=_line(0,'coin',SKIN.GOLD)
	gold_text=_text(gold_line,Color('#fff4cb'))
	item_line=_line(50,'bag',SKIN.BLUE_SOFT)
	item_text=_text(item_line,SKIN.INK)
	gold_line.hide();item_line.hide()
	set_process(true)

func _line(y: float, icon_kind: String, accent: Color) -> Panel:
	var panel:=SKIN.panel(self,Rect2(0,y,size.x,44),Color('#112c36eb'),Color(accent,.66),1,12)
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var icon:=ICON.new();icon.kind=icon_kind
	SKIN.place(panel,icon,Rect2(8,6,32,32))
	return panel

func _text(parent: Panel, tint: Color) -> Label:
	var label:=SKIN.label('',16,tint)
	label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	SKIN.place(parent,label,Rect2(46,2,size.x-54,40))
	return label

func add_reward(gold: int, xp: int, drops: Array[Dictionary], chest: bool) -> void:
	var now:=Time.get_ticks_msec()/1000.0
	if now>=gold_until:gold_total=0;xp_total=0
	gold_total+=gold;xp_total+=xp
	gold_until=now+3.3
	gold_text.text='획득 +%s G   경험치 +%s'%[_number(gold_total),_number(xp_total)]
	_reveal(gold_line)
	for entry in drops:
		var item: Dictionary=entry.get('item',{})
		item_queue.append({'text':str(item.get('name','장비'))+' · '+str(item.get('rarity','장비')),'rarity':str(item.get('rarity','')),'handling':str(entry.get('handling',''))})
	if chest:item_queue.append({'text':'사냥 스테이지 보상 상자 획득','rarity':'상자','handling':'수령 대기'})
	if now>=item_until and not item_queue.is_empty():_next_item(now)

func show_claim(gold: int, xp: int) -> void:
	if gold<=0 and xp<=0:return
	gold_total=gold;xp_total=xp
	gold_until=Time.get_ticks_msec()/1000.0+3.0
	gold_text.text='오프라인 수령  +%s G   +%s XP'%[_number(gold),_number(xp)]
	_reveal(gold_line)

func _next_item(now: float) -> void:
	var entry: Dictionary=item_queue.pop_front()
	var rarity: String=entry.get('rarity','')
	item_text.text=str(entry.get('text',''))
	item_text.tooltip_text=str(entry.get('handling',''))
	item_text.add_theme_color_override('font_color',Color('#ffd779') if rarity=='전설' else (Color('#b3dfff') if rarity=='희귀' else SKIN.INK))
	item_until=now+2.5
	_reveal(item_line)

func _reveal(panel: Panel) -> void:
	panel.show();panel.modulate.a=0.0;panel.position.x=14.0
	var motion:=create_tween().set_parallel(true)
	motion.tween_property(panel,'position:x',0.0,.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(panel,'modulate:a',1.0,.18)

func _number(value: int) -> String:
	var digits:=str(value)
	var result: String=''
	for i in digits.length():
		if i>0 and (digits.length()-i)%3==0:result+=','
		result+=digits[i]
	return result

func _process(_delta: float) -> void:
	var now:=Time.get_ticks_msec()/1000.0
	if now>=gold_until and gold_line.visible:gold_line.hide()
	if now>=item_until and item_line.visible:item_line.hide()
	if now>=item_until and not item_queue.is_empty():_next_item(now)
