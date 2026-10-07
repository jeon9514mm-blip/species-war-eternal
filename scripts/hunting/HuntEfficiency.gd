extends RefCounted
## Game-time window: credits only observed kills and actual hunt receipts.
const WINDOW:=120.0
static func context(main) -> String:
	return str(main.current_zone_id)+str(main._deployed_hero_ids())
static func begin(main) -> void:
	main.set_meta('hunt_efficiency',{'time':0.0,'recovery':0.0,'kills':0,'gold':0,'samples':[{'time':0.0,'recovery':0.0,'kills':0,'gold':0}], 'next_sample':1.0,'context':context(main)})
static func advance(main, delta: float) -> void:
	if main.challenge_session!=null or bool(main.get_meta('practice_active',false)):return
	if not main.has_meta('hunt_efficiency') or main.get_meta('hunt_efficiency').context!=context(main):begin(main)
	var state: Dictionary=main.get_meta('hunt_efficiency')
	state.time+=delta
	if main.hunt_ai.state==AutoHuntController.State.RECOVERING:state.recovery+=delta
	if state.time>=state.next_sample:
		state.samples.append({'time':state.time,'recovery':state.recovery,'kills':state.kills,'gold':state.gold})
		state.next_sample=state.time+1.0
		while state.samples.size()>1 and state.samples[1].time<state.time-WINDOW:state.samples.pop_front()
static func kill(main) -> void:
	if main.challenge_session==null and not bool(main.get_meta('practice_active',false)) and main.has_meta('hunt_efficiency'):main.get_meta('hunt_efficiency').kills+=1
static func reward(main, gold: int) -> void:
	if main.challenge_session==null and not bool(main.get_meta('practice_active',false)) and main.has_meta('hunt_efficiency'):main.get_meta('hunt_efficiency').gold+=maxi(0,gold)
static func summary(main) -> Dictionary:
	var state: Dictionary=main.get_meta('hunt_efficiency',{})
	if state.is_empty() or state.samples.is_empty():return {'seconds':0.0,'kills_per_minute':0.0,'gold_per_minute':0.0,'recovery_percent':0.0}
	var start: Dictionary=state.samples[0]
	var seconds: float=maxf(0,state.time-start.time)
	return {'seconds':seconds,'kills_per_minute':(state.kills-start.kills)*60/maxf(1,seconds),'gold_per_minute':(state.gold-start.gold)*60/maxf(1,seconds),'recovery_percent':100*(state.recovery-start.recovery)/maxf(1,seconds)}
static func text(main) -> String:
	var value:=summary(main)
	if value.seconds<10:return '사냥 효율 측정 중 · 10초 이상 사냥하면 표시돼요.'
	return '최근 %d초 · 게임 시간 기준\n분당 처치 %.1f · 분당 골드 %.0fG\n재정비 %.0f%% · 같은 지역·성장에서 편성을 비교하세요.'%[int(value.seconds),value.kills_per_minute,value.gold_per_minute,value.recovery_percent]
