extends "res://scripts/Main.gd"
## Portrait presentation subclass. All v32 AI, heroes, skills, combat math,
## persistence, growth and territorial commands remain inherited unchanged.
const P_PAGES := preload('res://scripts/portrait/PortraitPages.gd')
const NAV = preload("res://scripts/NavigationCatalog.gd")
const P_HUD := preload('res://scripts/portrait/PortraitHud.gd')
const P_MENUS := preload('res://scripts/portrait/PortraitMenus.gd')
const P_TERRAIN := preload('res://scripts/portrait/PortraitScenery.gd')
const P_SKY := preload('res://scripts/portrait/PortraitSky.gd')
const P_SKIN := preload('res://scripts/portrait/PortraitSkin.gd')
const P_PROPS := preload('res://scripts/portrait/PortraitMeadowProps.gd')
const P_GROUND_SHADOW := preload('res://scripts/portrait/PortraitGroundShadow.gd')
const P_HERO_RIG := preload('res://scripts/portrait/PortraitHeroSkeletalRig.gd')
const P_KILL_BURST := preload('res://scripts/portrait/PortraitKillBurst.gd')
const P_DAMAGE := preload('res://scripts/portrait/PortraitDamageNumber.gd')
const P_SKILL_BURST := preload('res://scripts/portrait/PortraitSkillBurst.gd')
var portrait_hud: Control
var _resize_pending := false
var _hunt_details_layer: CanvasLayer
var _hunt_details_shade: ColorRect
var _number_lane := 0
var _offline_settling := false

func _save_idle_state() -> void:
	if bool(get_meta("practice_active", false)): return
	# Online hunting, raids and older pending balances reach the wallet on the
	# same committed save. Only recorded offline proceeds stay claimable.
	if not _offline_settling and not _save_blocked_for_newer_version:
		_deposit_nonoffline_rewards()
	super._save_idle_state()

func _calculate_offline_reward() -> void:
	_offline_settling=true
	super._calculate_offline_reward()
	_offline_settling=false
	# The estimate may have saved during a gear swap. Persist its protected
	# offline balance and any older nonoffline proceeds together at the end.
	if not _save_blocked_for_newer_version and (unclaimed_gold>offline_pending_gold or unclaimed_xp>offline_pending_xp or idle_chest_gold>offline_pending_chest_gold or idle_chest_xp>offline_pending_chest_xp):
		_save_idle_state()

func _deposit_nonoffline_rewards() -> void:
	var gold:=maxi(0,unclaimed_gold-offline_pending_gold)
	var xp:=maxi(0,unclaimed_xp-offline_pending_xp)
	var chest_gold:=maxi(0,idle_chest_gold-offline_pending_chest_gold)
	var chest_xp:=maxi(0,idle_chest_xp-offline_pending_chest_xp)
	wallet_gold+=gold+chest_gold
	wallet_xp+=xp+chest_xp
	unclaimed_gold-=gold;unclaimed_xp-=xp
	idle_chest_gold-=chest_gold;idle_chest_xp-=chest_xp

func _on_offline_hunt_reward(gold: int, xp: int, chest_gold: int, chest_xp: int) -> void:
	offline_pending_gold+=gold;offline_pending_xp+=xp
	offline_pending_chest_gold+=chest_gold;offline_pending_chest_xp+=chest_xp

func _claim_offline_rewards() -> void:
	var gold:=mini(unclaimed_gold,offline_pending_gold)
	var xp:=mini(unclaimed_xp,offline_pending_xp)
	var chest_gold:=mini(idle_chest_gold,offline_pending_chest_gold)
	var chest_xp:=mini(idle_chest_xp,offline_pending_chest_xp)
	if gold+xp+chest_gold+chest_xp<=0:return
	wallet_gold+=gold+chest_gold;wallet_xp+=xp+chest_xp
	unclaimed_gold-=gold;unclaimed_xp-=xp
	idle_chest_gold-=chest_gold;idle_chest_xp-=chest_xp
	offline_pending_gold=0;offline_pending_xp=0
	offline_pending_chest_gold=0;offline_pending_chest_xp=0
	offline_reward_gold=0;offline_reward_xp=0;offline_reward_seconds=0
	offline_pet_xp=0;offline_rations=0;offline_gear_rolls=0
	offline_stage_clears=0;offline_efficiency=0
	_update_reward_labels();_save_idle_state()
	if active_screen=='combat' and is_instance_valid(portrait_hud):
		portrait_hud.show_claim(gold+chest_gold,xp+chest_xp)
		portrait_hud.refresh()

