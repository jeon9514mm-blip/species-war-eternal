extends 'res://tools/diagnostics/game-audit-2026-10-07/FinalPolishReview.gd'
func measure(label: String,seconds: float) -> void:
	await super.measure(label,seconds)
	var item: Dictionary=report.profiles.back()
	item['buffer_bytes']=RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)
	item['render_resource_bytes']=int(item.texture_bytes)+int(item.buffer_bytes)
	item['memory_static_bytes']=Performance.get_monitor(Performance.MEMORY_STATIC)
	var field=game.combat_labels.get('terrain') if game.active_screen=='combat' else game.content_root.get_node('PortraitRaidView').battlefield_3d
	item['render_profile']=field.map_root.get_meta('ultra_render_profile',{})
	item['skill_casts']=field.skill_overlay.accepted_casts
	item['gpu_bursts']=field.skill_overlay.gpu_pool.accepted
