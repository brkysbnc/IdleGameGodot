class_name GameDebugPanel
extends PanelContainer
## B10. Fast mode advances the same economy/clicker functions as the live timers.
## Engine.time_scale alone would NOT accelerate Economy, which uses a real-time clock.

var orbit_manager: Node3D
var fast_mode: bool = false
var _speed_button: Button
var _stats: Label
var _confirmation: ConfirmationDialog
var _refresh_timer: Timer
var _tap_count: int = 0
var _last_tap_msec: int = 0


func _ready() -> void:
	if not OS.is_debug_build():
		set_process(false)
		set_process_unhandled_key_input(false)
		queue_free()
		return
	custom_minimum_size.x = 620
	var column := VBoxContainer.new()
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := GameTheme.label("Geliştirici araçları", 34, GameTheme.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := _button("Kapat", hide)
	header.add_child(close_button)
	_stats = GameTheme.label("", 28, GameTheme.MUTED)
	column.add_child(_stats)
	column.add_child(_button("+1.000 yıldız tozu", func() -> void: add_money(1000.0)))
	column.add_child(_button("+1.000.000 yıldız tozu", func() -> void: add_money(1000000.0)))
	_speed_button = _button("Oyun hızı: ×1", func() -> void: set_fast_mode(not fast_mode))
	column.add_child(_speed_button)
	column.add_child(_button("500 gök cismiyle dene", populate_orbits))
	column.add_child(_button("İlerlemeyi sıfırla…", _ask_reset))
	_confirmation = ConfirmationDialog.new()
	_confirmation.title = "İlerleme sıfırlansın mı?"
	_confirmation.dialog_text = "Para, gök cisimleri ve yükseltmeler sıfırlanacak."
	_confirmation.ok_button_text = "Sıfırla"
	_confirmation.cancel_button_text = "Vazgeç"
	_confirmation.get_ok_button().custom_minimum_size = Vector2(180, 96)
	_confirmation.get_cancel_button().custom_minimum_size = Vector2(180, 96)
	_confirmation.confirmed.connect(reset_progress)
	add_child(_confirmation)
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 0.5
	_refresh_timer.timeout.connect(_update_stats)
	add_child(_refresh_timer)
	_refresh_timer.start()
	visibility_changed.connect(_update_stats)
	hide()
	set_process(false)


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 96)
	button.pressed.connect(action)
	return button


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


func register_corner_tap() -> void:
	if not OS.is_debug_build():
		return
	var now := Time.get_ticks_msec()
	_tap_count = _tap_count + 1 if now - _last_tap_msec <= 600 else 1
	_last_tap_msec = now
	if _tap_count >= 5:
		_tap_count = 0
		toggle()


func toggle() -> void:
	if OS.is_debug_build():
		visible = not visible


func add_money(amount: float) -> void:
	if OS.is_debug_build() and amount > 0.0:
		GameState.add_currency(BigNumber.from_float(amount))


func set_fast_mode(enabled: bool) -> void:
	fast_mode = enabled and OS.is_debug_build()
	set_process(fast_mode)
	_speed_button.text = "Oyun hızı: ×10" if fast_mode else "Oyun hızı: ×1"


func _process(delta: float) -> void:
	if not OS.is_debug_build() or not fast_mode:
		return
	# Use short slices to respect each system's catch-up cap without losing x10 time.
	var remaining := minf(delta, 0.25) * 9.0
	while remaining > 0.0:
		var step := minf(remaining, 0.1)
		Economy.process_elapsed(step)
		for child in UpgradeSystem.get_children():
			if child.has_method("process_elapsed"):
				child.call("process_elapsed", step)
		if is_instance_valid(orbit_manager):
			orbit_manager.call("step", step)
		remaining -= step


func populate_orbits() -> void:
	if not OS.is_debug_build():
		return
	for data in GameData.orbiters():
		var missing := 100 - GameState.get_orbiter_count(data.id)
		if missing > 0:
			GameState.add_orbiter(data.id, missing)


func _ask_reset() -> void:
	_confirmation.popup_centered(Vector2i(720, 360))


func reset_progress() -> void:
	if not OS.is_debug_build():
		return
	set_fast_mode(false)
	UpgradeSystem.deserialize({})
	GameState.deserialize({})
	# GameState emits positive saved counts only; explicitly clear every drawn type.
	if is_instance_valid(orbit_manager):
		for data in GameData.orbiters():
			orbit_manager.call("set_count", data.id, 0)
	Economy.refresh()
	SaveService.save_game()


func _update_stats() -> void:
	if visible and _stats != null:
		var count := int(orbit_manager.call("get_total_visible")) if is_instance_valid(orbit_manager) else 0
		_stats.text = "%d FPS  ·  %d gök cismi" % [Engine.get_frames_per_second(), count]
