extends 'res://scripts/portrait/PortraitMain.gd'
## Actual production combat, with independently observed damage for rewards.
var training_damage:=0
var training_taken:=0
var training_kills:=0
func _damage_enemy(index: int,damage: int,source_index:=0) -> int:
	var enemy: Dictionary=enemy_wave[index] if index>=0 and index<enemy_wave.size() else {}
	var before:=int(enemy.get('hp',0))
	var actual:=super._damage_enemy(index,damage,source_index)
	training_damage+=actual
	if before>0 and int(enemy.get('hp',0))<=0:training_kills+=1
	return actual
func _incoming_damage_to_hero(id: String,amount: int,index: int=-1) -> int:
	var actual:=super._incoming_damage_to_hero(id,amount,index)
	training_taken+=actual
	return actual
