extends Node
## Watch confirmed wallet changes; never rolls, grants or previews rewards.
const FONT=preload('res://assets/fonts/combat/outfit/Outfit-ExtraBold.ttf')
var game: Node
var previous_gold:=0
var previous_gems:=0
func bind(host: Node) -> void:
	game=host;previous_gold=int(game.wallet_gold);previous_gems=int(game.wallet_gems)
func _process(_delta: float) -> void:
	if not is_instance_valid(game):return
	var gold:=maxi(0,int(game.wallet_gold)-previous_gold);var gems:=maxi(0,int(game.wallet_gems)-previous_gems)
	previous_gold=int(game.wallet_gold);previous_gems=int(game.wallet_gems)
	if gold+gems==0 or not game.combat_effects_enabled or game._application_suspended or bool(game.get_meta('background_hunt_tick',false)) or not is_instance_valid(game.content_root):return
	var origin:=Vector2(game.get_viewport_rect().size.x*.5,120)
	var field: Control=game.combat_labels.get('terrain') if game.active_screen=='combat' else null
	if game.active_screen=='raid':
		var view=game.content_root.get_node_or_null('PortraitRaidView')
		if view!=null:field=view.battlefield_3d
	if is_instance_valid(field) and field.has_method('actor_world_height'):
		var point: Vector2=field.raid_to_world(game.raid_boss_position) if field.raid_mode else field.get_meta('last_loot_point',game.expedition_position)
		field.hunt_overlay.loot(point);origin=field.position+field.project_world(point)-Vector2(0,52)
		if field.raid_mode:origin+=field.get_parent().position
	game._presentation_event('reward')
	if gold>0:popup('골드 +'+str(gold),origin,Color('#c4a484'))
	if gems>0:popup('젬 +'+str(gems),origin-Vector2(0,23),Color('#a8b89e'))
func popup(message: String,origin: Vector2,tint: Color) -> void:
	var nodes: Array=get_tree().get_nodes_in_group('loot_reward_popup')
	if nodes.size()>=8:nodes[0].remove_from_group('loot_reward_popup');nodes[0].queue_free()
	var label:=Label.new();label.name='LootRewardPopup';label.text=message;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.z_index=106
	label.add_theme_font_override('font',FONT);label.add_theme_font_size_override('font_size',12);label.add_theme_color_override('font_color',tint)
	label.add_theme_color_override('font_outline_color',Color('#000000cc'));label.add_theme_constant_override('outline_size',2)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.size=Vector2(180,24);label.position=origin-Vector2(90,12);label.add_to_group('loot_reward_popup');game.content_root.add_child(label)
	var tween:=label.create_tween().set_parallel(true);tween.set_ignore_time_scale(true)
	tween.tween_property(label,'position',label.position-Vector2(0,24),.8);tween.tween_property(label,'modulate:a',0,.3).set_delay(.5);tween.chain().tween_callback(label.queue_free)
