extends 'res://tests/support/V83UpgradeTestBase.gd'
const MAIL=preload('res://scripts/equipment/EquipmentMailService.gd')
class CountingStore extends SaveStore:
	var writes:=0
	var fail:=false
	func write_save(path: String, data: Dictionary) -> Dictionary:
		writes+=1
		return {'ok':false,'status':'mail_injected_failure'} if fail else super.write_save(path,data)
var main: Node
var store: CountingStore
func _init() -> void:run.call_deferred()
func gear(id: String, locked:=false) -> Dictionary:
	return main.GEAR.normalize({'id':id,'name':'우편 검증 장비','slot':'weapon','rarity':'일반','level':1,'origin':'hunt','locked':locked})
func fixture(mail_count: int, bag_count:=200) -> void:
	main.equipment_overflow=[];main.loot_inventory=[];main.equipment_mail_headers={};main.pending_equipment_rolls={}
	main.auto_salvage_min_rarity='일반';main.gear_auto_equip=false;main.raid_running=false
	main.set_meta('game_save_pending',false);main.set_meta('equipment_mail_paused',false)
	for i in bag_count:main.loot_inventory.append(gear('bag-%04d'%i))
	for i in mail_count:main.equipment_overflow.append(gear('mail-%04d'%i,true))
func snapshot() -> Dictionary:
	return {'bag':main.loot_inventory.duplicate(true),'mail':main.equipment_overflow.duplicate(true),
		'headers':main.equipment_mail_headers.duplicate(true),'pending':main.pending_equipment_rolls.duplicate(true),
		'gold':main.wallet_gold,'rng':main.loot_rng.state,'writes':store.writes,'crystals':main.raid_crystals}
func rules() -> void:
	fixture(2999)
	var bag: Array=main.loot_inventory.duplicate(true);var gold: int=main.wallet_gold
	check(main._store_or_salvage_loot(gear('overflow-common'))=='우편함으로 배송','all ordinary overflow goes to equipment mail')
	check(main.equipment_overflow.size()==3000 and main.loot_inventory==bag and main.wallet_gold==gold,'overflow never replaces or salvages existing bag gear')
	var header: Dictionary=main.equipment_mail_headers['overflow-common']
	check(header.sent_at>0 and header.sender=='원정대 보급소' and header.title=='사냥 장비 배송' and header.attachment_id=='overflow-common','new mail has durable sender reason time and attachment identity')
	var before:=snapshot()
	check(not MAIL.deliver(main,gear('over-cap',true)) and snapshot()==before,'hard mail cap rejects admission without currency or item mutation')
	for producer: String in ['hunt','raid','guaranteed']:
		before=snapshot();var result: Dictionary={}
		if producer=='hunt':result=main._roll_equipment_drop(main._current_zone())
		if producer=='raid':result=main._roll_raid_equipment(main._current_zone())
		if producer=='guaranteed':result=main._v77_guaranteed_hunt_drop(main._current_zone(),'검증')
		check(result.is_empty() and snapshot()==before,'full mail blocks RNG before '+producer+' generation')
	main.auto_salvage_min_rarity='희귀';gold=main.wallet_gold
	main._store_or_salvage_loot(gear('configured-salvage'))
	check(main.wallet_gold>gold and main.equipment_overflow.size()==3000,'explicit auto salvage preference still applies')
	fixture(1,0);before=snapshot()
	check(not MAIL.deliver(main,gear('mail-0000')) and snapshot()==before,'duplicate mail ID cannot own a second attachment')
	var original: Dictionary=main.equipment_overflow[0].duplicate(true)
	main.equipment_mail_headers=MAIL.sanitize_headers(main.equipment_overflow,{})
	check(main.equipment_mail_headers['mail-0000'].sent_at==0 and main.equipment_mail_headers['mail-0000'].title=='기존 보관 장비 이관','migration preserves unknown arrival date without fake expiration')
	check(main._gear_claim_overflow('mail-0000').ok and main.loot_inventory==[original] and main.equipment_mail_headers.is_empty(),'receipt removes mail and header but retains exact attachment once')
	main._load_idle_state()
	check(main.loot_inventory==[original] and main.equipment_overflow.is_empty() and main.equipment_mail_headers.is_empty(),'received mail stays received after disk reload')
	fixture(3002);main._save_idle_state();main._load_idle_state()
	check(main.equipment_overflow.size()==3002 and main.equipment_mail_headers.size()==3002,'legacy over-cap mail is retained on real save reload')
	before=snapshot();check(not MAIL.deliver(main,gear('legacy-over-cap')) and snapshot()==before,'legacy over-cap inbox admits nothing until below the limit')
	var clean: Dictionary=SaveValidation.sanitize({'equipment_overflow':[gear('clean')],'equipment_mail_headers':{'clean':{'sent_at':-123,'title':42},'orphan':{'sent_at':23}},'pending_equipment_rolls':{'gray_meadow':3,'bad-zone':9,'forgotten_mine':-1}},['gray_meadow'])
	check(clean.equipment_mail_headers.size()==1 and clean.equipment_mail_headers.clean.sent_at==0 and clean.equipment_mail_headers.clean.title=='장비 배송','malformed and orphan mail headers are repaired')
	check(clean.pending_equipment_rolls=={'gray_meadow':3},'pending loot validation rejects unknown zones and negative counts')
