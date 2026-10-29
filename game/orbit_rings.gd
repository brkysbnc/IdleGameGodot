extends MeshInstance3D
## All orbit guides share one mesh/material; geometry is built once.

const SEGMENTS := 160


func _ready() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for file_name: String in DirAccess.get_files_at("res://game/visuals"):
		var path := file_name.trim_suffix(".remap")
		if not path.ends_with(".tres"):
			continue
		var visual: Resource = load("res://game/visuals/" + path)
		if not visual is OrbiterVisualData:
			continue
		var radius: float = visual.orbit_radius
		var tilt := deg_to_rad(float(visual.inclination_deg))
		for i in SEGMENTS:
			var a := float(i) / SEGMENTS * TAU
			var b := float(i + 1) / SEGMENTS * TAU
			var points: Array[Vector3] = [
				_point(a, radius - 0.07, tilt), _point(b, radius - 0.07, tilt), _point(b, radius + 0.07, tilt),
				_point(a, radius - 0.07, tilt), _point(b, radius + 0.07, tilt), _point(a, radius + 0.07, tilt)]
			for point in points:
				surface.add_vertex(point)
	mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("293c58")
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _point(angle: float, radius: float, tilt: float) -> Vector3:
	return Vector3(cos(angle) * radius, sin(angle) * radius * sin(tilt), sin(angle) * radius * cos(tilt))
