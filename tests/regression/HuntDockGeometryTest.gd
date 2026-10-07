extends SceneTree
## Asset-independent geometry test; run with Godot --headless --script this_file.
const LAYOUT := preload("res://scripts/portrait/LandscapeHuntLayout.gd")
var checks: int = 0
var failures: Array[String] = []

func verify(ok: bool, note: String) -> void:
	checks += 1
	if not ok: failures.append(note)

func _init() -> void:
	for width: int in [720,854,960,1120,1179,1180,1280,1440,1600,1920,2560]:
		for height: int in [405,540,630,720,900,1080,1440]:
			if height >= width: continue
			var screen: Vector2 = Vector2(width,height)
			var viewport: Rect2 = Rect2(Vector2.ZERO,screen)
			var dock: Rect2 = LAYOUT.footer(screen)
			var party: Rect2 = LAYOUT.party_rect(screen)
			var slots: Rect2 = LAYOUT.slots_rect(screen)
			var nav: Rect2 = LAYOUT.navigation_rect(screen)
			var field: Rect2 = LAYOUT.field(screen)
			var tag: String = "%dx%d" % [width,height]
			verify(viewport.encloses(dock),tag+" dock fits viewport")
			verify(dock.encloses(party) and dock.encloses(nav),tag+" dock contains both groups")
			verify(party.encloses(slots),tag+" slots fit party group")
			verify(not party.intersects(nav),tag+" controls never overlap")
			verify(viewport.encloses(field) and field.size.y > 0,tag+" field remains positive and visible")
			verify(field.end.y+8 <= dock.position.y,tag+" field/dock separation")
			verify(nav.size.y >= 48 and nav.size.x/5.0-4.0 >= 48,tag+" navigation hit boxes")
			for count: int in range(1,11):
				var cell: float = minf(LAYOUT.HERO_CELL_MAX,slots.size.x/float(count))
				for i: int in count:
					var card: Rect2 = Rect2(slots.position+Vector2(i*cell+2.0,0),Vector2(cell-4.0,60))
					verify(slots.encloses(card),tag+" hero card fits")
					verify(card.size.x >= 48 and card.size.y >= 48,tag+" hero hit box")
					verify(card.size.x >= 44 and 59 <= card.size.y,tag+" portrait and gauges fit")
	verify(LAYOUT.field(Vector2(1280,720)).size.y == 488.0,"default field grows from 432 to 488 viewport units")
	verify(not LAYOUT.single_row(Vector2(1179,720)) and LAYOUT.single_row(Vector2(1180,720)),"breakpoint boundary")
	print("HUNT_DOCK_GEOMETRY "+JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
