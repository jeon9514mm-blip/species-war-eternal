extends SceneTree

const ROSTER = preload("res://scripts/HeroRosterCatalog.gd")
const ACTIONS := ["idle", "walk", "run", "attack_1", "attack_2", "skill", "ultimate", "hit", "knockback", "dodge", "guard", "buff", "debuff", "victory", "death"]
var checks := 0
var failures: Array[String] = []
var finished: Dictionary = {}

func _init() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func on_finished(action: String, id: String) -> void:
	var key := id + "/" + action
	finished[key] = int(finished.get(key, 0)) + 1

func run() -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var actors: Array[HeroSpriteController] = []
	for id in ROSTER.HEROES:
		var actor := HeroSpriteFactory.create_hero(id, Vector2.ONE * HeroSpriteFactory.BATTLEFIELD_SCALE)
		holder.add_child(actor)
		actors.append(actor)
		actor.observe_game = false
		check(actor._frames_ready and actor.sprite_frames != null, id + " production factory loads current action art")
		check(actor.atlas_key == id, id + " retains canonical identity")
		check(absf(actor.get_visual_height() - 40.0) < 0.01, id + " retains battlefield scale")
		for action in ACTIONS:
			check(actor.sprite_frames.has_animation(action), id + " has " + action)
			if not actor.sprite_frames.has_animation(action):
				continue
			check(actor.sprite_frames.get_frame_count(action) > 0, id + "/" + action + " has artwork")
			check(actor.sprite_frames.get_animation_speed(action) > 0, id + "/" + action + " has valid timing")
			for i in actor.sprite_frames.get_frame_count(action):
				var texture := actor.sprite_frames.get_frame_texture(action, i)
				check(texture != null and texture.get_width() > 0 and texture.get_height() > 0, id + "/" + action + " frame loads")
				if texture is AtlasTexture:
					check(texture.atlas != null and Rect2(Vector2.ZERO, texture.atlas.get_size()).encloses(texture.region), id + "/" + action + " crop inside source")
		actor.play_walk(Vector2.LEFT)
		check(actor.flip_h and actor.state == "walk", id + " faces left while moving")
		actor.play_walk(Vector2.RIGHT)
		check(not actor.flip_h, id + " faces right while moving")
		actor.action_finished.connect(on_finished.bind(id))
		actor.play_attack("right")
	await create_timer(1.5).timeout
	for actor in actors:
		check(actor.state == "idle" and int(finished.get(actor.atlas_key + "/attack", 0)) == 1, actor.atlas_key + " attack completes once and returns to idle")
		actor.play_death()
	await create_timer(0.2).timeout
	var paused: Dictionary = {}
	for actor in actors:
		actor.speed_scale = 0
		paused[actor.atlas_key] = [actor.frame, actor.frame_progress, actor.modulate.a]
	await create_timer(0.2).timeout
	for actor in actors:
		check(paused[actor.atlas_key] == [actor.frame, actor.frame_progress, actor.modulate.a], actor.atlas_key + " pause freezes death frames and fading")
		actor.speed_scale = 1
	await create_timer(1.0).timeout
	for actor in actors:
		check(actor.state == "death" and actor.modulate.a < 0.5, actor.atlas_key + " stays dead until gameplay revival")
		actor.play_idle()
		check(actor.state == "idle" and is_equal_approx(actor.modulate.a, 1.0), actor.atlas_key + " explicit revival restores visibility")
	holder.free()
	print("v46_current_assets checks=%d failures=%d heroes=%d actions_per_hero=15" % [checks, failures.size(), ROSTER.HEROES.size()])
	quit(0 if failures.is_empty() else 1)
