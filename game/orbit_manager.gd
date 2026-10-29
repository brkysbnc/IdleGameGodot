extends Node3D
## B5 (#14). TUM orbiter'lari cizer ve hareket ettirir.
## - Tur basina TEK MultiMeshInstance3D, orbiter basina node YOK.
## - Tek yonetici, tek _process: konumlar toplu hesaplanir ve tek atamayla GPU'ya gider.
## - Kare basina allocation yok: buffer onceden ayrilir, yerinde yazilir. Kapasite sadece sayi buyuyunce artar.
## - Sayi EventBus.orbiter_count_changed ile gelir, UI/Economy ile dogrudan bagi yok.
## - Hicbir orbiter yokken _process kapali (idle oyunun ilk dakikalarinda sifir maliyet).
## - Golge yok, hafif shader yok (vertex basi aydinlatma), dusuk poligonlu kure (mobil hedefi).
##
## Sahneye (B7 main.tscn) yildizla ayni konuma, orijine koyulur. Yorungeler orijin etrafindadir.
## Gorsel veri game/visuals/*.tres (OrbiterVisualData, B6). Yeni orbiter = yeni .tres, kod degismez.
##
## Cizim siniri: bir turde sahip olunan sayi `max_instances`'i asarsa gelir yine sayilir, sadece
## o kadar orbiter cizilir (mobil: toplam ~500). Gercek cihazda profil al, sinirlari .tres'lerden ayarla.

const OrbitMath := preload("res://game/orbit_math.gd")
const VisualScript := preload("res://game/visuals/orbiter_visual_data.gd")
const VISUALS_DIR := "res://game/visuals"

## Bir orbiter turunun cizim durumu.
class OrbitType extends RefCounted:
	var id: StringName
	var speed: float = 0.0
	var size: float = 1.0
	var center: float = 10.0
	var spread: float = 0.0
	var incl_sin: float = 0.0
	var incl_cos: float = 1.0
	var max_instances: int = 100
	var multimesh: MultiMesh
	var buffer: PackedFloat32Array = PackedFloat32Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	var phases: PackedFloat32Array = PackedFloat32Array()
	var capacity: int = 0 # ayrilmis instance sayisi
	var visible: int = 0 # cizilen instance sayisi
	var owned: int = 0 # oyuncunun sahip oldugu gercek sayi

var _types: Dictionary = {} # StringName -> OrbitType
var _type_list: Array[OrbitType] = [] # _process'te Dictionary.values() allocation'i olmasin diye
var _time: float = 0.0
var _shared_mesh: Mesh


func _ready() -> void:
	setup(_load_visuals())
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.connect("orbiter_count_changed", _on_orbiter_count_changed)
	else:
		push_warning("OrbitManager: EventBus autoload'u bulunamadi, orbiter sayisi takip edilmeyecek.")
	# Sahne, kayit yuklendikten SONRA acilir: kacirdigimiz sinyaller yerine mevcut sayilari oku.
	var economy: Node = get_node_or_null("/root/Economy")
	if economy != null:
		for orbit_type: OrbitType in _type_list:
			set_count(orbit_type.id, int(economy.call("get_orbiter_count", orbit_type.id)))


func _process(delta: float) -> void:
	step(delta)


# ---------------------------------------------------------------- Genel API

## Gorsel tanimlarindan cizim turlerini kurar (test icin dis API).
func setup(visuals: Array) -> void:
	if _shared_mesh == null:
		_shared_mesh = _make_shared_mesh()
	for visual: Resource in visuals:
		_add_type(visual)
	set_process(false)


## Bir turun sahip olunan sayisi degisti. Cizilen sayi max_instances ile sinirlanir.
func set_count(id: StringName, count: int) -> void:
	var orbit_type: OrbitType = _types.get(id)
	if orbit_type == null:
		return # gorseli olmayan orbiter: gelir calisir, sadece cizilmez
	orbit_type.owned = maxi(count, 0)
	var wanted: int = mini(orbit_type.owned, orbit_type.max_instances)
	if wanted == orbit_type.visible:
		return
	if wanted > orbit_type.capacity:
		_grow(orbit_type, wanted)
	orbit_type.visible = wanted
	orbit_type.multimesh.visible_instance_count = wanted
	_write_positions(orbit_type) # yeni instance'lar bir kare orijinde gorunmesin
	_refresh_processing()


## Zamani ilerletip konumlari gunceller. _process cagirir, testte dogrudan cagrilabilir.
func step(delta: float) -> void:
	_time += delta
	for orbit_type: OrbitType in _type_list:
		if orbit_type.visible > 0:
			_write_positions(orbit_type)


func get_visible_count(id: StringName) -> int:
	var orbit_type: OrbitType = _types.get(id)
	return orbit_type.visible if orbit_type != null else 0


func get_owned_count(id: StringName) -> int:
	var orbit_type: OrbitType = _types.get(id)
	return orbit_type.owned if orbit_type != null else 0


func get_capacity(id: StringName) -> int:
	var orbit_type: OrbitType = _types.get(id)
	return orbit_type.capacity if orbit_type != null else 0


