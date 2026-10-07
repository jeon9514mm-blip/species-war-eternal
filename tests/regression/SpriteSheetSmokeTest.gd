extends SceneTree

const HERO_SPRITES := {
	"leonhardt": "res://assets/sprites/leonhardt-sheet.png",
	"mira": "res://assets/sprites/mira-sheet.png",
	"elisia": "res://assets/sprites/elisia-sheet.png"
}

func _init() -> void:
	var holder = Node.new()
	get_root().add_child(holder)
	for hero_id in HERO_SPRITES:
		var texture = load(HERO_SPRITES[hero_id]) as Texture2D
		if texture == null:
			push_error("Missing sprite sheet: %s" % hero_id)
			quit(1)
		var sprite = HeroSpriteController.new()
		sprite.name = "%sSmokeSprite" % hero_id
		holder.add_child(sprite)
		sprite.set_sprite_sheet(texture)
		await process_frame
		for direction in ["down", "left", "right", "up"]:
			for state in ["idle", "walk", "attack", "hit", "death"]:
				var animation_name = "%s_%s" % [state, direction]
				if not sprite.sprite_frames.has_animation(animation_name):
					push_error("Missing animation: %s/%s" % [hero_id, animation_name])
					quit(1)
				if sprite.sprite_frames.get_frame_count(animation_name) < 1:
					push_error("Empty animation: %s/%s" % [hero_id, animation_name])
					quit(1)
		sprite.play_walk(Vector2.LEFT)
		if sprite.animation != "walk_left":
			push_error("Direction selection failed for %s" % hero_id)
			quit(1)
		sprite.queue_free()
	print("sprite_sheet_smoke_test_ok heroes=%d animations_per_hero=20" % HERO_SPRITES.size())
	holder.queue_free()
	quit(0)