func _toggle_skill_auto() -> void:
	skill_auto=not skill_auto
	_save_idle_state()

func _toggle_ultimate_auto() -> void:
	ultimate_auto=not ultimate_auto
	_save_idle_state()
func _layout_width() -> float:
	return maxf(720.0,get_viewport_rect().size.x)
func _layout_height() -> float:
	return maxf(720.0 if get_viewport_rect().size.x > get_viewport_rect().size.y else 1280.0,get_viewport_rect().size.y)
func _clear_screen() -> void:
	super._clear_screen()
	hero_slot_labels.clear();hero_select_buttons.clear()
	party_composition_label=null;hero_hint=null
	_finalize_portrait_view.call_deferred(content_root.get_instance_id())
func _finalize_portrait_view(instance_id: int) -> void:
	if not is_instance_valid(content_root) or content_root.get_instance_id()!=instance_id:return
	if content_root.has_meta('portrait_ready'):return
	if active_screen=='combat':return
	P_MENUS.adapt(self,'모험 상세')

func _ready() -> void:
	super._ready()
	get_viewport().size_changed.connect(_portrait_resize)
func _configure_mobile_display() -> void:
	preload('res://scripts/DisplayOrientation.gd').apply(self)
	if OS.has_feature('mobile'):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
func _build_background() -> void:
	# Unified fantasy-mobile backdrop used behind every portrait menu.
	var tex:=TextureRect.new();tex.name='PortraitMenuBackground'
	tex.texture=preload('res://assets/terrain-v70/evergreen-overview.png')
	tex.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.mouse_filter=Control.MOUSE_FILTER_IGNORE
	content_root.add_child(tex)
	var shade:=ColorRect.new();shade.name='PortraitMenuShade';shade.color=Color('#102d33ab')
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	content_root.add_child(shade)
func _combat_layout_for_width(_layout_w: float, _safe: Vector4) -> Dictionary:
	var viewport_size: Vector2=get_viewport_rect().size
	var w:=viewport_size.x;var h:=viewport_size.y
	if w > h:
		return {'left':0.0,'usable':w,'field':Rect2(12,136,w-360,h-276),'side':Rect2(w-354,132,330,h-246)}
	return {'left':0.0,'usable':w,'field':Rect2(0,200,w,h-285),'side':Rect2(18,290,w-36,h-615)}
func _combat_map_scale() -> Vector2:
	# v69: show the complete 32x20 hunt lawn instead of a zoomed tile-sized crop.
	if get_viewport_rect().size.x > get_viewport_rect().size.y:
		return Vector2.ONE * minf(combat_field_rect.size.x/32.0, combat_field_rect.size.y/20.0)
	return Vector2.ONE*22.0
func _combat_actor_scale() -> float:
	# Slightly smaller actors match the wide-stage reference while remaining readable.
	return .064
func _combat_camera_anchor() -> Vector2:
	# World y=0 meets the illustrated horizon around 250 px. At 22 px/unit
	# the entire navigable 32x20 stage remains visible at once.
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x > viewport_size.y: return combat_field_rect.get_center()
	return Vector2(viewport_size.x * 0.5, combat_field_rect.position.y + 270.0)

func _clamp_combat_camera(_point: Vector2) -> Vector2:
	# Video-style fixed stage: actors roam; the stage itself does not drift.
	return RoamingHuntDirector.FIELD_CENTER

func _update_combat_camera(_delta: float) -> void:
	combat_camera_position = RoamingHuntDirector.FIELD_CENTER
	var terrain = combat_labels.get("terrain")
	if is_instance_valid(terrain):
		if terrain.has_method("configure_world_view"):
			terrain.configure_world_view(_combat_map_scale().x, _combat_camera_anchor() - combat_field_rect.position)
		if terrain.has_method("set_camera_position"):
			terrain.set_camera_position(combat_camera_position)

