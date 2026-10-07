extends 'res://scripts/combat/CombatDecisionEngine.gd'
## Training-only score adjustment. All production eligibility/range rules apply.
var tactic:=0
func _enemy_score(hero: Dictionary,enemy: Dictionary,index: int) -> float:
	var score:=super._enemy_score(hero,enemy,index)
	match tactic:
		1:score+=float(enemy.get('hp',0))/maxf(1,float(enemy.get('max_hp',1)))*1.5
		2:score-=minf(2.0,float(enemy.get('attack',0))*.02)
		3:score-=.8 if str(enemy.get('archetype',''))=='support' else 0.0
		4:score-=.8 if bool(enemy.get('elite',false)) else 0.0
	return score
