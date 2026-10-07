extends RefCounted
## Compare all three encounters without hiding their entry buttons below long cards.
const S=preload('res://scripts/portrait/PortraitSkin.gd')
const BALANCE=preload('res://scripts/raid/RaidBalance.gd')
const DESIGN=preload('res://scripts/raid/RaidBossDesign.gd')
const SCENERY=preload('res://scripts/art/RaidSceneryCatalog.gd')
const ZONES=['gray_meadow','forgotten_mine','moonrest_forest']
const COUNTERS={
	'gray_meadow':'갑주 파괴 후 약점에 집중 공격',
	'forgotten_mine':'수정핵을 제거하고 보스 공격',
	'moonrest_forest':'표식 분산 · 의식 시간 안에 저지',
}

static func _line(ui: Script, parent: Node, value: String, points: int=16, color: Color=S.INK) -> Label:
	var label: Label=ui.text(parent,value,points,color)
	label.max_lines_visible=1;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text=value
	return label

static func build(main: Node, page: VBoxContainer, ui: Script) -> void:
	var power: int=main._calculate_party_power()
	var summary:=HBoxContainer.new();summary.name='RaidPartySummary';summary.add_theme_constant_override('separation',12);page.add_child(summary)
	var overview:=_line(ui,summary,'출전 %d / %d명  ·  전투력 %s  ·  180초 광폭화 / 240초 제한'%[main.deployed_heroes.size(),main._party_slot_cap(),main._compact_hud_amount(power)],17,S.BLUE_SOFT)
	overview.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var formation: Button=ui.action(summary,'편성하기' if main.deployed_heroes.is_empty() else '편성 수정',Callable(main,'_open_content_party').bind('meta',''),main.deployed_heroes.is_empty())
	formation.name='ContentPartyButton';formation.custom_minimum_size=Vector2(160,48);formation.size_flags_horizontal=Control.SIZE_SHRINK_END
	var columns: GridContainer=ui.grid(page,3);columns.name='RaidCatalogGrid'
	for zone_id: String in ZONES:
		var zone: Dictionary=main._zone_data()[zone_id]
		var stats: Dictionary=BALANCE.stats(zone)
		var design: Dictionary=DESIGN.raid(zone_id)
		var unlocked: bool=main._is_zone_unlocked(zone_id)
		var panel:=PanelContainer.new();panel.name='RaidCatalog_'+zone_id;panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var style:=S.elevated(S.DARK_2,Color(design.accent,.7),12);style.set_content_margin_all(12);panel.add_theme_stylebox_override('panel',style);columns.add_child(panel)
		var box: VBoxContainer=ui.stack(panel,6)
		var scene:=Control.new();scene.name='RaidCatalogScene_'+zone_id;scene.custom_minimum_size=Vector2(0,106);scene.clip_contents=true;box.add_child(scene)
		var scenery:=TextureRect.new();scenery.texture=load(str(SCENERY.profile(zone_id).texture))
		scenery.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;scenery.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;scenery.mouse_filter=Control.MOUSE_FILTER_IGNORE
		scene.add_child(scenery);scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var location:=S.label(str(SCENERY.profile(zone_id).title),15,S.GOLD)
		scene.add_child(location);location.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		location.offset_left=8;location.offset_right=-124;location.offset_top=8;location.offset_bottom=30
		location.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;location.clip_text=true
		var painting:=TextureRect.new();painting.texture=main._boss_texture(str(zone.boss));painting.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;painting.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;painting.mouse_filter=Control.MOUSE_FILTER_IGNORE
		scene.add_child(painting);painting.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE);painting.offset_left=-120;painting.offset_right=-8;painting.offset_bottom=-6
		var shade:=ColorRect.new();shade.color=Color('#0b1525db');shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
		scene.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);shade.offset_top=-35
		var title:=S.label(str(zone.boss),20,S.INK);title.clip_text=true;title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;title.tooltip_text=str(zone.boss)
		scene.add_child(title);title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);title.offset_left=8;title.offset_right=-8;title.offset_top=-34
		var health:=_line(ui,box,'HP %s  ·  공격력 %s'%[main._compact_hud_amount(stats.max_hp),main._compact_hud_amount(stats.attack)],16,S.INK)
		health.name='RaidCatalogStats_'+zone_id;health.set_meta('raid_stats',stats.duplicate());health.tooltip_text='보스 HP %d · 기본 공격력 %d'%[stats.max_hp,stats.attack]
		var readiness: String='권장 충족' if power>=int(stats.recommended_power) else '전투력 부족'
		if main.deployed_heroes.is_empty():readiness='편성 필요'
		var required:=_line(ui,box,'권장 %s  ·  %s'%[main._compact_hud_amount(stats.recommended_power),readiness],16,S.SUCCESS if power>=int(stats.recommended_power) else S.GOLD)
		required.name='RaidCatalogReadiness_'+zone_id;required.tooltip_text='현재 %d / 권장 %d · 권장 전투력 미만이어도 해금된 레이드에 도전할 수 있습니다.'%[power,stats.recommended_power]
		_line(ui,box,'스테이지 %d 해금  ·  토벌 %d회'%[int(zone.unlock_stage),int(main.raid_clears.get(zone_id,0))],14,S.MUTED)
		_line(ui,box,COUNTERS[zone_id],15,S.BLUE_SOFT)
		_line(ui,box,'전용 세트 1개  ·  정수 %d개'%[6+6*int(zone.difficulty)],15,S.GOLD)
		var caption: String='스테이지 %d에서 해금'%int(zone.unlock_stage) if not unlocked else ('원정대가 필요해요' if main.deployed_heroes.is_empty() else '레이드 준비')
		var enter: Button=ui.action(box,caption,Callable(main,'_select_zone_for_raid').bind(zone_id),true)
		enter.name='RaidCatalogEnter_'+zone_id;enter.custom_minimum_size.y=48;enter.disabled=not unlocked or main.deployed_heroes.is_empty()
		enter.tooltip_text=caption if enter.disabled else str(design.description)