func _build_combat_screen() -> void:
	super._build_combat_screen()
	_install_portrait_hud()
func _create_map_hero_sprites() -> void:
	super._create_map_hero_sprites()
	for index in hero_map_sprites.size():
		var sprite: HeroSpriteController=hero_map_sprites[index]
		_attach_hunt_shadow(sprite,18.0)
		var rig:=P_HERO_RIG.new()
		if not rig.install(sprite):rig.queue_free()
func _attach_hunt_shadow(sprite: Node2D, radius: float) -> void:
	if not is_instance_valid(sprite) or sprite.get_node_or_null('PortraitGroundShadow')!=null:return
	var shadow:=P_GROUND_SHADOW.new()
	shadow.name='PortraitGroundShadow';shadow.radius=radius
	shadow.z_index=-1
	shadow.scale=Vector2(1.0/maxf(.001,absf(sprite.scale.x)),1.0/maxf(.001,absf(sprite.scale.y)))
	sprite.add_child(shadow)
func _spawn_enemy_wave_sprites(start_index: int = 0) -> void:
	super._spawn_enemy_wave_sprites(start_index)
	for index in range(start_index, enemy_wave_sprites.size()):
		var sprite: MonsterSpriteController=enemy_wave_sprites[index]
		MonsterSpriteFactory.apply_casual(sprite,str(enemy_wave[index]['name']),sprite.presentation_scale)
		_attach_hunt_shadow(sprite,17.0)
func _damage_enemy(enemy_index: int, damage: int, source_index := 0) -> int:
	var actual: int=super._damage_enemy(enemy_index,damage,source_index)
	if actual>0 and active_screen=='combat' and enemy_index>=0 and enemy_index<enemy_wave.size() and int(enemy_wave[enemy_index].get('hp',1))<=0 and enemy_index<enemy_wave_sprites.size() and is_instance_valid(skill_fx_layer) and combat_fx._fx_budget_available() and combat_effects_enabled:
		var sprite: MonsterSpriteController=enemy_wave_sprites[enemy_index]
		if is_instance_valid(sprite):
			var burst:=P_KILL_BURST.new()
			burst.position=sprite.position-Vector2(0,14)
			skill_fx_layer.add_child(burst)
	return actual

func _emit_skill_cast_fx(hero_id: String, target_index: int, aoe: bool, profile: Dictionary, ultimate := false) -> void:
	super._emit_skill_cast_fx(hero_id,target_index,aoe,profile,ultimate)
	if not combat_effects_enabled or active_screen!='combat' or not combat_fx._fx_budget_available() or not is_instance_valid(skill_fx_layer):return
	var accent: Color=_skill_visual_profile(_hero_role_group(hero_id)).get('color',P_SKIN.GOLD)
	var flare:=P_SKILL_BURST.new()
	flare.configure(_hero_role_group(hero_id),accent,ultimate,skill_fx_sequence)
	var clip: Control=skill_fx_layer.get_node_or_null('HeroSkillClip')
	if is_instance_valid(clip):
		flare.position=_hero_skill_fx_position(hero_id)-clip.position
		clip.add_child(flare)
	else:
		flare.position=_hero_skill_fx_position(hero_id)
		skill_fx_layer.add_child(flare)