func pending_rewards() -> void:
	fixture(3000);main._offline_checked=false;main.last_idle_timestamp=int(Time.get_unix_time_from_system())-28800
	var rng: int=main.loot_rng.state
	main._calculate_offline_reward()
	check(main.offline_gear_rolls>0 and int(main.pending_equipment_rolls.get('gray_meadow',0))==main.offline_gear_rolls and main.loot_rng.state==rng,'real capped offline calculation persists blocked equipment without rolling or dropping it')
	var offline: Dictionary=snapshot();main._calculate_offline_reward()
	check(snapshot()==offline,'repeating offline calculation cannot duplicate pending equipment entitlement')
	fixture(3000);main.pending_equipment_rolls={'gray_meadow':3}
	var before:=snapshot()
	check(MAIL.deliver_pending(main)==0 and snapshot()==before,'offline loot entitlement waits intact when full')
	main._save_idle_state();main._load_idle_state()
	check(main.pending_equipment_rolls=={'gray_meadow':3},'unrolled offline rewards persist across app reload')
	main.loot_inventory.resize(197);var writes: int=store.writes
	check(MAIL.deliver_pending(main)==3 and main.pending_equipment_rolls.is_empty(),'offline loot entitlement delivers after storage is cleared')
	check(main.loot_inventory.size()<=200 and main.equipment_overflow.size()==3000 and store.writes==writes+1,'pending rolls respect capacity and commit once')
	before=snapshot();check(MAIL.deliver_pending(main)==0 and snapshot()==before,'pending receipt cannot replay')
	fixture(3000);main.pending_equipment_rolls={'gray_meadow':2};main.loot_inventory.resize(198);store.fail=true
	check(MAIL.deliver_pending(main)==2 and main.pending_equipment_rolls.is_empty() and main.get_meta('game_save_pending',false),'failed pending save retains consumed receipt in memory')
	before=snapshot();check(MAIL.deliver_pending(main)==0 and snapshot()==before,'failed save bars repeated offline loot generation')
	store.fail=false;main._retry_pending_save();check(not main.get_meta('game_save_pending',false),'pending mail result can retry storage')
	main._load_idle_state();check(main.pending_equipment_rolls.is_empty(),'successful retry persists consumed entitlement')
func hunt_and_raid() -> void:
	fixture(3000);main._build_combat_screen();await settle();main.combat_running=true
	var before:=snapshot();var clock: float=main.invasion.clock;var hp: Dictionary=main.hero_battle_state.duplicate(true)
	main._advance_auto_hunt(.2)
	check(snapshot()==before and main.invasion.clock==clock and main.hero_battle_state==hp,'full inbox freezes hunt clock HP rewards and RNG')
	check(main.get_meta('equipment_mail_paused',false) and main.hunt_event_text.contains('우편'),'paused hunt explains the action needed')
	main.loot_inventory.resize(195);main._advance_auto_hunt(.01)
	check(not main.get_meta('equipment_mail_paused',false) and main.invasion.clock>clock,'freeing safe delivery budget resumes existing hunt')
	fixture(2999,190);main._build_raid_screen();await settle();before=snapshot()
	main._start_raid();check(not main.raid_running and snapshot()==before,'raid refuses entry before rewards if two mail slots cannot be reserved')
	fixture(2998);main.raid_running=true;before=snapshot()
	check(MAIL.available(main)==0 and not MAIL.deliver(main,gear('steal-reservation')) and snapshot()==before,'other equipment producers cannot consume raid mail reservation')
	main.raid_running=false
	check(MAIL.deliver(main,gear('raid-slot-1')) and MAIL.deliver(main,gear('raid-slot-2')) and main.equipment_overflow.size()==3000,'released raid reservation holds both settlement attachments')
	# A producer must check the same reservation as the delivery service before
	# rolling an item. Otherwise it reports a reward that owns no storage slot.
	for producer: String in ['hunt','guaranteed']:
		fixture(2998);main.raid_running=true;before=snapshot()
		var result: Dictionary=main._roll_equipment_drop(main._current_zone()) if producer=='hunt' else main._v77_guaranteed_hunt_drop(main._current_zone(),'예약 검증')
		check(result.is_empty() and snapshot()==before,'raid reservation blocks '+producer+' before loot RNG and ownership changes')
	main.raid_running=false
	var wave=preload('res://scripts/hunting/InvasionWaveState.gd').new();var id: int=wave.register({})
	var members: Array=[]
	for i in 20:members.append({'corps_id':id,'habitat_pack':i/5,'hp':0})
	check(wave.take_finished(members,4).is_empty() and wave.groups.has(id),'insufficient budget leaves defeated corps receipt unconsumed')
	check(wave.take_finished(members,5).size()==1 and wave.take_finished(members,5).is_empty(),'deferred corps settles once after space is available')
func run() -> void:
	main=await make_main('aurelia',3);store=CountingStore.new();main.save_store=store
	rules();pending_rewards();await hunt_and_raid()
	await dispose(main);done('equipment_mail')
