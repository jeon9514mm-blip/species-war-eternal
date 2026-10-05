extends RefCounted
## The UI confirms a fixed budget and exact loadout; execution revalidates both.
const DIALOG=preload('res://scripts/RewardDialogs.gd')
const SKIN=preload('res://scripts/portrait/PortraitSkin.gd')
static func preview(main, budget: int) -> Dictionary:
	var rows: Array=[];var spent:=0
	var roster: Array=main.deployed_heroes if not main.deployed_heroes.is_empty() else main._hero_roster_for_faction().slice(0,3)
	var available:=mini(maxi(0,budget),maxi(0,main.wallet_gold))
	for hero in roster:
		var id:=str(hero.get('id',''))
		if not main._valid_growth_hero(id):continue
		for slot in ['weapon','armor','accessory']:
			var item: Dictionary=main._gear_item('',id,slot).duplicate(true)
			var level:=int(item.get('level',1))
			if level>=10:continue
			var cost: int=main._inventory_upgrade_cost(item)
			if spent+cost>available:continue
			spent+=cost;rows.append({'id':id,'slot':slot,'item':item,'cost':cost})
	return {'rows':rows,'cost':spent,'budget':maxi(0,budget)}
static func execute(main, plan: Dictionary) -> Dictionary:
	var error: String=preload('res://scripts/SaveSafety.gd').mutation_error(main)
	if not error.is_empty():return {'ok':false,'reason':error}
	var current:=preview(main,int(plan.get('budget',0)))
	if current!=plan:return {'ok':false,'reason':'장비나 골드가 변경되어 비용을 다시 계산했어요.'}
	if current.rows.is_empty():return {'ok':false,'reason':'예산 안에서 강화할 장비가 없어요.'}
	for row in current.rows:
		var item: Dictionary=row.item.duplicate(true)
		item.level=int(item.level)+1;item.power=main._item_power(item)
		main._get_hero_equipment(str(row.id))[row.slot]=item.level
		main.hero_equipment_items.get_or_add(str(row.id),{})[row.slot]=item
	main.wallet_gold-=int(current.cost)
	main._refresh_growth_runtime();main._record_first_session_action('growth');main._save_idle_state()
	main._presentation_event('upgrade')
	return {'ok':true,'cost':int(current.cost),'count':current.rows.size()}
static func show(main) -> void:
	if not preload('res://scripts/SaveSafety.gd').allow_mutation(main):return
	var modal: Dictionary=DIALOG._modal(main,'BulkEnhancePreview','BulkEnhanceShade',Vector2(620,330))
	var panel: Panel=modal.panel
	DIALOG._heading(main,panel,'장착 장비 일괄 강화',Rect2(24,20,572,34),24,SKIN.INK)
	var info: Label=DIALOG._heading(main,panel,'',Rect2(24,112,572,86),18,SKIN.INK,true)
	info.name='BulkEnhanceCost'
	var option:=OptionButton.new();option.name='BulkEnhanceBudget';option.add_item('골드 25% 이내');option.add_item('골드 50% 이내');option.add_item('현재 골드 이내');option.selected=1
	SKIN.place(panel,option,Rect2(24,66,572,44))
	var plans: Array=[{}]
	var update:=func(_index: int):
		var factor: float=[.25,.5,1.0][option.selected]
		plans[0]=preview(main,int(main.wallet_gold*factor))
		var confirm: Button=panel.find_child('DialogConfirm',true,false)
		if confirm!=null:confirm.disabled=plans[0].rows.is_empty()
		info.text='%d개 장비 · 총 %dG\n강화 후 %dG · 각 장비 +1'%[plans[0].rows.size(),plans[0].cost,main.wallet_gold-int(plans[0].cost)]
	option.item_selected.connect(update);update.call(1)
	var cancel:=SKIN.button('취소',func():
		for control in [modal.panel,modal.overlay]:control.hide();control.queue_free())
	cancel.name='BulkEnhanceCancel';SKIN.place(panel,cancel,Rect2(24,246,168,52))
	DIALOG._confirm(main,modal,'표시한 비용으로 강화',Rect2(204,246,392,52),func():
		var result:=execute(main,plans[0])
		if not result.ok:main._show_toast(str(result.reason));show(main);return
		main._show_toast('%d개 강화 · %dG 사용'%[result.count,result.cost])
		if main.active_screen not in ['combat','raid']:main._build_inventory_screen()
		else:main._update_reward_labels())
	update.call(option.selected)