func _spawn_floating_combat_text(message: String, color: Color, origin: Vector2) -> void:
	if active_screen!='combat':
		super._spawn_floating_combat_text(message,color,origin)
		return
	if not combat_effects_enabled or not is_instance_valid(content_root):return
	if message=='무리 격파':return
	var amount:=message.replace(' HP','').strip_edges()
	var is_number:=amount.begins_with('-') or amount.begins_with('+')
	if not is_number:
		super._spawn_floating_combat_text(message,color,origin)
		return
	var number:=absi(int(amount))
	var is_heal:=amount.begins_with('+')
	var near_hero:=false
	for sprite in hero_map_sprites:
		if is_instance_valid(sprite) and sprite.position.distance_to(origin+Vector2(90,75))<60.0:
			near_hero=true;break
	var tint:=P_SKIN.SUCCESS if is_heal else (Color('#ff777a') if near_hero else Color('#ffe19a'))
	var displayed:=('+' if is_heal else '−')+str(number)
	var field_top:=combat_field_rect.position.y+145.0
	var field_bottom:=get_viewport_rect().size.y-(390.0 if maxi(_party_slot_cap(),deployed_heroes.size())>5 else 300.0)
	var center:=Vector2(clampf(origin.x+90.0,84.0,get_viewport_rect().size.x-84.0),clampf(origin.y+45.0,field_top,maxf(field_top+42,field_bottom)))
	var floats:=get_tree().get_nodes_in_group('floating_combat_text')
	while floats.size()>=int(_presentation_profile()['float_limit']):
		var oldest: Node=floats.pop_front();oldest.remove_from_group('floating_combat_text');oldest.queue_free()
	_number_lane+=1
	var label:=P_DAMAGE.new();content_root.add_child(label)
	label.show_value(displayed,tint,center,number>=300,_number_lane)

func _on_hunt_reward(gold: int, xp: int, drops: Array[Dictionary], stage_cleared: bool, chest_gold := 0, chest_xp := 0) -> void:
	# Hero XP was granted by the hunt. Move its account XP and gold directly to
	# the wallet before Main writes the encounter save.
	var paid_gold:=mini(maxi(0,unclaimed_gold-offline_pending_gold),gold)
	var paid_xp:=mini(maxi(0,unclaimed_xp-offline_pending_xp),xp)
	var paid_chest_gold:=mini(maxi(0,idle_chest_gold-offline_pending_chest_gold),chest_gold)
	var paid_chest_xp:=mini(maxi(0,idle_chest_xp-offline_pending_chest_xp),chest_xp)
	unclaimed_gold-=paid_gold;unclaimed_xp-=paid_xp
	idle_chest_gold-=paid_chest_gold;idle_chest_xp-=paid_chest_xp
	wallet_gold+=paid_gold+paid_chest_gold;wallet_xp+=paid_xp+paid_chest_xp
	if active_screen=='combat' and is_instance_valid(portrait_hud):portrait_hud.show_hunt_reward(gold,xp,drops,stage_cleared)

func _claim_rewards() -> void:
	_deposit_nonoffline_rewards()
	_update_reward_labels();_save_idle_state()
func _monster_texture(monster_name: String) -> Texture2D:
	return MonsterSpriteFactory.get_casual_portrait_texture(monster_name)
func _boss_texture(boss_name: String) -> Texture2D:
	return MonsterSpriteFactory.get_casual_portrait_texture(boss_name)
func _update_monster_portrait(monster_name: String) -> void:
	if not is_instance_valid(monster_sprite):return
	monster_sprite.visible=MonsterSpriteFactory.apply_casual(monster_sprite,monster_name,monster_sprite.presentation_scale)
	if monster_sprite.visible:monster_sprite.play_idle('down')
func _update_boss_portrait(boss_name: String) -> void:
	if not is_instance_valid(raid_boss_sprite):return
	raid_boss_sprite.visible=MonsterSpriteFactory.apply_casual(raid_boss_sprite,boss_name,raid_boss_sprite.presentation_scale)
	if raid_boss_sprite.visible:raid_boss_sprite.play_idle('down')
func _spawn_open_map_boss() -> void:
	# Boss encounters live in the content menu, away from the hunting field.
	pass
