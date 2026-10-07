extends SceneTree
## Isolated CPU cost, not a GPU/FPS benchmark. See movement-pacing evidence.
const NAV=preload('res://scripts/hunting/MeadowNavigation.gd')
func _initialize() -> void:
	var nav:=NAV.new()
	var started:=Time.get_ticks_usec()
	var checksum:=Vector2.ZERO
	for frame in 3000:
		for actor in 30:
			var from:=Vector2(3+float((frame+actor*13)%250)*.1,2+float((frame+actor*7)%150)*.1)
			var target:=from+Vector2(.17,-.11)
			nav.is_walkable(target)
			nav.has_clear_path(from,target)
			checksum+=nav.move_toward(actor,from,target,.0975)
	print('HUNT_NAVIGATION_COST '+JSON.stringify({'queries':90000,'elapsed_ms':float(Time.get_ticks_usec()-started)/1000,'checksum':[checksum.x,checksum.y],'stats':nav.get_debug_stats()}))
	quit()
