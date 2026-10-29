extends SceneTree
## Camera pose checks run without a scene tree, renderer or player save.
## godot --headless --path . --script res://game/tests/orbit_camera_test.gd

const CameraScript := preload("res://game/orbit_camera.gd")
const ANGLE_TOLERANCE := 0.01

var _checks: int = 0
var _failures: int = 0


func _init() -> void:
	_test_initial_pose()
	_test_full_rotation(Vector2.RIGHT, "yaw")
	_test_full_rotation(Vector2.DOWN, "pitch")
	_test_combined_rotations()
	_test_zoom_limits()
	_test_resize_preserves_view()
	_test_reset()
	print("OrbitCamera tests: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _camera() -> Camera3D:
	var camera: Camera3D = CameraScript.new()
	camera.call("fit_to_extent", 30.0, Vector2(1200, 720))
	return camera


func _rotation(camera: Camera3D) -> Quaternion:
	return camera.call("get_view_rotation")


func _test_initial_pose() -> void:
	var camera := _camera()
	var expected := Quaternion(Vector3.RIGHT, -atan(0.8))
	_check(_rotation(camera).angle_to(expected) < ANGLE_TOLERANCE, "default viewing angle")
	_near(float(camera.call("get_zoom_ratio")), 1.0, "default zoom")
	_assert_pose(camera, "initial")
	camera.free()


func _test_full_rotation(axis: Vector2, label: String) -> void:
	var camera := _camera()
	var initial := _rotation(camera)
	# Infer a small angular increment through the public API, without depending
	# on the implementation's sensitivity or drag direction.
	var probe_pixels := 10.0
	camera.call("rotate_view", axis * probe_pixels)
	var probe_angle := initial.angle_to(_rotation(camera))
	_check(probe_angle > 0.00001 and probe_angle < PI * 0.5, label + " responds to a small drag")
	if probe_angle <= 0.00001 or probe_angle >= PI * 0.5:
		camera.free()
		return
	camera.call("reset_view")
	var quarter_turn := probe_pixels * (TAU / probe_angle) / 4.0
	for i in 4:
		camera.call("rotate_view", axis * quarter_turn)
		_assert_pose(camera, "%s quarter %d" % [label, i + 1])
	_check(initial.angle_to(_rotation(camera)) < ANGLE_TOLERANCE, label + " completes a full turn without a pole clamp")
	camera.free()


func _test_combined_rotations() -> void:
	var camera := _camera()
	var distance := float(camera.call("get_orbit_distance"))
	for i in 80:
		camera.call("rotate_view", Vector2(173.0, 317.0 if i % 3 == 0 else -109.0))
	_assert_pose(camera, "many combined turns")
	_near(float(camera.call("get_orbit_distance")), distance, "rotation preserves orbital distance")
	camera.free()


func _test_zoom_limits() -> void:
	var camera := _camera()
	var initial := _rotation(camera)
	camera.call("zoom_by", 0.000001)
	_near(float(camera.call("get_zoom_ratio")), CameraScript.MIN_ZOOM_RATIO, "zoom-in limit")
	_assert_pose(camera, "closest zoom")
	camera.call("zoom_by", 1000000000.0)
	_near(float(camera.call("get_zoom_ratio")), CameraScript.MAX_ZOOM_RATIO, "zoom-out limit")
	_assert_pose(camera, "farthest zoom")
	_check(initial.angle_to(_rotation(camera)) < ANGLE_TOLERANCE, "zoom preserves viewing angle")
	camera.free()


func _test_resize_preserves_view() -> void:
	var camera := _camera()
	camera.call("rotate_view", Vector2(219, -391))
	camera.call("zoom_by", 0.7)
	var before_rotation := _rotation(camera)
	var before_zoom := float(camera.call("get_zoom_ratio"))
	var before_distance := float(camera.call("get_orbit_distance"))
	camera.call("fit_to_extent", 30.0, Vector2(500, 1000))
	_check(before_rotation.angle_to(_rotation(camera)) < ANGLE_TOLERANCE, "resize preserves viewing angle")
	_near(float(camera.call("get_zoom_ratio")), before_zoom, "resize preserves relative zoom")
	_check(not is_equal_approx(float(camera.call("get_orbit_distance")), before_distance), "narrow viewport changes fitted distance")
	_assert_pose(camera, "after resize")
	camera.free()


func _test_reset() -> void:
	var camera := _camera()
	var initial_rotation := _rotation(camera)
	var initial_distance := float(camera.call("get_orbit_distance"))
	camera.call("rotate_view", Vector2(731, 942))
	camera.call("zoom_by", 1.8)
	camera.call("reset_view")
	_check(initial_rotation.angle_to(_rotation(camera)) < ANGLE_TOLERANCE, "reset restores default angle")
	_near(float(camera.call("get_zoom_ratio")), 1.0, "reset restores default zoom")
	_near(float(camera.call("get_orbit_distance")), initial_distance, "reset restores fitted distance")
	_assert_pose(camera, "after reset")
	camera.free()


func _assert_pose(camera: Camera3D, label: String) -> void:
	var rotation := _rotation(camera)
	var finite := is_finite(rotation.x) and is_finite(rotation.y) and is_finite(rotation.z) and is_finite(rotation.w)
	_check(finite and camera.position.is_finite(), label + ": finite transform")
	_near(rotation.length(), 1.0, label + ": unit quaternion")
	_near(camera.basis.determinant(), 1.0, label + ": right-handed basis")
	var distance := float(camera.call("get_orbit_distance"))
	_check(is_finite(distance) and distance > 0.0, label + ": positive finite distance")
	_near(camera.position.length(), distance, label + ": position stays on orbit")
	_check((-camera.basis.z).dot(-camera.position.normalized()) > 0.9999, label + ": forward points at the star")


func _near(actual: float, expected: float, label: String) -> void:
	_check(absf(actual - expected) <= maxf(0.0001, absf(expected) * 0.0001), label)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAILED: ", label)
