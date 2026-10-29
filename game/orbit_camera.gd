class_name OrbitCamera
extends Camera3D
## Orbit around a fixed target, including over the poles, without look_at singularities.
## Only receives events forwarded into the game's SubViewport; shop input stays outside.

signal view_changed
signal tap_requested(screen_position: Vector2)

const MIN_ZOOM_RATIO := 0.2
const MAX_ZOOM_RATIO := 2.5
const ROTATION_SPEED := 0.005
const DRAG_THRESHOLD := 10.0
const DEFAULT_PITCH := -0.6747409422 # -atan(0.8)

var pivot := Vector3.ZERO
var _orientation := Quaternion(Vector3.RIGHT, DEFAULT_PITCH)
var _fit_distance: float = 76.0
var _zoom_ratio: float = 1.0
var _mouse_button: int = 0
var _touches: Dictionary = {} # finger index -> most recent position
var _touch_origin := Vector2.ZERO
var _touch_moved: bool = false
var _multiple_touches: bool = false


func fit_to_extent(extent: float, viewport_size: Vector2) -> void:
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var vertical_half_angle := deg_to_rad(fov) * 0.5
	var horizontal_half_angle := atan(tan(vertical_half_angle) * maxf(aspect, 0.1))
	_fit_distance = maxf(extent, 1.0) * 1.07 / sin(minf(vertical_half_angle, horizontal_half_angle))
	far = _fit_distance * MAX_ZOOM_RATIO + extent * 2.0
	_apply_pose()


func rotate_view(delta_pixels: Vector2) -> void:
	_orientation = (Quaternion(Vector3.UP, -delta_pixels.x * ROTATION_SPEED)
		* _orientation * Quaternion(Vector3.RIGHT, -delta_pixels.y * ROTATION_SPEED)).normalized()
	_apply_pose()


func zoom_by(factor: float) -> void:
	if not is_finite(factor) or factor <= 0.0:
		return
	_zoom_ratio = clampf(_zoom_ratio * factor, MIN_ZOOM_RATIO, MAX_ZOOM_RATIO)
	_apply_pose()


func reset_view() -> void:
	_orientation = Quaternion(Vector3.RIGHT, DEFAULT_PITCH)
	_zoom_ratio = 1.0
	cancel_gestures()
	_apply_pose()


func get_zoom_ratio() -> float:
	return _zoom_ratio


func get_orbit_distance() -> float:
	return _fit_distance * _zoom_ratio


func get_view_rotation() -> Quaternion:
	return _orientation


func _apply_pose() -> void:
	quaternion = _orientation
	position = pivot + _orientation * Vector3.BACK * get_orbit_distance()
	h_offset = 0.0
	v_offset = 0.0
	view_changed.emit()


func _input(event: InputEvent) -> void:
	# Raw touches below handle both tap and orbit. Ignore their emulated mouse events.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		_touch(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_touch_drag(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_button = event.button_index if event.pressed else 0
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(pow(0.9, maxf(event.factor, 1.0)))
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(pow(1.0 / 0.9, maxf(event.factor, 1.0)))
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _mouse_button != 0:
		var mask := MOUSE_BUTTON_MASK_MIDDLE if _mouse_button == MOUSE_BUTTON_MIDDLE else MOUSE_BUTTON_MASK_RIGHT
		if event.button_mask & mask:
			rotate_view(event.relative)
			get_viewport().set_input_as_handled()
		else:
			# Release can happen outside the SubViewport or over the shop.
			_mouse_button = 0


func _touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _touches.is_empty():
			_touch_origin = event.position
			_touch_moved = false
			_multiple_touches = false
		_touches[event.index] = event.position
		if _touches.size() > 1:
			_multiple_touches = true
		return
	if not _touches.has(event.index):
		return
	var is_tap := (not event.canceled and not _multiple_touches and not _touch_moved
		and event.position.distance_to(_touch_origin) < DRAG_THRESHOLD)
	_touches.erase(event.index)
	if is_tap:
		tap_requested.emit(event.position)


func _touch_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	var previous: Vector2 = _touches[event.index]
	if _touches.size() == 1:
		_touches[event.index] = event.position
		if event.position.distance_to(_touch_origin) >= DRAG_THRESHOLD:
			_touch_moved = true
		if _touch_moved:
			rotate_view(event.position - previous)
	elif _touches.size() == 2:
		var other_index: int = _touches.keys()[0]
		if other_index == event.index:
			other_index = _touches.keys()[1]
		var other: Vector2 = _touches[other_index]
		var old_distance := previous.distance_to(other)
		var new_distance := event.position.distance_to(other)
		_touches[event.index] = event.position
		if old_distance > 1.0 and new_distance > 1.0:
			zoom_by(old_distance / new_distance)
	else:
		_touches[event.index] = event.position


func cancel_gestures() -> void:
	_mouse_button = 0
	_touches.clear()
	_touch_moved = false
	_multiple_touches = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		cancel_gestures()
