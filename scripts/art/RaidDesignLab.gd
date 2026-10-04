extends "res://scripts/art/ArtDirectionLab.gd"
## F6 review uses real raid rules and disposable progress/settings only.
func _ready() -> void:
	super._ready()
	combat_running=false
	idle_stage=100;party_slot_legacy_cap=10
	_restore_deployed_heroes(["leonhardt","mira","elisia","kairen","orwin","seria","astel","darius","lunea","caelum"])
	for hero: Dictionary in deployed_heroes:
		hero_progress[str(hero.id)]={"level":60,"xp":0}
	selected_raid_id=preview_zone_id
	_build_raid_screen()
