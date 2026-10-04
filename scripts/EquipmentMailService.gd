extends RefCounted
## Attachment ownership stays in equipment_overflow for existing save compatibility.
## Headers never own a second copy of equipment; receiving removes both atomically.
const SAFETY=preload('res://scripts/SaveSafety.gd')
const MAX_TIMESTAMP=4102444800

static func available(main: Node, reserve_raid:=true) -> int:
	var free: int=maxi(0,main.INVENTORY_CAP-main.loot_inventory.size())+maxi(0,main.GEAR_OVERFLOW_CAP-main.equipment_overflow.size())
	return maxi(0,free-(2 if reserve_raid and main.raid_running else 0))

static func header(item: Dictionary, raw: Variant=null) -> Dictionary:
	var source: Dictionary=raw if raw is Dictionary else {}
	var stamp: Variant=source.get('sent_at',0)
	var title: Variant=source.get('title','기존 보관 장비 이관')
	return {'sender':'원정대 보급소','title':title.substr(0,80) if title is String else '장비 배송',
		'sent_at':int(clampf(float(stamp),0,MAX_TIMESTAMP)) if typeof(stamp) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(stamp)) else 0,
		'attachment_id':str(item.get('id',''))}

static func sanitize_headers(items: Array, raw: Variant) -> Dictionary:
	var source: Dictionary=raw if raw is Dictionary else {}
	var result: Dictionary={}
	for item: Dictionary in items:
		var id:=str(item.get('id',''));result[id]=header(item,source.get(id))
	return result

static func deliver(main: Node, item: Dictionary, title: String='가방 초과 장비 배송') -> bool:
	if not SAFETY.mutation_error(main).is_empty() or main.equipment_overflow.size()>=main.GEAR_OVERFLOW_CAP-(2 if main.raid_running else 0):return false
	var id:=str(item.get('id',''))
	if id.is_empty():return false
	for owned: Dictionary in main.loot_inventory+main.equipment_overflow:
		if str(owned.get('id',''))==id:return false
	if title=='가방 초과 장비 배송':
		title='레이드 장비 배송' if str(item.get('origin',''))=='raid' else '사냥 장비 배송'
	main.equipment_overflow.append(item.duplicate(true))
	main.equipment_mail_headers[id]=header(item,{'title':title,'sent_at':int(Time.get_unix_time_from_system())})
	return true

static func pending_count(main: Node) -> int:
	var count:=0
	for value in main.pending_equipment_rolls.values():count+=int(value)
	return count

static func deliver_pending(main: Node, save:=true) -> int:
	if not SAFETY.mutation_error(main).is_empty():return 0
	var delivered:=0
	for zone_id in main.pending_equipment_rolls.keys():
		while int(main.pending_equipment_rolls.get(zone_id,0))>0 and delivered<32 and available(main)>0:
			main._roll_equipment_drop(main._zone_data()[zone_id])
			main.pending_equipment_rolls[zone_id]-=1;delivered+=1
		if int(main.pending_equipment_rolls.get(zone_id,0))<=0:main.pending_equipment_rolls.erase(zone_id)
	if delivered>0 and save:main._save_idle_state()
	return delivered

static func pause_hunt(main: Node) -> bool:
	if main.challenge_session!=null:return false
	deliver_pending(main)
	if not SAFETY.mutation_error(main).is_empty():return true
	if available(main)>=5:
		if bool(main.get_meta('equipment_mail_paused',false)):
			main.set_meta('equipment_mail_paused',false);main.hunt_event_text='우편 배송 공간 확보 · 사냥 재개'
		return false
	main.hunt_event_text='우편 배송 공간 부족 · 사냥 대기 · 가방에서 장비를 정리하세요'
	if not bool(main.get_meta('equipment_mail_paused',false)):
		main.set_meta('equipment_mail_paused',true)
		main._show_toast('사냥 보상을 잃지 않도록 대기합니다. 가방·우편의 빈칸을 5개 이상 확보하세요.')
		main._update_hunt_hud()
	return true
