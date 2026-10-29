class_name ClickableStar
extends Node3D
## Desktop clicks use Area3D. Touch taps are arbitrated by OrbitCamera before ray picking.

signal clicked(amount: BigNumber)

const RADIUS := 3.3

var _model: Node3D
var _shape: SphereShape3D
var _pulse: Tween


func _ready() -> void:
	_model = Node3D.new()
	add_child(_model)
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	var material := ShaderMaterial.new()
	material.shader = preload("res://game/star.gdshader")
	var surface := MeshInstance3D.new()
	surface.mesh = sphere
	surface.material_override = material
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(surface)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.66, 0.22, 0.5))
	gradient.set_color(1, Color(1.0, 0.43, 0.10, 0.0))
	gradient.add_point(0.38, Color(1.0, 0.59, 0.18, 0.12))
	var glow_texture := GradientTexture2D.new()
	glow_texture.gradient = gradient
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(0.5, 0.5)
	glow_texture.fill_to = Vector2(1.0, 0.5)
	glow_texture.width = 128
	glow_texture.height = 128
	var glow_material := StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow_material.albedo_texture = glow_texture
	glow_material.no_depth_test = false
	var quad := QuadMesh.new()
	quad.size = Vector2(22, 22)
	var halo := MeshInstance3D.new()
	halo.mesh = quad
	halo.material_override = glow_material
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model.add_child(halo)
	var area := Area3D.new()
	area.name = "ClickArea"
	area.input_ray_pickable = true
	area.collision_layer = 1
	area.collision_mask = 0
	_shape = SphereShape3D.new()
	_shape.radius = RADIUS * 1.25
	var collision := CollisionShape3D.new()
	collision.shape = _shape
	area.add_child(collision)
	area.input_event.connect(_on_input_event)
	add_child(area)


func fit_touch_target(camera: Camera3D, viewport_height: float) -> void:
	var visible_height := camera.size
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		visible_height = 2.0 * camera.global_position.distance_to(global_position) * tan(deg_to_rad(camera.fov) * 0.5)
	_shape.radius = maxf(RADIUS * 1.25, 48.0 * visible_height / maxf(viewport_height, 1.0))


func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_index: int) -> void:
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		activate()
		get_viewport().set_input_as_handled()


func activate() -> void:
	var amount := Economy.click()
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_model.scale = Vector3.ONE * 1.06
	_pulse = create_tween()
	_pulse.tween_property(_model, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_SINE)
	clicked.emit(amount)
