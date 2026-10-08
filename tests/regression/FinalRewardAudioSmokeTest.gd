extends SceneTree
const BADGE=preload('res://scripts/presentation/CurrencyFeedbackBadge.gd')
var failures: Array[String]=[]
var checks:=0
class WalletHost:
	extends Node
	var wallet_gold:=49000
	var wallet_gems:=840
	var combat_effects_enabled:=true
	var _application_suspended:=false
	var loot_rng:=RandomNumberGenerator.new()
	func _compact_hud_amount(amount: int) -> String:return str(amount)
class SpatialField:
	extends Node
	var world: Node3D
	var viewport_3d: SubViewport
	func _ready() -> void:
		viewport_3d=SubViewport.new();viewport_3d.own_world_3d=true;add_child(viewport_3d)
		world=Node3D.new();viewport_3d.add_child(world)
		var camera:=Camera3D.new();camera.position=Vector3(0,40,28);camera.current=true;world.add_child(camera)
func _init() -> void:_run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func _run() -> void:
	var wallet:=WalletHost.new();root.add_child(wallet);wallet.loot_rng.seed=1718
	var gold:=BADGE.new();root.add_child(gold);gold.bind(wallet,'gold',Rect2(0,0,142,30))
	var gem:=BADGE.new();root.add_child(gem);gem.bind(wallet,'gem',Rect2(148,0,94,30))
	gold.set_process(false);gem.set_process(false)
	check(gold.caption.text=='49000' and gem.caption.text=='840','initial balance displayed without invented reward')
	var rng_state:=wallet.loot_rng.state
	wallet.wallet_gold+=800;gold.sync_wallet();gold._process(.19)
	check(gold.shown_amount>49000 and gold.shown_amount<49800 and is_equal_approx(gold.caption.scale.x,1.2),'confirmed receipt counts upward and pops at 1.2')
	gold._process(.3)
	check(gold.caption.text=='49800' and is_equal_approx(gold.caption.scale.x,1),'count ends at authoritative wallet amount')
	wallet.wallet_gold-=3000;gold._process(.02)
	check(gold.caption.text=='46800' and gold.positive_changes==1 and gold.pulse_age==1,'spending snaps to balance without reward pulse')
	wallet._application_suspended=true;wallet.wallet_gems+=10;gem._process(.1)
	check(gem.caption.text=='850' and gem.positive_changes==0,'background balance update has no reward animation')
	wallet._application_suspended=false;wallet.combat_effects_enabled=false;wallet.wallet_gems+=10;gem._process(.1)
	check(gem.caption.text=='860' and gem.positive_changes==0 and gem.icon.scale==Vector2.ONE,'effects opt-out preserves accurate static readout')
	wallet.combat_effects_enabled=true
	for i in 100:wallet.wallet_gold+=1;gold._process(.01)
	check(gold.get_child_count()==2 and gem.get_child_count()==2 and gold.clip_contents,'100 receipts reuse bounded clipped icon and number widgets')
	check(wallet.loot_rng.state==rng_state and wallet.wallet_gold==46900 and wallet.wallet_gems==860,'wallet feedback never grants currency or consumes loot RNG')
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://audio/final-feedback/manifest.json'))
	check(manifest.tracks.size()==4,'four original offline PCM cue assets')
	for key in manifest.tracks:
		var stream: AudioStream=load('res://'+str(manifest.tracks[key].file))
		check(stream!=null and absf(stream.get_length()-float(manifest.tracks[key].seconds))<.02,'decoded cue '+str(key))
	var audio:=GameAudioDirector.new();root.add_child(audio);audio.set_process(false);audio.configure({},true)
	var field:=SpatialField.new();root.add_child(field)
	seed(9301);var before_random:=randi()
	check(audio.play_positional('hit',field,Vector2(-3,7)),'actual 3D hit voice accepted')
	var after_random:=randi();seed(9301)
	check(randi()==before_random and randi()==after_random,'random pitch and volume use a dedicated RNG')
	check(field.viewport_3d.audio_listener_enable_3d and audio.spatial_voices.size()==4 and audio.spatial_voices[0].position==Vector3(-3,.15,7),'voice belongs to actual battle World3D and current camera listener')
	var pitches: Array[float]=[]
	for i in 40:
		audio._process(.11);audio.play_positional('hit',field,Vector2(i%7,7));pitches.append(audio.spatial_voices[0].pitch_scale)
	check(pitches.min()>=.94 and pitches.max()<=1.06 and pitches.min()!=pitches.max(),'pitch variation bounded and audible samples reused')
	for i in 200:
		var names: Array=GameAudioDirector.CUES.keys();audio._process(.01)
		if i%2==0:audio.play_positional(str(names[i%names.size()]),field,Vector2(i%7,7))
		else:audio.play_cue(str(names[i%names.size()]))
		if i%25==24:await process_frame
	check(audio.max_active_voices<=8 and field.world.get_child_count()==5,'UI and spatial burst share eight active voices and fixed four world nodes')
	audio.combat_paused=true
	check(not audio.play_positional('hit',field,Vector2.ZERO) and audio._spatial_until.max()<=audio._clock,'combat pause stops and rejects world contact sounds')
	audio.combat_paused=false;audio._process(1.0);audio.configure({'effects_volume':0.0},true)
	check(not audio.play_positional('skill',field,Vector2.ZERO),'combat volume opt-out rejects positional skill')
	audio.configure({},true);audio.set_suspended(true)
	check(not audio.play_positional('critical',field,Vector2.ZERO),'background rejects crit playback')
	var haptic:=HapticDirector.new();var pulses: Array=[]
	haptic.sink=func(duration: int,strength: float):pulses.append([duration,strength])
	check(not haptic.pulse('hit',0),'haptics preserve saved opt-out default')
	haptic.mode='light'
	check(haptic.pulse('hit',0) and not haptic.pulse('critical',10) and haptic.pulse('skill',600),'contact haptics bounded by common cooldown')
	haptic.suspended=true
	check(not haptic.pulse('gold',1200) and pulses.size()==2,'background haptics suppressed')
	audio.shutdown();audio.queue_free();field.queue_free();gold.queue_free();gem.queue_free();wallet.queue_free()
	await create_timer(.3).timeout
	print('final_reward_audio checks=%d failures=%s actual_haptic_device_test=false'%[checks,JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
