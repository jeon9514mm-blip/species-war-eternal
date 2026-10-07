extends SceneTree

const HERO_SPRITES := [
	"res://assets/sprites/leonhardt-sheet.png",
	"res://assets/sprites/mira-sheet.png",
	"res://assets/sprites/elisia-sheet.png"
]

const MONSTER_SPRITES := [
	"res://assets/monsters/gray-meadow-goblin.png",
	"res://assets/monsters/gray-meadow-wolves.png",
	"res://assets/monsters/gray-meadow-boar.png",
	"res://assets/monsters/gray-meadow-crow.png",
	"res://assets/monsters/forgotten-mine-orc.png",
	"res://assets/monsters/forgotten-mine-mole.png",
	"res://assets/monsters/forgotten-mine-bat.png",
	"res://assets/monsters/forgotten-mine-spider.png",
	"res://assets/monsters/moonrest-wolf.png",
	"res://assets/monsters/moonrest-wraith.png",
	"res://assets/monsters/moonrest-mushroom.png",
	"res://assets/monsters/moonrest-raven.png",
	"res://assets/monsters/moonrest-deer.png",
	"res://assets/monsters/gray-meadow-boss.png",
	"res://assets/monsters/forgotten-mine-boss.png",
	"res://assets/monsters/moonrest-boss.png"
]

func _init() -> void:
	var holder = Node2D.new()
	get_root().add_child(holder)
	for path in HERO_SPRITES:
		var texture = load(path) as Texture2D
		if texture == null:
			push_error("Missing hero sprite: %s" % path)
			quit(1)
		var hero = HeroSpriteController.new()
		hero.frame_columns = 4
		hero.frame_rows = 4
		holder.add_child(hero)
		hero.set_sprite_sheet(texture)
		hero.play_idle("down")
		if hero.sprite_frames.get_frame_count("idle_down") != 2:
			push_error("Hero idle frame count mismatch: %s" % path)
			quit(1)
		hero.play_attack("right")
		if hero.animation != "attack_right":
			push_error("Hero attack animation failed: %s" % path)
			quit(1)
		hero.play_hit("left")
		if hero.animation != "hit_left":
			push_error("Hero hit animation failed: %s" % path)
			quit(1)
		hero.queue_free()
	for path in MONSTER_SPRITES:
		var texture = load(path) as Texture2D
		if texture == null:
			push_error("Missing monster sprite: %s" % path)
			quit(1)
		var monster = MonsterSpriteController.new()
		monster.frame_columns = 1
		monster.frame_rows = 1
		holder.add_child(monster)
		monster.set_sprite_sheet(texture)
		monster.play_idle("down")
		if monster.sprite_frames.get_frame_count("idle_down") != 1:
			push_error("Monster idle frame count mismatch: %s" % path)
			quit(1)
		monster.play_attack("right")
		if monster.animation != "attack_right":
			push_error("Monster attack animation failed: %s" % path)
			quit(1)
		monster.play_hit("left")
		if monster.animation != "hit_left":
			push_error("Monster hit animation failed: %s" % path)
			quit(1)
		monster.queue_free()
	print("combat_sprite_smoke_test_ok heroes=%d monsters=%d states=idle,attack,hit" % [HERO_SPRITES.size(), MONSTER_SPRITES.size()])
	holder.queue_free()
	quit(0)
