extends SceneTree
## Collection controls stay usable after the portrait page is reconstructed.
var checks := 0
var failures: Array[String]=[]

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		push_error('V66 UI: '+message)

func _settle() -> void:
	for frame in 7:await process_frame

func _run() -> void:
	root.content_scale_size=Vector2i(720,1280)
	root.size=Vector2i(720,1280)
	var game:=preload('res://scenes/PortraitMain.tscn').instantiate()
	game.save_state_path='user://v66-ui-filter.json'
	root.add_child(game)
	await _settle()
	game.set_physics_process(false)
	game._offline_checked=true
	game.selected_faction='aurelia'
	game._guardian_ensure_starter()
	game.set_meta('summon_mode','guardian')
	game._build_summon_screen()
	await _settle()
	var scroll: ScrollContainer=game.content_root.get_node('PortraitContentScroll')
	check(scroll.get_v_scroll_bar().max_value>scroll.size.y,'guardian collection is scrollable')
	check(scroll.scroll_deadzone==8 and scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,'page uses native vertical scrolling')
	var filter: OptionButton=game.content_root.find_child('GuardianCollectionFilter',true,false)
	check(filter!=null and filter.item_count==8,'collection exposes ownership and tier filters')
	var all_count: int=game.content_root.find_children('GuardianEquip_*','Button',true,false).size()
	filter.item_selected.emit(1)
	await _settle()
	var owned_count: int=game.content_root.find_children('GuardianEquip_*','Button',true,false).size()
	check(owned_count>0 and owned_count<all_count,'owned filter narrows the collection')
	filter=game.content_root.find_child('GuardianCollectionFilter',true,false)
	check(filter.selected==1,'selected filter survives page rebuild')
	filter.item_selected.emit(0)
	await _settle()
	check(game.content_root.find_children('GuardianEquip_*','Button',true,false).size()==all_count,'all filter restores the full collection')
	game.free()
	print('V66 UI ',checks-failures.size(),'/',checks,' PASS')
	quit(0 if failures.is_empty() else 1)
