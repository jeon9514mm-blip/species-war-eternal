extends RefCounted
## Starter pacing and late progression; existing progress is never reduced.
const REVISION := "first-session-economy-2"
static func solo_starter(main: Node, zone: Dictionary) -> bool:
	return str(main.current_zone_id)=="gray_meadow" and int(zone.get("difficulty",1))==1 and main.idle_stage<=2 and main.deployed_heroes.size()==1
static func unmeasured_pack_interval(party_size: int) -> float:
	# Conservative starter-region allowance until this build has real samples.
	return 60.0 / sqrt(float(clampi(party_size,1,10)))
static func xp_cost(level: int, max_level: int) -> int:
	level=clampi(level,1,max_level)
	var late: int=maxi(0,level-20)
	return 100+(level-1)*75+late*late*8
static func equipment_cost(slot: String, level: int) -> int:
	level=clampi(level,1,10)
	var late: int=maxi(0,level-4)
	var base: int=100+level*75
	return int(float(base)*(1.0+float(late*late)*1.5))*int({"weapon":1,"armor":2,"accessory":3}.get(slot,1))

static func stage_chest(stage: int) -> Dictionary:
	stage=clampi(stage,1,10000)
	# First 25 milestones retain their exact rewards. Later rewards grow with
	# the square root of progress, matching gradually rising field pressure.
	var tier: float=float(stage) if stage<=25 else 25.0+sqrt(float(stage-25))
	return {"gold":250+floori(tier*50.0),"xp":100+floori(tier*25.0),"rations":40+floori(tier*3.0)}
