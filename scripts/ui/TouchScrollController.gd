extends Node
## One gesture owner for all lists, including buttons that stop GUI propagation.
## Observe the GUI's actual hit target so modal shades and nested lists retain ownership.
var _scroll: ScrollContainer
var _pointer: int = -2
var _origin := Vector2.ZERO
var _initial := Vector2.ZERO
var _dragging := false
var _canceled := false
var _axis: int = 0
var _contacts: Dictionary = {}
var _suppress_mouse_release := false
var _emulated_press := false
var _blocked_contacts := false
var _gui_press_seen := false

func _ready() -> void:
	get_tree().node_added.connect(_watch)
	get_viewport().size_changed.connect(_cancel)
	_watch_tree(get_parent())
	set_process(false)

func _watch_tree(node: Node) -> void:
	_watch(node)
	for child in node.get_children(): _watch_tree(child)

func _watch(node: Node) -> void:
	if node is Control and get_parent().is_ancestor_of(node):
		var callback := _observe.bind(node)
		if not node.gui_input.is_connected(callback): node.gui_input.connect(callback)

func _list_for(control: Control) -> ScrollContainer:
	var node: Node = control
	while node != null and node != get_parent():
		# Sliders, text editing and scrollbar handles keep their own gestures.
		if node is Range or node is LineEdit or node is TextEdit or node is OptionButton or node is MenuButton: return null
		if node is ScrollContainer: return node
		node = node.get_parent()
	return null

func _observe(event: InputEvent, control: Control) -> void:
	var point := Vector2.ZERO
	var pointer: int = -2
	if event is InputEventScreenTouch and event.pressed:
		if _contacts.size() > 1: return
		point = control.get_global_transform_with_canvas() * event.position
		pointer = event.index
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = control.get_global_transform_with_canvas() * event.position
		pointer = -1
	else: return
	# Only the actual hit target can claim a press, never a bubbling ancestor.
	# This also keeps slider/text gestures and nested lists out of outer lists.
	var first_target := not _gui_press_seen
	_gui_press_seen = true
	var list := _list_for(control)
	if list == null: return
	if first_target and _pointer == -2:
		_scroll = list
		_pointer = pointer
		_emulated_press = event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION
		_origin = _scroll.get_global_transform_with_canvas().affine_inverse() * point
		_initial = Vector2(list.scroll_horizontal, list.scroll_vertical)
		_dragging = false
		_canceled = false
		_axis = 0
		set_process(true)
	# Stop native emulated-mouse scrolling; this controller handles real touch
	# positions once, while a normal short tap still reaches its button.
	if control is ScrollContainer and _scroll != null: control.accept_event()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_gui_press_seen = false
			_contacts[event.index] = true
			# Godot dispatches the emulated mouse press before the real touch.
			if _pointer == -1 and _emulated_press: _pointer = event.index
			if _pointer != -2 and _contacts.size() > 1:
				_blocked_contacts = true
				_cancel()
				get_viewport().set_input_as_handled()
			elif _blocked_contacts: get_viewport().set_input_as_handled()
		else:
			_contacts.erase(event.index)
			if _blocked_contacts:
				event.canceled = true
				if _contacts.is_empty():
					_blocked_contacts = false
					_finish()
				return
			if event.index == _pointer:
				_prepare_release(event.position, event.canceled)
				var consumed := _dragging or _canceled
				_suppress_mouse_release = consumed
				_finish()
				if consumed: event.canceled = true
			elif _canceled:
				event.canceled = true
			if _contacts.is_empty() and _canceled: _finish()
	elif event is InputEventScreenDrag:
		if _blocked_contacts: get_viewport().set_input_as_handled()
		elif event.index == _pointer:
			_move(event.position)
		elif _pointer != -2 and _canceled: get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _pointer >= 0 or _blocked_contacts:
			# Android also emits a mouse motion for finger zero.
			if event.device == InputEvent.DEVICE_ID_EMULATION: get_viewport().set_input_as_handled()
		elif _pointer == -1:
			if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				_cancel(); _finish()
			else: _move(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _gui_press_seen = false
		if event.device == InputEvent.DEVICE_ID_EMULATION and _blocked_contacts:
			if event.pressed: get_viewport().set_input_as_handled()
			else: event.canceled = true
		elif event.device == InputEvent.DEVICE_ID_EMULATION and _pointer >= 0 and not event.pressed:
			_prepare_release(event.position, event.canceled)
			if _dragging or _canceled: event.canceled = true
		elif event.pressed:
			_suppress_mouse_release = false
		elif event.device == InputEvent.DEVICE_ID_EMULATION and _suppress_mouse_release:
			_suppress_mouse_release = false
			event.canceled = true
		elif _pointer == -1:
			_prepare_release(event.position, event.canceled)
			var consumed := _dragging or _canceled
			_finish()
			if consumed: event.canceled = true

func _move(point: Vector2) -> void:
	if not _valid_owner(): _cancel()
	if _canceled:
		get_viewport().set_input_as_handled()
		return
	var local := _scroll.get_global_transform_with_canvas().affine_inverse() * point
	var delta := local - _origin
	if not _dragging:
		if delta.length() < maxf(10.0, _scroll.scroll_deadzone): return
		_dragging = true
		var horizontal := _scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
		var vertical := _scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
		_axis = 1 if horizontal and (not vertical or absf(delta.x) > absf(delta.y)) else 2
		_scroll.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
		_scroll.scroll_started.emit()
	if _axis == 1: _scroll.scroll_horizontal = roundi(_initial.x - delta.x)
	else: _scroll.scroll_vertical = roundi(_initial.y - delta.y)
	get_viewport().set_input_as_handled()

func _valid_owner() -> bool:
	if not is_instance_valid(_scroll) or not _scroll.is_inside_tree() or not _scroll.is_visible_in_tree(): return false
	var node: Node = _scroll
	while node != null:
		if node.is_queued_for_deletion(): return false
		node = node.get_parent()
	return true

func _prepare_release(point: Vector2, canceled: bool) -> void:
	if canceled or not _valid_owner():
		_cancel()
	elif not _dragging:
		var local := _scroll.get_global_transform_with_canvas().affine_inverse() * point
		# A dropped motion event must not turn a displaced release into a purchase.
		if local.distance_to(_origin) >= maxf(10.0, _scroll.scroll_deadzone): _cancel()

func _process(_delta: float) -> void:
	if not _valid_owner(): _cancel()

func _cancel() -> void:
	if _pointer == -2: return
	_canceled = true
	_suppress_mouse_release = true
	if is_instance_valid(_scroll):
		_scroll.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	set_process(false)

func _finish() -> void:
	if is_instance_valid(_scroll) and _dragging:
		_scroll.propagate_notification(Control.NOTIFICATION_SCROLL_END)
		_scroll.scroll_ended.emit()
	_scroll = null
	_pointer = -2
	_dragging = false
	_canceled = false
	set_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_cancel()
		_contacts.clear()
		_blocked_contacts = false
		_finish()