func _install_portrait_hud() -> void:
	if not is_instance_valid(content_root):return
	content_root.set_meta('portrait_ready',true)
	# All legacy text values remain alive for the original v32 HUD updater.
	for child: Node in content_root.get_children():
		if child is CanvasItem and child!=skill_fx_layer:
			if child.name not in ['RoamingTerrain','FieldActorClip','CombatTargetMarker','CombatDangerBanner','OfflineRewardPopup','OfflineRewardOverlay']:
				child.visible=false
	var original: Control=combat_labels.get('terrain')
	var terrain:=P_TERRAIN.new();terrain.name='RoamingTerrainPortrait'
	terrain.position=combat_field_rect.position;terrain.size=combat_field_rect.size
	terrain.configure(current_zone_id,_current_zone()['color'])
	content_root.add_child(terrain);content_root.move_child(terrain,0)
	combat_labels['terrain']=terrain
	if is_instance_valid(original):original.hide()
	var sky:=P_SKY.new();sky.name='PortraitSky'
	sky.zone_id=current_zone_id
	sky.position=Vector2.ZERO;sky.size=Vector2(get_viewport_rect().size.x,270)
	content_root.add_child(sky);sky.z_index=-8
	# v70: no legacy raised terrain props are layered over the finished map art.
	# Runtime heroes, monsters, HP bars and effects remain separate animated nodes.
	var details: Control=combat_labels.get('details_panel')
	if is_instance_valid(details):
		details.position=combat_side_rect.position;details.size=combat_side_rect.size
		details.z_index=115
		P_MENUS.retint(details)
		for key in ['raid_button','boss_raid_button','boss_alert']:
			var old_entry: Node=combat_labels.get(key)
			if is_instance_valid(old_entry):old_entry.hide()
		_install_hunt_details_modal(details)
	var danger: Label=combat_labels.get('danger_banner')
	if is_instance_valid(danger):
		danger.position=Vector2(22,maxf(38,_safe_margins().y+10)+250);danger.size=Vector2(get_viewport_rect().size.x-44,42)
		danger.z_index=105;danger.add_theme_font_size_override('font_size',19)
		danger.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		P_MENUS.retint(danger)
	portrait_hud=_new_hunt_hud()
	content_root.add_child(portrait_hud)
	portrait_hud.build(self)
	_update_combat_camera(0.0)
func _install_hunt_details_modal(details: Control) -> void:
	# A higher z_index only changes paint order. A CanvasLayer also gives the
	# visible information panel input priority over the later HUD buttons.
	_hunt_details_layer=CanvasLayer.new()
	_hunt_details_layer.name='PortraitHuntDetailsLayer'
	_hunt_details_layer.layer=3
	content_root.add_child(_hunt_details_layer)
	_hunt_details_shade=ColorRect.new()
	_hunt_details_shade.name='PortraitHuntDetailsShade'
	_hunt_details_shade.color=Color(0,0,0,.44)
	_hunt_details_shade.mouse_filter=Control.MOUSE_FILTER_STOP
	_hunt_details_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hunt_details_layer.add_child(_hunt_details_shade)
	details.reparent(_hunt_details_layer)
	_hunt_details_layer.visible=details.visible

func _toggle_hunt_details() -> void:
	super._toggle_hunt_details()
	var details: Control=combat_labels.get('details_panel')
	if is_instance_valid(_hunt_details_layer) and is_instance_valid(details):
		_hunt_details_layer.visible=details.visible
	if is_instance_valid(portrait_hud):portrait_hud.refresh()

func _portrait_resize() -> void:
	if not is_inside_tree() or _resize_pending:return
	_resize_pending=true
	_apply_portrait_resize.call_deferred()
