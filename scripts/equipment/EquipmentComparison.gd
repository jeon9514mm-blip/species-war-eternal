extends RefCounted
## Read-only previews use the same item, set and capped affix rules as combat.
const RULES=preload('res://scripts/equipment/EquipmentRules.gd')
const EFFECTS={'attack_mult':'세트 공격력','hp_mult':'세트 체력','defense_bonus':'세트 방어력','haste_pct':'세트 공격 속도','ultimate_pct':'세트 궁극기 충전'}

static func selected_hero(main: Node) -> String:
	var remembered:=str(main.get_meta('gear_equip_hero_id',''))
	if main._valid_growth_hero(remembered):return remembered
	var roster: Array=main.deployed_heroes if not main.deployed_heroes.is_empty() else main._hero_roster_for_faction()
	for hero: Dictionary in roster:
		if int(hero.get('unlock_stage',1))<=main.idle_stage:return str(hero.get('id',''))
	return ''

static func preview(main: Node, item: Dictionary, hero_id: String) -> Dictionary:
	if str(item.get('item_type','equipment'))!='equipment' or not main._valid_growth_hero(hero_id):return {}
	var slot:=str(item.get('slot','weapon'))
	var old: Dictionary=main._gear_item('',hero_id,slot)
	var sets: Dictionary=main._get_hero_equipment_sets(hero_id).duplicate()
	var before_set:=RULES.set_profile(sets)
	sets[slot]=str(item.get('set','초보자'))
	var after_set:=RULES.set_profile(sets)
	var before_items: Array=[];var after_items: Array=[]
	for equipped_slot: String in main.EQUIPMENT_SLOTS:
		var equipped: Dictionary=main._gear_item('',hero_id,equipped_slot)
		before_items.append(equipped);after_items.append(item if equipped_slot==slot else equipped)
	var before_options:=RULES.affix_profile(before_items)
	var after_options:=RULES.affix_profile(after_items)
	var changes: Array=[];var loss:=false
	for key: String in EFFECTS:
		var a: float=before_set[key];var b: float=after_set[key]
		if is_equal_approx(a,b):continue
		loss=loss or b<a
		var percent:=key!='defense_bonus'
		if key.ends_with('_mult'):a=(a-1.0)*100.0;b=(b-1.0)*100.0
		changes.append({'label':EFFECTS[key],'before':roundi(a),'after':roundi(b),'percent':percent})
	for key: String in RULES.STAT_NAMES:
		if before_options[key]==after_options[key]:continue
		changes.append({'label':RULES.STAT_NAMES[key],'before':before_options[key],'after':after_options[key],'percent':key!='defense'})
	var before: int=main._item_power(old);var after: int=main._item_power(item)
	return {'old':old,'before':before,'after':after,'delta':after-before,'compatible':main._gear_role_matches(item,hero_id),'changes':changes,'set_loss':loss,'before_set':before_set.summary,'after_set':after_set.summary}

static func change_text(change: Dictionary) -> String:
	var unit:='%' if bool(change.percent) else ''
	return '%s  %d%s → %d%s'%[change.label,int(change.before),unit,int(change.after),unit]
