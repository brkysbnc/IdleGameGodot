class_name SafeArea
extends MarginContainer
## One reusable safe-area container. Public calculation is independent of a device.

@export var base_margin: int = 24


func _ready() -> void:
	get_window().size_changed.connect(refresh)
	refresh()


static func calculate_insets(window_rect: Rect2, safe_rect: Rect2, scale: Vector2, base: int) -> Vector4i:
	var safe := window_rect.intersection(safe_rect)
	if not safe.has_area():
		return Vector4i(base, base, base, base)
	var factor := Vector2(maxf(scale.x, 0.001), maxf(scale.y, 0.001))
	return Vector4i(
		base + ceili(maxf(safe.position.x - window_rect.position.x, 0.0) / factor.x),
		base + ceili(maxf(safe.position.y - window_rect.position.y, 0.0) / factor.y),
		base + ceili(maxf(window_rect.end.x - safe.end.x, 0.0) / factor.x),
		base + ceili(maxf(window_rect.end.y - safe.end.y, 0.0) / factor.y))


func refresh() -> void:
	var insets := Vector4i(base_margin, base_margin, base_margin, base_margin)
	if OS.has_feature("mobile"):
		var window_rect := Rect2(Vector2(DisplayServer.window_get_position()), Vector2(DisplayServer.window_get_size()))
		insets = calculate_insets(window_rect, Rect2(DisplayServer.get_display_safe_area()),
			get_window().get_final_transform().get_scale(), base_margin)
	add_theme_constant_override("margin_left", insets.x)
	add_theme_constant_override("margin_top", insets.y)
	add_theme_constant_override("margin_right", insets.z)
	add_theme_constant_override("margin_bottom", insets.w)