func _apply_portrait_resize() -> void:
	_resize_pending=false
	if str(presentation_options.get("orientation", "portrait")) == "auto":
		preload("res://scripts/DisplayOrientation.gd").apply(self, false)
	if active_screen=='combat':
		# No screen reconstruction: do not reset the encounter, RNG, HP or movement.
		var layout:=_combat_layout_for_width(0,_safe_margins())
		combat_field_rect=layout['field'];combat_side_rect=layout['side']
		var clip: Control=combat_labels.get('actor_clip')
		if is_instance_valid(clip):clip.position=combat_field_rect.position;clip.size=combat_field_rect.size
		var actors: Node2D=combat_labels.get('actor_layer')
		if is_instance_valid(actors):actors.position=-combat_field_rect.position
		var terrain: Control=combat_labels.get('terrain')
		if is_instance_valid(terrain):terrain.position=combat_field_rect.position;terrain.size=combat_field_rect.size
		var sky: Control=content_root.get_node_or_null('PortraitSky')
		if is_instance_valid(sky):sky.size.x=get_viewport_rect().size.x
		var details: Control=combat_labels.get('details_panel')
		if is_instance_valid(details):details.position=combat_side_rect.position;details.size=combat_side_rect.size
		var danger: Label=combat_labels.get('danger_banner')
		if is_instance_valid(danger):
			danger.position=Vector2(22,maxf(38,_safe_margins().y+10)+250)
			danger.size=Vector2(get_viewport_rect().size.x-44,42)
		if is_instance_valid(portrait_hud):portrait_hud.free()
		portrait_hud=_new_hunt_hud();content_root.add_child(portrait_hud);portrait_hud.build(self)
		_update_combat_camera(0.0)
	elif active_screen=='title':_build_title_screen()
	elif active_screen=='faction':_build_faction_screen()
	elif active_screen=='hero_select':_build_hero_select_screen()
	elif active_screen=='raid':
		# Rebuild presentation only. The new view reparents the live boss and FX
		# before freeing the old view, preserving encounter timers and HP.
		var old_view:=content_root.get_node_or_null('PortraitRaidView')
		for node_name in ['PortraitMenuHeader','PortraitNavigation']:
			var old_node:=content_root.get_node_or_null(node_name)
			if old_node!=null:old_node.free()
		if old_view!=null:old_view.name='PreviousRaidView'
		var view:=preload('res://scripts/portrait/PortraitRaid.gd').new()
		content_root.add_child(view);view.install(self)
		if old_view!=null:old_view.free()
	elif is_instance_valid(content_root) and content_root.has_meta('portrait_ready') and content_root.get_node_or_null('PortraitNavigation')!=null:
		var nav: Control=content_root.get_node_or_null('PortraitNavigation')
		if nav!=null: nav.free()
		P_HUD.navigation(self,content_root,str(content_root.get_meta('portrait_tab','')),get_viewport_rect().size.y-90,90)
func _build_title_screen() -> void:
	P_MENUS.landing(self)
func _build_login_screen() -> void:
	P_PAGES.onboarding(self,'login')
func _build_lobby_screen() -> void:
	P_PAGES.lobby(self)
func _build_faction_screen() -> void:
	P_MENUS.faction(self)
func _build_intro_screen() -> void:
	P_PAGES.onboarding(self,'intro')
func _build_hero_select_screen() -> void:
	P_MENUS.roster(self)
func _build_hero_detail_screen(hero_id: String) -> void:
	if not _hero_belongs_to_selected_faction(hero_id):
		_show_toast('선택한 진영의 영웅만 확인할 수 있습니다.');_build_hero_select_screen();return
	P_PAGES.detail(self,hero_id)
func _build_party_ready_screen(names: Array[String]) -> void:
	P_PAGES.onboarding(self,'party_ready',names)
func _build_growth_screen() -> void:
	P_PAGES.growth(self)
func _build_inventory_screen() -> void:
	P_PAGES.inventory(self)
func _build_meta_hub_screen() -> void:
	P_PAGES.meta(self)
func _build_summon_screen() -> void:
	P_PAGES.summon(self)
func _build_bm_screen() -> void:
	P_PAGES.rewards(self)
func _build_codex_screen() -> void:
	P_PAGES.codex(self)
func _build_world_map_screen() -> void:
	P_PAGES.world(self)
func _build_boss_select_screen() -> void:
	set_meta('content_meta_tab','raids')
	P_PAGES.meta(self)
func _raid_play_hero_action(hero_id: String) -> void:
	var view:=content_root.get_node_or_null('PortraitRaidView')
	if is_instance_valid(view):view.play_hero_attack(hero_id)
func _show_raid_victory(headline: String, details: String) -> void:
	var view:=content_root.get_node_or_null('PortraitRaidView')
	if is_instance_valid(view):view.show_victory()
	var serial: int=raid_encounter_serial
	get_tree().create_timer(1.7).timeout.connect(func() -> void:
		if is_instance_valid(content_root) and active_screen=='raid' and raid_encounter_serial==serial and raid_outcome=='victory':
			_show_battle_result_popup('RAID CLEAR',headline,details,GREEN)
	)
func _emit_boss_telegraph(skill_name: String, seconds: float) -> void:
	if active_screen!='raid':
		super._emit_boss_telegraph(skill_name,seconds)
		return
	_presentation_event('boss_warning')
	var view:=content_root.get_node_or_null('PortraitRaidView')
	if is_instance_valid(view):view.refresh()
