extends SceneTree
const ACTIONS: Array[String] = ["idle","walk","run","attack_1","attack_2","skill","ultimate","hit","knockback","dodge","guard","buff","debuff","victory","death"]

func _fail(msg: String) -> void:
	push_error(msg)
	quit(1)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var roster = preload("res://scripts/HeroRosterCatalog.gd")
	var factory = preload("res://scripts/HeroSpriteFactory.gd")
	var ids: Array = roster.HEROES.keys()
	if ids.size() != 30:
		_fail("expected 30 heroes, got %d" % ids.size())
		return
	for hidv in ids:
		var hid := str(hidv)
		var actor = factory.create_hero(hid)
		if actor == null:
			_fail("actor null %s" % hid)
			return
		root.add_child(actor)
		if actor.sprite_frames == null:
			_fail("frames null %s" % hid)
			return
		for action in ACTIONS:
			if not actor.sprite_frames.has_animation(action):
				_fail("missing %s %s" % [hid, action])
				return
			if actor.sprite_frames.get_frame_count(action) < 1:
				_fail("empty %s %s" % [hid, action])
				return
		actor.queue_free()
	await process_frame
	print("v43_all_hero_motion_smoke_ok heroes=30 actions=15")
	quit(0)