func get_total_visible() -> int:
	var total: int = 0
	for orbit_type: OrbitType in _type_list:
		total += orbit_type.visible
	return total


## Debug paneli (B10) ve testler icin: i. orbiter'in yerel konumu.
func get_instance_position(id: StringName, index: int) -> Vector3:
	var orbit_type: OrbitType = _types.get(id)
	if orbit_type == null or index < 0 or index >= orbit_type.visible:
		return Vector3.ZERO
	return OrbitMath.position_at(orbit_type.buffer, index)


# ------------------------------------------------------------------ Kurulum

func _add_type(visual: Resource) -> void:
	var problems: PackedStringArray = visual.call("validate")
	var id: StringName = visual.get("orbiter_id")
	if not problems.is_empty():
		push_warning("OrbitManager: '%s' gorseli atlandi (%s)." % [id, ", ".join(problems)])
		return
	if _types.has(id):
		push_warning("OrbitManager: '%s' birden fazla tanimlanmis, ilki kullanildi." % id)
		return

	var orbit_type := OrbitType.new()
	orbit_type.id = id
	orbit_type.speed = visual.get("angular_speed")
	orbit_type.size = visual.get("size")
	orbit_type.center = visual.get("orbit_radius")
	orbit_type.spread = visual.get("orbit_spread")
	orbit_type.max_instances = visual.get("max_instances")
	var inclination: float = deg_to_rad(float(visual.get("inclination_deg")))
	orbit_type.incl_sin = sin(inclination)
	orbit_type.incl_cos = cos(inclination)

	var custom_mesh: Mesh = visual.get("mesh")
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = custom_mesh if custom_mesh != null else _shared_mesh
	orbit_type.multimesh = multimesh

	var extent: float = visual.call("get_extent")
	var instance := MultiMeshInstance3D.new()
	instance.name = String(id)
	instance.multimesh = multimesh
	instance.material_override = _make_material(visual)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Instance'lar her kare hareket ediyor, otomatik AABB guncellenmez: tum yorunge alanini kapsayan sabit kutu ver.
	instance.custom_aabb = AABB(Vector3.ONE * -extent, Vector3.ONE * (extent * 2.0))
	add_child(instance)

	_types[id] = orbit_type
	_type_list.append(orbit_type)


## Kapasiteyi buyutur. Sadece sayi artinca calisir (satin alma aninda), kare basina degil.
func _grow(orbit_type: OrbitType, needed: int) -> void:
	var old_capacity: int = orbit_type.capacity
	var new_capacity: int = OrbitMath.next_capacity(needed, old_capacity, orbit_type.max_instances)
	orbit_type.multimesh.instance_count = new_capacity # GPU verisini sifirlar, buffer yeniden atanir
	orbit_type.buffer.resize(new_capacity * OrbitMath.FLOATS_PER_INSTANCE)
	orbit_type.radii.resize(new_capacity)
	orbit_type.phases.resize(new_capacity)
	for i: int in range(old_capacity, new_capacity):
		orbit_type.radii[i] = OrbitMath.band_radius(i, orbit_type.center, orbit_type.spread)
		orbit_type.phases[i] = OrbitMath.start_phase(i)
	OrbitMath.init_scale(orbit_type.buffer, old_capacity, new_capacity, orbit_type.size)
	orbit_type.capacity = new_capacity


func _write_positions(orbit_type: OrbitType) -> void:
	OrbitMath.update_positions(
		orbit_type.buffer, orbit_type.visible, orbit_type.radii, orbit_type.phases,
		_time, orbit_type.speed, orbit_type.incl_sin, orbit_type.incl_cos)
	orbit_type.multimesh.buffer = orbit_type.buffer


func _refresh_processing() -> void:
	set_process(get_total_visible() > 0)


func _on_orbiter_count_changed(id: StringName, count: int) -> void:
	set_count(id, count)


# --------------------------------------------------------------- Varliklar

## Tum turlerin paylastigi dusuk poligonlu kure (cap 1 birim).
func _make_shared_mesh() -> Mesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 8
	sphere.rings = 4
	return sphere


func _make_material(visual: Resource) -> Material:
	var material := StandardMaterial3D.new()
	material.albedo_color = visual.get("color")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX # piksel basi isik yok: mobilde ucuz
	var texture: Texture2D = visual.get("texture")
	if texture != null:
		material.albedo_texture = texture
	return material


func _load_visuals() -> Array:
	var result: Array = []
	var dir: DirAccess = DirAccess.open(VISUALS_DIR)
	if dir == null:
		push_warning("OrbitManager: '%s' acilamadi." % VISUALS_DIR)
		return result
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name: String in names:
		var clean_name: String = file_name.trim_suffix(".remap") # export'ta .remap'li
		if not clean_name.ends_with(".tres"):
			continue
		var resource: Resource = load(VISUALS_DIR.path_join(clean_name))
		if resource != null and resource.get_script() == VisualScript:
			result.append(resource)
		else:
			push_warning("OrbitManager: '%s' OrbiterVisualData degil, atlandi." % clean_name)
	return result