func _build_raid_screen() -> void:
	super._build_raid_screen()
	var panel:=preload('res://scripts/portrait/PortraitRaid.gd').new()
	content_root.add_child(panel);panel.install(self)
func _build_faction_war_screen() -> void:
	super._build_faction_war_screen();P_MENUS.war(self)
func _show_main_menu() -> void:
	# Keep one input-blocking menu even when the open action is repeated.
	var existing:=content_root.get_node_or_null('PortraitActionSheet')
	if existing!=null:
		content_root.remove_child(existing)
		existing.queue_free()
	var root:=Control.new();root.name='PortraitActionSheet';root.z_index=125
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_root.add_child(root)
	var shade:=ColorRect.new();shade.color=Color(0,0,0,.58);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var panel:=PanelContainer.new()
	panel.name='PortraitMenuSheet'
	var style:=P_SKIN.elevated(P_SKIN.DARK_2,P_SKIN.GOLD,20)
	style.content_margin_left=22;style.content_margin_right=22
	style.content_margin_top=20;style.content_margin_bottom=20
	panel.add_theme_stylebox_override('panel',style)
	root.add_child(panel)
	panel.anchor_right=1;panel.anchor_top=.5;panel.anchor_bottom=.5
	panel.offset_left=28;panel.offset_right=-28
	panel.offset_top=-290;panel.offset_bottom=290
	var menu_scroll:=ScrollContainer.new();menu_scroll.name='PortraitMenuScroll'
	menu_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(menu_scroll)
	var box:=P_PAGES.stack(menu_scroll,12)
	var heading:=HBoxContainer.new();box.add_child(heading)
	var heading_label:=P_PAGES.text(heading,'모험 메뉴',30,P_SKIN.GOLD)
	heading_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var close:=P_SKIN.button('닫기',root.queue_free)
	close.custom_minimum_size=Vector2(92,52);heading.add_child(close)
	var entries: Array = NAV.menu_entries()
	var menu_grid:=P_PAGES.grid(box,2)
	for entry in entries:
		if str(entry["id"]) in ["training", "title", "formation"]: continue
		var menu_button:=P_PAGES.action(menu_grid,str(entry['label']),Callable(self,str(entry['method'])))
		menu_button.name='PortraitMenu_'+str(entry['id'])
	P_PAGES.text(box,'화면과 소리',20,P_SKIN.GOLD)
	var switches:=P_PAGES.grid(box,2)
	var effects:=CheckButton.new();effects.name='PortraitEffectSetting'
	effects.text='전투 연출';effects.button_pressed=combat_effects_enabled
	effects.custom_minimum_size=Vector2(0,52);effects.add_theme_font_size_override('font_size',18)
	effects.toggled.connect(func(enabled: bool):
		combat_effects_enabled=enabled
		combat_fx.enabled=enabled
		_save_ui_preferences())
	switches.add_child(effects)
	var sounds:=CheckButton.new();sounds.name='PortraitSoundSetting'
	sounds.text='효과음';sounds.button_pressed=sound_effects_enabled
	sounds.custom_minimum_size=Vector2(0,52);sounds.add_theme_font_size_override('font_size',18)
	sounds.toggled.connect(func(enabled: bool):
		sound_effects_enabled=enabled
		if not enabled and is_instance_valid(skill_audio_bus):skill_audio_bus.stop()
		_save_ui_preferences())
	switches.add_child(sounds)
	P_PAGES.action(box,'화면 · 소리 · 진동 · 성능 설정',Callable(self,'_open_presentation_settings')).name='PresentationSettingsEntry'
	P_PAGES.action(box,'원정 가이드',Callable(self,'_show_portrait_guide')).name='PortraitOpenGuide'
	if not tutorial_completed:P_PAGES.text(box,_tutorial_text(),16,P_SKIN.MUTED)
	# Keep existing settings/guide in their original visible position. Routes
	# carried over from the compatibility menu remain available below them.
	var extra_grid:=P_PAGES.grid(box,2)
	for entry: Dictionary in entries:
		if str(entry["id"]) not in ["training", "title", "formation"]: continue
		var extra:=P_PAGES.action(extra_grid,str(entry["label"]),Callable(self,str(entry["method"])))
		extra.name="PortraitMenu_"+str(entry["id"])


