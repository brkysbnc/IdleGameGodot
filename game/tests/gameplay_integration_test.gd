extends Node
## Exercises the real composed scene, economy, shop, HUD, effects and debug tools.
## Run through tests/runner.tscn, in an isolated verification project (verify.py).

var _checks: int = 0
var _failures: int = 0
var _main: GameMain


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveService.save_path = "user://gameplay_verification.json"
	UpgradeSystem.deserialize({})
	GameState.deserialize({})
	Economy.refresh()
	_main = preload("res://main.tscn").instantiate()
	get_tree().root.add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_main.world.camera.current, "camera is active")
	_check(_main.world.get_viewport().physics_object_picking, "3D input picking enabled")
	_check(_main.world.get_node("OrbitGuides").mesh != null, "orbit guides built")
	var sky_texture: Texture2D = _main.world.get_node("WorldEnvironment").environment.sky.sky_material.panorama
	_check(sky_texture.get_width() <= 2048 and sky_texture.get_height() <= 1024, "panorama fits background texture budget")
	_test_safe_area()
	await _test_hud()
	await _test_pointer_routing()
	await _test_camera_controls()
	_test_star_input()
	await _test_shop()
	_test_effect_pool()
	_test_debug()
	await _test_layouts()
	if DisplayServer.get_name() != "headless":
		await _profile_rendered_scene()
	_main.debug_panel.set_fast_mode(false)
	_main.queue_free()
	await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		var path: String = SaveService.save_path + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("Gameplay integration: %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_safe_area() -> void:
	var bounds := Rect2(0, 0, 2400, 1080)
	_check(SafeArea.calculate_insets(bounds, Rect2(80, 0, 2280, 1040), Vector2(1.25, 1.0), 24)
		== Vector4i(88, 24, 56, 64), "notch and bottom inset converted to design pixels")
	_check(SafeArea.calculate_insets(bounds, bounds, Vector2.ONE, 24) == Vector4i(24, 24, 24, 24), "desktop inset unchanged")


func _test_hud() -> void:
	var before := _main.hud.refresh_count
	for i in 50:
		GameState.add_currency(BigNumber.from_float(1.0))
	_check(_main.hud.refresh_count == before, "HUD does not rebuild immediately for every signal")
	await get_tree().create_timer(0.12).timeout
	_check(_main.hud.refresh_count == before + 1, "50 signals coalesced into one HUD refresh")
	_check(_main.hud.currency_label.text == "50", "HUD shows latest balance")


func _test_star_input() -> void:
	var star := _main.world.star
	var before := GameState.get_currency()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	star._on_input_event(_main.world.camera, press, Vector3.ZERO, Vector3.UP, 0)
	_check(GameState.get_currency().equals(before.add(Economy.get_click_value())), "one press credits exactly one click")
	var after := GameState.get_currency()
	press.pressed = false
	star._on_input_event(_main.world.camera, press, Vector3.ZERO, Vector3.UP, 0)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	star._on_input_event(_main.world.camera, touch, Vector3.ZERO, Vector3.UP, 0)
	_check(GameState.get_currency().equals(after), "release and raw touch do not double count emulated mouse")


func _test_pointer_routing() -> void:
	var container: Control = _main.get_node("SafeArea/Layout/Stage/Observatory/ViewportContainer")
	var point := container.global_position + _main.world.camera.unproject_position(Vector3.ZERO)
	var before := GameState.get_currency()
	await _pointer_click(point)
	_check(GameState.get_currency().equals(before.add(Economy.get_click_value())), "real root viewport click reaches the 3D star once")
	before = GameState.get_currency()
	await _pointer_click(container.global_position + Vector2(8, 8))
	_check(GameState.get_currency().equals(before), "click outside the star does not give currency")
	var shop: Control = _main.get_node("%ShopPanel")
	await _pointer_click(shop.global_position + Vector2(50, 50))
	_check(GameState.get_currency().equals(before), "shop input does not click the star behind it")


func _pointer_click(point: Vector2, device: int = 0) -> void:
	var motion := InputEventMouseMotion.new()
	motion.device = device
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.device = device
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = point
	event.global_position = point
	event.pressed = true
	get_viewport().push_input(event, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	get_viewport().push_input(event, true)
	await get_tree().process_frame


func _test_camera_controls() -> void:
	var camera := _main.world.camera
	var container: Control = _main.get_node("SafeArea/Layout/Stage/Observatory/ViewportContainer")
	var center := container.global_position + camera.unproject_position(Vector3.ZERO)
	var initial_rotation := camera.get_view_rotation()
	var balance := GameState.get_currency()
	await _camera_drag(center, Vector2(140, 80), MOUSE_BUTTON_MIDDLE)
	_check(not camera.get_view_rotation().is_equal_approx(initial_rotation), "middle drag orbits the real camera")
	_check(GameState.get_currency().equals(balance), "middle drag over the star does not pay income")
	var rotation := camera.get_view_rotation()
	await _camera_drag(center, Vector2(-60, -100), MOUSE_BUTTON_RIGHT)
	_check(not camera.get_view_rotation().is_equal_approx(rotation), "right drag also orbits the real camera")
	_check(camera.basis.z.dot(camera.position.normalized()) > 0.9999, "camera remains aimed at the star after combined rotation")
	await _pointer_click(center)
	_check(GameState.get_currency().equals(balance.add(Economy.get_click_value())), "desktop star click still works after orbiting")
	balance = GameState.get_currency()
	var zoom := camera.get_zoom_ratio()
	await _wheel_at(center)
	_check(camera.get_zoom_ratio() < zoom, "wheel over game zooms towards the star")
	zoom = camera.get_zoom_ratio()
	var shop: Control = _main.get_node("%ShopPanel")
	await _wheel_at(shop.global_position + Vector2(50, 50))
	_check(is_equal_approx(camera.get_zoom_ratio(), zoom), "wheel over the shop never zooms the camera")
	rotation = camera.get_view_rotation()
	await _camera_drag(shop.global_position + Vector2(70, 80), Vector2(90, 50), MOUSE_BUTTON_RIGHT)
	_check(camera.get_view_rotation().is_equal_approx(rotation), "dragging shop UI never orbits the camera")
	var before_resize := camera.get_view_rotation()
	var before_zoom := camera.get_zoom_ratio()
	get_window().size = Vector2i(1440, 1080)
	for i in 4:
		await get_tree().process_frame
	_check(camera.get_view_rotation().is_equal_approx(before_resize) and is_equal_approx(camera.get_zoom_ratio(), before_zoom), "resizing keeps the selected angle and zoom")
	get_window().size = Vector2i(1920, 1080)
	for i in 4:
		await get_tree().process_frame
	var reset_button: Button = _main.get_node("%CenterView")
	await _pointer_click(reset_button.global_position + reset_button.size * 0.5)
	_check(camera.get_view_rotation().is_equal_approx(initial_rotation) and is_equal_approx(camera.get_zoom_ratio(), 1.0), "Center button resets orientation and zoom")
	_check(GameState.get_currency().equals(balance), "camera controls do not award currency")
	center = container.global_position + camera.unproject_position(Vector3.ZERO)
	await _pointer_click(center, InputEvent.DEVICE_ID_EMULATION)
	_check(GameState.get_currency().equals(balance), "emulated mouse never duplicates a raw touch")
	rotation = camera.get_view_rotation()
	_touch_at(0, true, center)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = center + Vector2(100, 60)
	drag.relative = Vector2(100, 60)
	get_viewport().push_input(drag, true)
	_touch_at(0, false, drag.position)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not camera.get_view_rotation().is_equal_approx(rotation), "one-finger drag orbits through the root viewport")
	_check(GameState.get_currency().equals(balance), "touch drag starting on the star does not count as a tap")
	_touch_at(0, true, center)
	_touch_at(0, false, center)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(GameState.get_currency().equals(balance.add(Economy.get_click_value())), "raw touch tap ray-picks the star exactly once")
	balance = GameState.get_currency()
	zoom = camera.get_zoom_ratio()
	_touch_at(0, true, center - Vector2(40, 0))
	_touch_at(1, true, center + Vector2(40, 0))
	drag.index = 1
	drag.position = center + Vector2(90, 0)
	drag.relative = Vector2(50, 0)
	get_viewport().push_input(drag, true)
	_touch_at(0, false, center - Vector2(40, 0))
	_touch_at(1, false, drag.position)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(camera.get_zoom_ratio() < zoom, "two-finger pinch zooms the camera")
	_check(GameState.get_currency().equals(balance), "pinching never taps the star")
	camera.reset_view()


func _camera_drag(at: Vector2, delta: Vector2, button: int) -> void:
	var press := InputEventMouseButton.new()
	press.position = at
	press.global_position = at
	press.button_index = button
	press.button_mask = MOUSE_BUTTON_MASK_MIDDLE if button == MOUSE_BUTTON_MIDDLE else MOUSE_BUTTON_MASK_RIGHT
	press.pressed = true
	get_viewport().push_input(press, true)
	var motion := InputEventMouseMotion.new()
	motion.position = at + delta
	motion.global_position = motion.position
	motion.relative = delta
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE if button == MOUSE_BUTTON_MIDDLE else MOUSE_BUTTON_MASK_RIGHT
	get_viewport().push_input(motion, true)
	press = press.duplicate()
	press.position = motion.position
	press.global_position = motion.position
	press.pressed = false
	press.button_mask = 0
	get_viewport().push_input(press, true)
	await get_tree().process_frame


func _wheel_at(at: Vector2) -> void:
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.position = at
	wheel.global_position = at
	wheel.pressed = true
	get_viewport().push_input(wheel, true)
	wheel = wheel.duplicate()
	wheel.pressed = false
	get_viewport().push_input(wheel, true)
	await get_tree().process_frame


func _touch_at(index: int, pressed: bool, point: Vector2) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.pressed = pressed
	touch.position = point
	get_viewport().push_input(touch, true)


func _test_shop() -> void:
	GameState.add_currency(BigNumber.from_float(1000000.0))
	var shop: ShopPanel = _main.get_node("%ShopPanel")
	_check(shop._orbiter_rows.size() == GameData.orbiters().size(), "all data-driven orbiter rows composed")
	var row: OrbiterRow = shop._orbiter_rows[0]
	var id: StringName = row._data.id
	row.refresh_affordability()
	row._buy_button.pressed.emit()
	_check(Economy.get_orbiter_count(id) == 1, "shop button buys the orbiter")
	_check(_main.world.orbit_manager.call("get_visible_count", id) == 1, "purchase immediately updates 3D orbit count")
	_check(Economy.get_income_per_sec().gt(BigNumber.zero()), "purchase generates passive income")
	_check(Economy.try_buy_upgrade(&"click_power_1"), "real upgrade content is connected")
	_check(UpgradeSystem.get_click_multiplier() > 1.0, "upgrade affects real multipliers")
	shop._menu.open_menu()
	_check(shop._menu.visible, "orbiter upgrade overlay opens")
	shop._menu.close_menu()
	_check(not shop._menu.visible, "orbiter upgrade overlay closes")
	await get_tree().create_timer(0.12).timeout
	_check(_main.hud.income_label.text == "+%s / sn" % Economy.get_income_per_sec().to_string_short(), "HUD receives purchase income")


func _test_effect_pool() -> void:
	var before := _main.effects.get_child_count()
	for i in 200:
		_main.effects.show_gain(BigNumber.from_float(12), Vector2(200, 200))
	_check(_main.effects.get_child_count() == before and before == ClickEffects.POOL_SIZE, "200 rapid clicks keep a fixed effect pool")
	_main.effects._process(2.0)
	_check(not _main.effects.is_processing(), "effects stop processing after expiration")


func _test_debug() -> void:
	var debug := _main.debug_panel
	_check(debug != null and not debug.visible, "debug panel starts hidden")
	for i in 5:
		debug.register_corner_tap()
	_check(debug.visible, "five corner taps open debug tools")
	debug.toggle()
	var key := InputEventKey.new()
	key.keycode = KEY_F1
	key.pressed = true
	debug._unhandled_key_input(key)
	_check(debug.visible, "F1 opens debug tools")
	debug.hide()
	var before := GameState.get_currency()
	debug.add_money(1000.0)
	_check(GameState.get_currency().gte(before.add(BigNumber.from_float(1000))), "debug currency action works")
	debug.populate_orbits()
	_check(_main.world.orbit_manager.call("get_total_visible") == 500, "500-orbiter test setup")
	debug.set_fast_mode(true)
	before = GameState.get_currency()
	var income := Economy.get_income_per_sec()
	debug._process(0.1)
	_check(GameState.get_currency().gte(before.add(income.mul_float(0.89))), "x10 mode adds nine extra income steps")
	debug.set_fast_mode(false)
	debug.reset_progress()
	_check(GameState.get_currency().is_zero(), "debug reset clears balance")
	_check(_main.world.orbit_manager.call("get_total_visible") == 0, "debug reset clears every drawn orbiter")
	_check(not UpgradeSystem.is_purchased(&"click_power_1"), "debug reset clears upgrades")
	_check(not debug.fast_mode, "reset restores normal speed")


func _test_layouts() -> void:
	# Representative populated game for screenshots, kept in the isolated test profile.
	GameState.add_currency(BigNumber.from_float(1250000))
	var counts: Array[int] = [28, 16, 8, 4, 2]
	var index := 0
	for data in GameData.orbiters():
		GameState.add_orbiter(data.id, counts[index])
		index += 1
	for resolution: Vector2i in [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1440, 1080)]:
		get_window().size = resolution
		await get_tree().create_timer(0.15).timeout
		for i in 6:
			await get_tree().process_frame
		var shop: Control = _main.get_node("%ShopPanel")
		var stage: Control = _main.get_node("SafeArea/Layout/Stage")
		_check(shop.get_global_rect().end.x <= _main.size.x + 1.0, "shop fits width at %s" % resolution)
		_check(not shop.get_global_rect().intersects(stage.get_global_rect()), "shop and game area do not overlap at %s" % resolution)
		_check(stage.size.x >= 700.0, "star viewport remains usable at %s" % resolution)
		var viewport := _main.world.get_viewport()
		var center := _main.world.camera.unproject_position(Vector3.ZERO)
		_check(Rect2(Vector2.ZERO, Vector2(viewport.size)).has_point(center), "star stays visible at %s" % resolution)
		for edge: Vector3 in [Vector3(30, 0, 0), Vector3(-30, 0, 0), Vector3(0, 0, 30), Vector3(0, 0, -30)]:
			_check(Rect2(Vector2.ZERO, Vector2(viewport.size)).has_point(_main.world.camera.unproject_position(edge)), "outer orbits stay visible at %s" % resolution)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			image.save_png("res://screenshots/game-%dx%d.png" % [resolution.x, resolution.y])


func _profile_rendered_scene() -> void:
	get_window().size = Vector2i(1920, 1080)
	_main.debug_panel.populate_orbits()
	for i in 30:
		await get_tree().process_frame
	var started := Time.get_ticks_usec()
	for i in 120:
		await get_tree().process_frame
	var elapsed := float(Time.get_ticks_usec() - started) / 1000000.0
	var stats := {
		"drawn_orbiters": _main.world.orbit_manager.call("get_total_visible"),
		"measured_fps": 120.0 / elapsed,
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"platform": OS.get_name(),
		"renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"device": RenderingServer.get_video_adapter_name(),
		"note": "Desktop measurement only. This does not validate a physical Android device.",
	}
	var file := FileAccess.open("res://screenshots/desktop-profile.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(stats, "\t"))
	file.close()
	_main.debug_panel.show()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshots/debug-panel.png")
	_main.debug_panel.hide()
	var shop: ShopPanel = _main.get_node("%ShopPanel")
	shop._menu.open_menu()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screenshots/orbiter-upgrades.png")
	shop._menu.close_menu()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAILED: ", message)
