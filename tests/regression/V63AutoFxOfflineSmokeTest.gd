extends SceneTree
const HERO_KITS:=preload('res://scripts/heroes/HeroKitRuntime.gd')
var checks:=0
var failures: Array[String]=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error('V63 '+message)
func _initialize() -> void:run.call_deferred()
func settle() -> void:
	for i in 5:await process_frame

func run() -> void:
	root.content_scale_size=Vector2i(720,1280);root.size=Vector2i(720,1280)
	var main:=preload('res://scenes/PortraitMain.tscn').instantiate()
	main.save_state_path='user://v63-auto-fx-offline.json'
	root.add_child(main);await settle()
	main.set_physics_process(false)
	main.selected_faction='aurelia';main._restore_deployed_heroes(['leonhardt','mira','elisia'])
	main._build_combat_screen();await settle()
	var hud: Control=main.portrait_hud
	check(hud.get_node_or_null('PortraitClaimRewards')==null and hud.offline_button.disabled,'ordinary hunt has no claim button')
	check(hud.skill_button.get_rect().end.y<hud.auto_button.get_rect().position.y and hud.ultimate_button.get_rect().end.y<hud.auto_button.get_rect().position.y,'separate auto buttons fit above hunt controls')
	check(hud.reward_feed.get_rect().end.y<hud.skill_button.get_rect().position.y,'reward feed leaves auto buttons unobstructed')
	main._cycle_battle_speed()
	check(main.battle_speed==2.0,'2x is available')
	main._cycle_battle_speed()
	check(main.battle_speed==1.0,'3x is absent')
	main._toggle_skill_auto();main._toggle_ultimate_auto();hud.refresh()
	check(not main.skill_auto and not main.ultimate_auto and '끔' in hud.skill_button.text and '끔' in hud.ultimate_button.text,'buttons independently turn off and reflect status')
	check(HERO_KITS.preferred_slot(main,'mira')=='basic' and not main._should_use_skill('mira') and not main._should_use_ultimate('mira'),'disabled automation never schedules active casts')
	main._toggle_skill_auto();main._toggle_ultimate_auto()
	var fx_profile: Dictionary={'slot':'a1','fx_targets':[]}
	main._emit_skill_cast_fx('mira',-1,false,fx_profile)
	var clip: Control=main.skill_fx_layer.get_node_or_null('HeroSkillClip')
	check(clip!=null and clip.get_child_count()>0,'skill effect uses bounded combat clip')
	if clip!=null:
		var signature: Control=clip.get_child(0)
		check(signature.position==Vector2.ZERO and signature.source==main._hero_skill_fx_position('mira')-clip.position,'skill art uses one field origin, never a doubled offset')
		check(clip.get_node_or_null('PortraitSkillBurst')!=null,'cast accent is clipped together with skill art')
	# Online settlement is a real killed pack; the same encounter cannot pay twice.
	main.enemy_wave=[{'hp':0,'max_hp':10,'habitat_pack':0}]
	main.hunt_ai.encounter_id+=1;main.hunt_ai.set_state(AutoHuntController.State.FIGHTING)
	var before_gold: int=main.wallet_gold
	var before_xp: int=main.wallet_xp
	main._finish_hunt_target()
	check(main.wallet_gold>before_gold and main.wallet_xp>before_xp and main.unclaimed_gold==0 and main.unclaimed_xp==0,'online hunt credits currency and account XP without a claim')
	var earned: int=main.wallet_gold
	main._finish_hunt_target()
	check(main.wallet_gold==earned,'duplicate kill callback cannot pay again')
	main.offline_reward_gold=120;main.offline_reward_xp=36;main.offline_reward_seconds=600
	main.unclaimed_gold+=120;main.unclaimed_xp+=36
	main._on_offline_hunt_reward(120,36,44,16)
	main.idle_chest_gold+=44;main.idle_chest_xp+=16
	main._save_idle_state();hud.refresh()
	var xp_before_claim: int=main.wallet_xp
	check(not hud.offline_button.disabled and main.wallet_gold==earned,'offline proceeds stay separate until receipt')
	main._load_idle_state()
	check(main.offline_pending_gold==120 and main.offline_pending_chest_gold==44 and main.wallet_gold==earned,'restart retains only claimable offline proceeds')
	main._show_offline_reward_popup()
	var confirm: Button=main.content_root.find_child('DialogConfirm',true,false)
	check(confirm!=null and confirm.text=='오프라인 사냥 받기','offline receipt is a named action')
	if confirm!=null:confirm.pressed.emit()
	check(main.wallet_gold==earned+164 and main.wallet_xp==xp_before_claim+52,'offline button pays gold and XP once')
	check(main.offline_pending_gold==0 and main.offline_pending_chest_gold==0 and main.unclaimed_gold==0 and main.idle_chest_gold==0,'claim clears only offline buckets')
	main._claim_offline_rewards()
	check(main.wallet_gold==earned+164,'repeated claim is idempotent')
	main.battle_speed=3.0
	main.skill_auto=false;main.ultimate_auto=true
	main._save_idle_state()
	main._load_idle_state()
	check(main.battle_speed==2.0 and not main.skill_auto and main.ultimate_auto,'old 3x saves become 2x and auto choices survive reload')
	main.enemy_wave=[{'hp':0,'max_hp':10,'habitat_pack':0}]
	main.hunt_ai.encounter_id+=1;main.hunt_ai.set_state(AutoHuntController.State.FIGHTING)
	main.idle_stage_kills=main.idle_stage_target-1
	var stage_gold: int=250+main.idle_stage*50
	var gold_before_stage: int=main.wallet_gold
	main._finish_hunt_target()
	check(main.wallet_gold>=gold_before_stage+stage_gold and main.idle_chest_gold==0 and main.idle_chest_xp==0,'online stage chest pays immediately without a hidden claim')
	main.free()
	print('v63_auto_fx_offline ',checks-failures.size(),'/',checks,' pass')
	quit(0 if failures.is_empty() else 1)