func _show_portrait_guide() -> void:
	var sheet:=content_root.get_node_or_null('PortraitActionSheet')
	if sheet!=null:
		content_root.remove_child(sheet)
		sheet.queue_free()
	UI_CHROME.guide(self)
	var guide_panel:=content_root.get_node_or_null('MenuOverlay')
	if guide_panel!=null:P_MENUS.retint(guide_panel)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed('ui_cancel') and is_instance_valid(content_root):
		var sheet:=content_root.get_node_or_null('PortraitActionSheet')
		if is_instance_valid(sheet):
			sheet.queue_free()
			get_viewport().set_input_as_handled()
			return
		var details: Control=combat_labels.get('details_panel')
		if active_screen=='combat' and is_instance_valid(details) and details.visible:
			_toggle_hunt_details()
			get_viewport().set_input_as_handled()
			return
	super._unhandled_key_input(event)

func _show_offline_reward_popup() -> void:
	super._show_offline_reward_popup()
	_tint_portrait_dialog('OfflineRewardPopup')
func _show_summon_reveal(result: Dictionary) -> void:
	super._show_summon_reveal(result)
	_tint_portrait_dialog('SummonRevealPanel')
func _show_guardian_reveal(result: Dictionary) -> void:
	super._show_guardian_reveal(result)
	_tint_portrait_dialog('GuardianRevealPanel')
func _show_battle_result_popup(title_text: String, headline: String, detail: String, accent: Color) -> void:
	super._show_battle_result_popup(title_text,headline,detail,accent)
	_tint_portrait_dialog('BattleResultPopup')
	if active_screen=='combat':
		var panel:=content_root.get_node_or_null('BattleResultPopup')
		if panel!=null:panel.position=Vector2(22,450)
func _tint_portrait_dialog(node_name: String) -> void:
	var dialog:=content_root.get_node_or_null(node_name)
	if dialog!=null:P_MENUS.retint(dialog)
func _display_toast(message: String) -> void:
	super._display_toast(message)
	var toast: Label=content_root.get_node_or_null('ToastNotice')
	if toast!=null:
		toast.add_theme_color_override('font_color',P_SKIN.INK)
		var style:=P_SKIN.box(P_SKIN.DARK_2,P_SKIN.GOLD,12,1)
		style.content_margin_left=16;style.content_margin_right=16
		style.content_margin_top=12;style.content_margin_bottom=12
		toast.add_theme_stylebox_override('normal',style)
		toast.position=Vector2(22,get_viewport_rect().size.y-230)
		toast.size=Vector2(get_viewport_rect().size.x-44,70)

func _emit_ultimate_cutin(hero_id: String, detail: String) -> void:
	if active_screen!='raid':
		super._emit_ultimate_cutin(hero_id,detail)
		return
	if not combat_effects_enabled or not is_instance_valid(content_root):return
	var old:=content_root.get_node_or_null('PortraitUltimateNotice')
	if old!=null:old.free()
	var panel:=PanelContainer.new()
	panel.name='PortraitUltimateNotice';panel.z_index=100
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override('panel',P_SKIN.box(P_SKIN.DARK_2,P_SKIN.GOLD,12,2))
	content_root.add_child(panel)
	panel.position=Vector2(24,340)
	panel.size=Vector2(get_viewport_rect().size.x-48,96)
	var box:=P_PAGES.stack(panel,6)
	P_PAGES.text(box,_hero_short_name(hero_id)+' · 궁극기',22,P_SKIN.GOLD)
	P_PAGES.text(box,detail,17)
	var fade:=panel.create_tween()
	fade.tween_interval(.8);fade.tween_property(panel,'modulate:a',0.0,.2);fade.tween_callback(panel.queue_free)

func _new_hunt_hud() -> Control:
	if get_viewport_rect().size.x > get_viewport_rect().size.y:
		return preload("res://scripts/portrait/LandscapeHuntHud.gd").new()
	return P_HUD.new()
