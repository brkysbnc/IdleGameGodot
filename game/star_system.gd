class_name StarSystem
extends Node3D

@onready var camera: OrbitCamera = $Camera3D
@onready var star: ClickableStar = $Star
@onready var orbit_manager: Node3D = $OrbitManager

var _extent: float = 30.0
var _tap_requests := PackedVector2Array()


func _ready() -> void:
	for file_name: String in DirAccess.get_files_at("res://game/visuals"):
		var path := file_name.trim_suffix(".remap")
		if path.ends_with(".tres"):
			var visual: Resource = load("res://game/visuals/" + path)
			if visual is OrbiterVisualData:
				_extent = maxf(_extent, visual.get_extent())
	camera.view_changed.connect(_on_view_changed)
	camera.tap_requested.connect(_queue_touch_tap)
	get_viewport().size_changed.connect(fit_camera)
	fit_camera()
	set_physics_process(false)


func fit_camera() -> void:
	var viewport_size := Vector2(get_viewport().size)
	camera.fit_to_extent(_extent, viewport_size)


func _on_view_changed() -> void:
	star.fit_touch_target(camera, float(get_viewport().size.y))


func _queue_touch_tap(point: Vector2) -> void:
	_tap_requests.append(point)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	for point in _tap_requests:
		var origin := camera.project_ray_origin(point)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(point) * camera.far, 1)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if not result.is_empty() and result.collider == star.get_node("ClickArea"):
			star.activate()
	_tap_requests.clear()
	set_physics_process(false)
