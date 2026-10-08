extends Control
## Selected hero marker in the same camera space as damage footprints.
var raid: Control
func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:queue_redraw()
func _draw() -> void:
	if not is_instance_valid(raid) or not is_instance_valid(raid.battlefield_3d):return
	var actor: Node2D=raid.hero_actors.get(raid.selected_hero_id)
	if not is_instance_valid(actor) or float(raid.game.hero_battle_state.get(raid.selected_hero_id,{}).get('hp',0))<=0:return
	var view=raid.battlefield_3d
	var foot: Vector2=view.project_world(view.raid_display_world(actor,actor.position))
	var head: Vector2=foot+view.actor_head_offset(actor)-Vector2(0,12)
	var gold:=Color('#ffe1a0')
	var arrow:=PackedVector2Array([head+Vector2(-9,-8),head+Vector2(9,-8),head+Vector2(0,3)])
	draw_colored_polygon(arrow,Color('#101823'));draw_polyline(PackedVector2Array([arrow[0],arrow[1],arrow[2],arrow[0]]),gold,2.5,true)
	draw_arc(foot,14,0,TAU,36,Color('#101823'),6,true)
	draw_arc(foot,14,0,TAU,36,gold,3,true)
