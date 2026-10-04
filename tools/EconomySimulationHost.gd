extends "res://scripts/portrait/PortraitMain.gd"
## Test-only host: production combat/economy, without UI painting or disk I/O.
var simulation_day := 1
var spent_gold := 0
var upgrade_count := 0
var first_upgrade_seconds := -1.0
var first_three_seconds := -1.0
var first_pack_seconds := -1.0
var elapsed_online := 0.0
func _ready() -> void: pass
func _save_idle_state() -> void: _deposit_nonoffline_rewards()
func _queue_hunt_save() -> void: _deposit_nonoffline_rewards()
func _load_idle_state() -> void: pass
func _show_toast(_value: String) -> void: pass
func _update_hunt_hud() -> void: pass
func _update_map_tiles() -> void: pass
func _update_map_hero_motion(_delta: float) -> void: pass
func _update_roaming_enemy_motion(_delta: float) -> void: pass
func _update_combat_camera(_delta: float) -> void: pass
func _spawn_enemy_wave_sprites(_start_index: int = 0) -> void: pass
func _show_battle_result_popup(_title: String, _headline: String, _detail: String, _accent: Color) -> void: pass
func _spawn_floating_combat_text(_value: String, _color: Color, _position: Vector2) -> void: pass
func _update_reward_labels() -> void: pass
func _update_stage_label() -> void: pass
func _update_hero_progress_label() -> void: pass
func _update_equipment_card(_id: String) -> void: pass
func _today_key() -> String: return Time.get_date_string_from_unix_time(1760000000+(simulation_day-1)*86400)
func _week_key() -> String: return str(int((1760000000+(simulation_day-1)*86400+9*3600-4*86400)/604800.0))

func _create_map_hero_sprites() -> void:
	field_navigation.configure_zone(current_zone_id,true)
	field_navigation.clear_routes();roaming_hunt.field_navigation=field_navigation;party_movement.field_navigation=field_navigation
	roaming_hunt.party_position=field_navigation.clamp_to_walkable(expedition_position);expedition_position=roaming_hunt.party_position
	party_movement.configure(deployed_heroes,hero_battle_state,expedition_position)
	party_movement.apply_formation(deployed_heroes,formation_id);party_movement.place_formation(expedition_position)

func boot(faction: String, fixture_seed: int) -> void:
	set_process(false);set_physics_process(false)
	selected_faction=faction;current_zone_id="gray_meadow";idle_stage=1;party_slot_legacy_cap=0
	combat_effects_enabled=false;sound_effects_enabled=false;combat_fx.enabled=false
	battle_speed=1.0;skill_auto=true;ultimate_auto=true;_offline_checked=true
	loot_rng.seed=fixture_seed;roaming_hunt.configure(expedition_position,fixture_seed)
	content_root=Control.new();add_child(content_root);combat_field_rect=Rect2(16,132,940,440)
	combat_side_rect=Rect2(968,132,290,440);active_screen="combat";combat_running=true
	_restore_deployed_heroes([str(_hero_roster_for_faction()[0].id)])
	_setup_hero_skills();_create_map_hero_sprites();_spawn_enemy_wave(_current_zone())

func manage() -> void:
	var ids: Array[String]=[]
	for hero in _hero_roster_for_faction():
		if idle_stage>=int(hero.unlock_stage) and ids.size()<_party_slot_cap():ids.append(str(hero.id))
	if ids!=_deployed_hero_ids():
		background_hunt.party_ids=_deployed_hero_ids().duplicate();_restore_deployed_heroes(ids);background_hunt._reconcile_party(self)
	if ids.size()>=3 and first_three_seconds<0:first_three_seconds=elapsed_online
	_recommend_equip_all()
	var budget:=maxi(175,int(wallet_gold*.25))
	for id in ids:
		while _skill_tree_available_points(id)>0:
			var tree:=_get_skill_tree(id)
			var branch: String="offense" if int(tree.offense)<10 else ("survival" if int(tree.survival)<10 else "utility")
			_upgrade_skill_tree(id,branch)
		var before:=wallet_gold
		_try_ascend_hero(id)
		spent_gold+=before-wallet_gold
		for slot: String in EQUIPMENT_SLOTS:
			var item:=_gear_item("",id,slot)
			var cost:=_inventory_upgrade_cost(item)
			if int(item.level)>=MAX_EQUIPMENT_LEVEL or wallet_gold<cost or cost>budget:continue
			var result:=_gear_enhance_item(str(item.id),id,slot)
			if bool(result.get("ok",false)):
				spent_gold+=cost;budget-=cost;upgrade_count+=1
				if first_upgrade_seconds<0:first_upgrade_seconds=elapsed_online

func checkpoint() -> Dictionary:
	var levels: Array[int]=[];var maxed:=0;var gear_sum:=0
	for id in _deployed_hero_ids():
		var level:=int(_get_hero_progress(id).level);levels.append(level)
		if level>=MAX_HERO_LEVEL:maxed+=1
		for slot in EQUIPMENT_SLOTS:gear_sum+=int(_get_hero_equipment(id)[slot])
	return {"day":simulation_day,"stage":idle_stage,"party":deployed_heroes.size(),"levels":levels,"max_level_heroes":maxed,"average_gear_level":float(gear_sum)/maxi(1,deployed_heroes.size()*3),"gold":wallet_gold,"spent_gold":spent_gold,"power":_calculate_party_power(),"packs":combat_kills,"bag":loot_inventory.size(),"overflow":equipment_overflow.size(),"first_pack_seconds":first_pack_seconds,"first_upgrade_seconds":first_upgrade_seconds,"first_three_seconds":first_three_seconds}
