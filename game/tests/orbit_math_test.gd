extends SceneTree
## B5 testi: orbit_math.gd saf fonksiyonlari. Node/autoload gerekmez.
## Calistirma (proje kokunden):
##   godot --headless --path . --script res://game/tests/orbit_math_test.gd
## Basarisiz test varsa cikis kodu 1 olur.

const OrbitMath := preload("res://game/orbit_math.gd")

var _failures: int = 0
var _checks: int = 0


func _init() -> void:
	_test_band_radius_stays_in_band()
	_test_band_radius_spread_zero()
	_test_band_radius_is_evenly_distributed()
	_test_phase_range_and_distinct()
	_test_next_capacity()
	_test_init_scale_only_touches_range()
	_test_update_flat_orbit()
	_test_update_inclined_orbit_keeps_radius()
	_test_update_leaves_scale_and_extra_instances_alone()
	_test_motion_matches_angular_speed()
	print("OrbitMath testleri: %d kontrol, %d basarisiz" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_band_radius_stays_in_band() -> void:
	var inside: bool = true
	for i: int in 2000:
		var r: float = OrbitMath.band_radius(i, 10.0, 4.0)
		if r < 8.0 - 0.0001 or r > 12.0 + 0.0001:
			inside = false
	_check(inside, "yaricap her zaman [8, 12] bandinda (2000 orbiter)")


func _test_band_radius_spread_zero() -> void:
	_check(is_equal_approx(OrbitMath.band_radius(37, 10.0, 0.0), 10.0), "spread 0 -> tam merkez yaricap")


func _test_band_radius_is_evenly_distributed() -> void:
	var sum: float = 0.0
	var count: int = 1000
	for i: int in count:
		sum += OrbitMath.band_radius(i, 10.0, 4.0)
	var mean: float = sum / float(count)
	_check(absf(mean - 10.0) < 4.0 * 0.02, "yaricaplar banta duzgun dagilir (ortalama merkeze yakin: %s)" % mean)


func _test_phase_range_and_distinct() -> void:
	var seen: Dictionary = {}
	var in_range: bool = true
	for i: int in 200:
		var phase: float = OrbitMath.start_phase(i)
		if phase < 0.0 or phase >= TAU:
			in_range = false
		seen[snappedf(phase, 0.0001)] = true
	_check(in_range, "faz [0, TAU) araliginda")
	_check(seen.size() == 200, "ilk 200 orbiter'in fazi birbirinden farkli (%d benzersiz)" % seen.size())


func _test_next_capacity() -> void:
	_check(OrbitMath.next_capacity(5, 0, 100) == 16, "0 -> en az 16 acilir")
	_check(OrbitMath.next_capacity(16, 16, 100) == 16, "sigiyorsa degismez")
	_check(OrbitMath.next_capacity(17, 16, 100) == 32, "tasinca 2 kati")
	_check(OrbitMath.next_capacity(65, 16, 1000) == 128, "ust uste 2 katina cikar")
	_check(OrbitMath.next_capacity(100, 32, 100) == 100, "limit'i asmaz")
	_check(OrbitMath.next_capacity(5, 0, 10) == 10, "limit MIN_CAPACITY'den kucukse limit gecerli")
	_check(OrbitMath.next_capacity(0, 0, 100) == 0, "ihtiyac yoksa 0 kalir")


func _test_init_scale_only_touches_range() -> void:
	var buffer: PackedFloat32Array = _filled(3, -1.0)
	OrbitMath.init_scale(buffer, 1, 3, 0.5)
	_check(buffer[0] == -1.0 and buffer[11] == -1.0, "aralik disindaki instance (0) degismedi")
	var base: int = OrbitMath.FLOATS_PER_INSTANCE
	var expected: Array[float] = [0.5, 0.0, 0.0, 0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.5, 0.0]
	var matches: bool = true
	for k: int in 12:
		if buffer[base + k] != expected[k] or buffer[2 * base + k] != expected[k]:
			matches = false
	_check(matches, "kosegen = olcek, konum = 0 (instance 1 ve 2)")


func _test_update_flat_orbit() -> void:
	var radii: PackedFloat32Array = PackedFloat32Array([5.0, 8.0, 11.0])
	var phases: PackedFloat32Array = PackedFloat32Array([0.0, 1.0, 2.0])
	var buffer: PackedFloat32Array = _filled(3, 0.0)
	OrbitMath.update_positions(buffer, 3, radii, phases, 2.0, 0.5, 0.0, 1.0)
	for i: int in 3:
		var angle: float = phases[i] + 0.5 * 2.0
		var pos: Vector3 = OrbitMath.position_at(buffer, i)
		_check(absf(pos.length() - radii[i]) < 0.001, "duz yorunge: %d. orbiter yaricapta" % i)
		_check(absf(pos.y) < 0.0001, "duz yorunge: %d. orbiter y=0" % i)
		_check(absf(pos.x - cos(angle) * radii[i]) < 0.001 and absf(pos.z - sin(angle) * radii[i]) < 0.001, "duz yorunge: %d. konum dogru" % i)


func _test_update_inclined_orbit_keeps_radius() -> void:
	var incl: float = deg_to_rad(30.0)
	var radii: PackedFloat32Array = PackedFloat32Array([10.0, 12.0])
	var phases: PackedFloat32Array = PackedFloat32Array([0.7, 3.9])
	var buffer: PackedFloat32Array = _filled(2, 0.0)
	OrbitMath.update_positions(buffer, 2, radii, phases, 3.0, 0.2, sin(incl), cos(incl))
	for i: int in 2:
		var pos: Vector3 = OrbitMath.position_at(buffer, i)
		_check(absf(pos.length() - radii[i]) < 0.001, "egik yorunge de yaricapi korur (%d)" % i)
		var along: float = sin(phases[i] + 0.2 * 3.0) * radii[i]
		_check(absf(pos.y - along * sin(incl)) < 0.001, "egik yorunge y bileseni dogru (%d)" % i)


func _test_update_leaves_scale_and_extra_instances_alone() -> void:
	var buffer: PackedFloat32Array = _filled(3, 123.0)
	OrbitMath.init_scale(buffer, 0, 3, 0.25)
	buffer[2 * OrbitMath.FLOATS_PER_INSTANCE + OrbitMath.OFFSET_X] = 123.0 # 3. instance: sentinel
	var radii: PackedFloat32Array = PackedFloat32Array([5.0, 6.0, 7.0])
	var phases: PackedFloat32Array = PackedFloat32Array([0.0, 1.0, 2.0])
	OrbitMath.update_positions(buffer, 2, radii, phases, 1.0, 1.0, 0.0, 1.0) # sadece ilk 2
	_check(buffer[0] == 0.25 and buffer[5] == 0.25 and buffer[10] == 0.25, "olcek degerleri bozulmadi")
	_check(buffer[OrbitMath.FLOATS_PER_INSTANCE] == 0.25, "2. instance'in olcegi bozulmadi")
	_check(buffer[2 * OrbitMath.FLOATS_PER_INSTANCE + OrbitMath.OFFSET_X] == 123.0, "count disindaki instance'a dokunulmadi")


func _test_motion_matches_angular_speed() -> void:
	var radii: PackedFloat32Array = PackedFloat32Array([9.0])
	var phases: PackedFloat32Array = PackedFloat32Array([0.4])
	var buffer: PackedFloat32Array = _filled(1, 0.0)
	OrbitMath.update_positions(buffer, 1, radii, phases, 0.0, 0.3, 0.0, 1.0)
	var before: Vector3 = OrbitMath.position_at(buffer, 0)
	OrbitMath.update_positions(buffer, 1, radii, phases, 2.0, 0.3, 0.0, 1.0)
	var after: Vector3 = OrbitMath.position_at(buffer, 0)
	var turned: float = atan2(after.z, after.x) - atan2(before.z, before.x)
	_check(absf(turned - 0.3 * 2.0) < 0.001, "2 sn'de speed*2 radyan doner (%s)" % turned)


func _filled(instance_count: int, value: float) -> PackedFloat32Array:
	var buffer: PackedFloat32Array = PackedFloat32Array()
	buffer.resize(instance_count * OrbitMath.FLOATS_PER_INSTANCE)
	buffer.fill(value)
	return buffer


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("BASARISIZ: %s" % label)
