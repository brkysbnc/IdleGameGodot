class_name ClickEffects
extends Control
## Fixed pools: a burst of clicks never creates more Labels or particles.

const POOL_SIZE := 12
const PARTICLE_COUNT := 32
const LIFE := 0.85

var _labels: Array[Label] = []
var _ages := PackedFloat32Array()
var _origins := PackedVector2Array()
var _particle_ages := PackedFloat32Array()
var _particle_origins := PackedVector2Array()
var _velocities := PackedVector2Array()
var _next: int = 0
var _particle_next: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ages.resize(POOL_SIZE)
	_ages.fill(LIFE)
	_origins.resize(POOL_SIZE)
	for i in POOL_SIZE:
		var text := GameTheme.label("", 34, GameTheme.GOLD)
		text.add_theme_color_override("font_shadow_color", Color("080e1d"))
		text.add_theme_constant_override("shadow_offset_y", 3)
		text.hide()
		add_child(text)
		_labels.append(text)
	_particle_ages.resize(PARTICLE_COUNT)
	_particle_ages.fill(LIFE)
	_particle_origins.resize(PARTICLE_COUNT)
	_velocities.resize(PARTICLE_COUNT)
	set_process(false)


func show_gain(amount: BigNumber, at: Vector2) -> void:
	var index := _next
	_next = (_next + 1) % POOL_SIZE
	_ages[index] = 0.0
	_origins[index] = at + Vector2(-30.0 + float(index % 3) * 18.0, -36.0)
	_labels[index].text = "+%s" % amount.to_string_short()
	_labels[index].position = _origins[index]
	_labels[index].modulate.a = 1.0
	_labels[index].show()
	for i in 6:
		var particle := _particle_next
		_particle_next = (_particle_next + 1) % PARTICLE_COUNT
		_particle_ages[particle] = 0.0
		_particle_origins[particle] = at
		_velocities[particle] = Vector2.from_angle(float(index * 6 + i) * 2.39996) * (50.0 + i * 14.0)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	var active := false
	for i in POOL_SIZE:
		if _ages[i] >= LIFE:
			continue
		_ages[i] += delta
		var progress := minf(_ages[i] / LIFE, 1.0)
		_labels[i].position = _origins[i] + Vector2(0, -94.0 * progress)
		_labels[i].modulate.a = 1.0 - progress
		_labels[i].visible = progress < 1.0
		active = active or progress < 1.0
	for i in PARTICLE_COUNT:
		if _particle_ages[i] < LIFE:
			_particle_ages[i] += delta
			active = active or _particle_ages[i] < LIFE
	queue_redraw()
	set_process(active)


func _draw() -> void:
	for i in PARTICLE_COUNT:
		if _particle_ages[i] < LIFE:
			var age := _particle_ages[i]
			var color := GameTheme.GOLD
			color.a = 1.0 - age / LIFE
			draw_circle(_particle_origins[i] + _velocities[i] * age, 3.5 * color.a, color)
