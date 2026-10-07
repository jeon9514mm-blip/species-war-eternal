extends SceneTree
## Dedicated localhost training process. Never loaded by the shipped game.
const HOST=preload('res://tools/combat_ai/TrainingHost.gd')
const DECISION=preload('res://tools/combat_ai/TrainingDecision.gd')
var server:=TCPServer.new()
var peer: StreamPeerTCP
var buffer:=''
var busy:=false
var game: Node
var elapsed:=0.0
var episode:=0
const IDS: Array[String]=['leonhardt','mira','elisia']
func _init() -> void:
	var port:=int(OS.get_environment('COMBAT_AI_PORT'))
	if port<=0 or server.listen(port,'127.0.0.1')!=OK:quit(1);return
	Engine.max_fps=120
	print('COMBAT_AI_READY ',port)
func _process(_delta: float) -> bool:
	if busy:return false
	if peer==null:
		if server.is_connection_available():peer=server.take_connection()
		return false
	peer.poll()
	if peer.get_status()!=StreamPeerTCP.STATUS_CONNECTED:quit();return false
	var available:=peer.get_available_bytes()
	if available>0:buffer+=peer.get_data(available)[1].get_string_from_utf8()
	if not buffer.contains('\n'):return false
	var end:=buffer.find('\n');var line:=buffer.substr(0,end);buffer=buffer.substr(end+1)
	var request=JSON.parse_string(line)
	if not request is Dictionary:send({'error':'invalid request'});return false
	busy=true
	handle_request(request)
	return false
func handle_request(request: Dictionary) -> void:
	match str(request.get('command','')):
		'reset':
			await reset_episode(int(request.get('seed',7)))
			send(result(0.0,false,false))
		'step':
			if not is_instance_valid(game):send({'error':'reset required'})
			else:
				game.combat_decisions.tactic=clampi(int(request.get('action',0)),0,4)
				var damage: int=game.training_damage;var taken: int=game.training_taken;var kills: int=game.training_kills
				for tick in 5:
					game._advance_auto_hunt(.05)
					for source in game.hero_map_sprites+game.enemy_wave_sprites:source.set_process(false)
				elapsed+=.25
				var reward: float=(game.training_damage-damage)*.01-(game.training_taken-taken)*.015+(game.training_kills-kills)*2.0-.005
				var dead: bool=game._alive_hero_ids().is_empty()
				send(result(reward-5.0 if dead else reward,dead,elapsed>=32.0))
		'close':
			send({'closed':true})
			await cleanup();server.stop();quit()
		_:send({'error':'unknown command'})
	busy=false
func reset_episode(seed_value: int) -> void:
	await cleanup();episode+=1;elapsed=0
	seed(seed_value)
	game=HOST.new();game.save_state_path='user://training-'+str(episode)+'.json';game._offline_checked=true
	game.combat_decisions=DECISION.new();root.add_child(game)
	for i in 5:await process_frame
	game.set_process(false);game.set_physics_process(false);game.sound_effects_enabled=false;game.combat_effects_enabled=false
	game.tutorial_completed=true;game.selected_faction='aurelia';game.current_zone_id='gray_meadow';game.idle_stage=1;game.party_slot_legacy_cap=10
	for id in IDS:game.hero_progress[id]={'level':3,'xp':0}
	game.loot_rng.seed=seed_value;game._restore_deployed_heroes(IDS);game._build_combat_screen()
	for i in 5:await process_frame
	game.party_movement._decisions=game.combat_decisions
	game.combat_running=true;game.battle_speed=1.0
	if is_instance_valid(game.combat_timer):game.combat_timer.stop()
	game.combat_labels.terrain.set_process(false)
	for source in game.hero_map_sprites+game.enemy_wave_sprites:source.set_process(false)
func cleanup() -> void:
	if not is_instance_valid(game):return
	game.combat_running=false;game.background_hunt.discard();game.presentation_runtime.audio.shutdown()
	game.queue_free();game=null
	for i in 5:await process_frame
func result(reward: float,terminated: bool,truncated: bool) -> Dictionary:
	var observation: Array[float]=[]
	for id in IDS:
		var state: Dictionary=game.hero_battle_state.get(id,{})
		observation.append(clampf(float(state.get('hp',0))/maxf(1,float(state.get('max_hp',1))),0,1))
	for id in IDS:observation.append(1.0 if float(game.hero_skill_runtime.get(id,{}).get('windup',-1))<0 else 0.0)
	var enemies: Array[Dictionary]=[]
	for index in game.enemy_wave.size():
		var enemy: Dictionary=game.enemy_wave[index]
		if int(enemy.get('hp',0))>0:enemies.append({'hp':float(enemy.hp)/maxf(1,float(enemy.get('max_hp',1))),'distance':game.expedition_position.distance_to(game.roaming_hunt.enemy_position(index))/12.0,'attack':float(enemy.get('attack',0))/100.0,'support':1.0 if str(enemy.get('archetype',''))=='support' else 0.0,'elite':1.0 if bool(enemy.get('elite',false)) else 0.0})
	enemies.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:return a.distance<b.distance)
	for property in ['hp','distance','attack','support','elite']:
		for index in 4:observation.append(clampf(float(enemies[index][property]),0,1) if index<enemies.size() else 0.0)
	observation.append(clampf(elapsed/32.0,0,1));observation.append(minf(1.0,float(enemies.size())/16.0))
	return {'observation':observation,'reward':reward,'terminated':terminated,'truncated':truncated,'info':{'episode_id':episode,'seconds':elapsed,'damage':game.training_damage,'taken':game.training_taken,'kills':game.training_kills,'tactic':game.combat_decisions.tactic,'production_combat':true}}
func send(value: Dictionary) -> void:
	peer.put_data((JSON.stringify(value)+'\n').to_utf8_buffer())
